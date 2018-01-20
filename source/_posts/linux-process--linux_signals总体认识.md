---
title: linux signals 总体认识
date: 2017-04-05 23:24:22
categories:
  - linux
  - process
tags:
  - linux:process
---

> linux 的信号系统其实是一个非常重要的概念, 进程间通信的常用方法之一;
不过长期以来, 我们对 linux 信号的直观认识, 只有 kill (SIGTERM), ctrl + c (SIGINT) 和 kill -9 等进程终止信号; 而 linux 的信号系统中存在 64 种各司其职的信号, 适用于各种各样的场景; 很多信号在实际工作中有着妙用;
本文正是想对 linux 世界中林林总总的 signals 作一次梳理, 总结一些日常工作中频繁使用以及不太接触但十分有用的信号;

<!--more-->

## **linux signals 总览**
linux siginal 可分为如下几大类:

1. 系统错误信号
2. 进程终止信号
3. 作业控制信号
4. AIO 信号
5. 定时器信号
6. 操作错误信号
7. 其他信号

&nbsp;
linux signals 的产生源一般分为三类: 硬件方式(除数为 0, 内存非法访问等), IO 方式(键盘事件), 以及软件方式: kill 命令, alarm 定时器等;
其中我们最熟悉的莫不过 kill 命令了, 详情请见: [kill 命令族及其选项]();

&nbsp;
使用 kill -l 查看所有信号分布:
``` bash
> kill -l
 1) SIGHUP	     2) SIGINT	    	 3) SIGQUIT	     4) SIGILL	    	 5) SIGTRAP
 6) SIGABRT	     7) SIGBUS	    	 8) SIGFPE	     9) SIGKILL	    	10) SIGUSR1
11) SIGSEGV	    12) SIGUSR2	    	13) SIGPIPE	    14) SIGALRM	    	15) SIGTERM
16) SIGSTKFLT	    17) SIGCHLD	    	18) SIGCONT	    19) SIGSTOP	    	20) SIGTSTP
21) SIGTTIN	    22) SIGTTOU	    	23) SIGURG	    24) SIGXCPU	    	25) SIGXFSZ
26) SIGVTALRM	    27) SIGPROF	    	28) SIGWINCH        29) SIGIO	    	30) SIGPWR
31) SIGSYS	    34) SIGRTMIN    	35) SIGRTMIN+1      36) SIGRTMIN+2  	37) SIGRTMIN+3
38) SIGRTMIN+4	    39) SIGRTMIN+5  	40) SIGRTMIN+6      41) SIGRTMIN+7  	42) SIGRTMIN+8
43) SIGRTMIN+9	    44) SIGRTMIN+10 	45) SIGRTMIN+11     46) SIGRTMIN+12 	47) SIGRTMIN+13
48) SIGRTMIN+14	    49) SIGRTMIN+15 	50) SIGRTMAX-14     51) SIGRTMAX-13 	52) SIGRTMAX-12
53) SIGRTMAX-11	    54) SIGRTMAX-10 	55) SIGRTMAX-9      56) SIGRTMAX-8  	57) SIGRTMAX-7
58) SIGRTMAX-6	    59) SIGRTMAX-5  	60) SIGRTMAX-4      61) SIGRTMAX-3  	62) SIGRTMAX-2
63) SIGRTMAX-1	    64) SIGRTMAX
```

## **各类别信号整理**

### **进程终止信号**
进程终止信号是我们日常操作中最常用的一类信号;
进程终止信号共有五个, 其中除了 SIGKILL 之外, 其他信号都是 可阻塞, 可忽略, 可处理的;
``` bash
# terminate, kill 不加任何选项的默认信号, 默认处理是终止进程;
SIGTERM
# interrupt, ctrl + c 发出的信号, 默认处理是终止进程;
SIGINT
# quit, ctrl + / 发出的信号, 与 SIGINT 类似, 不过其默认处理相比 SIGINT 还增加了一项:
# 1. 终止进程; 2. 产生进程 core dump 文件;
SIGQUIT
# kill, 不可阻塞, 不可忽略, 最强力的终止信号, 通常会导致进程立即终止, 其占有的资源无法释放清理
# 一般需要在 SIGTERM/SIGINT/SIGQUIT 等信号无法响应之后, 才最后使用
SIGKILL
# hang up, 通常在用户退出终端断开 sessiion 时由系统发出该信号给 session
# session 接收该信号并将其发送给子进程
SIGHUP
```
另外一篇详细梳理与 SIGHUP 相关知识点的链接: [SIGHUP 相关全梳理]();
该文章主要涉及 SIGHUP 信号发生的条件, 传导, 与 SIGHUP 相关的 nohup, &,  shopt huponexit, disown 等概念, 并包括一些 SIGHUP 的自定义应用;

### **任务控制信号**

### **其他信号**
其他信号是指未在上述分类中的一些小众信号, 这些信号本身并未有太多关联, 不能用一个类别去统一描述它们;
&nbsp;
(1) 用户自定义信号: SIGUSR1 / SIGUSR2
这两个信号, linux 保证系统自身不会向进程发送, 完全由使用者自己定义该信号的语义以及处理逻辑;
SIGUSR1 与 SIGUSR2, 在系统层面完全没有区别, 如果可以, linux 其实能再定义一个 SIGUSR3; 所以用户自定义信号的预留数量, 本身是一个模糊的界定;
以下是 SIGUSR1 / SIGUSR2 的具体使用场景:
``` bash
# 通知 nginx 关闭当前句柄, 重新打开日志文件, 用于 logrotate 切割日志
kill -USR1 `cat /var/run/nginx.pid`
# 通知 nginx 平滑升级 二进制可执行程序
kill -s SIGUSR2 `cat /var/run/nginx.pid`
```
&nbsp;
(2) SIGWINCH (winch 译作: 吊车, 摇柄), 默认处理是忽略该信号;
以下是 SIGWINCH 的具体使用场景:
``` bash
# 通知 nginx worker process 不再接受新 request, 并从容关闭
kill -WINCH `cat /var/run/nginx.pid`
```
当然, 通知 worker process 不再接受新请求, nginx 并不需要使用者直接在 linux signals 层面直接处理, nginx 本身提供了平滑重启命令 `sbin/nginx -c conf/nginx.conf -s reload`, SIGWINCH 信号的发送封装在了该命令里;
&nbsp;
关于 nginx 与 linux signals 的关系, 在本站另一篇文章中有详细介绍: [nginx signals 处理]();

## **站内相关文章**
- [kill 命令族及其选项]()
- [SIGHUP 相关全梳理]()
- [nginx signals 处理]()

## **参考链接**
- [24.2.2 Termination Signals](http://www.gnu.org/software/libc/manual/html_node/Termination-Signals.html#Termination-Signals)
- [24.2.5 Job Control Signals](http://www.gnu.org/software/libc/manual/html_node/Job-Control-Signals.html)
- [24.2.7 Miscellaneous Signals](http://www.gnu.org/software/libc/manual/html_node/Miscellaneous-Signals.html#Miscellaneous-Signals)
- [Difference between SIGUSR1 and SIGUSR2](https://stackoverflow.com/questions/27403641/difference-between-sigusr1-and-sigusr2)
- [linux kill 命令 以及 USR1 信号 解释](http://blog.csdn.net/fuming0210sc/article/details/50906372)
- [Linux 信号入门详解](http://blog.csdn.net/lisongjia123/article/details/50471854)
- [文章3: Nginx中与信号有关的内容](http://blog.csdn.net/yankai0219/article/details/8453261)

