---
title: cli 控制字符
date: 2016-11-17 21:11:33
categories:
 - linux
 - other
tags:
 - cheat sheet
---

> cli 控制字符是终端操作中非常实用, 也极其频繁使用的快捷键; 使用得好可以加快敲命令的速度, 提升敲命令的准确性, 为工作带来极大便利; 同时, 这也是我们对 linux 爱不释手, 难以回到 windows 的原因之一;
另外, 很多 cli 控制字符本质上是向 linux 或进程发送特定的信号, 关于 linux 信号的介绍, 本站有另外一篇文章: [linux signals 总体认识](https://zshell-zhang.github.io/2017/04/05/linux-process--linux_signals%E6%80%BB%E4%BD%93%E8%AE%A4%E8%AF%86/);
本文总结一些常用的 cli 控制字符的使用及技巧;

<!--more-->

------

### **简单的 cli 控制字符**
``` bash
# 发送 SIGINT 中断信号
ctrl + c
# 清屏
ctrl + l
# reverse-i-search 搜索历史命令
ctrl + r
# 从机器上 logout
ctrl + d
# 暂停控制台标准输出 / 恢复控制台标准输出
ctrl + s / ctrl + q
# 发送 SIGQUIT 信号给前台进程, 并生成 core dump
ctrl + /
# 向前删除到第一个空格
ctrl + w
# 向后删除到第一个空格
 alt + d
# 向后删除所有的内容
ctrl + k
# 撤销上一步操作
ctrl + ?
# 光标快速跃进
ctrl + 方向键
# 补全命令/文件
tab
```

### **与其他命令组合的 cli 控制字符 **
``` bash
# 发送 SIGTSTP 信号, 挂起前台进程
ctrl + z
# ctrl + z 的输出
[1]+  Stopped                 sudo vim /etc/profile
```
此时该前台进程被挂起, 操作系统将不会调度任何 cpu time 给此进程;
接下来可以有以下配套操作:
``` bash
# 查看后台任务
> jobs
[1]+  Stopped                 sudo vim /etc/profile
# 查看后台任务的 pid
jobs -p

# 将后台作业 1 恢复到前台
fg 1
fg %1
# 将后台作业 1 恢复到后台
bg 1
bg %1
```
要杀死被挂起的后台任务有一些麻烦, 因为该任务处于 suspend 状态, 无法主动响应 SIGTERM, SIGINT 等相对柔和的信号, 但可以被 SIGKILL 这种强力的信号直接杀死:
``` bash
kill -9 %1
kill -9 `jobs -p`
```
还有一种比较讨巧的方法是结合 fg/bg 等唤醒后台任务的命令:
``` bash
# 当任务被唤醒, 将接收到 SIGTERM 信号并终止
kill %1 && fg
kill %1 && bg
kill `jobs -p` && bg
kill `jobs -p` && fg
```

### **控制字符的管理与设置**
``` bash
# 打印所有控制字符的设置 (--all)
> stty -a
speed 38400 baud; rows 60; columns 211; line = 0;
intr = ^C; quit = ^\; erase = ^?; kill = ^U; eof = ^D; eol = <undef>; eol2 = <undef>; swtch = <undef>; start = ^Q; stop = ^S; susp = ^Z; rprnt = ^R; werase = ^W; lnext = ^V; flush = ^O; min = 1; time = 0;
-parenb -parodd cs8 -hupcl -cstopb cread -clocal -crtscts -cdtrdsr
-ignbrk -brkint -ignpar -parmrk -inpck -istrip -inlcr -igncr icrnl ixon -ixoff -iuclc -ixany -imaxbel -iutf8
opost -olcuc -ocrnl onlcr -onocr -onlret -ofill -ofdel nl0 cr0 tab0 bs0 vt0 ff0
isig icanon iexten echo echoe echok -echonl -noflsh -xcase -tostop -echoprt echoctl echoke
```

### **参考链接**
- [Bg, Fg, &, Ctrl-Z – 5 Examples to Manage Unix Background Jobs](http://www.thegeekstuff.com/2010/05/unix-background-job/)
- [Linux中 ctrl-c, ctrl-z, ctrl-d 区别](http://blog.csdn.net/mylizh/article/details/38385739)

