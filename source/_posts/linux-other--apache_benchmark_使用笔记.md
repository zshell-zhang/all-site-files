---
title: apache benchmark 使用笔记
date: 2017-11-25 20:41:55
categories:
 - linux
 - other
tags:
 - linux:other
 - linux:perf
---

> 各个公司或多或少都在推出自己的压力测试工具, 形形色色, 种类繁多; 其实, 在开源世界已经有了一个经典成熟的压力测试工具 ---- apache benchmark;
小巧, 简单, 基于 http 的普适性, 这些都是 apache benchmark 被广泛使用的原因;

<!--more-->

------

apache benchmark, 其对应的命令被简称为 ab, 是 httpd-tools 里使用最广泛的工具;

## **httpd-tools 安装**
直接用 yum install ab 是找不到软件包的, 因为 ab 并没有单独提供, 而是封装在 httpd-tools 里面;
```
sudo yum install -y httpd-tools
```
安装完后, httpd-tools 提供的系列工具如下:
```
apache benchmark

htdbm
htdigest
htpassword
httxt2dbm
logresolve
```
后面的 5 个工具, 都是与 apache 服务器相关的辅助工具, 一旦脱离了 apache server 则作用有限; 但是 apache benchmark 却不一样, 虽然它本来的设计目的也是为了压测 apache server, 但既然是 http 请求, 那么大部分 web server 都可以使用其作压力测试;

## **ab 的使用方法**
``` bash
# 最简单使用: -c concurrency 并发数; -n requests 请求数量
ab -n 10000 -c 100 ${target_url}
# post 请求: -p 指定需要 post 的数据文件, -T 指定 content-type
ab -n 10000 -c 100 -p params.file -T 'application/x-www-form-urlencoded' ${target_url}
# -s: timeout, 单位为秒
ab -n 10000 -c 100 -s 20 ${target_url}

# -t: timelimit, 指定本次压测的最长时间限制
# 如果不指定 -n, 这里还会默认指定一个 -n 50000
ab -c 100 -s 20 -t 60000 ${target_url}

# -r: 当发生 socket error 时不退出, 而是继续执行请求
# -k: 在 http 请求的 headers 中加上 Connection: keep-alive, 以保持连接 
ab -n 10000 -c 100 -r -k ${target_url}

# 将压测数据记录为 gunplot 可以分析的 dump 文件, 以供其渲染
ab -n 10000 -c 100 -g data.plt ${target_url}
```

## **ab 的输出分析**
### **顺利完成测试任务的输出**
``` bash
# 部分 version, licene 信息已省略
> ab -n 100 -c 10 http://www.baidu.com/
......
Server Software:        BWS/1.1
Server Hostname:        www.baidu.com
Server Port:            80

Document Path:          /
Document Length:        111488 bytes

Concurrency Level:      10
Time taken for tests:   2.055 seconds
Complete requests:      100
```
这里有一个需要注意的地方: failed requests;
ab 请求失败的原因分为几类:

* Connect: tcp 连接错误, 属于网路问题;
* Length: http response 的 Content-Length 与第一次接收的值不一致, 这种属于业务问题, 并不能严格将其归为失败;
* Exceptions: 服务器端异常, 一般 status code 为 5XX;

不过, 如果返回客户端错误 4XX, ab 不会判定为 failed requests, 这里需要注意;

``` bash
Failed requests:        89 (Connect: 0, Receive: 0, Length: 89, Exceptions: 0)
```

如上所示, 像 baidu.com 这种属于动态网页, 每次返回的内容长度不固定, 所以大量请求被 ab 判定为 failed requests;
类似这种情况的场景很多, 所以这就提醒我们在使用 ab 作压力测试时, 构造的 mock 接口一定要能够返回固定长度的内容, 而被测试接口的返回内容校验, 应该放在 mock 接口内部逻辑中实现; 一旦校验失败, 不要在返回内容上作标记, 而是直接抛出异常, 以让 ab 识别为 failed requests;

``` bash
Write errors:           0
Total transferred:      11320607 bytes
HTML transferred:       11223796 bytes
Requests per second:    48.65 [#/sec] (mean)
Time per request:       205.533 [ms] (mean)
Time per request:       20.553 [ms] (mean, across all concurrent requests)
Transfer rate:          5378.84 [Kbytes/sec] received
```
传输各个阶段的统计指标:
``` bash
Connection Times (ms)
#             最短时间  平均时间    标准差  中位数时间  最长时间
              min       mean        [+/-sd]     median      max
Connect:       36         38            0.8         38       39
Processing:   113        154           14.5        152      198
Waiting:       37         39            1.0         39       42
Total:        150        192           14.7        190      237
```
最后是 rt 响应时间的分位数统计:
``` bash
Percentage of the requests served within a certain time (ms)
  50%    190
  66%    192
  75%    194
  80%    195
  90%    198
  95%    230
  98%    234
  99%    237
 100%    237 (longest request)
```

### **测试被迫终止**
以上是一个顺利完成压测任务的输出; 有的时候压力测试并不会很顺利得结束, 如果压得比较猛, 可能待测服务会发生各种问题, 这时 ab 就有可能被迫提前终止任务;
**情况一 tcp connection error**
``` bash
apr_socket_recv: Connection timed out (110)
apr_socket_recv: Connection reset by peer (104)
```
当 ab 遇到 connection error 时默认会直接 exit; 此时可以使用 -r 选项:
> -r     Don't exit on socket receive errors.

这样 ab 就不会在遇到 connection error 时退出了; 但这有时并不能从根本上解决问题, 比如在某些高并发环境下, 待测服务所在的系统内核开启了 SYN flood 攻击保护, 故意拖慢了请求速度, 造成 connection error, 这可能会导致所有的请求都失败, 从而失去了压测意义; 这种情况下, 往往需要调整内核参数, 关闭一些安全保护:
``` bash
# 关闭洪流攻击保护
net.ipv4.tcp_syncookies = 0
```

&nbsp;
**情况二 tcp read/write error**
``` bash
apr_pollset_poll: The timeout specified has expired (70007)
```
以上输出反映了 ab 在测试途中遇到了 read/write timeout, 请求服务超过了选项 -s 设置的 timeout 时间; 这其实是一个不合理的设计, 一个请求超时是很正常的事情, 但是它一遇到超时就直接 exit, 这就让使用者不爽了, 它完全可以放到最后的统计里面的;
但是除非你修改 ab 的 source code 重新编译, 否则对于这种错误你也只能是修改 -s 增大超时时间了;

## **一个典型的使用实践**
光说不练肯定是不行的, 这里正好有一个比较系统性地压力测试报告, 其将 apache benchmark 作为了一个主要的分析工具, 可以分享一下: [berkeley db 7.x 压力测试报告](http://zshell.cc/2018/08/12/linux-other--berkeley_db7.x压力测试报告);

## **其他类似工具**
有一个与 ab 类似的开源 http 压力测试工具: [wrk - a HTTP benchmarking tool](https://github.com/wg/wrk), 在 github 上也获得了 1.7 万的 stars;
wrk 与 ab 的类似之处在于它们都是基于 http 的命令行工具, 通过命令选项控制压测条件; 但是 wrk 在某种程度上只能算是 ab 的一个子集:
wrk 只能通过给定一个确定的压测时间限制, 在给定的时间内以给定的并发度请求, 当时间到了, 压力测试结束, 其并不能设置请求多少次后结束测试;
另外, wrk 的输出与 ab 也不太相同:
``` bash
Running 30s test @ http://127.0.0.1:8080/index.html
  12 threads and 400 connections
  
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   635.91us    0.89ms  12.92ms   93.69%
    Req/Sec    56.20k     8.07k   62.00k    86.54%
    
  22464657 requests in 30.00s, 17.76GB read
  
Requests/sec: 748868.53
Transfer/sec:    606.33MB
```
相比 ab 的报告略显简洁, 只能说是见仁见智吧;

## **站内相关文章**
- [berkeley db 7.x 压力测试报告](http://zshell.cc/2018/08/12/linux-other--berkeley_db7.x压力测试报告)

## **参考链接**
- [Package httpd-tools](https://www.mankier.com/package/httpd-tools)
- [Apache Benchmark安装、参数含义&使用总结、结果分析](http://blog.csdn.net/sangyongjia/article/details/49093945)
- [ab输出信息解释以及Failed requests原因分析](http://www.ttlsa.com/web/analysis-of-ab-output-information-interpretation-and-failed-requests/)
- [apachebench(ab)压测遇到问题的解决方案记录](https://www.douban.com/note/501373268/)
- [ab - Apache HTTP server benchmarking tool](http://httpd.apache.org/docs/2.2/programs/ab.html)
- [apache ab压力测试报错 (apr_socket_recv: Connection reset by peer (104))](http://www.cnblogs.com/archoncap/p/5883723.html)

