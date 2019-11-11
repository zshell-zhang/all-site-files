---
title: curator 使用注意点总结
date: 2019-09-07 21:43:46
categories:
 - zookeeper
 - curator
tags:
 - zookeeper
 - curator
---

> 最近做的项目涉及到 server 端的服务注册与 client 端的服务发现, 其中大量使用到了 zookeeper; 在实践过程中不可避免得遇到了很多问题与坑, 历经数月的打磨与沉淀, 总算是步入了一个稳定的阶段, 至此总结一番是十分必要的;

<!--more-->

------

由于我在项目中直接使用了 curator (v4.1.0) 作为 zookeeper 客户端, 所以这篇文章便叫做了 "curator 使用注意点总结"; 然而, curator 对原生 zkclient 的良好封装, 使得很多原生的坑被处理掉了, 面向 curator 编程是感知不到的, 所以出于刨根问底, 我又写了一篇文章分析 curator 对 zookeeper 原生客户端的封装以及坑的处理: [curator 对 zookeeper 的封装逻辑梳理]();

### **系统关闭时, zkclient 一定要同时关闭**
无论将 zookeeper 用作什么场景, 在系统关闭时, 都应该调用 zkclient 的 close 接口 (如 curator 的 close() 方法); 或许在部分场景下不调用 close 不会导致业务上的问题, 但这个语义理应被当做规范强制执行;
那么什么情况不调用 close 会导致严重问题呢? **当系统需要创建临时节点时!**
举一个典型的例子, 将 zookeeper 当作服务发布与发现的注册中心, 这种场景需要 service provider 将自身信息以临时节点的方式写入 zk, service consumer 订阅 zk 的节点变更, 以及时发现服务提供者的地址; provider 维护的 zkclient 在 zk server 上维持一个 session, 如果 provider 在系统关闭时没有及时 close zkclient, 这个 session 将一直保持直到设定的 sessionTimeout 过期时间, 而后才会通知 consumer 有 provider 节点下线; **那么从 provider 关闭到 sessionTimeout 这个时间段内, 实际上 provider 已经无法提供服务了, 但 zookeeper 却无法及时通知到 consumer**, 一旦这个时间比较长且 consumer 没有调用失败后的 failover 或熔断, 此场景将导致服务调用大量失败;
以上例子虽然杀伤力挺大的, 但毕竟还是一把明枪, 至少我们可以很快发现; 而下面我将举的第二个例子, 虽然杀伤力没有第一个例子这么猛烈, 但却是一支难防的暗箭, 不易察觉!
zkclient 与 zk server 的一次正常连接通过一个 session 来维持, 每个 session 都有自己的唯一的 sessionId; 对于 zk 临时节点 (EPHEMERAL) 而言, 有一个重要的特性是排他性: 相同 path 下的节点同一时间只允许有一个 session 占有它, 我们可以通过 zkclient 观察一个临时节点的 stat:
``` bash
cZxid = 0x2641accf49
ctime = Fri Aug 16 17:08:45 CST 2019
mZxid = 0x2664d0fb75
mtime = Tue Aug 20 14:36:43 CST 2019
pZxid = 0x2641accf49
cversion = 0
dataVersion = 14
aclVersion = 0
ephemeralOwner = 0x96cf2ab2799b53e
dataLength = 46
numChildren = 0
```
其中有一个属性叫做 `ephemeralOwner`, 对于临时节点, 这个属性总会被赋值为一个 sessionId, 表示这个节点目前唯一属于这个 session, 若有其他 session 想要设置此节点是不生效的 (删除除外);
那么对于服务注册与发现的场景, 会存在一种情况: provider 系统快速重启, 且没有 close zkclient, 在其试图重新注册相同路径下的临时节点时, 由于之前的旧 session 还没有过期, **根据排他性, 新注册的节点是不生效的; 等到旧 session timeout 节点下线之后, 这个 provider 提供的服务就无法被 client 端发现了;** 如果我们只观察业务监控指标, 几乎不会有任何异样, 最多就是 rt 涨了点 (毕竟少了一台机器), 这个问题只有去观察机器指标, 才能发现有一台机器的网络流量和 cpu/load 掉下去了, 而等我们发现时, 可能已经过了很长时间了;
以上两个例子, 如果在系统结束的时候正确得关闭 zkclient, 便可以及时关闭 session, 下线节点, 避免问题的发生!

### **临时节点第一次创建前要确保其已被删除**
上一小节中指出了及时关闭 zkclient 可以有效避免 "无用临时节点" 与 "节点无故下线" 的问题, 但是这并非是能够完全避免问题的办法, 有的时候会有一些更极端的情况发生, 比如说: 服务假死, 不响应任何请求, 包括 kill -15 信号; **这个时候我们可能要使用 kill -9 强制杀死进程, 这个过程是不会给进程机会去作 zkclient close 的**, 那么就仍然存在可能性导致上一小节提到的第二种情况 "节点无故下线";
所以我们要如何操作才能确保避免类似问题的发生呢? 其实很简单, 我们只需要主动在创建节点的时候检查节点是否已经存在, 如果存在, 先删除之, 然后再创建, 就可以避免了; 临时节点的排他性只针对 set 操作, 对于删除操作是没有限制的;

### **创建节点时, 一定要带着初始化数据**
如果像如下代码, 指定 path 创建一个节点, 而不带任何数据, 会导致什么事情发生呢?
``` java
// CuratorFramework zkClient
zkClient.create().creatingParentsIfNeeded().withMode(createMode).forPath(nodePath);
```
v4.x 的 curator 会默认将 zkclient 所在机器的 IP 地址作为内容写入节点中, 且看下方我截出来的关键源码:
``` java
// CreateBuilderImpl, 不给定初始化数据便会使用 CuratorFrameworkImpl 给定的 defaultData
@Override
public String forPath(String path) throws Exception {
    return forPath(path, client.getDefaultData());
}
```
``` java
// CuratorFrameworkImpl, 使用 CuratorFrameworkFactory.Builder 中的 defaultData 作为默认值
public CuratorFrameworkImpl(CuratorFrameworkFactory.Builder builder) {
    ...
    byte[] builderDefaultData = builder.getDefaultData();
    defaultData = (builderDefaultData != null) ? Arrays.copyOf(builderDefaultData, builderDefaultData.length) : new byte[0];
    ...
}
```
``` java
public class CuratorFrameworkFactory {
    public static class Builder {
        ...
        private byte[] defaultData = LOCAL_ADDRESS;
        ...
    }
}
```
如果这里使用节点的作用是服务注册, client 端接收到了节点变更并试图解析, **读出了这个硬生生的 IP 地址很可能并不符合 client - server 约定的数据协议格式, 那么就只能解析报错了**; 所以为了不埋坑, 我们在创建节点时一定要带上我们自己控制的初始化数据:
``` java
// CuratorFramework zkClient
zkClient.create().creatingParentsIfNeeded().withMode(createMode).forPath(nodePath, data);
```

### **zk 事件回调里耗时任务要异步执行**
zkclient 有两个后台线程: IO 和心跳线程 (SendThread) 与事件处理线程 (EventThread), 均为单线程, 且互相独立; 如果多个事件在短时间内一起到来, 会在 EventThread 中串行执行, **当有耗时的事件回调任务长时间占用线程资源时, 后续的事件便会处于饥饿状态而得不到及时处理, 在一些场景下会发生比较严重的问题 (如节点上下线)**;
不过需要指出的是, 由于 SendThread 与 EventThread 互为独立, 当事件饥饿现象发生时, 并不会影响 zkclient 的心跳;

### **ExponentialBackoffRetry 的重试次数**
在正常情况下, 每隔一个 server 端配置的 tickTime 时间间隔, zkclient 便会向 server 发送心跳以保持 session; 在遇到环境的波动 (网络抖动, 长时间 FGC, 调试断点等) 时, 发送心跳失败, zkclient 会接收到 state 为 Disconnected 的事件, 接下来 zkclient 会尽可能重试 (当然, 长时间 FGC, 调试断点会导致无法重试) 直到再次连接上 server 并重新接收到 state 为 SyncConnected 的事件; 而如果直到 sessionTimeout 都没有重新连上 server, 便会收到 state 为 Expired 的事件, 此时就算环境波动解除了, 再连 server 也会被拒绝, 当下的 session 已经过期, 什么操作都做不了了, 此刻唯一能做的就剩重建 zkclient 了;
curator 提供了重建 zkclient 的逻辑封装, 并使用 `RetryPolicy` 接口以定制重建的策略; 这个接口有很多实现, 包括:

1. 重试一次 (RetryOneTime)
2. 重试 N 次 (RetryNTimes)
3. 不停重试 (RetryForever)
4. 重试一段时间 (RetryUntilElapsed)
5. 指数退避重试 N 次 (ExponentialBackoffRetry)

其中, 使用最普遍的便是第五个 ExponentialBackoffRetry 了, 因为如果真得走到了需要重建 zkclient 的地步, 可能已经发生了比较严重的问题了 (比如网络故障), 一时半会儿恢复不了, 如果使用其他策略频繁重试, 非但无用, 当重试的机器很多的时候反而还会加重负担; 指数退避算法在局域网网路冲突处理中也有着广泛的应用;
[采用zookeeper的EPHEMERAL节点机制实现服务集群的陷阱](http://cms.smartfeng.com/technology/others/zookeeper-qa-ephemeral) 这篇文章认为, ExponentialBackoffRetry 有一个坑, **它设置了最大允许重试次数为 29, 当发生机房长时间断网时, 有可能重试次数不够导致 zkclient 永久失效**; 他提出的问题在于以下代码:
``` java
private static final int MAX_RETRIES_LIMIT = 29;
private static int validateMaxRetries(int maxRetries) {
    if ( maxRetries > MAX_RETRIES_LIMIT ) {
        log.warn(String.format("maxRetries too large (%d). Pinning to %d", maxRetries, MAX_RETRIES_LIMIT));
        maxRetries = MAX_RETRIES_LIMIT;
    }
    return maxRetries;
}
```
那么为什么不是 28, 不是 30, 却偏偏是 29, 我猜可能与下面这段代码有关:
``` java
@Override
protected long getSleepTimeMs(int retryCount, long elapsedTimeMs) {
    long sleepMs = baseSleepTimeMs * Math.max(1, random.nextInt(1 << (retryCount + 1)));
    if ( sleepMs > maxSleepMs ) {
        log.warn(String.format("Sleep extension too large (%d). Pinning to %d", sleepMs, maxSleepMs));
        sleepMs = maxSleepMs;
    }
    return sleepMs;
}
```
当 retryCount 到了 29, 那么 sleepMs 的取值范围会变成 [1, 1 << 30], 而有符号整数的取值范围是 [-2^31 + 1, 2^31 - 1], 如果 retryCount 再加到 30, 就要发生数据溢出了! 所以这可能就是 netflix 的工程师将 MAX_RETRIES_LIMIT 设置为 29 的原因吧;
从代码逻辑来看, 确实有可能连续 29 次重试的时间间隔都比较短, 导致还没撑到网络故障恢复就彻底死了; 
在我看来, 这个指数退避算法可能还有一个坑: 默认的 maxSleepMs 被设置为了 `Integer.MAX_VALUE`;
试想一下, 假定 baseSleepTimeMs == 1000, 如果第 N 次重试 sleepMs 的取值正好取到了上限 1 << N, 当 N 等于 12 时, 对应的 sleepMs 已经超过了 1 小时, 当 N 等于 16 时, 对应的 sleepMs 就快要达到 1 天了! 一天才重试一次, 那和死了也没什么区别了; 我认为, 当发生网络故障久久无法恢复时, 理想的重试时间应该控制在 [30min, 1h] 区间内, 我们其实可以设计一个组合策略: 当刚发生故障时, 前几次重试使用指数退避算法, 当连续数十次重试都无效, 时间区间已经增长到  1h 时, 锁定时间区间, 在 [30min, 1h] 的范围内随机产生下一次重试时间, 无限次重试, 直到故障恢复为止, 这样做的好处如下:

1. 可以避免由于重试次数有限, 重试时间间隔短引起的短时间内 zkclient 永久失效;
2. 可以避免由于重试时间间隔太长导致实质上等效于失效, 控制最大重试时间, 当故障恢复时确保 zkclient 也及时恢复;
3. 可以通过随机产生下一次重试时间, 让大量 zkclient 尽可能错开重试时间, 削去网络拥塞;

下面是一个简单的示例:
``` java
private static final int POLICY_SWITCH_THRESHOLD = 12;
private static final int BASE_SLEEP_RANGE = 30 * 60;
private static final int baseSleepTimeMs = 1000;
private final Random random = new Random(System.currentTimeMillis());

@Override
protected long getSleepTimeMs(int retryCount, long elapsedTimeMs) {
    long sleepMs;
    if (retryCount < POLICY_SWITCH_THRESHOLD) {
        // exponentialBackoff retry
        sleepMs = baseSleepTimeMs * Math.max(retryCount, random.nextInt(1 << (retryCount + 1)));
    } else {
        // random retry
        sleepMs = baseSleepTimeMs * (BASE_SLEEP_RANGE + random.nextInt(BASE_SLEEP_RANGE));
    }
    return sleepMs;
}
```
[采用zookeeper的EPHEMERAL节点机制实现服务集群的陷阱](http://cms.smartfeng.com/technology/others/zookeeper-qa-ephemeral) 这篇文章最后说自己因为这个诡异的 29 最终放弃了 curator 回到了原生 zk 客户端, 我个人认为这个决定的机会成本实在是太高, 自己实现一个改进策略也就是分分钟的事, 怎能舍得放弃 curator 那么多好处回到原始时代?

### **站内相关文章**
- [curator 对 zookeeper 的封装逻辑梳理]()
- [curator-recipes: cache 使用实践]()

### **参考链接**
- [采用zookeeper的EPHEMERAL节点机制实现服务集群的陷阱](http://cms.smartfeng.com/technology/others/zookeeper-qa-ephemeral)

