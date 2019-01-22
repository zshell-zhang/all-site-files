---
title: fedora 折腾经验备忘录
date: 2018-12-15 23:13:49
categories:
 - life
 - pc
tags:
 - life:pc
---

> 当我试图注销重新登陆时, 惊悚的一幕发生了: 黑屏! 近乎绝望般得按下电源键强制重启, 等来的居然是字符登陆界面, 讽刺的是我输入账号密码后, 还登陆成功了......
字符界面下, 所有的命令都能正常执行, 可是进不了 tty7, 这系统实质上就是废的呀! 我猜测 gnome 的核心组件大概是被我误删了...... 无奈, 思忖着崩溃前我到底做了什么, 也只能重头再来;

<!--more-->

------

2018 年 10 月 30 日, fedora 发布了新版本: [feodra 29](https://fedoramagazine.org/announcing-fedora-29/), 令无数 linux 忠实拥趸跃跃欲试;
历经各种曲折, 耗费几近半年时间, 我终于赶在 2019 年前折腾出了一个有着勉强模样的 fedora, 装在了我的笔记本上, 甚为欣慰; 这半年间, 我试过了 fedora 26, 27, 28, 以及最新的 29, 一次又一次得蹂躏着我入手没多久的 ssd, 遭遇了各种有厘头, 无厘头的 bug, 缺陷, 宕机, 在 "几乎打算放弃" 的边缘上游走了数月; 可是我心里面总是咽不下这口气, 不把 fedora 搞定我浑身不自在, 就是特想做成这件事, 说是为了装逼也好, 学习也罢, 反正我整个人都豁出去了, 不达目的坚决不罢休, 死不瞑目!
于是, 今天终于有了这篇文章, 好好总结一下, 也好好纪念一下;

## **关键软件安装**

### **重要软件源添加**
添加 rpm fusion 与 FZUG 源 (以 fedora 29 为例):
``` bash
sudo dnf install https://mirrors.tuna.tsinghua.edu.cn/fzug/free/29/x86_64/fzug-release-29-0.1.noarch.rpm
```
如果是其他 fedora 版本, 直接参考 [官方文档](https://github.com/FZUG/repo/wiki/添加-FZUG-源) 即可;

### **sogoupinyin 输入法**
输入法是万物之源, 没有中文输入法, 一个中国人如何正常使用 fedora?
搜狗公司也算是个有情怀的公司, 为我们广大 linux 用户开发了 linux 版本的 sogoupinyin; 但是美中不足的是, 它只提供了 debian 系列才能使用的 deb 包, 而没有提供 redhat 系列的 rpm 包; 为了将其移植到 fedora, 我作了一些尝试与努力, 并专门总结了一篇文章: [fedora 安装 sogoupinyin 输入法](https://zshell.cc/2018/11/29/life-pc--fedora_安装_sogoupinyin_输入法/);

### **vim**
fedora 自带的 vim 是功能简化的 vim, 或者说是功能增强型的 vi:
``` bash
> sudo rpm -qa | grep vim
vim-minimal-8.1.450-1.fc29.x86_64
```
而在日常脚本编写中, 一个 minimal 的 vim 是不够用的, 我们需要完整版的 vim:
``` bash
sudo dnf install vim-enhanced
```

### **jdk**
### **postman**
### **shadowsocks client**
一般装 shadowsocks client 不会使用 yum / dnf / apt-get 之类的工具, python-pip 直接上:
``` bash
sudo pip install shadowsocks
```
其运行命令的选项也是十分的简洁:
``` bash
#  -c CONFIG              path to config file
#  -s SERVER_ADDR         server address
#  -p SERVER_PORT         server port, default: 8388
#  -b LOCAL_ADDR          local binding address, default: 127.0.0.1
#  -l LOCAL_PORT          local port, default: 1080
#  -k PASSWORD            password
#  -m METHOD              encryption method, default: aes-256-cfb
#  -t TIMEOUT             timeout in seconds, default: 300
  
sslocal -s xxx.xxx.xxx.xxx -p 8388 -k "*************" -b 127.0.0.1 -l 1080 & 1>/var/log/shadowsocks.log 2>&1
```
重定向一下命令的标准输出流与标准错误流, 方便故障时排查问题;

不过, 还是不建议直接在命令的选项里配置参数, 更好的方式是加载配置文件, 方便管理也不容易遗忘:
``` bash
# /usr/local/etc/shadowsocks.json
{
    "server": "xxx.xxx.xxx.xxx",
    "server_port": 8388,
    "local_address": "127.0.0.1",
    "local_port": 1080,
    "password": "*************",
    "timeout": 3000,
    "method": "aes-256-cfb",
    "fast_open": false
}
```
``` bash
sslocal -c /usr/local/etc/shadowsocks.json 1>/var/log/shadowsocks.log 2>&1
```
另外, 这里只是 shadowsocks client, 要真正翻出去还需要 server 端的配合, 我在另一篇文章里有具体介绍: [在裸镜像上搭建 shadowsocks server](https://zshell.cc/2018/07/21/life-pc--在裸镜像上搭建shadowsocks_server/);

### **atom**
### **bcloud 客户端**
### **虚拟化**

### **netease-cloud-music**
网易云音乐客户端虽然谈不上是必装的关键软件, 但是毕竟人家是个有情怀的公司, 专门为 linux 用户出了客户端, 而我之前也拿到过云音乐部门的 offer, 无论如何我对 netease-cloud-music 都是有感情的;
同 sogoupinyin 输入法一样, netease-cloud-music 客户端美中不足的是它只提供了 deb 包, 故而我就需要做一些移植工作了, 总结文章链接如下: [fedora 安装 netease-cloud-music](https://zshell.cc/2018/07/11/life-pc--fedora_安装_netease-cloud-music/);

## **桌面主题设置**
无论是 fedora, 还是如今高版本的 ubuntu (18.04 及以上), 默认使用的桌面环境都是 gnome 这一通用主流的标准了, 而管理 gnome 的最佳工具是 gnome-tweak-tool:
``` bash
sudo dnf install gnome-tweak-tool
```

### **gnome-shell-extension**
桌面主题个性化的精髓就在于 shell 拓展, 各种方便的工具可以帮助我们展示个性, 优化交互等;
之前折腾 fedora 28 时, 我下载收集了一些实用的拓展工具, 并统一整理到百度网盘上; 而现在 fedora 29 将 gnome 的版本升级到了 3.30, 这些插件对于 gnome 的版本要求很高, 连中版本都要对上号, 3.28 的插件在 3.30 的 gnome 环境下竟然不能兼容;
``` bash
> gnome-shell --version
GNOME Shell 3.30.1
```
现在我打算放弃这种思路, 毕竟以后 fedora 还会继续升级, 就算我现在将百度网盘上的插件都更新为最新的, 也难保以后能兼容更高版本的 fedora; 所以更好的思路是寻找一个稳定的代理, 去帮助自己实时获取最适配的各种插件;
这个理想的代理就是 chrome, 让浏览器帮忙下载, 这需要两样东西:
1. 首先是对应的 chrome 插件: [GNOME Shell integration](https://chrome.google.com/webstore/detail/gnome-shell-integration/gphhapmejobijbbhgpjhcjognlahblep);
2. 与 chrome 插件交互的本地 agent:
``` bash
sudo dnf install chrome-gnome-shell
```
这两样东西准备好后, 就可以去 [gnome-shell-extension 官方网站](https://extensions.gnome.org/) 下载插件了; 除了默认带有的, 目前我又安装了如下几个插件:
1. [Dash to Dock](https://extensions.gnome.org/extension/307/dash-to-dock/), 类似于 ubuntu 启动器, 方便用于放置常用的应用程序, 快速启动;
2. [Hide Top Bar](https://extensions.gnome.org/extension/545/hide-top-bar/), 隐藏最上方的管理栏 top bar, 主要用于没有外接显示器情况下的笔记本, 最大化利用屏幕尺寸;

### **窗口按钮设置**
fedora 默认情况下的窗口只展示关闭按钮, 而我们需要同时将 关闭, 最小化, 最大化 三个按钮都展示出来才符合使用习惯; 这个设置十分简单, gnome 的一条命令搞定:
``` bash
gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:appmenu'
```
以上配置会让 关闭, 最小化, 最大 三个按钮从前到后分别出现在窗口的左上角, 十分符合 linux 用户 (以及 Mac 用户) 的使用习惯;

## **系统配置**
### **重要的 daemon service**
(1) **fcitx**
输入法守护进程肯定是要在开机时就启动的, 毕竟打字的场景无处不在; 为了让 fcitx 顺利开机启动, 我竟然费了好些波折:
fcitx 是一个 XWindow 程序, 使用 dbus 通信; 而 dbus 是一个仅限于普通用户 session 的进程; 我们配置开机启动, 传统的思路都是使用 systemd 生成对应的 service (早期的系统使用 system V init), 但这种方式仅适用于使用 root 用户启动的非 XWindow 程序, 如果碰到一个带图形界面的程序, 例如 fcitx, 会报类似如下的错误: 
``` bash
(WARN-31472 dbusstuff.c:197) Connection Error (/usr/bin/dbus-launch terminated abnormally with the following error: No protocol specified
Autolaunch error: X11 initialization failed.
```
没法启动 X 进程, 和 dbus 无法通信, connection error;

查了一下, 对于这种用户级别的 XWindow 程序, fedora 有非常友好的解决方案: 将需要开机启动的应用的 .desktop 启动配置文件复制到如下目录中:
``` bash
cp -a /usr/share/applications/fcitx.desktop ~/.config/autostart/
```
fedora 会在开机后某一个合适的时间点, 回调 ~/.config/autostart/ 下面的所有应用, 从而做到开机启动;

(2) shadowsocks client


### **快捷键设置**

### **字体设置**

### **定制终端的命令行提示符**
fedora 终端的命令行提示符默认是和标准输出一样的普通白色, 没有任何区分, 这会导致一个问题: 当屏幕上有上一条命令的输出时, 无法明显得区分本条命令输出的起始位置, 看起来都是白花花的一片, 很费眼睛, 所以我们需要个性化, 酷炫而显眼的命令行提示符;
linux 命令行提示符的样式是通过一个叫 `PS1` 的环境变量控制的, 默认情况下, 它在 `/etc/bashrc` 中被初始化; linux 不建议使用者直接修改 `/etc/bashrc`, 而是建议将定制逻辑放在 `/etc/profile.d` 目录下, `/etc/bashrc` 会回调该目录下的脚本;
所以这里需要创建一个类似于 `/etc/profile.d/PS1_reset.sh`:
``` bash
# 重新定义命令行提示符的展示样式
export PS1="[\e[m\e[1;32m\u\e[m\e[1;33m@\e[m\e[1;35m\h\e[m \e[1;36m\w\e[m\e[1;36m\e[m] \$"
```
重新定义 `PS1` 即可;
我上面给出了一个具体的样式案例, 关于它的详细含义就不多说了 (这个相比正则表达式有过之而无不及之处), 我就上一个效果图吧:

![terminal_new_PS1](https://raw.githubusercontent.com/zshell-zhang/static-content/master/life/pc/fedora折腾经验备忘录/fedora_new_PS1.png)

### **ssh / git**

## **站内相关文章**
- [fedora 安装 sogoupinyin 输入法](https://zshell.cc/2018/11/29/life-pc--fedora_安装_sogoupinyin_输入法/)
- [fedora 安装 netease-cloud-music](https://zshell.cc/2018/07/11/life-pc--fedora_安装_netease-cloud-music/)
- [在裸镜像上搭建 shadowsocks server](https://zshell.cc/2018/07/21/life-pc--在裸镜像上搭建shadowsocks_server/)

## **参考链接**
- [Announcing the release of Fedora 29](https://fedoramagazine.org/announcing-fedora-29/)
- [如何使用 GNOME Shell 扩展](https://linux.cn/article-9447-1.html)
- [修改linux终端命令行颜色](http://www.cnblogs.com/menlsh/archive/2012/08/27/2659101.html)
- [fcitx在 sudo 无法输入的问题](https://www.jianshu.com/p/902fc5b2fa4d)
- [Fedora 28 - startup application](https://forums.fedoraforum.org/showthread.php?318140-Fedora-28-startup-application)

