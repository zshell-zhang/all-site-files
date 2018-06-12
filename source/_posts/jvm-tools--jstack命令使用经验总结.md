---
title: jstack命令使用经验总结
date: 2017-10-24 17:11:51
categories:
 - jvm
 - tools
tags:
 - jvm:tools
---

> jstack 在命令使用上十分简洁, 然而其输出的内容却十分丰富, 信息量足, 值得深入分析;
以往对于 jstack 产生的 thread dump, 我很少字斟句酌得分析过每一部分细节, 针对 jstack 的性能诊断也没有一个模式化的总结; 今天这篇文章我就来详细整理一下与 jstack 相关的内容;

<!--more-->

------

## **jstack 命令的基本使用**
jstack 在命令使用上十分简洁, 其信息量与复杂度主要体现在 thread dump 内容的分析上;
``` bash
# 最基本的使用
sudo -u xxx jstack {vmid}
# 从 core dump 中提取 thread dump
sudo -u xxx jstack core_file_path
# 除了基本输出外, 额外展示 AbstractOwnableSynchronizer 锁的占有信息
# 可能会消耗较长时间
sudo -u xxx jstack -l {vmid}
```

## **jstack 输出内容结构分析**
首先展示几段 thread dump 的典型例子:
正在 RUNNING 中的线程:
``` c
"elasticsearch[datanode-39][[xxx_index_v4][9]: Lucene Merge Thread #2403]" #45061 daemon prio=5 os_prio=0 tid=0x00007fb968213800 nid=0x249ca runnable [0x00007fb6843c2000]
   java.lang.Thread.State: RUNNABLE
        ...
        at org.elasticsearch.index.engine.ElasticsearchConcurrentMergeScheduler.doMerge(ElasticsearchConcurrentMergeScheduler.java:94)
        at org.apache.lucene.index.ConcurrentMergeScheduler$MergeThread.run(ConcurrentMergeScheduler.java:626)
```
阻塞在 java.util.concurrent.locks.Condition 上:
``` c
"DubboServerHandler-10.64.16.66:20779-thread-510" #631 daemon prio=5 os_prio=0 tid=0x00007fb6f4ce5800 nid=0x1743 waiting on condition [0x00007fb68ed2f000]
   java.lang.Thread.State: WAITING (parking)
        at sun.misc.Unsafe.park(Native Method)
        - parking to wait for  <0x00000000e2978ef0> (a java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject)
        at java.util.concurrent.locks.LockSupport.park(LockSupport.java:175)
        at java.util.concurrent.locks.AbstractQueuedSynchronizer$ConditionObject.await(AbstractQueuedSynchronizer.java:2039)
        ...
```
阻塞在内置锁上:
``` c
"qtp302870502-26-acceptor-0@45ff00a-ServerConnector@63475ace{HTTP/1.1}{0.0.0.0:9088}" #26 prio=5 os_prio=0 tid=0x00007f1830d3a800 nid=0xdf64 waiting for monitor entry [0x00007f16b5ef9000]
   java.lang.Thread.State: BLOCKED (on object monitor)
        at sun.nio.ch.ServerSocketChannelImpl.accept(ServerSocketChannelImpl.java:234)
        - waiting to lock <0x00000000c07549f8> (a java.lang.Object)
        at org.eclipse.jetty.server.ServerConnector.accept(ServerConnector.java:377)
        ...
        at java.lang.Thread.run(Thread.java:745)
```
``` c
"JFR request timer" #6 daemon prio=5 os_prio=0 tid=0x00007fc2f6b1f800 nid=0x18070 in Object.wait() [0x00007fb9aa96b000]
   java.lang.Thread.State: WAITING (on object monitor)
        at java.lang.Object.wait(Native Method)
        - waiting on <0x00007fba6b50ea38> (a java.util.TaskQueue)
        at java.lang.Object.wait(Object.java:502)
        at java.util.TimerThread.mainLoop(Timer.java:526)
        - locked <0x00007fba6b50ea38> (a java.util.TaskQueue)
        at java.util.TimerThread.run(Timer.java:505)
```
以上展示了四个线程的 jstack dump, 有 running 状态, 也有阻塞状态, 覆盖面广, 具有典型性; 下面来对 jstack 的输出内容作详细梳理;

### **输出内容的结构**
首先还是要说一下 jstack 输出的内容结构, 就以上方举的第四个线程为例:
以下是第一部分内容, 记录了线程的一些基本信息, 从左到右每个元素的含义已经以注释标注在元素上方; 其中比较重要的是 `nid`, 它是 java 线程与操作系统的映射, 在 linux 中它和与其对应的轻量级进程 pid 相同 (需要十六进制与十进制转换), 这将为基于 java 线程的性能诊断带来帮助, 详细请见本文后面段落 [线程性能诊断的辅助脚本](#线程性能诊断的辅助脚本);
``` c
//|-----线程名------| |-线程创建次序-| |是否守护进程| |---线程优先级---| |-------线程 id-------| |-所映射的linux轻量级进程id-| |-------------线程动作--------------|
  "JFR request timer" #6              daemon        prio=5 os_prio=0  tid=0x00007fc2f6b1f800 nid=0x18070                 in Object.wait() [0x00007fb9aa96b000]
```
以下是第二部分内容, 表示线程当前的状态;
``` c
   java.lang.Thread.State: WAITING (on object monitor)
```
以下是第三部分内容, 主要记录了线程的调用栈; 其中比较重要的是一些关键调用上的 [动作修饰](#线程的重要调用修饰), 这些为线程死锁问题的排查提供了依据;
``` c
        at java.lang.Object.wait(Native Method)
        - waiting on <0x00007fba6b50ea38> (a java.util.TaskQueue)
        at java.lang.Object.wait(Object.java:502)
        at java.util.TimerThread.mainLoop(Timer.java:526)
        - locked <0x00007fba6b50ea38> (a java.util.TaskQueue)
        at java.util.TimerThread.run(Timer.java:505)
```

### **线程的动作**
线程动作的记录在每个 thread dump 的第一行末尾, 一般情况下可分为如下几类:

1. `runnable`, 表示线程在参与 cpu 资源的竞争, 可能在被调度运行也可能在就绪等待;
2. `sleeping`, 表示调用了 Thread.sleep(), 线程进入休眠;
3. `waiting for monitor entry [0x...]`, 表示线程在试图获取内置锁, 进入了等待区 Entry Set, 方括号内的地址表示线程等待的资源地址;
4. `in Object.wait() [0x...]`, 表示线程调用了 object.wait(), 放弃了内置锁, 进入了等待区 Wait Set, 等待被唤醒, 方括号内的地址表示线程放弃的资源地址;
5. `waiting on condition [0x...]`, 表示线程被阻塞原语所阻塞, 方括号内的地址表示线程等待的资源地址; 这种和 jvm 的内置锁体系没有关系, 它是 jdk5 之后的 java.util.concurrent 包下的锁机制;

### **线程的状态**
线程的状态记录在每个 thread dump 的第二行, 并以 java.lang.Thread.State 开头, 一般情况下可分为如下几类:

1. `RUNNABLE`, 这种一般与线程动作 `runnable` 一起出现;
2. `BLOCKED (on object monitor)`, 这种一般与线程动作 `waiting for monitor entry` 一起出现, 不过在其线程调用栈最末端并没有一个固定的方法, 因为 `synchronized` 关键字可以修饰各种方法或者同步块;
3. `WAITING (on object monitor)` 或者 `TIMED_WAITING (on object monitor)`, 这种一般与线程动作 `in Object.wait() [0x...]` 一起出现, 并且线程调用栈的最末端调用方法为 at java.lang.Object.wait(Native Method), 以表示 object.wait() 方法的调用;
另外, `WAITING` 与 `TIMED_WAITING` 的区别在于是否设置了超时中断, 即 `wait(long timeout)` 与 `wait()` 的区别;
4. `WAITING (parking)` 或者 `TIMED_WAITING (parking)`, 这种一般与线程动作 `waiting on condition [0x...]` 一起出现, 并且线程调用栈的最末端调用方法一般为 at sun.misc.Unsafe.park(Native Method);
Unsafe.park 使用的是线程阻塞原语, 主要在 java.util.concurrent.locks.AbstractQueuedSynchronizer 类中被使用到, 很多基于 AQS 构建的同步工具, 如 ReentrantLock, Condition, CountDownLatch, Semaphore 等都会诱发线程进入该状态;
另外, `WAITING` 与 `TIMED_WAITING` 的区别与第三点中提到的原因一致;

### **线程的重要调用修饰**
thread dump 的第三部分线程调用栈中, 一般会把与锁相关的资源使用状态以附加的形式作重点修饰, 这与线程的动作及状态有着密切的联系, 一般情况下可分为如下几类:

1. `locked <0x...>`, 表示其成功获取了内置锁, 成为了 owner;
2. `parking to wait for <0x...>`, 表示其被阻塞原语所阻塞, 通常与线程动作 `waiting on condition` 一起出现;
3. `waiting to lock <0x...>`, 表示其在 Entry Set 中等待某个内置锁, 通常与线程动作 `waiting for monitor entry` 一起出现;
4. `waiting on <0x...>`, 表示其在 Wait Set 中等待被唤醒, 通常与线程动作 `in Object.wait() [0x...]` 一起出现;
另外, waiting on 调用修饰往往与 locked 调用修饰一同出现, 如之前列举的第四个 thread dump:
``` c
      at java.lang.Object.wait(Native Method)
        - waiting on <0x00007fba6b50ea38> (a java.util.TaskQueue)
        at java.lang.Object.wait(Object.java:502)
        at java.util.TimerThread.mainLoop(Timer.java:526)
        - locked <0x00007fba6b50ea38> (a java.util.TaskQueue)
        at java.util.TimerThread.run(Timer.java:505)
```
这是因为该线程之前获得过该内置锁, 现在因为 object.wait() 又将其放弃了, 所以在调用栈中会出现先后两个调用修饰;

### **死锁检测的展示**
在 jdk5 之前, Doug Lea 大神还没有发布 java.util.concurrent 包, 这个时候提及的锁, 就仅限于 jvm 监视器内置锁; 此时如果进程内有死锁发生, jstack 将会把死锁检测信息打印出来:
``` c
Found one Java-level deadlock:
=============================
"Thread-xxx":
  waiting to lock monitor 0x00007f0134003ae8 (object 0x00000007d6aa2c98, a java.lang.Object),
  which is held by "Thread-yyy"
"Thread-yyy":
  waiting to lock monitor 0x00007f0134006168 (object 0x00000007d6aa2ca8, a java.lang.Object),
  which is held by "Thread-xxx"

Java stack information for the threads listed above:
===================================================
"Thread-xxx":
    ...
"Thread-yyy":
    ...
Found 1 deadlock.
```
然而后来 Doug Lea 发布了 java.util.concurrent 包, 当谈及 java 的锁, 除了内置锁之外还有了基于 AbstractOwnableSynchronizer 的各种形式; 由于是新事物, 彼时 jdk5 的 jstack 没有及时提供对以 AQS 构建的同步工具的死锁检测功能, 直到 jdk6 才完善了相关支持;

## **常见 java 进程的 jstack dump 特征**
首先, 不管是什么类型的 java 应用, 有一些通用的线程是都会存在的:
**VM Thread 与 VM Periodic Task Thread**
虚拟机线程, 属于 native thread, 凌驾与其他用户线程之上;
VM Periodic Task Thread 通常用于虚拟机作 sampling/profiling, 收集系统运行信息, 为 JIT 优化作决策依据;

**主线程 main**
通常 main 线程是 jvm 创建的 1 号用户线程, 有了 main 之后才有了后来的其他用户线程;

**Reference Handler 线程与 Finalizer 线程**
这两个线程用于虚拟机处理 override 了 Object.finalize() 方法的实例, 对实例回收前作最后的判决;
``` c
"Reference Handler" #2 daemon prio=10 os_prio=0 tid=0x00007f91e007f000 nid=0xa80 in Object.wait() [0x...]
   java.lang.Thread.State: WAITING (on object monitor)
        at java.lang.Object.wait(Native Method)
        at java.lang.Object.wait(Object.java:502)
        at java.lang.ref.Reference$ReferenceHandler.run(Reference.java:157)
        - locked <0x00000000c0495140> (a java.lang.ref.Reference$Lock)
```
``` c
"Finalizer" #3 daemon prio=8 os_prio=0 tid=0x00007f91e0081000 nid=0xa81 in Object.wait() [0x...]
   java.lang.Thread.State: WAITING (on object monitor)
        at java.lang.Object.wait(Native Method)
        at java.lang.ref.ReferenceQueue.remove(ReferenceQueue.java:143)
        - locked <0x00000000c008db88> (a java.lang.ref.ReferenceQueue$Lock)
        at java.lang.ref.ReferenceQueue.remove(ReferenceQueue.java:164)
        at java.lang.ref.Finalizer$FinalizerThread.run(Finalizer.java:209)
```

**gc 线程**
这块对于不同的 gc 收集器有各自不同的线程状态;

### **纯 tomcat 容器**

### **tomcat with dubbo**

### **elasticsearch datanode 节点**

## **相关衍生工具**
### **使用代码作 thread dump**
除了使用 jstack 之外, 还有其他一些方法可以对 java 进程作 thread dump, 如果将其封装为 http 接口, 便可以不用登陆主机, 直接在浏览器上查询 thread dump 的情况;
**使用 jmx 的 api**
``` java
public void  threadDump() {
   ThreadMXBean threadMxBean = ManagementFactory.getThreadMXBean();
   for (ThreadInfo threadInfo : threadMxBean.dumpAllThreads(true, true)) {
       // deal with threadInfo.toString()
   }
}
```
**使用 Thread.getAllStackTraces() 方法**
``` java
public void threadDump() {
    for (Map.Entry<Thread, StackTraceElement[]> stackTrace : Thread.getAllStackTraces().entrySet()) {
        Thread thread = (Thread) stackTrace.getKey();
        StackTraceElement[] stack = (StackTraceElement[]) stackTrace.getValue();
        if (thread.equals(Thread.currentThread())) {
            continue;
        }
        // deal with thread
        for (StackTraceElement stackTraceElement : stack) {
            // deal with stackTraceElement
        }
    }
}
```

### **线程性能诊断的辅助脚本**
使用 jstack 还有一个重要的功能就是分析热点线程: 找出占用 cpu 资源最高的线程;
首先我先介绍一下手工敲命令分析的方法:

* 使用 top 命令找出 cpu 使用率高的 thread id:
``` bash
# -p pid: 只显示指定进程的信息
# -H: 展示线程的详细信息
top -H -p {pid}
# 使用 P 快捷键按 cpu 使用率排序, 并记录排序靠前的若干 pid (轻量级进程 id)
```
* 作进制转换:
``` bash
# 将记录下的十进制 pid 转为十六进制
thread_id_0x=`printf "%x" $thread_id`
`echo "obase=16; $thread_id" | bc`
```
* 由于 thread dump 中记录的每个线程的 nid 是与 linux 轻量级进程 pid 一一对应的 (只是十进制与十六进制的区别), 所以便可以拿转换得到的十六进制 thread_id_0x, 去 thread dump 中搜索对应的 nid, 定位问题线程;
&nbsp;

下面介绍一个脚本, 其功能是: 按照 cpu 使用率从高到低排序, 打印指定 jvm 进程的前 n 个线程;
``` bash
#!/bin/sh

default_lines=10
top_head_info_padding_lines=8
default_stack_lines=15

jvm_pid=$1
jvm_user=$2
((thread_stack_lines=${3:-$default_lines}+top_head_info_padding_lines))

threads_top_capture=$(top -b -n1 -H -p $jvm_pid | grep $jvm_user | head -n $thread_stack_lines)
jstack_output=$(echo "$(sudo -i -u $jvm_user jstack $jvm_pid)")
top_output=$(echo "$(echo "$threads_top_capture" | perl -pe 's/\e\[?.*?[\@-~] ?//g' | awk '{gsub(/^ +/,"");print}' | awk '{gsub(/ +|[+-]/," ");print}' | cut -d " " -f 1,9 )\n ")

echo "***********************************************************"
uptime
echo "Analyzing top $top_threads threads"
echo "***********************************************************"

printf %s "$top_output" | while IFS= read line
do
    pid=$(echo $line | cut -d " " -f 1)
    hexapid=$(printf "%x" $pid)
    cpu=$(echo $line | cut -d " " -f 2)
    echo -n $cpu "% [$pid] "
    echo "$jstack_output" | grep "tid.*0x$hexapid " -A $default_stack_lines | sed -n -e '/0x'$hexapid'/,/tid/ p' | head -n -1
done
```
该脚本有多种版本, 在我司的每台主机上的指定路径下都存放了一个副本; 出于保密协议, 该脚本源码不便于公开, 上方所展示的版本是基于美团点评的技术专家王锐老师在一次 [问答分享](https://mp.weixin.qq.com/s?__biz=MjM5NjQ5MTI5OA==&mid=2651746699&idx=2&sn=c52feeab2576056e4a65e26a99702206&chksm=bd12a8c68a6521d0de81ac8ab437df1a9e702053b7840af9ac86b29979865c6fc1000286875e&mpshare=1&scene=1&srcid=0610dNiqShEJLkHiQLiIN4z1#rd) 中给出的代码所改造的;

### **thread dump 可视化分析工具**
与 [gceasy.io](gceasy.io) 一道, 同出自一家之手: [fastthread.io](http://fastthread.io);

## **参考链接**
- [如何使用jstack分析线程状态](https://www.jianshu.com/p/6690f7e92f27)
- [java命令--jstack 工具](http://www.cnblogs.com/kongzhongqijing/articles/3630264.html)
- [7 个抓取 Java Thread Dumps 的方式](https://my.oschina.net/dabird/blog/691692)
- [你与Java大牛的距离，只差这24个问题](https://mp.weixin.qq.com/s?__biz=MjM5NjQ5MTI5OA==&mid=2651746699&idx=2&sn=c52feeab2576056e4a65e26a99702206&chksm=bd12a8c68a6521d0de81ac8ab437df1a9e702053b7840af9ac86b29979865c6fc1000286875e&mpshare=1&scene=1&srcid=0610dNiqShEJLkHiQLiIN4z1#rd)

