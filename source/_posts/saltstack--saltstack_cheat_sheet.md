---
title: saltstack cheat sheet
date: 2017-05-13 21:42:21
categories:
 - saltstack
tags:
 - saltstack
 - cheat sheet
 - 运维自动化
---

> 本文主要整理日常 saltstack 使用时的最常用的一些命令,以供快速查阅;

<!--more-->

------

### **自由度最大的模块: cmd 模块**
适用于登录 salt master 机器, 人工操作时执行;
``` bash
# cmd.run: 在 minions 上执行任意命令
sudo salt * cmd.run "ls -l /etc/localtime"
sudo salt * cmd.run uptime

# cmd.script: 在 master 上下发任意脚本至 minions 执行
sudo salt * cmd.script salt://minion_exeute.sh "args1 args2"
```

### **控制 minions 的定时任务执行情况: cron 模块**
``` bash
# 查看指定用户的 cron 内容
sudo salt * cron.raw_cron root
# 为指定用户添加指定任务
sudo salt * cron.set_job root '*' '*' '*' '*' '*' /home/minion_execute.sh 1>/dev/null
# 为指定用户删除指定任务
sudo salt * cron.rm_job root '*' '*' '*' '*' '*' /home/minion_execute.sh 1>/dev/null
```

### **master 与 minions 的文件传输: cp 模块**
``` bash
# 推送文件到 minions 指定路径 (只能推送文件, 不能推送目录)
sudo salt * cp.get_file salt://target_file /minion_path
# 推送目录到 minions 指定路径
suod salt * cp.get_dir salt://target_dir /minion_path
# 下载指定 url 的内容到 minions 指定路径 (不限于本地路径, 更加广泛)
sudo salt * cp.get_url salt://target_file /minion_path
sudo salt * cp.get_url https://d3kbcqa49mib13.cloudfront.net/spark-2.2.0-bin-hadoop2.7.tgz /minion_path
```

### **服务启停控制: systemd 模块**
salt.modules.systemd 模块是以 systemd 与 systemctl 为基础的, 尽管其命令多以 serice 开头, 不过该模块和 sysvinit 的 service 命令应该没什么关系;
``` bash
# 分别对应了 systemctl [enable, disable, start, stop, status, restart] httpd.service
sudo salt * service.enable httpd
sudo salt * service.disable httpd

sudo salt * service.start httpd
sudo salt * service.stop httpd
sudo salt * service.status httpd
sudo salt * service.restart httpd
```

### **远程文件控制相关: file 模块**
``` bash
# 创建文件
sudo salt * file.touch /opt/rsync_passwd
# 创建目录
sudo salt * file.mkdir /opt/rsync
# 删除指定文件
sudo salt * file.remove /opt/rsync_passwd
# 删除目录
sudo salt * file.rmdir /opt/rsync

# sudo chown root:root /opt/rsync_passwd
sudo salt * file.chown /opt/rsync_passwd root root
# sudo chmod 600 /etc/rsync_passwd
sudo salt * file.set_mode /etc/rsync_passwd 600
```

### **salt 常用的状态检测**
包括:
master 与 minions 之间的连通性 check_ping 检查;
minions salt version, dependency version, system version 检查;
minions network ping 外网检查;
磁盘容量 check_disk 检查;
等等;
``` bash
# 测试 salt 主从连通性
sudo salt * test.ping
# 打印 salt 的版本以及 salt 依赖的第三方组件的版本
sudo salt * test.versions_report
# 测试 minions 的网络 ping
sudo salt * network.ping www.qunar.com
# 查看 minions 的磁盘使用情况
sudo salt * disk.usage
```

### **参考链接**
- [服务自动化部署平台之Saltstack总结](http://blog.csdn.net/shjh369/article/details/49799269)
- [Saltstack系列3: Saltstack常用模块及API](https://www.cnblogs.com/MacoLee/p/5753640.html)
- [SALT.MODULES.FILE](https://docs.saltstack.com/en/latest/ref/modules/all/salt.modules.file.html#salt.modules.file.rmdir)

