---
title: du / df 使用及其区别
date: 2017-04-07 22:58:04
categories:
 - linux
 - other
tags:
 - linux:disk
---

> 本文主要是整理 磁盘使用量 相关的命令, 如 du, df 等;
接着, 一般性得总结这两个命令在实际工作中的应用;
然后再以 du, df 命令的区别为例, 讨论命令背后的逻辑, 工作中存在的问题, 最后引申出问题解决的工具: lsof;

<!--more-->

------

## **du命令**
estimate disk file space usage. ---- man du
### **du 的常用选项**
``` bash
# 不加任何选项, 默认是 列举指定路径下, 每一个目录(递归所有的子目录)的大小
sudo du /target_path
# 列举指定路径下所有的文件(包括目录与文件)的大小
sudo du -a /target_path
# 以 human-readable 的形式, 列举目标路径的文件磁盘占用总大小(将该路径下所有子文件大小求和)
sudo du -s /target_path
# 以指定路径下所有的子一级路径为 target, 以 human-readable 的方式列举其中每一个下的所有子文件大小之和(诊断 磁盘满问题 最常用的方式)
sudo du -sh /target_path/*
# 除了其余选项该有的输出之外, 最后一行另附一个给定 target_path 下的 total 总和
# 理论上这与目标路径不含通配符的 -sh 输出结果是相同的
sudo du -c /target_path
```
&nbsp;

## **df 命令**
file system disk space usage. ---- man df
### **df 的常用选项**
``` bash
# 显示给定的路径所挂载的磁盘分区的大小及使用量等
df /target_path
# 以 MB 最小单位显示大小及使用量
df --block-size=1m /target_path
df -B 1m /target_path
# 以 human-readable 的方式显示 当前挂载的所有可用健康的文件系统 的大小, 使用量等情况
df -h # 1024
df -H # 1000
# 显示所有的文件系统, 包括 伪文件系统, 重复的, 不可访问的文件系统 (pseudo, duplicate, inaccessible)
df -a
# 过滤 nfs 远程文件系统后的本地文件系统
df -l
```
&nbsp;
**一般性总结:**
df 命令主要关心的是磁盘分区的 size, 而不是具体某文件的占用大小; 
所以 df 命令的主要运用场景是: `df -h`, 判断所挂载的每个分区的使用率, 是不是满了;
作为先决判断依据, 如果发现磁盘满了, 再接着使用 `du -sh` 等命令进一步排查;
&nbsp;

## **du 与 df 命令的区别**
### **df 命令与 du 命令的工作原理**
df 命令使用 系统调用 `statfs`, 获取磁盘分区的超级块 (super block) 使用情况;
du 命令使用 系统调用 `fstat`, 获取待统计文件的大小;
### **df 命令与 du 命令可接受范围内不一致**
问题场景: *du -s 与 df 核算精确结果总有差异;*
&nbsp;
原因: du -s 命令通过将指定文件系统中所有的目录, 符号链接和文件使用的块数累加得到该文件系统使用的总块数, 这是上层用户级的数据;
df 命令通过查看文件系统磁盘块分配图得出总块数与剩余块数, 这是直接从底层获取的数据;
所以, 一些元数据信息(inode, super blocks 等)不会被上层的 du 命令计入在内, 而 df 命令由于直接获取的底层超级块的信息, 则会将其计入在内;
&nbsp;
结论: *这种差异属于系统性的差异, 是由命令的特点决定的, 无法改变;*
### **df 命令与 du 命令显著不一致**
问题场景: *当一个被某进程持有其句柄的文件被删除后, 进程不释放句柄, du 将不会再统计该文件, 而 df 的使用量会将其计入在内;*
&nbsp;
原因: 当文件句柄被进程持有, 尽管文件被删除, 目录项已经不存在该文件路径了, 但只要句柄不释放, 文件在磁盘上就不会真正删除该文件;
这样一来, 目录项不存在该文件了, du 命令就不会统计到该文件, 但文件没真正删除, 磁盘分区 super block 的信息就不会改变, df 命令仍会将其计入使用量;
&nbsp;
结论: *这种差异属于第三方因素干扰导致的差异, 且差异十分显著, 需要通过下一节所讨论的方式加以解决;*
### **问题解决方案**
磁盘满了, 但是有进程持有大文件的句柄, 无法真正从磁盘删除掉; 对于这类问题, 有如下两种解决方案:
1.配合使用 lsof 找出相关的 `幽灵文件` 的句柄持有情况(command 与 pid):
``` bash
> sudo lsof | grep deleted
nginx      4804      nobody   59u      REG	253,1    110116  243425480 /usr/local/openresty/nginx/client_body_temp/0068359496 (deleted)
nginx      4819      nobody   51u      REG	253,1    115876  243425480 /usr/local/openresty/nginx/client_body_temp/0068359498 (deleted)
...
```
然后 kill 掉进程 (或 restart 进程), 即可释放文件句柄;
当然, 本文是以 nginx 举例, 但实际上 nginx 对于日志文件的文件句柄释放, 有自己专有的方法, 具体内容请见本站另外两篇文章: [linux signals 总体认识#其他信号](https://zshell-zhang.github.io/2017/04/05/linux-process--linux_signals总体认识/#其他信号) 和 [nginx signals 处理]();
另外, 磁盘满的问题, 不能总是靠人肉登机器去解决, 我们需要一些自动化的方案来将我们从这种低级的操作中解放出来; 
所以, 对于所有机器上都会遇到的日志文件不断累积占满磁盘的问题, 这篇文章介绍了解决方案: [logrotate 配置与运维]();
&nbsp;
2.如果进程很重要, 不能容忍任何时间范围内的服务不可用 (其实理论上这种情况属于单点瓶颈, 未能做到高可用), 则可以采用如下方式:
``` bash
# 将文件写空
sudo echo > file_path
```
将文件内容间接删除, 这样即便句柄未释放, 但文件本身已经没有内容, 也就不再占用空间了;
&nbsp;

## **参考链接**
- [df和du显示的磁盘空间使用情况不一致的原因及处理](http://www.cnblogs.com/heyonggang/p/3644736.html)
- [linux lsof 详解](http://blog.csdn.net/guoguo1980/article/details/2324454)

