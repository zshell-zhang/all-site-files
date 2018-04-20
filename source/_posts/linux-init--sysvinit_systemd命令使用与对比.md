---
title: sysvinit / systemd 命令使用与对比
date: 2017-11-12 17:18:06
categories:
 - linux
 - init
tags:
 - linux:init
 - systemd
---

> 当用户空间引导程序 systemV init 被 systemd 所取代, centos 7 下操纵与查看 daemon service 的命令也随之而改变;
不过, 由于 systemd 的庞大复杂, 命令选项繁多, 本文对 systemd 的整理主要集中于与 sysvinit 所提供的功能重合度最高的 systemctl 命令;

<!--more-->

------

## **传统的 sysvinit 相关命令**
与传统的 systemV init 引导程序相匹配的 daemon service 操纵命令主要是 service 与 chkconfig/ntsysv;
其中:
service 命令用于 启, 停, 查看 具体的 daemon service; 
chkconfig 命令用于 修改, 查看 具体 daemon service 的 runlevel 及启停信息;
ntsysv 命令提供了一个 GUI 界面用于操纵各个 runlevel 上各 daemon service 的启停;
### **service 的使用方式**
``` bash
# 启动, 停止, 重启, 查看
sudo service ntpd start
sudo service ntpd stop
sudo service ntpd restart
sudo service ntpd status
```
### **chkconfig 的使用方式**
``` bash
# 列举所有的 daemon service 在各个 runlevel 上的启停状态
sudo chkconfig --list
# 列举指定的 daemon service 在各个 runlevel 上的启停状态
> sudo chkconfig --list ntpd
ntpd           	0:on	1:on	2:on	3:on	4:on	5:on	6:off

# 添加一个 daemon service
sudo chkconfig --add mysqld
# 在默认的 2, 3, 4, 5 四个 runlevel 上自动启动 mysqld
sudo chkconfig mysqld on
# 在指定的 3, 5 两个 runlevel 上自动启动 mysqld
sudo chkconfig --level 35 mysqld on

# 删除一个 daemon service
sudo chkconfig --del rngd
```
### **ntsysv 的使用方式**
ntsysv 在 centos 7 之前的各发行版本上都默认安装, 不过从 centos 7 之后, 该命令的 GUI 形式已经不再默认提供, 只提供了 chkconfig 命令用于兼容照顾老的 systemV init 方式;
``` bash
# 默认情况下 ntsysv 配置的是当前 user session 所在的 runlevel
sudo ntsysv
# 配置 runlevel = 5 的 daemon service
sudo ntsysv --level 5
```

## **主流的 systemd 相关命令**
systemd 相比 sysvinit 就要复杂多了, 同时也比 sysvinit 强大多了;
systemd 相比 sysvinit 更强大的其中一个重要点是, systemd 不仅仅管理系统中的各进程, 它管理 linux 系统中的所有资源, 并把不同的资源称为 unit:
``` bash
service unit: 系统服务
target unit: 多个 unit 构成的一个组
device unit: 硬件设备
mount unit: 文件系统的挂载点
automount unit: 自动挂载点
path unit: 文件或路径
scope unit: 不是由 systemd 启动的外部进程
slice unit: 进程组
snapshot unit: systemd 快照, 可以切回某个快照
socket unit: 进程间通信的 socket
swap unit: swap 文件
timer unit: 定时器, 可与 crond 相对比, 可圈可点
```
其中, **service unit** 在 12 类 unit 中是最主要的一类, 也是日常操作中最频繁接触的一类, 当然也是与传统的 sysvinit 可以直接比较的对象;
另外, systemd 里另外一个比较有意思的是 timer unit, 关于此的详细内容可以参见: [systemd 的定时器功能]();
&nbsp;
systemd 主要涉及到的命令有: `systemctl`, `hostnamectl`, `localectl`, `timedatectl`, `loginctl`, `journalctl` 等, 其中:

- `systemctl` 是最重要的命令, 最核心的操作都与此命令有关, 比如启停服务, 管理各 unit 等;
- `hostnamectl` 用于管理主机信息等;
- `localectl` 用于本地化设置管理;
- `timedatectl` 用于时区管理;
- `loginctl` 用于管理当前登录的用户;
- `journalctl` 用于管理 systemd 与各 unit 的输出日志, 用于辅助其余命令查看状态与日志;

&nbsp;
本主要整理与 systemctl 有关的内容, 其余的如 timedatectl, journalctl 请参见另一篇文章: [sysvinit / systemd 日志系统的使用与对比]();

### **systemctl 的常用命令列表**
systemctl 的使用场景十分广泛, 从大的角度来说, 可以分为 **系统管理** 和 **unit 管理** 两大类;
系统管理类的命令如下:
``` bash
# 重启系统
sudo systemctl reboot
# 关闭系统, 切断电源
sudo systemctl poweroff
# CPU 停止工作
sudo systemctl halt
# 暂停系统
sudo systemctl suspend
# 让系统进入冬眠状态
sudo systemctl hibernate
# 让系统进入交互式休眠状态
sudo systemctl hybrid-sleep
# 启动进入救援状态 (单用户状态, runlevel = 1)
sudo systemctl rescue
```
unit 管理类 的命令种类繁多, 大致可以再细分为两小类: **查看管理类** 与 **操纵动作类**;
**查看管理类仅仅是统计与查看, 并不改变 unit 的状态:**
(1) 从整体角度管理 units
``` bash
# 默认列出正在运行的 unit
sudo systemctl list-units
# 列出所有 unit, 包括没有找到配置文件的或者启动失败的
sudo systemctl list-units --all
# 列出所有没有运行的 unit
sudo systemctl list-units --all --state=inactive
# 列出所有加载失败的 unit
sudo systemctl list-units --failed
# 列出所有正在运行的, 类型为 service 的 unit; -t: --type
sudo systemctl list-units --type=service
```
(2) 管理具体的某个 unit
``` bash
# 显示某个 unit 的状态
sudo systemctl status rsyslog.service
# 显示某个 unit 是否正在运行
sudo systemctl is-active rsyslog.service
# 显示某个 unit 是否处于启动失败状态
sudo systemctl is-failed rsyslog.service
# 显示某个 unit 服务是否建立了启动链接
sudo systemctl is-enabled rsyslog.service

# 显示某个 unit 的启动是否依赖其他 unit 的启动, --all 展开所有 target unit 下的每一个详细 unit
sudo systemctl list-dependencies --all rsyslog.service

# 显示某个 unit 的所有底层参数
sudo systemctl show rsyslog.service
# 显示某个 unit 的指定属性的值
sudo systemctl show -p CPUShares rsyslog.service
```
**操纵动作类, 主要是针对 service unit:**
``` bash
# 设置为开机启动
sudo systemctl enable nginx.service
# 启动
sudo systemctl start nginx.service
# 停止
sudo systemctl stop nginx.service
# 重启
sudo systemctl restart nginx.service
# 杀死一个服务的所有子进程
sudo systemctl kill nginx.service
# 重新加载一个服务的配置文件
sudo systemctl reload nginx.service

# 设置某个 unit 的指定属性
sudo systemctl set-property nginx.service CPUShares=500
```

### **systemctl 的状态与诊断**
使用 systemctl status 输出服务详情状态:
``` bash
# Loaded:   该 unit 配置文件的位置以及是否开机启动
# Active:   运行状态
# Main PID: 父进程 pid
# CGroup:   所有的子进程列表
# 最后是 service 的日志
> sudo systemctl status rsyslog.service

● rsyslog.service - System Logging Service
   Loaded: loaded (/usr/lib/systemd/system/rsyslog.service; enabled; vendor preset: enabled)
   Active: active (running) since Wed 2017-07-19 16:01:19 CST; 6 months 10 days ago
 Main PID: 504 (rsyslogd)
   CGroup: /system.slice/rsyslog.service
           └─504 /usr/sbin/rsyslogd -n

Jul 19 16:01:19 localhost.localdomain systemd[1]: Starting System Logging Service...
Jul 19 16:01:19 localhost.localdomain systemd[1]: Started System Logging Service.
```
使用 journalctl 查看日志:
``` bash
# 指定查看某个 unit 的日志
sudo journalctl -u nagios
# 指定时间范围 --since=  --until=
sudo journalctl -u nagios -S "2017-04-19 09:00:00"
sudo journalctl -u nagios -S "2 days ago"
sudo journalctl -u nagios -U "2017-12-31 23:59:59"
# 指定某次启动后的所有日志
sudo journalctl -u nagios -b [-0] # 当前启动后
sudo journalctl -u nagios -b  -1  # 上次启动后
sudo journalctl -u nagios -b  -2  # 继续往上追溯
```
关于 journalctl 的详细内容, 请参见另外一篇文章: [sysvinit / systemd 日志系统的使用与对比]();

## **站内相关文章**
- [sysvinit/systemd/upstart 初始化过程梳理]()
- [systemd 的定时器功能]()
- [systemd 相关配置文件整理]()
- [sysvinit / systemd 日志系统的使用与对比]()

## **参考链接**
- [Linux下chkconfig命令详解](https://www.cnblogs.com/panjun-Donet/archive/2010/08/10/1796873.html)
- [ntsysv命令](http://man.linuxde.net/ntsysv)
- [CentOS 7 启动, 重启, chkconfig 等命令已经合并为 systemctl](https://zhangzifan.com/centos-systemctl.html)
- [RHEL 7 中 systemctl 的用法 (替代service 和 chkconfig)](http://blog.csdn.net/catoop/article/details/47318225)
- [Systemd 入门教程: 命令篇](http://www.ruanyifeng.com/blog/2016/03/systemd-tutorial-commands.html)
- [systemctl 命令完全指南](https://linux.cn/article-5926-1.html)

