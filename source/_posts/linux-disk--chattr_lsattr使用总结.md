---
title: chattr / lsattr 使用总结
date: 2018-04-06 21:23:22
categories:
 - linux
 - disk
tags:
 - linux:disk
 - 系统安全
---

> 对于在机器上操作的人来说, 如果有 sudo 权限, 那 chattr 根本就不是事, 这也不是 chattr 的意义所在;
对 chattr 来说, 其所要阻止的, 是那些有意无意想要修改机器上重要文件的程序, 从而保证机器上重要的文件不会因非人为因素而遭到非预期的操作;

<!--more-->

------

### **chattr 命令**
``` bash
# + 在原有参数基础上追加设置
# - 在原有参数基础上移除设置
# = 将设置更改为指定的参数
# mode 指定的设置项
sudo chattr +|-|=mode file_path

# 递归设置指定目录下的所有文件
sudo chattr -R +|-|=mode file_path
```

其中, mode 中常用的设置项如下:
``` bash
a   设置只能向指定文件中追加内容, 不能删除
i   设置文件不能修改, 删除, 不能被设置链接关系, 是最常用的 mode
s   security, 当 rm 该文件时, 从磁盘上彻底删除它;
```

chattr 并非万能, 以下几个目录 chattr 并不能干预:
``` bash
/
/dev
/tmp
/var
```

### **lsattr 命令**
lsattr 命令用于查看文件被 chattr 设置的情况;
``` bash
> lsattr file_path
----i--------e- file_path
```
可以发现, 有的时候 lsattr 所展示的文件属性掩码中, 有一个 `e`, 这在 chattr 的 manual 文档里是这么说的:
> The `e` attribute indicates that the file is using extents for mapping the blocks on disk. It may not be removed using chattr(1).

所以说, 对 chattr 来说, 这个掩码并不意味着什么;

### **常用的情景**
对于生产环境中的机器, 有如下一些重要文件一般会将其用 chattr 设为不可修改, 不可删除:
``` bash
sudo chattr +i /etc/resolv.conf
sudo chattr +i /etc/hosts.allow
sudo chattr +i /etc/hosts.deny
```
其中, /etc/hosts.allow 与 /etc/hosts.deny 是关于 ssh 的登陆白名单/黑名单信息, 安全考虑, 正常只允许跳板机 ssh 到本机, 而禁止其他所有的机器; 这两个文件绝不允许被无故修改;
而 /etc/resolv.conf 则是关于 dns 解析的文件, 一旦被修改, 会导致一些网络请求中的域名无法正常解析, 所以也需要被 chattr 锁定防止无故修改;

### **参考链接**
- [Linux的chattr与lsattr命令详解](http://www.ha97.com/5172.html)

