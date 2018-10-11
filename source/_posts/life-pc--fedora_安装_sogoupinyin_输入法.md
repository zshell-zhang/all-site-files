---
title: fedora 安装 sogoupinyin 输入法
date: 2018-07-29 23:00:24
categories:
 - life
 - pc
tags:
 - life:pc
---

> 搜狗公司也是一个有情怀的公司, 不过除了情怀之外, 我觉得还有责任在里面; 试想: 如果 sogoupinyin 不推出 linux 版本, 那 linux workstation 在中国的发展会增添多少阻力? 连输入法这一最频繁使用的工具都搞不定, 纵使我们这些拥趸再忠诚, 也只能算是痛苦郁闷的拥趸, 而不是真心诚意, 心甘情愿得使用 linux, 享受 linux;
所以, 我觉得搜狗公司的程序员一定会认为, 开发 linux 版本的 sogoupinyin 是一项神圣而伟大的光荣事迹!

<!--more-->

------

与之前在 fedora 上安装 netease-cloud-music 类似, sogoupinyin 输入法官方也是只提供了 ubuntu 版本, 而没有 fedora 版本; 民间一些 fedora 爱好者打包了 fedora 环境下的 sogoupinyin rpm 版本, 但是存在严重的 bug (怀疑内存泄露), 当输入字符达到一定量时, 便卡死无法继续输入, 只能重启 sogoupinyin 进程;
很明显使用民间的版本是无法高效而专注得工作的, 所以我只能模仿之前 netease-cloud-music 的路数, 下载 ubuntu 下的 deb 包, 解压提取里面的关键内容自己安装了;

### **安装步骤**
(1) 停止 ibus 守护进程
ibus 与 fcitx 这两个 linux 输入法架构同时只能有一个运行, 而 sogoupinyin 使用的是 fcitx 架构, 所以必须停止 fedora 默认的 ibus-daemon 进程;
``` bash
ibus exit
```

(2) 安装 fcitx
``` bash
sudo yum install fcitx
```
同时配置 fcitx 的启动环境:
``` bash
# .bashrc 添加如下变量
export GTK_IM_MODULE=fcitx  
export QT_IM_MODULE=fcitx  
export XMODIFIERS="@im=fcitx"
```

(3) 下载 sogoupinyin 软件包:
我这里已经收集了搜狗最新发布的版本 (2018.4.24): [下载地址](https://pan.baidu.com/s/1fQrD1o-jIgkHuvybZEL8AA#list/path=/apps/software/input-methods&parentPath=/apps), 可以选择 2.2 或者 2.1 版本, 都不会有内存泄露的 bug 存在;
然后就是和 netease-cloud-music 差不多的步骤了:
``` bash
# 解压 deb 包
ar vx sogoupinyin_2.2.0.0108_amd64.deb
# 将最核心的 data.tar.xz 复制到系统目录中
sudo tar -Jxvf data.tar.xz -C /
```
下一步比较重要: 将 sogoupinyin 库导入 fcitx 中, 以使 fcitx 识别并统一管理;
``` bash
sudo cp /usr/lib/x86_64-linux-gnu/fcitx/fcitx-sogoupinyin.so  /usr/lib64/fcitx/fcitx-sogoupinyin.so
# 检查一下是否具有执行权限
sudo chmod +x /usr/lib64/fcitx/fcitx-sogoupinyin.so
```

(4) 安装 fcitx-configtool

(5) 启动输入法
``` bash
# 启动输入法核心驱动
fcitx
# 启动 sogoupinyin 面板
sogou-qimpanel
```

### **下载关键依赖**
在以上安装过程中, 可能会遇到一些依赖问题需要解决 (主要是启动 sogou-qimpanel 时), 我已经将这些依赖都收集起来了: [下载地址](https://pan.baidu.com/s/1fQrD1o-jIgkHuvybZEL8AA#list/path=/apps/software/input-methods&parentPath=/apps);
依次安装即可:
``` bash
sudo yum localinstall lib64qtwebkit4-4.8.2-2-mdv2012.0.x86_64.rpm
sudo yum localinstall libidn1.34-1.34-1.fc29.x86_64.rpm
```

### **遇到的坑**
在本次安装过程的探索中, 还遇到了一些比较深的坑, 这里也一并总结一下:
1. ibus 与 gnome 存在一些依赖关系 (依赖了 gnome-shell, gnome-session 等, 但是又没有真正去使用), 所以刚我开始不是停止 ibus-daemon 进程, 而是试图去删除 ibus 时, 把 gnome 的关键组件也一并删除了, 结果等我下次再进入系统时, 登陆 tty7 直接黑屏, 图形界面用不了了;
相关的文章说应该使用 `yum erase ibus` 而不是 `yum remove ibus` 便可以避免, 我之前在 fedora 27/28 上测试好像是没问题的, 但是在最新的 fedora 29 上 erase 和 remove 没有区别, 命令执行完桌面系统就崩了; 我查了一下 manual 文档, fedora 29 直接将 yum 重定向到 dnf, 并在其中说明 erase 被 deprecate 了, 请使用 remove;
所以我只能将 ibus-daemon 进程停止而不能删除它了;

### **站内相关文章**
- [fedora 安装 netease-cloud-music](https://zshell.cc/2018/07/11/life-pc--fedora_安装_netease-cloud-music/)

### **参考链接**
- [fedora20 安装搜狗输入法及各种问题的解决](https://blog.csdn.net/g457499940/article/details/38656719)

