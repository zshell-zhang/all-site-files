---
title: 在裸镜像上搭建 shadowsocks server
date: 2018-07-21 22:29:35
categories:
 - life
 - pc
tags:
 - life:pc
---

> 什么废话都不用多说, 就一句话: 搭梯子, 程序员的基本功!
最近在折腾 fedora, 想着不能老是蹭公司的 "绿色通道", 遂自己兑了点美刀, 自力更生干了起来, 顺手在这里总结一下;

<!--more-->

### **国外云主机搭梯子的痛点**
要搭梯子, 得买个国外的云主机服务; 以 DigitalOcean 为例, 选择 centos 系统的 elastic compute service, 如果不使用定制的 cloud-init, DigitalOcean 创建的虚机将配置默认的 yum 源 (附带一个 digitalocean 自己的源):
``` bash
CentOS-Base.repo
CentOS-CR.repo
CentOS-Debuginfo.repo
CentOS-fasttrack.repo
CentOS-Media.repo
CentOS-Sources.repo
CentOS-Vault.repo
# digitalocean 附带的自己的源
digitalocean-agent.repo
```
默认的源里面是没有 shadowsocks 相关的软件包的, 这意味着我们无法使用 yum 安装 shadowsocks server;

### **解决问题: shadowsocks github 仓库**
在 shadowsocks 的 [官方 github](https://github.com/shadowsocks) 上, 有多种 shadowsocks 版本: python, go, rust, R, nodejs 等; 以 shadowsocks-go 为例, 其 [release 页面](https://github.com/shadowsocks/shadowsocks-go/releases) 提供各种版本的二进制包供下载; 而 GFW 迫于中国 IT 界的压力暂不能封锁 github, 这样我们就可以从 shadowsocks github 官方页面上下载 shadowsocks 了;

### **更加便捷的一站式工具**
在 github 有个好心人做了一个更加便捷的 shadowsocks 一站式安装工具 [teddysun/shadowsocks_install](https://github.com/teddysun/shadowsocks_install) 方便广大网民 "一键部署"; 以安装 shadowsocks-go 为例, 其提供了 [shadowsocks-go.sh](https://github.com/teddysun/shadowsocks_install/blob/master/shadowsocks-go.sh) 脚本, 其中安装 shadowsocks 的主函数内容如下:
``` bash
install_shadowsocks_go() {
    disable_selinux
    pre_install
    download_files
    config_shadowsocks
    if check_sys packageManager yum; then
        firewall_set
    fi
    install
}
```
其中:

* pre_install 方法通过 read 关键字从 stdin 中读取 password, port 与加密方式 cipher, 完成用户自定义行为;
* download_files 方法:
(1) 从远程 url 下载 shadowsocks-server 的二进制文件, 放入 `/usr/bin/` 目录;
(2) 从远程 url 下载 shadowsocks-server 的 daemon 启动脚本 shadowsocks, 放入 `/etc/init.d/` 目录;
* config_shadowsocks 方法将 pre_install 方法获取的 password, port, cipher 写入配置文件 `/etc/shadowsocks/config.json`;
* firewall_set 方法对 iptables filter 表加入了一条规则, 开放用户设置的 port 端口;
* install 方法就是使用 chkconfig 设置 shadowsocks-server 在 sysvinit 的启停级别, 并读取 启动服务, 交付给使用者;

可以发现, 

在 centos 裸镜像中, 使用以上工具部署 shadowsocks-server 的过程总结如下:
(1) 安装 wget
``` bash
yum -y install wget
```
(2) 下载安装脚本
``` bash
wget --no-check-certificate -O shadowsocks-go.sh https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocks-go.sh
sudo chmod +x shadowsocks-go.sh
```
(3) 执行脚本
``` bash
bash shadowsocks-go.sh 2>&1 | tee shadowsocks-server-install.log
```
可以说是相当方便, 为国外云主机上安装 shadowsocks-server 的首选方案;

### **参考链接**
- [SS_Server的搭建及加速](https://blog.csdn.net/qq_36163419/article/details/75452822)

