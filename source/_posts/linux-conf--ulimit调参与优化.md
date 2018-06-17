---
title: ulimit 调参与优化
date: 2017-10-28 23:23:05
categories:
 - linux
 - conf
tags:
 - linux:conf
---

> ulimit 未正确设置是很多线上故障的根源: 
`Too many open files`;
`java.lang.OutOfMemoryError: unable to create new native thread`;
对于生产环境来说, ulimit 的调参优化至关重要;
本文详细介绍并梳理一下与 ulimit 相关的林林总总;

<!--more-->

------

ulimit 是 linux 对于每个通过 PAM 登录的用户 ( 每个进程 ) 的资源最大使用限制的设置;
注意, 这里仅仅对通过 PAM 登陆的用户起作用, 而对于那些随系统启动而启动的 daemon service, ulimit 是不会去限制其资源使用的;
在 `/etc/security/limits.conf` 文件中的第一段注释如下:
> This file sets the resource limits for the users logged in via PAM.
It does not affect resource limits of the system services.

关于 linux PAM 相关的内容, 可以前往另外一篇文章: [pam 认证与配置]();

## **ulimit 基本信息**
``` bash
# 查看所有 ulimit 设置
> ulimit -a
core file size          (blocks, -c) 0
data seg size           (kbytes, -d) unlimited
scheduling priority             (-e) 0
file size               (blocks, -f) unlimited
pending signals                 (-i) 15018
max locked memory       (kbytes, -l) 64             # 每个进程可以锁住而不被 swap 出去的内存
max memory size         (kbytes, -m) unlimited      # 每个进程可使用的最大内存大小
open files                      (-n) 1024           # 每个进程可打开的文件数
pipe size            (512 bytes, -p) 8
POSIX message queues     (bytes, -q) 819200
real-time priority              (-r) 0
stack size              (kbytes, -s) 8192           # 每个进程可使用的最大堆栈大小
cpu time               (seconds, -t) unlimited
max user processes              (-u) 4096           # 每个用户的最大进程数
virtual memory          (kbytes, -v) unlimited
file locks                      (-x) unlimited
```

## **ulimit 需要优化的场景及待优化参数**
linux 默认的 ulimit 限制, 是出于安全考虑, 设置的有些保守; 实际的生产环境下, 往往需要对其作出适当的调整, 方可发挥机器的最大性能;
### **场景1: tomcat web 容器 **
一台 4C4G60G 的标准虚拟主机, 其上部署了一个 tomcat 实例, 启动 catalina 进程的是 tomcat:tomcat 用户;
如果该服务是一个网络 IO 密集的应用, 需要打开的 socket file 远不止 1024, ulimit 设置的 max open files 就会限制其性能; 另外, 该主机只部署了这一个服务, tomcat 用户是唯一一个需要占用大量资源的用户, ulimit 对单个用户的限制便会造成机器资源闲置, 极低的使用率, 降低 web 服务的性能;
所以, 可以对该机器的 ulimit 作出如下调整:
``` bash
1. max memory size -> unlimit
2. open files -> 65536
3. stack size -> unlimit
```
另外, 我们还遇到一种特殊的情况, 用标准配置虚拟机跑 dubbo 的服务治理: 当时发现, 如果服务注册到 zookeeper 的数量达到一定级别, 线上就会报 `java.lang.OutOfMemoryError: unable to create new native thread` 的异常;
最后确定问题的原因是 `ulimit -u` max user processes 的数量配置过低, 增大后解决问题:
``` bash
4. max user processes -> 65535
```
具体的情况可以参见这篇文章: [dubbo 服务治理系统设计]();

### **场景2: elasticsearch data node**
32C64G4T 的配置, 为确保指针压缩特性被打开, 一般我们都会控制 jvm 的最大堆内存与最小堆内存: '-Xmx30g -Xms30g', 并希望能锁住所有的内存, 避免堆内存被 swap 到磁盘, 降低了搜索性能; 这种场景下我们当然不希望 ulimit 限制了 max memory size 以及 max locked memory;
所以, 可以对该机器的 ulimit 作出如下调整:
```
1. max locked memory -> unlimit
2. max memory size -> unlimit
3. open files -> 65536
4. stack size -> unlimit
```
对于 max locked memory, elasticsearch.yml 本身有一个配置项 `bootstrap.mlockall`/`bootstrap.memory_lock` = true, 其背后实现就是通过类似于 ulimit -l unlimit 的方法完成的; 只是, elasticsearch 试图自己主动改变该配置能生效的前提, 是 ulimit 配置文件里要允许其这样设置, 具体的逻辑请看本文下下节: [#ulimit 的永久修改](#ulimit-的永久修改);

&nbsp;
另外, 还有其他的一些场景, 可能需要调整其他参数以作优化, 此处不一而论;
以上是需要调整 ulimit 参数的场景举例, 下面的内容是关于如何 临时/永久 修改 ulimit 设置;

## **ulimit 当前 session 下的临时修改**
ulimit 的临时调整, 只对当前 session 下的当前用户, 以及当前用户所起的进程生效;
其调整方法也已经在 `ulimit -a` 中被注明了:
``` bash
# max locked mem
ulimit -l unlimit
# max mem size
ulimit -m unlimit
# open files
ulimit -n 65536
# max user processes
ulimit -u 65536
...
```

## **ulimit 的永久修改**
上一节的方法, 只能在当前 session 下对当前用户作临时调整, 而 要想对 ulimit 作永久调整, 需要修改一些配置文件:

1. `/etc/security/limits.conf`;
2. `/etc/security/limits.d 目录`;

这些文件用于持久化每个用户的资源限制设置;
其中, `/etc/security/limits.conf` 自不必说, 这是配置 ulimit 的主要文件:
``` bash
domain  限制的目标:
        username    用户名;
        @groupname  组名, 需加 '@' 前缀;
        *           通配所有用户/组;
        %groupname  这种写法只能用于限制 某个 group 的 maxlogin limit, 即最大登陆用户数限制;
        
type    限制的属性:
        `soft` 对 domain 给出的用户设置默认值; 
        `hard` 限制 domain 给出的用户自己所能设置的最大值; 
        `-` 将 soft 与 hard 都设为相同的值;
        
item    限制的资源类型, 与 ulimit 所限制的资源类型大致相同:
        - core - limits the core file size (KB)
        - data - max data size (KB)
        - fsize - maximum filesize (KB)
        - memlock - max locked-in-memory address space (KB)
        - nofile - max number of open file descriptors
        - rss - max resident set size (KB)
        - stack - max stack size (KB)
        - cpu - max CPU time (MIN)
        - nproc - max number of processes
        - as - address space limit (KB)
        - maxlogins - max number of logins for this user
        - maxsyslogins - max number of logins on the system
        - priority - the priority to run user process with
        - locks - max number of file locks the user can hold
        - sigpending - max number of pending signals
        - msgqueue - max memory used by POSIX message queues (bytes)
        - nice - max nice priority allowed to raise to values: [-20, 19]
        - rtprio - max realtime priority

value   限制的具体值;
```
以下是一个具体的例子:
``` bash
#<domain>        <type>     <item>     <value>
*                 soft      nproc       65536
*                 hard      nproc       65536
*                 -         nofile      65536
%guest            -         maxlogins   10
elastic           -         memlock     unlimit
@dev              hard      fsize       10737418240
```
如上所示, 系统允许 elastic 用户的最大 memlock 为 unlimit, 如果这个值被设置为了一个比较小的值, 那么上上节 elasticsearch 试图将其改成 unlimit 便会失败;

&nbsp;
而对于 `/etc/security/limits.d` 目录的作用,  `/etc/security/limits.conf` 文件中的第二段与第三段有如下注释:

> Also note that configuration files in /etc/security/limits.d directory,
which are read in alphabetical order, override the settings in this
file in case the domain is the same or more specific.
&nbsp;
That means for example that setting a limit for wildcard domain here
can be overriden with a wildcard setting in a config file in the
subdirectory, but a user specific setting here can be overriden only
with a user specific setting in the subdirectory.

也就是说, limits.conf 配置文件, 可以在用户级别上被 limits.d 目录下的配置文件覆盖;
举一个例子, 在 redhat/centos 各发行版本中, limits.d 目录下就有一个文件 `20-nproc.conf`:
``` bash
# Default limit for number of user's processes to prevent
# accidental fork bombs.
# See rhbz #432903 for reasoning.
*          soft    nproc     4096
root       soft    nproc     unlimited
```
这里面对除了 root 用户之外的所有用户作了一个最大进程/线程数目的 soft 限制;
如果修改 limits.conf 文件:
``` bash
*          hard    nproc     65535
```
这时会发现, 除非自己试图 `ulimit -u` 修改 max processes, 否则这个值会依然被限制为 4096;
而要想将该值默认放到 65535, 就必须修改 `20-nproc.conf` 文件方才生效;

### **永久修改生效的必要条件**

## **站内相关文章**
- [pam 认证与配置]()
- [dubbo 服务治理系统设计]()

## **参考链接**
- [ulimit 命令详解](http://www.cnblogs.com/zengkefu/p/5649407.html)
- [linux /etc/security/limits.conf的相关说明](http://blog.csdn.net/taijianyu/article/details/5976319)

