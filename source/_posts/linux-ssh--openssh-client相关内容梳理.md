---
title: openssh-client 相关内容梳理
date: 2018-07-17 13:13:43
categories:
 - linux
 - ssh
tags:
 - linux:ssh
 - security
---

> ssh 相关的命令是日常开发中基础中的基础, 乃是登陆机器操作必不可少的过程; 但是越是寻常, 可能越容易疏于整理总结; 本文就从 openssh-client 着手, 总结一下 .ssh 目录, ssh 相关命令, 以及相关配置文件的使用;

<!--more-->

------

## **.ssh 目录**
.ssh 目录对权限的要求是比较苛刻的, 毕竟涉及到了私密信息的安全问题; 一般来说, .ssh 下各目录的权限要求如下 (这里只考虑使用 rsa 算法而不考虑 dsa, ecdsa 等其他非主流的加密算法):

1. .ssh 目录自己的权限是 700;
2. id_rsa 的目录权限是 600 (强制要求);
3. id_rsa.pub 的目录权限一般为 644 (这个没有特殊要求);
3. authorized_keys 的目录权限是 600 (强制要求);
4. known_hosts 的目录权限一般为 644 (这个没有特殊要求);

以下是一个直观的例子:
``` bash
> ls -al .ssh/
drwx------ 2 zshell.zhang qunarops    76 Dec 25 13:27 .
drwx------ 4 zshell.zhang qunarops    94 Dec 25 14:50 ..
-rw------- 1 zshell.zhang qunarops 12997 Dec 25 15:38 authorized_keys
-rw------- 1 zshell.zhang qunarops  1679 Dec 25 11:55 id_rsa
-rw-r--r-- 1 zshell.zhang qunarops   407 Dec 25 11:55 id_rsa.pub
-rw-r--r-- 1 zshell.zhang qunarops  7931 Dec 25 14:02 known_hosts
```
一般来说, id_rsa 是私钥, id_rsa.pub 是公钥, 公钥与私钥的命名只是约定俗成, 没有强制规定, 可以自定义; 但自定义之后要使用特定的私钥登陆就需要在命令中使用参数指定, 具体请见下一小节;
还有一点需要说明的是, 这四类文件虽然都默认存在于用户家目录下的 .ssh/ 目录中, 但对于同一台主机上的同一个用户, 这四个文件并不都会同时出现,  如果真的同时出现了, authorized_keys 与 id_rsa, known_hosts 中的内容也不会有什么关联; 关于 authorized_keys 和 known_hosts 的具体说明, 请见下文;

### **authorized_keys**
authorized_keys 记录了允许以当前用户登陆该主机的所有公钥, 但凡一个登陆请求的私钥与 authorized_keys 中的公钥相匹配, 则此次登陆成功; 所以, authorized_keys 并非用于 openssh-client, 而是 server 端的 sshd, 这也是上文所说的: 即便 authorized_keys 与 id_rsa 共存于一个 .ssh 目录下, 两者在内容上也是独立的, 前者是校验别人登陆到本机器的, 而后者是用于从本机器登陆其他主机的;
在日常运维值班中, 有一个比较频繁的事情便是机器权限申请的审核与开通, 这里面的操作就涉及到 authorized_keys 的更新; 通常我们会使用自动化运维工具 (例如 saltstack, ansible) 在目标主机上执行相关的逻辑:
``` bash
# 创建用户
useradd -g ${user_group} -d ${user_dir}/${user_name} $user_name
# 将公钥写入目标主机对应用户的 authorized_keys 文件
wget -O ${user_dir}/${user_name}/.ssh/authorized_keys http://user_query_service_url/${user_name}/id_rsa.pub
...
```

### **known_hosts**
对于最后一个 known_hosts, 其主要用于 openssh-client 对每次登陆的主机的 host key 作校验; 主机 host key 的构成在 `man sshd` 中有如下介绍:
> Each line in these files contains the following fields: hostnames, bits, exponent, modulus, comment.  The fields are separated by spaces.

host key 中存储了 hostname, ip 等内容, 并作了哈希编码; 当 openssh-client 试图连接一个主机时:

* 如果在 known_hosts 中不存在该主机的 host key 信息, 则会告知使用者从未连接过该主机, 并确认是否要连接:

``` c
The authenticity of host '10.64.0.11 (10.64.0.11)' can't be established.
RSA key fingerprint is SHA256:3O+bKYBXKHcYLBbltbuzu8dJbWaX42QHvkKeyABTyqU.
RSA key fingerprint is MD5:ff:3f:57:5c:54:39:8c:71:50:71:aa:bf:1a:6e:a1:0f.
Are you sure you want to continue connecting (yes/no)?
```
* 如果在 known_hosts 中存在该主机, 并且 ip 等信息并未发生变化, 则校验通过;
* 如果在 known_hosts 中存在该主机, 但是 ip 等信息发生了变化, 则会打印类似如下的 `中间人攻击` 告警信息:

``` bash
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that the RSA host key has just been changed.
The fingerprint for the RSA key sent by the remote host is
ad:12:0a:af:77:09:af:b0:65:16:9a:0a:04:57:2e:f1.
Please contact your system administrator.
Add correct host key in /home/zshell.zhang/.ssh/known_hosts to get rid of this message.
Offending key in /home/zshell.zhang/.ssh/known_hosts:96
Password authentication is disabled to avoid man-in-the-middle attacks.
Keyboard-interactive authentication is disabled to avoid man-in-the-middle attacks.
Agent forwarding is disabled to avoid man-in-the-middle attacks.
X11 forwarding is disabled to avoid man-in-the-middle attacks.
```
其实, 在公司的内网环境中, 大可不必考虑中间人攻击的可能, 倒是日常运维操作致使主机 ip 地址改变的情况时有发生, 所以对于这种提示, 只需要更新 known_hosts 文件, 删除对应的 host key 即可:
``` bash
ssh-keygen -f "/home/zshell.zhang/.ssh/known_hosts" -R l-xx1.ops.cn1
```
重新 ssh 连接, 经过询问与确认之后, 新的 host key 便会写入 known_hosts 文件;

最后回过头来总结一下:
像 id_rsa 以及 authorized_keys 这类涉及到私人信息安全的文件一定是要对其余用户不可访问的: 如果私钥文件对其余用户可读, openssh-client 会直接拒绝并提示文件权限设置过宽, 如果 authorized_keys 对其余用户可读, 则用户无法登陆, 会提示需要输入密码; 而类似 id_rsa.pub 公钥这种原本设计就是要公开的信息, 设置成 644, 对其余用户只读即可;

## **ssh 相关命令**
ssh 命令常用的选项如下:
``` bash
# -i:   identity, 指定私钥文件, 适用于文件名自定义的私钥文件
# -p:   port, 指定连接 openssh-server 的端口号
# -X:   开启 openssh 的 Forwarding X11 图形界面功能
ssh -p 22 -i .ssh/id_rsa_xxx zshell.zhang@l-xx1.ops.cn1
```
scp 命令常用的选项如下:
``` bash
# -r:   recursive, 传输整个目录下的子文件
# -l:   limit, 限制传输带宽, 单位是 kb/s
# -i:   identity, 指定私钥文件
# -P:   port, 指定端口
scp -r zshell.zhang@l-xx1.ops.cn2:/tmp/xxx ~/Downloads
```
与 openssh-client 相关的命令, 还有一个 sftp, 在本文中不作详细讨论, 本站另一篇文章中单独讨论了 sftp 相关的内容: [sftp 相关知识梳理]();

## **openssh-client 配置文件**
openssh-client 的配置文件主要有两方面, 全局配置和个人家目录下的私有配置; 在可配置的内容选项上, 全局配置与私有配置其实没有差别, 只不过习惯上会将一些比较通用的配置放在全局配置里;

### **全局配置文件**
openssh 的全局配置文件的路径: `/etc/ssh/ssh_config`;
``` bash
Host *  # 对所有的 host 适用的配置
ForwardAgent no
ForwardX11 no   # 允许开启图形界面支持
RhostsAuthentication no
RhostsRSAAuthentication no
RSAAuthentication yes
PasswordAuthentication yes
FallBackToRsh no
UseRsh no
BatchMode no
CheckHostIP yes
StrictHostKeyChecking no
# 默认的私钥文件, 按先后顺序依次获取
IdentityFile ~/.ssh/identity
IdentityFile ~/.ssh/id_rsa
Port 22
Cipher 3des
EscapeChar ~
```

### **私有配置文件**
openssh 的私有配置文件的路径: `$HOME/.ssh/config`;
``` bash
Host *  # 对所有的 host 适用的配置
ServerAliveInterval 30
ControlPersist yes
ControlMaster auto
ControlPath ~/tmp/ssh/master-%r@%h:%p

ConnectTimeout 30
TCPKeepAlive yes
StrictHostKeyChecking no

# 对所有匹配到 *.cn0 的主机, 均使用以下配置连接
Host *.cn0
Port 22
User zshell.zhang   # 使用 zshell.zhang 用户登陆目标主机
IdentityFile ~/.ssh/id_rsa  # 使用指定的私钥文件
ProxyCommand ssh zshell.zhang@l-rtools1. -W %h:%p   # 具体的 ssh 命令
```

## **站内相关文章**
- [sftp 相关知识梳理]()

## **参考链接**
- [ssh配置authorized_keys后仍然需要输入密码的问题](https://www.cnblogs.com/snowbook/p/5671406.html)

