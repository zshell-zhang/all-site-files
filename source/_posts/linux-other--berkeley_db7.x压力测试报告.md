---
title: berkeley db 7.x 压力测试报告
date: 2018-08-12 23:10:04
categories:
 - linux
 - other
tags:
 - linux:other
 - jvm:gc
 - linux:perf
---

> 之前写过一篇文章 [apache benchmark 使用笔记](http://zshell.cc/2018/01/22/linux-other--apache_benchmark_使用笔记), 介绍了 apache benchmark 的使用及注意事项, 当时我确实是使用 ab 作了一个系统的压力测试; 可惜不够重视, 我在博客里只作了关于 ab 的使用笔记, 却没有将当时压测的结果输出为一份详细报告;
这次被我逮到机会了: 最近我在调研一个 KV 数据库 `oracle berkeley db`, 需要测试其新版本 (7.4.5) 引入堆外内存作为辅助缓存的实际性能; 我详细得记录了本次压力测试的各种细节 (已经对所有涉及公司内部的信息作了脱敏处理), 希望能以此为模板, 当以后有相关的压力测试需要时, 可以从中获得参考价值;

<!--more-->

------

## **测试环境**
测试机器的物理配置如下:
``` bash
24C
64G
2.7T
```

## **测试内容**
为了构造大量的随机数据以模拟服务的真实场景, mock 了三个接口如下:
``` bash
# 随机写, key 在 (0, xxx] 范围内随机生成, valueSize 指定 key 的大小
http://${remote_url}/random_set?keyRange=xxx&valueSize=xxx
# 随机读, key 在 (0, xxx] 范围内随机生成
http://${remote_url}/random_get?keyRange=xxx
# 随机批量读, key 在 (0, xxx] 范围内随机生成, keyNum 指定批量个数
http://${remote_url}/random_mget?keyRange=xxx&keyNum=yyy
```
在各接口中使用当前时间作为随机数发生的 seed, 确保真实随机, 然后使用 apache benchmark 作压力测试:
``` bash
# 100 万次总请求, 250 并发, 5s timeout
ab -n 1000000 -c 250 -s 5 http://${remote_url}/random_get
```

### **基础指标分析**
使用 ab 收集基础数据:
``` bash
# rt
min, mean, median, P90, P99, max
# 标准差/乖离率
stdev
# failure stat
error/exception/timeout
```

### **jvm 指标分析**
使用 jstat 采样 jvm gc 状态:
``` bash
> sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/xxx

# sample
S0     S1     E      O      M     CCS    YGC     YGCT    FGC    FGCT     GCT
5.67   0.00  48.74  70.68  98.24     -  15588  1199.695    20   2.865   1202.561
```
``` bash
# 收集关键 gc 状态指标
YGC, YGCT, FGC, FGCT
```

### **堆外内存分析**
堆外内存无法使用 jmap / jstat 观察, 只能用 top 观察;
``` bash
top -b -n 100 -H -p ${vmid}
```

## **控制变量测试计划**
除了计划 E 是专门对比收集器效果的, 其余的测试计划内均使用 ParNew + CMS 的收集器组合, 配置如下:
``` bash
-XX:ParallelGCThreads=${CPU_COUNT}

-XX:+UseConcMarkSweepGC
-XX:+UseCMSCompactAtFullCollection
-XX:CMSMaxAbortablePrecleanTime=5000
-XX:+CMSClassUnloadingEnabled
-XX:CMSInitiatingOccupancyFraction=80
-XX:+UseCMSInitiatingOccupancyOnly
-XX:+CMSScavengeBeforeRemark
```

### **计划 A: in-heap 缓存大小控制**
测试环境:
``` bash
-Xms=25g
-Xmx=25g
-Xmn=10g
-XX:MaxDirectMemorySize=10g
-Dje.maxOffHeapMemory=10g
```

**A-1: 测试 set**
测试命令:
``` bash
# 100 万次请求, 250 个并发
ab -n 1000000 -c 250 -s 5 "http://${remote_url}/random_set?keyRange=9999999&valueSize=5000"
sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/A-1_X
```
测试结果:

|metrics \ je.maxMemoryPercent        |5%                  |10%                 |20%                 |30%       |
|:-----------------------------------:|:------------------:|:------------------:|:------------------:|:--------:|
|RT (min/P90/P99/max) (ms)            |6/122/316/1461      |6/128/352/1708      |6/125/365/3354      |ab timeout|
|RT (mean/median) (ms)                |85/73               |87/75               |88/75               |/         |
|error/timeout                        |0                   |0                   |0                   |/         |
|stdev/bias                           |68.2                |72.0                |77.0                |/         |
|YGC/YGCT (s)                         |14/2.998            |14/4.397            |16/6.278            |/         |
|FGC/FGCT (s)                         |0/0                 |0/0                 |2/0.589             |/         |

**A-2: 测试 get**
测试命令:
``` bash
# 100 万次请求, 250 个并发
ab -n 1000000 -c 250 -s 5 "http://${remote_url}/random_get?keyRange=9999999"
sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/A-2_X
```
测试结果:

|metrics \ je.maxMemoryPercent        |5%                  |10%                 |20%                 |30%       |
|:-----------------------------------:|:------------------:|:------------------:|:------------------:|:--------:|
|RT (min/P90/P99/max) (ms)            |9/32/29/1030        |8/26/29/1038        |8/27/29/1218        |/         |
|RT (mean/median) (ms)                |24/24               |23/24               |22/21               |/         |
|error/timeout                        |2                   |2                   |5                   |/         |
|stdev/bias                           |15.8                |17.8                |27.8                |/         |
|YGC/YGCT (s)                         |7/1.442             |6/0.963             |6/0.907             |/         |
|FGC/FGCT (s)                         |0/0                 |0/0                 |0/0                 |/         |

**A-3: 测试 mget**
测试命令:
``` bash
# 100 万次请求, 250 个并发
ab -n 1000000 -c 250 -s 5 "http://${remote_url}/random_mget?keyRange=9999999&keyNum=20"
sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/A-3_X
```
测试结果:

|metrics \ je.maxMemoryPercent        |5%                  |10%                 |20%                 |30%       |
|:-----------------------------------:|:------------------:|:------------------:|:------------------:|:--------:|
|RT (min/P90/P99/max) (ms)            |8/28/34/4529        |6/28/31/4804        |6/27/33/1073        |/         |
|RT (mean/median) (ms)                |34/26               |32/25               |25/23               |/         |
|error/timeout                        |2006                |10907               |14300               |/         |
|stdev/bias                           |139.5               |29.8                |24.3                |/         |
|YGC/YGCT (s)                         |26/31.157           |23/22.947           |24/4.687            |/         |
|FGC/FGCT (s)                         |0/0                 |2/1.689             |1/4.243             |/         |

**测试小结**
在当前的测试机器上, 共有 30g 的存量数据; 根据现有的状况, 在计划 A 中选取的几个测试条件, 分别代表了:

* 5%: 占用较少的 jvm 堆内存资源;
* 10%: 比较充分得使用 jvm 堆内存资源;
* 20%: 比较拥挤得争用 jvm 堆内存资源;
* 30%: 十分拥挤得争用 jvm 堆内存资源;

当然, 根据不同机器上的不同数据分布情况, 相应的测试条件也需要调整;
从以上测试结果中可以得知: 当各分片 bdb 实例的 in-heap 大小控制在比较高的水平 (20%) 时, 由于数据的 overflow, 将会对整体请求的稳定性造成影响, 产生比较大的乖离率, timeout/error 概率也相应增大; 而当 in-heap 大小控制到更高水平 (30%) 时, 甚至在 250 并发强度下无法正常提供服务, 发生大量 timeout 以及 connection error;
综合来说, 这里建议比较充分得使用 jvm 堆内存, 对应测试中的第二项条件 10%;

### **计划 B: off-heap 缓存大小控制**
测试环境:
``` bash
-Xms=25g
-Xmx=25g
-Xmn=10g
-Dje.maxMemoryPercent=10
```

**B-1: 测试 set**
测试命令:
``` bash
# 100 万次请求, 250 个并发
    ab -n 1000000 -c 250 -s 5 "http://${remote_url}/random_set?keyRange=9999999&valueSize=5000"
sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/B-1_X
```
测试结果:

|metrics \ je.maxMemoryPercent        |5%                  |10%                 |20%                 |30%           |
|:-----------------------------------:|:------------------:|:------------------:|:------------------:|:------------:|
|RT (min/P90/P99/max) (ms)            |6/122/339/3173      |7/117/318/1714      |6/128/352/1708      |6/131/153/3074|
|RT (mean/median) (ms)                |85/73               |83/72               |87/75               |89/76         |
|error/timeout                        |0                   |0                   |0                   |2             |
|stdev/bias                           |71.6                |69.0                |78.0                |75.3          |
|YGC/YGCT (s)                         |14/4.398            |15/5.051            |14/4.397            |15/4.954      |
|FGC/FGCT (s)                         |0/0                 |0/0                 |1/4.243             |0/0           |

**B-2: 测试 get**
测试命令:
``` bash
# 100 万次请求, 250 个并发
ab -n 1000000 -c 250 -s 5 "http://${remote_url}/random_get?keyRange=9999999"
sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/B-2_X
```
测试结果:

|metrics \ je.maxMemoryPercent        |5%                  |10%                 |20%                 |30%           |
|:-----------------------------------:|:------------------:|:------------------:|:------------------:|:------------:|
|RT (min/P90/P99/max) (ms)            |9/25/29/1030        |8/25/28/1225        |8/26/29/1038        |823/28/29/441 |
|RT (mean/median) (ms)                |23/22               |23/22               |23/24               |23/26         |
|error/timeout                        |11                  |5                   |2                   |371           |
|stdev/bias                           |22.5                |25.8                |17.8                |11.6          |
|YGC/YGCT (s)                         |8/1.222             |7/1.214             |6/0.963             |8/1.602       |
|FGC/FGCT (s)                         |0/0                 |0/0                 |0/0                 |0/0           |

**B-3: 测试 mget**
测试命令:
``` bash
# 100 万次请求, 250 个并发
ab -n 1000000 -c 250 -s 5 "http://${remote_url}/random_mget?keyRange=9999999&keyNum=20"
sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/B-3_X
```
测试结果:

|metrics \ je.maxMemoryPercent        |5%                  |10%                 |20%                 |30%           |
|:-----------------------------------:|:------------------:|:------------------:|:------------------:|:------------:|
|RT (min/P90/P99/max) (ms)            |6/28/162/1029       |6/27/145/1342       |6/28/31/4804        |6/27/67/1431  |
|RT (mean/median) (ms)                |26/24               |26/24               |32/25               |26/23         |
|error/timeout                        |9011                |9467                |10907               |10875         |
|stdev/bias                           |29.1                |35.5                |29.8                |36.8          |
|YGC/YGCT (s)                         |27/3.758            |26/3.535            |23/22.947           |23/3.05       |
|FGC/FGCT (s)                         |2/0.236             |2/0.236             |2/1.689             |2/0.245       |

**测试小结**
berkeley db 使用堆外内存作为堆内存 overflow 后 spill to disk 之间的缓冲区; 计划 B 分别选取了四个差异较大的测试条件; 从测试结果中可以得知: 
分配相对充分的 off-heap 比例作为 disk 缓冲区是有一定的效果的, 在 get 测试和 mget 测试中, 10g 与 20g 的测试组都在 gc 次数与 gc 时间上比 512m 和 1g 的测试组占有优势; 在乖离率方面, 10g 与 20g 的测试组也较 512m 和 1g 测试组较低, 稳定性更加;
综合来说, 这里建议分配相对充分的堆外内存 (10g ~ 20g) 作为 disk buffer;

### **计划 C: -Xmx / -Xms 大小控制**
一般控制 -Xmx 与 -Xms 相同, 同时这里设置 -XX:NewRatio=2;
需要注意的是, 在 64 位机器上, 当 jvm 内存超过 32g, 指针压缩 (CompressedOops) 功能将无法生效, 内存使用效率将会降低; 所以无论机器的物理内存有多大, 每个 jvm 实例的 Xmx 都不建议超过 31g;
测试环境:
``` bash
-Dje.maxMemoryPercent=10
-XX:MaxDirectMemorySize=10g
-Dje.maxOffHeapMemory=10g
```

**C-1: 测试 set**
测试命令:
``` bash
# 100 万次请求, 250 个并发
ab -n 1000000 -c 250 -s 5 "http://${remote_url}/random_set?keyRange=9999999&valueSize=5000"
sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/C-1_X
```
测试结果:

|metrics \ je.maxMemoryPercent        |5%                  |10%                 |20%                 |30%           |
|:-----------------------------------:|:------------------:|:------------------:|:------------------:|:------------:|
|RT (min/P90/P99/max) (ms)            |6/123/324/3092      |6/123/343/3140      |6/128/352/1708      |6/138/324/3101|
|RT (mean/median) (ms)                |83/70               |86/74               |87/75               |94/80         |
|error/timeout                        |0                   |0                   |0                   |26            |
|stdev/bias                           |69.0                |76.1                |72.0                |82.3          |
|YGC/YGCT (s)                         |38/4.035            |19/11.268           |6/0.963             |12/6.99       |
|FGC/FGCT (s)                         |2/0.202             |0/0                 |0/0                 |0/0           |

**C-2: 测试 get**
测试命令:
``` bash
# 100 万次请求, 250 个并发
ab -n 1000000 -c 250 -s 5 "http://${remote_url}/random_get?keyRange=9999999"
sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/C-2_X
```
测试结果:

|metrics \ je.maxMemoryPercent        |5%                  |10%                 |20%                 |30%           |
|:-----------------------------------:|:------------------:|:------------------:|:------------------:|:------------:|
|RT (min/P90/P99/max) (ms)            |9/25/28/2819        |8/25/28/1077        |8/26/29/1038        |10/25/28/1429 |
|RT (mean/median) (ms)                |22/22               |22/22               |23/24               |22/22         |
|error/timeout                        |368                 |539                 |112                 |86            |
|stdev/bias                           |45.1                |17.7                |17.8                |18.8          |
|YGC/YGCT (s)                         |17/1.912            |12/1.154            |14/4.397            |5/1.206       |
|FGC/FGCT (s)                         |1/1.934             |0/0                 |0/0                 |0/0           |

**C-3: 测试 mget**
测试命令:
``` bash
# 100 万次请求, 250 个并发
ab -n 1000000 -c 250 -s 5 "http://${remote_url}/random_mget?keyRange=9999999&keyNum=20"
sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/C-3_X
```
测试结果:

|metrics \ je.maxMemoryPercent        |5%                  |10%                 |20%                 |30%           |
|:-----------------------------------:|:------------------:|:------------------:|:------------------:|:------------:|
|RT (min/P90/P99/max) (ms)            |6/28/102/1195       |6/29/140/1264       |6/28/31/4804        |6/28/159/1344 |
|RT (mean/median) (ms)                |27/25               |27/25               |32/25               |28/25         |
|error/timeout                        |6125                |9410                |1090                |7670          |
|stdev/bias                           |28.8                |28.7                |29.8                |38.1          |
|YGC/YGCT (s)                         |66/4.818            |32/3.579            |23/22.947           |20/5.442      |
|FGC/FGCT (s)                         |4/0.197             |2/0.202             |2/1.689             |2/0.469       |

**测试小结**
此次升级 bdb 版本的重要目的就是使用堆外内存, 降低堆内存, 从而降低 gc 的压力; 在计划 C 中选取了不同的 Xmx, 从测试结果中可以得知:
较高的堆内存 (30g) 虽然没有明显的 gc 压力, 但是在乖离率, max rt 等方面相比中等内存 (20g, 25g) 有增加; 另外, 较低的堆内存 (10g) 由于可用内存太少, 可以看出存在频繁的 gc, 无论是 young gc 还是 old gc, 都明显高于其他测试组;
综合来说, 这里建议分配适当的堆内存空间 (20g ~ 25g) 作为 Xmx;

### **计划 D: bdb 版本对比**
选取对比的两个目标版本为: 6.4.25 vs 7.4.5;
测试环境:
``` bash
-Xms=25g
-Xmx=25g
-Xmn=10g
-Dje.maxMemoryPercent=10
-XX:MaxDirectMemorySize=30g
-Dje.maxOffHeapMemory=10g
```
**注意: 当 bdb 版本降为 6.4.25 时, 其性能已支撑不了前面三个测试计划中的 250 并发量, 频繁超时, 无法收集到有效数据; 经过多次调节, 确定将并发数降低到 50 方可收集到有效数据;**

**D-1: 测试 set**
测试命令:
``` bash
# 50 万次请求, 50 个并发
ab -n 1000000 -c 50 -s 5 "http://${remote_url}/random_set?keyRange=9999999&valueSize=5000"
sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/D-1_X
```
测试结果:

|metrics \ version                |6.4.25          |7.4.5           |
|:-------------------------------:|:--------------:|:--------------:|
|RT (min/P90/P99/max) (ms)        |6/24/40/755     |6/24/40/1015    |
|RT (mean/median) (ms)            |17/15           |17/15           |
|error/timeout                    |0               |0               |
|stdev/bias                       |13.5            |13.4            |
|YGC/YGCT (s)                     |7/2.739         |7/2.621         |
|FGC/FGCT (s)                     |0/0             |0/0             |

**D-2: 测试 get**
测试命令:
``` bash
# 50 万次请求, 50 个并发
ab -n 500000 -c 50 -s 5 "http://${remote_url}/random_get?keyRange=9999999"
sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/D-2_X
```
测试结果:

|metrics \ version                |6.4.25          |7.4.5           |
|:-------------------------------:|:--------------:|:--------------:|
|RT (min/P90/P99/max) (ms)        |6/8/8/1077      |6/8/8/1130      |
|RT (mean/median) (ms)            |7/7             |7/7             |
|error/timeout                    |2               |2               |
|stdev/bias                       |12.6            |10.9            |
|YGC/YGCT (s)                     |3/0.604         |4/0.849         |
|FGC/FGCT (s)                     |0/0             |0/0             |

**D-3: 测试 mget**
测试命令:
``` bash
# 50 万次请求, 50 个并发
ab -n 500000 -c 50 -s 5 "http://${remote_url}/random_mget?keyRange=9999999&keyNum=20"
sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/D-3_X
```
测试结果:

|metrics \ version                |6.4.25          |7.4.5           |
|:-------------------------------:|:--------------:|:--------------:|
|RT (min/P90/P99/max) (ms)        |6/8/9/510       |6/8/9/1068      |
|RT (mean/median) (ms)            |8/7             |8/7             |
|error/timeout                    |8               |2               |
|stdev/bias                       |9.2             |12.0            |
|YGC/YGCT (s)                     |8/1.561         |8/1.049         |
|FGC/FGCT (s)                     |0/0             |0/0             |

**测试小结**
从测试结果来看, 50 并发量的请求压力下, 6.4.25 与 7.4.5 版本没有存在明显的差距; 但是在更高的并发量下, 6.4.25 版本的 berkeley db 根本扛不住;
所以这里毫无疑问, 7.4.5 版本的 berkeley db 是优于 6.4.25 版本的;

### **计划 E: 收集器对比**
最后是关于收集器的对比; 考虑到 G1 对于大内存 (大于 16g) 的延时管理较其他收集器有优势, 这里也需要就收集器作一些对比测试;
两个收集器的选项对比如下:
ParNew + CMS:
``` bash
-XX:ParallelGCThreads=${CPU_COUNT}

-XX:+UseConcMarkSweepGC
-XX:+UseCMSCompactAtFullCollection
-XX:+CMSClassUnloadingEnabled
-XX:CMSInitiatingOccupancyFraction=80
-XX:+UseCMSInitiatingOccupancyOnly
-XX:+CMSScavengeBeforeRemark
```
G1:
``` bash
-XX:+UnlockDiagnosticVMOptions
-XX:+UseG1GC
-XX:+G1SummarizeConcMark
```
测试环境:
``` bash
-Xms=25g
-Xmx=25g
-Xmn=10g
-Dje.maxMemoryPercent=10
-XX:MaxDirectMemorySize=30g
-Dje.maxOffHeapMemory=10g
```

**E-1: 测试 set**
测试命令:
``` bash
# 100 万次请求, 250 个并发
ab -n 1000000 -c 250 -s 5 "http://${remote_url}/random_set?keyRange=9999999&valueSize=5000"
sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/E-1_X
```
测试结果:

|metrics \ collector              |CMS             |G1              |
|:-------------------------------:|:--------------:|:--------------:|
|RT (min/P90/P99/max) (ms)        |6/128/352/1708  |ab timeout      |
|RT (mean/median) (ms)            |87/75           |/               |
|error/timeout                    |0               |/               |
|stdev/bias                       |72.0            |/               |
|YGC/YGCT (s)                     |14/4.397        |/               |
|FGC/FGCT (s)                     |0/0             |/               |

**E-2: 测试 get**
测试命令:
``` bash
# 100 万次请求, 250 个并发
ab -n 1000000 -c 250 -s 5 "http://${remote_url}/random_get?keyRange=9999999"
sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/E-2_X
```
测试结果:

|metrics \ collector              |CMS             |G1              |
|:-------------------------------:|:--------------:|:--------------:|
|RT (min/P90/P99/max) (ms)        |8/26/29/1038    |/               |
|RT (mean/median) (ms)            |23/24           |/               |
|error/timeout                    |2               |/               |
|stdev/bias                       |17.8            |/               |
|YGC/YGCT (s)                     |6/0.963         |/               |
|FGC/FGCT (s)                     |0/0             |/               |

**E-3: 测试 mget**
测试命令:
``` bash
# 100 万次请求, 250 个并发
ab -n 1000000 -c 250 -s 5 "http://${remote_url}/random_mget?keyRange=9999999&keyNum=20"
sudo -u www jstat -gcutil -h 10 ${vmid} 1000 | tee /tmp/jstat_collect/E-3_X
```
测试结果:

|metrics \ collector              |CMS             |G1              |
|:-------------------------------:|:--------------:|:--------------:|
|RT (min/P90/P99/max) (ms)        |6/28/31/4804    |/               |
|RT (mean/median) (ms)            |32/25           |8/7             |
|error/timeout                    |10907           |/               |
|stdev/bias                       |29.8            |/               |
|YGC/YGCT (s)                     |23/22.947       |/               |
|FGC/FGCT (s)                     |2/1.689         |/               |

**测试小结**
可惜了, 我 retry 了几次, 使用 G1 gc, ab 都在途中 timeout 了; jstat 显示 G1 的 young gc 经历了一个非常长的时间:
``` bash
  S0     S1     E      O      M     CCS    YGC     YGCT    FGC    FGCT     GCT  
  0.00 100.00  94.87  47.44  98.45  96.54     12    6.923     0    0.000    6.923
  0.00 100.00  94.87  47.44  98.45  96.54     12    6.923     0    0.000    6.923
  0.00 100.00   2.89  50.92  98.46  96.54     12   14.315     0    0.000   14.315
  0.00 100.00   2.97  50.92  98.46  96.54     12   14.315     0    0.000   14.315
```
``` bash
  S0     S1     E      O      M     CCS    YGC     YGCT    FGC    FGCT     GCT  
  0.00 100.00  94.87  50.92  98.46  96.54     13   14.315     0    0.000   14.315
  0.00 100.00  94.87  50.92  98.46  96.54     13   14.315     0    0.000   14.315
  0.00 100.00   2.14  55.58  98.29  96.54     13   25.692     0    0.000   25.692
  0.00 100.00   2.21  55.58  98.29  96.54     13   25.692     0    0.000   25.692
```
我对 G1 的了解还是不够深入, 可能当前的场景比较特殊, 需要作定制化的调参, 之前使用 G1 都是只加 `-XX:+UseG1GC` 和 `-XX:+G1SummarizeConcMark` 两个参数, 其余的优化都交给 jvm 了, 然而对于今天的场景这可能不够用了, 这个需要另行研究了;

## **测试总结**
本次测试采用 ab + jstat 组合的方式同时采集测试数据, ab 用于反映系统表面的性能指标, jstat 用于反映系统的 gc 状态, 并进而反映隐藏在表面之下的系统性能问题或者服务潜力;
本次测试并没有作极限测量 (不断增大并发直至压挂为止), 而是根据当前的调用状况取了一个留有适当 buffer 的并发量, 从测试结果中可以间接得计算当前服务能承载的 TPS;
根据测试的结果, 7.4.5 版本的 berkeley db 优于 6.4.25 版本的 berkeley db, 其在并发承受能力上存在明显优势;
在收集器选择上, 暂时还是使用 CMS 比较稳妥, G1 可能遇到了特殊的情况, 需要后续研究调优的方法;
在使用 7.4.5 版本的 berkeley db 时, 建议作如下内存配置组合, 以达到较好的使用效果:
``` bash
-Xms= 20g ~ 30g
-Xmx= 20g ~ 30g

-Dje.maxMemoryPercent= ${Xmx} * 80% / ${bdb_shard_number}
-XX:MaxDirectMemorySize= (${machine_total_memory} - ${Xmx}) * 80%
-Dje.maxOffHeapMemory= ${MaxDirectMemorySize} / ${bdb_shard_number}
```

