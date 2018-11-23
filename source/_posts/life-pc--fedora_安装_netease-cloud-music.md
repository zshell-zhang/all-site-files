---
title: fedora 安装 netease cloud music
date: 2018-07-11 22:38:12
categories:
 - life
 - pc
tags:
 - life:pc
---

> 网易是个有情怀的公司, 云音乐客户端推出了 linux 版本, 虽然是个 deb 包, 那也值得尊敬!
我现在要做的, 就是把它移植到 fedora 环境中, 以造福更多的 linux 爱好者!

<!--more-->

### **安装思路**
网上流传着某些 netease-cloud-music 的 rpm 包, 但是经测试发现这些 rpm 包无法正常使用;
所以现在一个经测试验证可行的方案是下载官方的 deb 包, 然后提取关键内容手动移到 fedora 上: 无论是 ubuntu 还是 fedora, 都以同样的本质运行 linux 进程, 软件包只是打包方式而已, 不影响程序的执行过程;

### **提取关键内容**
以 netease-cloud-music_1.1.0_amd64_ubuntu.deb 为例, 将其解压后得到如下文件:
``` bash
control.tar.gz
data.tar.xz
debian-binary
```
其中, data.tar.xz 是核心的内容, 其余的都可以删除; data.tar.xz 是 xz 压缩包, 解压后得到如下目录结构:
``` bash
> xz -d data.tar.xz
> tree -L 2 data

data
└── usr
    ├── bin
    ├── lib
    └── share
```
它是对应到 /usr/ 目录的, 所以需要将其全部拷贝到对应目录:
``` bash
sudo cp -a usr /
```
至此, netease-cloud-music 的核心内容已经全部提取并放置到正确路径下了; 其余可能还有一些制作 desktop 图标放到 dock 启动器中等小动作, 本文不再详述;

### **下载关键依赖**
fedora 安装 netease-cloud-music 所需要的依赖 (安装命令) 列举如下:
``` bash
su -c 'dnf install http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm'
sudo dnf install gstreamer1-libav gstreamer1-plugins-ugly gstreamer1-plugins-bad-free gstreamer1-plugins-bad-freeworld gstreamer1-vaapi
sudo dnf install libmad
sudo dnf install vlc    # fedora 26 上需要安装, 在我的笔记本上亲测
sudo dnf install qt5-qtx11extras
sudo dnf install qt5-qtmultimedia
```
&nbsp;

以上便是 fedora 安装 netease-cloud-music 的过程记录, fedora 26 上亲测有效;

### **参考链接**
- [Fedora 全系列安装网易云音乐](https://blog.csdn.net/qqlwx/article/details/75094909)

