---
title: linux 重度使用者拿到 MacBook 后的一系列挣扎
date: 2018-08-26 15:46:05
categories:
 - life
 - pc
tags:
 - life:pc
 - MacBook
---

> 新东家发的办公笔记本是 MacBook Pro, 来之前我还觉得挺高大上, 然而真正开始用的时候发现, OS X 对于 linux 用户来说实在是太难于上手了, 甚至感觉比 Windows 系统还不习惯, Windows 好歹从前还是使用过的, OS X 简直就和初学者使用 vim 一样不知所措;

<!--more-->

------

关于一些常规而必备的软件 (如 chrome, thunderbird, atom/sublime, jetbrains 系列, jdk 等等), 本文就不再赘述了;

### **搞定 sudo 权限**
说来蛋疼的是, 即便已使用 visudo 命令开启了用户的 sudo 权限, OS X 依然不允许修改系统级的目录, 这是 OS X 在 10.11 中引入的 System Integrity Protection (SIP) 特性; 我观察了一下, 差不多除了 /usr/local 这一原本就该属于用户自己管理的目录下之外, 其余的都无法操纵, 切到 root 也不行, 可以说算是另一个阉割版的 admin;
所以拿到本子的第一件事就应该是关闭 SIP 特性, 否则后面的操作会显得束手束脚:
``` bash
# 开机, command + r 进入 rescue 模式
csrutil disable
```
这样就可以关闭 SIP 特性, 后面就可以以 sudo 权限操纵系统级的目录了;

### **安装 Homebrew**
作为 Mac 生态下主流的包管理软件, 安装 Homebrew 是使用 Mac 的程序员必做的事情之一, 否则后面想在命令行装东西可就费劲了;
``` bash
curl -LsSf http://github.com/mxcl/homebrew/tarball/master | sudo tar xvz -C/usr/local –strip 1
```
如果遇到 `Error: Unknown command: install`, 则需要更新 Homebrew:
``` bash
brew update
```
这时就体现了完整版 sudo 权限的重要性: `brew update` 命令需要更新 `/usr/local/` 下的文件, 如果开启了 SIP 特性, 这个操作就没权限执行了;

&nbsp;
有了 brew 之后, 后面安装与管理各种软件就方便多了; Homebrew 的命令是比较简洁明了的:
``` bash
# 安装与卸载
brew install $package
brew uninstall $package

# 查询
brew list
brew search $package
brew info $package
```

### **安装 showsocks client**
借助 brew 命令, Mac 下面部署梯子的操作倒还算方便:
``` bash
brew install shadowsocks-libev
```
自定义一个开机启动脚本, 让 mac 每次开机时自动运行 ss-local:
``` bash
#!/bin/bash

/usr/local/opt/shadowsocks-libev/bin/ss-local -c /etc/shadowsocks.json &
```

### **使用解放鼠标的资源定位器**
目前我了解到的, 这种通过快捷键召唤出来并能够根据关键字定位资源的工具, 大致有三类主流的代表: spotlight, alfred 以及 devonthink;

- mac 本身自带 spotlight, 通过 command + space 召唤出来, 其特点是增量渐进式得搜索各种类型的资源, 可能包括 app, document, image 等, 一边搜索一边展示最新的结果, 速度稍慢;
- 我在我的 mac 上安装的是第二个 alfred: alfred 通过 option + space 召唤出来, 并且默认优先搜索 app, 只有当多敲一个空格或单引号时才会搜索 document 等其他类型;
这个设计我觉得完全不冗余, 反而是很精妙, 因为它用极其微小的代价 (一个空格/单引号) 就将最频繁与非频繁的资源类型作了隔离, 让最频繁的资源类型以极高的效率被检索到, 而不是像 spotlight 那样全盘通吃却拉低了整体搜索的响应时间;
- 第三个是 devonthink: 这个工具的功能更加专注, 它就是一个搜索引擎, 当我们将需要被索引的文件放入 devonthink 作预处理, 往后就可以以极高的效率通过文档内容中的关键字检索到目标文档了;
对我来说, 需要被检索的知识与文档我都用专业的云笔记去作归档与备份, 所以我并不额外需要 devonthink 这样的工具了;

### **安装 sougoupinyin 代替默认输入法**
苹果自带的中文输入法不是很好用, 中英文切换默认使用 ctrl + space 组合, 十分不方便, 具体在哪里修改设置我也懒得看了; 此时需要下载符合国人习惯的 sougoupinyin, 当然由于搜狗对 mac 的支持比较友好, 仅需一键安装即可, 此处就不用多说了;
在输入法方面, 不得不承认 mac 是比 linux (至少是 fedora) 要方便不少的: fedora 上的 sougoupinyin 一直停滞更新, 目前最新版本依然有严重 bug, 我不得不去移植 ubuntu 环境下的 deb 包才能满足我在 fedora 下的使用;

### **配置更友好的终端环境**
mac 自带的 terminal 也不是很好用, 不过有第三方强大的替代品可以选择, 我这里选择的一个终端环境的组合是 iTerm2 + oh-my-zsh, 以代替原有的 terminal + bash 的默认组合;
首先通过菜单栏更改 iTerm2 为 default terminal;
iTerm2 支持各种个性化的配置, 包括终端颜色, 快捷键等, 我这里选择的配色方案是 [solarized](https://ethanschoonover.com/solarized/) 中的 Solarized Dark;
接下来是安装 zsh 的全能管家 [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh):
``` bash
# by curl
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
# by wget
sh -c "$(wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
```
oh-my-zsh 的配置文件默认是 ~/.zshrc, 这个文件里有几个关键配置项:
``` zsh
# 加载 oh-my-zsh 的核心内容
export ZSH="/Users/zshell/.oh-my-zsh"
source $ZSH/oh-my-zsh.sh
```
以下为个性化定制:
``` zsh
# 定制主题
ZSH_THEME="ys"
# 开启语法高亮插件
source /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# 定制插件
plugins=(
  git
  osx
  docker
  zsh-autosuggestions
)
```

一般比较漂亮顺眼的两款主题是 [ys](http://blog.ysmood.org/my-ys-terminal-theme/) 和 [agnoster](https://github.com/agnoster/agnoster-zsh-theme), 在 ZSH_THEME 中可以更换, 如果使用 agnoster, 需要另外安装 [Meslo](https://github.com/powerline/fonts/blob/master/Meslo%20Slashed/Meslo%20LG%20M%20Regular%20for%20Powerline.ttf) 字体并在 iTerm2 中启用它;
关于语法高亮插件, 可以使用 brew 安装:
``` bash
brew install zsh-syntax-highlighting
```
然后在 .zshrc 中 source 下载的 zsh-syntax-highlighting.zsh 脚本即可;
&nbsp;
与 iTerm2 相关的软件资源我整理到了一个公共目录下, 以方便日后在新的 MacBook 上下载: [software / iterm+](https://pan.baidu.com/s/1fQrD1o-jIgkHuvybZEL8AA#list/path=%2Fapps%2Fsoftware%2Fiterm%2B&parentPath=%2Fapps);

### **熟悉 mac 的按键及其标识**
这其实是个很扯淡的事情: mac 的按键体系与其他传统的笔记本不一致, 它多了一个 command 键, 更改了 delete 键的含义, 少了一些诸如 backspace, page up/down, home/end 等按键, 如此迥异以致很多传统的快捷键在 mac 下都有很大的不同, 有些功能需要依靠按键组合来实现, 让初次接触的人很不习惯;
另外 mac 的各个按键有着独特的图像标识, 在一些软件的快捷键设置面板上会频繁出现, 如果不稍作了解, 有很多标识是不太看得懂其象形含义的,  这里我对所有 MacBooK 基础按键的标识作一个整理:

|按键标识	   |含义				   |
|:------------:|:---------------------:|
|⌘			  |Command				  |
|⇧			  |Shift				  |
|⌥ 	     	  | Option, Alt		      |
|⌃			  |Control				  |
|↩			  |Return/Enter			  |
|⌫		    |Delete				     |
|⌦		    |向前删除键 (Fn + Delete) |  
|↑ / ↓ / ← / →|上下左右 箭头		  |
|⇞ / ⇟	     |Page Up/Down (Fn + ↑/↓)|
|Home / End	  |Fn + ←/→				  |
|⇥ 			  |右制表符 (Tab键)		  |
|⇤	    	  |左制表符 (Shift+Tab)	  |
|⎋			  |Escape (Esc)		   	  |

### **使用总结**
我相信从 Windows 迁移到 mac 环境是一件阻力不大的事情, 这也是大部分人的模式, 而且这部分人群的行业分布十分广泛, 软件工程师只是其中一个子集而已; 然而对于一个长期使用 linux PC 的程序员来说, 事情就没那么富有吸引力了: mac 所能给予的生产力与效率, linux 也不遑多让, 另外对于开源软件有信仰的人来说, 这事甚至没有任何商量的余地;
但其实我很清楚, 这本质上不过是一个人内心深处的偏见与执念, 长期使用 mac 的人, 让他们转投 linux 阵营也是不可能的事; 即便在 linux 业界之内, 关于 fedora, arch 与 ubuntu 的争论也是从未休止过; 关于 OS X 其实有大量的优点在本文中完全没有被提及, 可能是我觉得不值得花费时间去探索这些东西, 我在工作中所创造的价值完全依托于 linux 主机, 所以我亦使用 linux 作为我个人笔记本的操作系统, 借用这种方式以熟悉, 并更好得理解我的作品在生产环境下的工作原理: 兴许这就是我无可救药的执念......
我听说阿里巴巴的办公笔记本发放的是 MacBook Pro 15', 并且强烈不建议使用自己的笔记本办公, 非要使用的话必须安装各种安全监视与审计软件, 毕竟信息安全是上市公司的头等大事; 这么说无论如何, 我都得慢慢得去适应 mac 环境下的办公模式了, 否则将来因为强烈排斥使用公司统一发放的 MacBook Pro 而拒绝了某公司的 offer, 就有点扯淡了;

### **参考链接**
- [ios brew安装记录](https://blog.csdn.net/qq_24283329/article/details/77896380)
- [OS X 执行命令加了sudo还是提示Operation not permitted](https://blog.csdn.net/buyueliuying/article/details/74634712)
- [MAC 电脑如何启用root用户](https://blog.csdn.net/qq_24283329/article/details/77896380)
- [mac sip关闭教程 苹果MAC10.11系统关闭SIP教程](https://www.cr173.com/apple/126928_1.html)
- [Mac下终端配置(item2 + oh-my-zsh + solarized配色方案)](http://www.cnblogs.com/weixuqin/p/7029177.html)
- [Mac 按键标识](https://blog.csdn.net/HaoDaWang/article/details/78731098)
- [Alfred 3.7(938) 效率神器](http://xclient.info/s/alfred.html?t=ff3019e26174ceb44f3725cfb2282663e6a53526)

