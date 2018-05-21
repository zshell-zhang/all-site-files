---
title: top 命令与操作及其参数指标总结
date: 2017-03-16 18:59:15
categories:
 - linux
 - perf
tags:
 - linux:perf
 - 系统性能诊断
---

> 排查系统性能问题时, 最尴尬的事情莫过于敲下 top 命令后, 看着不断跳动的界面, 愣是不知道接下来要怎么操作, 最后无奈得按下了一个 q;
所以我专门写作本文, 系统性得整理一下 top 命令所展示的内容与结构, 常见操作快捷键与技巧; 虽然在 top 界面里按 h 便能进入帮助界面, 但那种操作排版比较密集, 信息量太大, 没有直观性;
当然, 即使是这篇文章的内容, 我最好也熟记于心, 否则排查问题的时候还要查操作笔记, 也是件挺尴尬的事情;

<!--more-->

------

## **top 命令的选项**
top 命令有丰富的选项可以使用, 常用的如以下几种:
``` bash
# -u    user, 指定展示的用户
# -d    delay, 指定刷新频率
top -u nginx -d 1

# -n    iteration, 指定刷新多少次之后自动退出 top 命令
# -p    pid, 指定进程 id
top -n 20 -p {pid1} {pid2} ...
```

## **全局系统信息**
top 命令的界面被分为泾渭分明的两部分, 上半部分是全局类的信息, 展示 load, cpu, 内存, 进程数目统计等信息, 本节主要介绍的就是上半部分: 全局系统信息;
``` bash
top - 13:37:53 up 12 days, 23:30,  1 user,  load average: 1.03, 0.80, 0.74
Tasks: 262 total,   1 running, 259 sleeping,   0 stopped,   2 zombie
%Cpu(s):  6.3 us,  1.9 sy,  0.0 ni, 88.4 id,  3.4 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem :  8062940 total,  2259668 free,  3244360 used,  2558912 buff/cache
KiB Swap:  5999612 total,  4462904 free,  1536708 used.  3654256 avail Mem
```
* 第一行是 uptime 信息;
* 第二行和第三行是 cpu 及进程信息;
* 第四行和第五行是 free 信息;

### **cpu 全局统计信息**
全局的 cpu 统计信息, 主要存在于 top 命令的第三行:
``` bash
# us    user time
# sy    system time
# ni    niceness process time
# id    idle time
# wa    wait time
# hi    hardware interrupt time
# si    software interrupt time
# st    stole time, used in virtualization
%Cpu(s):  5.8 us,  1.0 sy,  0.0 ni, 90.4 id,  2.8 wa,  0.0 hi,  0.0 si,  0.0 st
```
其中有几个比较重要的指标:

* user time 时间占比大, 说明用户空间内的 cpu 计算比较多, 这属于最常见的状态;
* system time 时间占比大, 说明 system call 系统调用比较多, 计算多在内核空间发生;
这往往不是一个好的兆头, 如果伴随着系统的性能异常, 需要使用 strace 等命令追踪系统调用的状态;
如果一个正常情况下 system time 很少的进程, 突然莫名其妙得 user time 与 system time 的差距达到了量级, 那么有相当的概率, 系统内核发生了性能问题, 比如缺页 (page fault);
如果一个进程每次启动都会造成很高的 system time, 那么很可能是进程内部的逻辑在执行某些耗时的 system call, 这一点在 [火丁笔记的总结](https://huoding.com/tag/strace) 里十分有代表性;
* idle time 时间占比很大, 说明 cpu 很闲, 时间多消耗在了闲置进程上;
* wait time 时间占比很大, 这十有八九是 cpu 等待 IO 设备的时间过长, 比较常见的是磁盘 IO 出现了吞吐瓶颈, 导致 cpu wait; 当然也有可能是网络适配器的带宽被打满了;

除此之外, 其余的几个指标, nice, hardware interrupt, software interrupt, stole, 相对来说要次重要一些, 对系统的影响有限;

### **全局系统信息 快捷键**

1. 按小写 `l` (字母) 可以显示/隐藏 uptime 信息;
2. 连续按 `t` 可以切换四种(包括隐藏) cpu 信息的显示方式;
3. 按小写 `1` (数字) 可以详细显示 cpu 的每一个 core 的状态统计信息;
4. 连续按 `m` 可以切换四种(包括隐藏) free 信息的显示方式;
5. 连续按 `E` 可以切换 KB, MB, GB, TB, PB, EB 六种 free 信息显示的单位;

## **进程详细信息**
top 命令的界面被分为泾渭分明的两部分, 下半部分是进程的详细信息, 展示特定进程的 cpu, 内存, 命令等信息, 本节主要介绍的就是下半部分: 进程详细信息;
``` bash
PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
1   root      20   0   44752   6880   3504 S   0.0  0.2   2:29.89 systemd
2   root      20   0       0      0      0 S   0.0  0.0   0:00.20 kthreadd
3   root      20   0       0      0      0 S   0.0  0.0   0:06.73 ksoftirqd/0
5   root       0 -20       0      0      0 S   0.0  0.0   0:00.00 kworker/0:0H
7   root      rt   0       0      0      0 S   0.0  0.0   0:00.36 migration/0
```
### **第一行的字段含义**
``` bash
PR:     priority
NI:     nice
VIRT:   virtual mem, 虚拟内存
RES:    resident mem, 常驻内存
SHR:    shared mem, 共享内存
S:      state: R(running), S(sleep), Z(zombie), T(terminate)
%CPU:   cpu  综合使用量
%MEM:   内存 综合使用量
TIME+:  进程的 cpu 时间
```
其中:
PR 为 rt 代表进程运行在实时态;
VIRT = RES + SWAP;
RES = CODE + DATA = SHR + 程序自身所占的物理内存;

### **进程详细信息 快捷键**
1. `V` 以树形结构显示各进程;
2. `c` 详细/简略 显示 COMMAND 列的信息(带命令参数与否);
3. `enter`/`space`  立即刷新指标;
4. `e`  连续敲击 可以切换 KB, MB, GB, TB, PB 五种内存显示(VIRT, RES, SHR)的单位;
5. `d`/`s`  改变 top 命令刷新指标的频率, 会出现交互提示, 输入指定的时间; 默认是 3s;
6. `M` 以内存使用率从大到小排序;
7. `P` 以 CPU 使用率从大到小排序;
8. `k` kill 掉指定的进程, 会出现交互提示, 先输入 pid, 再输入 signal id;

注意, 第 8 条 kill 指定进程, 一定要以启动进程的用户执行 top 命令才有权限 kill 它; 或者更统一的, 直接用 sudo 执行 top 命令, 就有权限 kill 指定进程了;

## **参考链接**
- [User space 与 Kernel space](http://www.ruanyifeng.com/blog/2016/12/user_space_vs_kernel_space.html)
- [你不一定懂的cpu显示信息](https://www.cnblogs.com/yjf512/p/3383915.html)
- [TOP命令详解](http://www.cnblogs.com/qiwenhui/articles/4262044.html)
- [程序如何影响VIRT (虚存) 和 RES (实存/常驻内存)](http://blog.csdn.net/rebirthme/article/details/50402107)
- [火丁笔记 tag: strace](https://huoding.com/tag/strace)

