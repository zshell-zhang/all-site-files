---
title: lsof 札记
date: 2017-01-06 15:17:04
categories:
  - linux
  - other
tags:
  - linux:net
  - linux:disk
---

> 第一次接触到 lsof 命令, 是因为偶然间发现 netstat 命令已经落伍了(与此同时, 还发现了 ss 命令, 详见另一篇文章: [netstat/ss 使用对比]() );
使用之后, 发现 lsof 被人称为 `神器`, 还是有一定道理的; 在任何资源都被抽象为 `文件` 的 linux 中, 一个面向 `文件` 的管理工具, 自然辖域辽阔, 神通广大, 再加上与其他命令的巧妙组合, 更如虎添翼, 在工作实践中独当一面;
本文参考了一些实用资料, 结合自己的经验, 对 lsof 命令的使用略作整理;

<!--more-->

------

## **lsof 命令的输出结构**
``` bash
# COMMAND   启动进程的命令
# PID       进程号
# TID       线程号
# USER      用户
# FD        文件描述符
# TYPE      文件类型
# DEVICE    磁盘名称
# SIZE      文件大小
# NODE      inode 号
# NAME      文件资源的名称
> sudo lsof | head -n 2
COMMAND     PID   TID      USER   FD      TYPE             DEVICE    SIZE/OFF       NODE NAME
systemd       1            root  cwd       DIR              253,1        4096        128 /
```

### **各字段的不同输出含义**
FD: 文件描述符 file description
``` bash
# 任何进程都必须有的
0:      标准输入流
1:      标准输出流
2:      标准错误流

# 几种特殊的保留 fd
cwd:    current work directory, 应用程序启动的目录
txt:    二进制可执行文件或共享库
rtd:    root directory, 根目录
mem:    memory mapped file, 内存映射文件
mmap:   memory-mapped device, 内存映射设备

# 整数后面跟着的字母
u:      可读可写模式
r:      只读模式
w:      只写模式
```
TYPE: 文件类型
``` bash
DIR:    目录文件
REG:    普通文件
CHR:    char, 字符设备文件
BLK:    block, 块设备文件
IPV4:   ipv4 socket 套接字文件
IPV6:   ipv6 socket 套接字文件
```
DEVICE:
``` bash
todo
```
SIZE: 文件大小
``` bash
# 套接字文件的文件大小比较特殊, 其没有大小, 用特殊字符占位, 其余则正常显示 size
0t0:    套接字文件的默认占位
```
&nbsp;
## **lsof 的日常应用**
### **lsof 网络 相关的应用**
``` bash
# 显示所有网络连接
sudo lsof -i
# 只显示 ipv6 的连接
sudo lsof -i 6
# 只显示 tcp 协议的连接
sudo lsof -i TCP
# 指定端口号
sudo lsof -i:port
# 指定主机(与端口)
sudo lsof -i@l-tracer15.tc.cn2.xx.com:9999
```

### **lsof 用户 相关的应用**
``` bash
# 显示某用户所打开的文件
sudo lsof -u zshell.zhang
sudo lsof -u ^zshell.zhang (排除此用户)
```

### **lsof 命令/进程 相关的应用**
``` bash
# 只显示 pid
sudo lsof -t
# 只显示指定的命令打开的文件
sudo lsof -c nginx
# 只显示指定 pid 的进程打开的文件
sudo lsof -p pid
```

### **lsof 文件/目录 相关的应用**
``` bash
# 搜索与指定路径相关的一切资源(user, process 等)
sudo lsof /target_path
# +d: 搜索与指定的一级目录下所有的文件相关的一切资源; +D: 递归操作(往下所有层级目录)
sudo lsof +d /target_path
sudo lsof +D /target_path
```

### **lsof 的选项组合及实践技巧**
上述的 lsof 操作, 对于多种选项的组合, 其默认是 或(or) 的关系, 即满足其中之一便会打印出来;
lsof 与(and) 的逻辑运算关系如下:
``` bash
# 使用 -a 达到 与(and) 的效果
# 必须同时满足三个条件: 
#   1. 是用户 zshell.zhang 启动的进程;
#   2. 是套接字文件, 且连接的主机是 10.64.4.11;
#   3. 该进程命令是 java;
sudo lsof -a -u zshell.zhang -i@10.64.4.11 -c java
```
lsof 常用的组合及实践:
``` bash
# 寻找已删除但未释放文件句柄的幽灵文件
sudo lsof | grep deleted
# 杀死所有匹配一定文件打开条件的进程
sudo kill `sudo lsof -t -c java` # 杀死所有 java 进程
sudo kill `sudo lsof -t -u zshell.zhang` # 杀死所有 zshell.zhang 的用户进程
# 恢复删除的文件
# 找到误删文件被什么进程持有, 获得 pid 和 fd
1. sudo lsof /target_deleted_file
# /proc/{pid}/fd/{fd_num} 的内容即为误删内容, 重定向到误删文件中即可
2. cat /proc/{pid}/fd/{fd_num} > /target_deleted_file
```
另外, lsof 还可以被运用于找出系统中的幽灵文件, 详见: [du / df 使用及其区别](https://zshell-zhang.github.io/2017/04/07/linux-other--du,df使用及其区别/);

## **站内相关文章**
- [netstat/ss 使用对比]()
- [du / df 使用及其区别](https://zshell-zhang.github.io/2017/04/07/linux-other--du,df使用及其区别/)

## **参考链接**
- [linux lsof详解](http://blog.csdn.net/guoguo1980/article/details/2324454)
- [每天一个Linux命令（45）lsof命令](http://www.cnblogs.com/MenAngel/p/5575479.html)
- [Linux 命令神器: lsof 入门](https://linux.cn/article-4099-1.html)
- [what-does-the-fd-column-of-pipes-listed-by-lsof-mean](https://stackoverflow.com/questions/25140730/what-does-the-fd-column-of-pipes-listed-by-lsof-mean)

