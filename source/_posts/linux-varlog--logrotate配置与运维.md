---
title: logrotate 配置与运维
date: 2018-01-15 00:23:27
categories:
 - linux
 - varlog
tags:
 - linux:varlog
---

> 本文主要讨论以下几个方面:
1. logrotate 的关键配置文件和配置项语法;
2. logrotate 的使用与运维技巧;
3. logrotate 的运行原理;
4. 特殊场景下 logrotate 的代替方案;

<!--more-->

------

### **配置文件与配置语法**
logrotate 的配置文件主要是 `/etc/logrotate.conf` 和 `/etc/logrotate.d` 目录;
/etc/logrotate.conf 文件作为主配置文件, include 了 /etc/logrotate.d 目录下具体的配置内容;
以下是 /etc/logrotate.conf 的默认内容:
``` bash
# 默认的历史日志保留周期单位: 周
weekly
# 历史日志保留四个周期单位, 即四周, 一个月
rotate 4
# use the syslog group by default, since this is the owning group of /var/log/syslog.
su root syslog
# 当旧日志作了 rotate 之后, 将会创建一个和旧日志同名的新文件
create
# 默认使用 gzip 压缩旧日志文件
compress
# 将 /etc/logrotate.d 下面的所有独立配置文件都 include 进来
include /etc/logrotate.d
```
/etc/logrotate.conf 的默认配置优先级比 /etc/logrotate.d/ 目录下的独立配置要低, /etc/logrotate.d 下所有的独立配置文件中的配置项可以覆盖 /etc/logrotate.conf;
以 rsyslog 的配置文件为例, 以下是 /etc/logrotate.d/rsyslog 的内容:
``` bash
/var/log/syslog {
    # 以 天 为周期单位, 保留 7 天的日志
    daily
    rotate 7
	
    # 忽略任何错误, 比如找不到文件
    missingok
	
    # not if empty, 当日志内容为空时, 不作 rotate
    notifempty
	
    # 压缩日志, 但是采用延时压缩, 即本轮周期产生的日志不压缩, 而在下一个周期时压缩之
    compress
    delaycompress
	
    # postrotate/endscript 内的命令, 作为后处理, 会在本轮周期 rotate 之后回调执行
    postrotate
	invoke-rc.d rsyslog rotate > /dev/null
    endscript
}

# 可以同时指定多个目标日志使用同一段配置
/var/log/mail.info
/var/log/mail.warn
/var/log/mail.err
/var/log/mail.log
/var/log/daemon.log
/var/log/kern.log
/var/log/auth.log
/var/log/user.log
/var/log/lpr.log
/var/log/cron.log
/var/log/debug
/var/log/messages {
    weekly
    rotate 4
	
    missingok
    notifempty
	
    compress
    delaycompress
	
    # 共享处理脚本, 仅对 prerotate/postrotate 定义时生效
    sharedscripts
	
    postrotate
	invoke-rc.d rsyslog rotate > /dev/null
    endscript
}
```
注意:

1. `sharedscripts` 选项打开后, 所有使用该段配置作 rotate 的目标日志名都会作为参数一次性传给 prerotate/postrotate;
而默认的选项 `nosharedscripts` 则是将每一个日志名分别作为参数传给 prerotate/postrotate;
2. logrotate 支持的周期单位, 有 hourly, daily, weekly, monthly; 但是这里有坑: hourly 默认是不生效的, 具体原因见本文第三节;

&nbsp;
如上所叙, prerotate/postrotate 是一种在 rotate 过程中某个时机回调的一段脚本, 像这样类似的配置项总共有如下几种 (所有的配置项必须与 `endscript` 成对出现):
``` bash
# 在所有匹配的日志 rotate 之前, 仅执行一次
firstaction/endscript
# 在日志 rotate 之前回调
prerotate/endscript
# 在日志 rotate 之后回调
postrotate/endscript
# 在所有匹配的日志 rotate 之后, 仅执行一次
lastaction/endscript

# 在某个日志将要被删除之前回调执行
preremove/endscript
```
这几种回调时间点的设计, 不禁让人想到 junit 测试类几种注解的方法执行时机, 不得不说有异曲同工之妙;
&nbsp;
rsyslog 的 logrotate 配置是一个典型, 但同时 logrotate 还有着其他的个性化配置选项:
``` bash
# 以下是另一段案例
/var/log/test.log {
    # 不以时间为周期单位, 而是以 日志size 为周期单位, 当日志大小达到 100MB 时, 作一次 rotate, 日志保留 5 个周期
    size=100M
    rotate 5
    
    # 使用日期命名 rotate 后的旧文件, 日期格式采用 -%Y-%m-%d
    dateext
    dateformat -%Y-%m-%d
    
    # 以指定的权限掩码, owner/group 创建 rotate 后的新文件
    create 644 root root
    
    postrotate
        /usr/bin/killall -HUP rsyslogd
    endscript
}
```

### **logrotate 命令的常用运维选项**
1.指定目标配置文件, 手动执行:
``` bash
# 将会执行 /etc/logrotate.d/ 下所有的配置
logrotate /etc/logrotate.conf
# 将会只执行指定配置文件中的配置
logrotate /etc/logrotate.d/xxx.log
```
2.debug 验证配置文件正误:
``` bash
# -d:   --debug
> logrotate -d /etc/logrotate.d/redis-server.log
# output
reading config file /etc/logrotate.d/redis-server
Handling 1 logs
rotating pattern: /var/log/redis/redis-server*.log  weekly (12 rotations)
empty log files are not rotated, old logs are removed
considering log /var/log/redis/redis-server.log
  log does not need rotating
```
3.强制 rotate:
即便当前不满足 rotate 的条件, force rotate 也会强制作一次 rotate, 而那些超过指定轮数的旧日志将会被删除;
force rotate 比较适用于加入了新的配置文件, 需要对其存量历史立即作一次 rotate;
``` bash
# -f:   --force
logrotate -f /etc/logrotate.d/xxx.log
```
4.verbose 详细信息:
``` bash
# -v:   --verbose
logrotate -vf /etc/logrotate.d/xxx.log
```
5.指定 logrotate 自身的日志文件路径:
``` bash
# -s:   --state
# 默认 logrotate 的日志路径: /var/lib/logrotate/status
logrotate -s /tmp/logrotate.log /etc/logrotate.conf
```

### **logrotate 的运行原理及其缺陷**
logrotate 并不是一个 daemon service, 其本质上只是一个 '什么时候调用就什么时候立即执行一次' 的 C 程序;
所以 logrotate 的执行, 依赖于其他 daemon service 的调用, 那么最自然的就是通过 crond 定时任务来调用了;
默认情况下, logrotate 是一天被调用一次的, 因为与它相关的 crontab 配置在 `/etc/cron.daily` 里:
``` bash
#!/bin/sh

# Clean non existent log file entries from status file
cd /var/lib/logrotate
test -e status || touch status
head -1 status > status.clean
sed 's/"//g' status | while read logfile date
do
    [ -e "$logfile" ] && echo "\"$logfile\" $date"
done >> status.clean
mv status.clean status

test -x /usr/sbin/logrotate || exit 0
/usr/sbin/logrotate /etc/logrotate.conf
```
如本文第二节所述, 由于 logrotate 的执行方式是通过 cron 默认 1 天执行一次, 所以按小时 rotate 的 `hourly` 配置项, 默认是不生效的; logrotate 的 manual 文档里也有说明:
> `hourly` Log files are rotated every hour. Note that usually logrotate is configured to be run by cron daily. You have to change this configuration and run logrotate hourly to be able to really rotate logs hourly.

不过, 这还不是最大的问题, 毕竟我们只要把上述脚本放到 `cron.hourly` 里, 就能解决该问题;
这种靠定时任务来运行的方式, 最大的问题是: 当我们对某个日志配置成按 `size` 来 rotate 时, 无法做到当日志触达 size 条件时及时切分, 其所能实现的最小延时是一分钟 (当把 logrotate 脚本的定时任务配成 \* \* \* \* \*, 即每分钟执行一次时), 没法更短了;

### **其他的特殊场景**
logrotate 集日志切分, 日志压缩, 删除旧日志, 邮件提醒等功能为一体, 提供了非常完整的日志管理策略; 不过, 并不是所有的系统日志, 自身都不具有上述功能, 都需要依赖 logrotate 来管理自己;
有一个非常典型, 而且使用十分广泛的场景: tomcat web 服务器; 当我们在 tomcat 上部署的服务使用了诸如 logback 之类的第三方日志框架时, 日志切分, 日志压缩等服务它自己便能够胜任了 (与 logback 相关功能的文章请见: [logback appender 使用总结]()), 而且我们绝大部分人 (去哪儿网), 即便不怎么接触 logback 的日志压缩功能, 也至少都习惯于使用 logback  `RollingFileAppender` 的基础功能去作日志切分;
基于以上, 我们只需要一个简单的脚本, 便能够满足日常的 tomcat web 服务器日志运维:
``` bash
#!/bin/bash
HOUR1=$(date -d "1 hours ago" +%F-%H)
DATE7=$(date -d "7 days ago" +%F-%H)
# for example: /home/web/my_server/logs
for i in `find /home/web/ -maxdepth 2 \( -type d -o -type l \) -name logs`; do
        find -L $i -maxdepth 1 -type f \( -name "*${HOUR1}*" -a ! -name "*.gz" \) -exec gzip {} \;
        find -L $i -maxdepth 1 -type f \( -name "*${DATE7}*" -a -name "*.gz" \) -exec rm -f {} \;
done
```
本节内容讨论的是针对 tomcat web 系统上的日志切分, 压缩, 以及删除等常规运维内容; 其实, 针对公司各业务线 web 系统的业务日志, 除此之外至少还有另外两项重要的运维内容: *日志冷备份收集* 与 *日志实时收集及其可视化 (ELK)*; 与之相关的内容请参见如下文章: 

1. [改造 flume-ng: 融入公司的技术体系]();
2. [日志冷备份收集的方案选型]();

### **站内相关文章**
- [cron 相关全梳理]()
- [logback appender 使用总结]()
- [改造 flume-ng: 融入公司的技术体系]()
- [日志冷备份收集的方案选型]()

### **参考链接**
- [Linux日志文件总管——logrotate](https://linux.cn/article-4126-1.html)
- [被遗忘的 Logrotate](https://huoding.com/2013/04/21/246)

