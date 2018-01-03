---
title: r syncd 配置与运维
date: 2017-10-14 23:20:21
tags:
  - rsync
categories:
  - rsync
---

> 本文主要梳理 rsync server 的基本配置与使用方式;

<!--more-->

### **rsync server 的几个关键配置文件**
1. /etc/rsyncd.conf: 主配置文件;
2. /etc/rsyncd.password/rsyncd.secrets: 秘钥文件;
3. /etc/rsyncd.motd: rysnc 服务器元信息, 非必须;

其中, rsyncd.password 秘钥文件的掩码必须是 600:
``` bash
> ll /etc/ | grep rsyncd
-rw-r--r--   1 root root    361 Apr  6  2017 rsyncd.conf
-rw-------   1 root root     24 Apr  6  2017 rsyncd.password
```

### **rsyncd.conf 配置说明**
一个典型的 rsyncd.conf 文件如下:
``` bash
# rsyncd 守护进程运行系统用户全局配置, 可在具体的块中配置
uid=nobody
gid=nobody

# 是否需要 chroot, 若为 yes, 当客户端连接某模块时, 首先 chroot 到 模块的 path 目录下
user chroot = no

max connections = 200
timeout = 600

pid file = /data1/trans_file/rsyncd.pid
lock file = /data1/trans_file/rsyncd.lock
log file = /data1/trans_file/rsyncd.log
# 用户秘钥文件, 可在具体的模块中配置
secrets file = /etc/rsyncd.password
# 服务器元信息, 非必选
# motd file = /etc/rsyncd/rsyncd.motd
# 指定不需要压缩就可以直接传输的文件类型
dont compress = *.gz *.tgz *.zip *.z *.Z *.rpm *.deb *.bz2

# 模块配置
[wireless_log]
# 模块使用的 user, 此模块将使用 rsyncd.password 文件中 sync 用户对应的秘钥进行文件传输
auth users = sync
path = /data1/trans_file/files/wireless_log
ignore errors
# 是否只读
read only = no
# 是否允许列出模块里的内容
list = no
```

### **rsyncd.password / rsyncd.secrets 配置说明**
以 `:` 分隔, 用户名和密码, 每行一个:
```
user1:password1
user2:password2
```

### **rsyncd 启动方式**
``` bash
# 当负载高时, 以守护进程的方式运行 rsyncd
sudo /usr/bin/rsync --daemon --config=/etc/rsyncd.conf
```

### **参考链接**
- [centos下配置rsyncd服务器](https://segmentfault.com/a/1190000000444614)
- [RSync实现文件备份同步](http://www.cnblogs.com/itech/archive/2009/08/10/1542945.html)

