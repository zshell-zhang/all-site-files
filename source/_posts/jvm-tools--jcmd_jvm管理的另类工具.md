---
title: 'jcmd: jvm 管理的另类工具'
date: 2017-06-25 19:13:05
categories:
 - jvm
 - tools
tags:
 - jvm:tools
---

> 曾经 oracle 向我们提供了一套 jvm 管理与诊断问题的 "工具全家桶": jps, jstack, jmap, jstat, jhat, jinfo 等等, 我们针对不同的情景使用不同的工具, 解决特定的问题;
现在, oracle 在 jdk7 之后又为我们带来了一个全能的工具 jcmd; 它最重要的功能是启动 java flight recorder, 不过 oracle 在设计该命令的时候, "不小心" 为它附加上了一些其他功能, 从而将原本平静的水面搅起了波澜;

<!--more-->

------

### **jcmd 工具的定位**
jcmd 是 jdk7 之后新增的工具, 它是 java flight recorder 的唯一启动方式, 详细的内容请见 [java flight recorder 的使用](); 不过, oracle 顺手又为其附带了一些 "便捷" 小工具:

1. 列举 jvm 进程 (对标 jps)
2. dump 栈信息 (对标 jstack)
3. dump 堆信息 (对标 jmap -dump)
4. 统计类信息 (对标 jmap -histo)
5. 获取系统信息 (对标 jinfo)

这样一下子就有意思了, jcmd 似乎有了想要取代其他命令的野心; 下面来具体介绍一下 jcmd 都能顺手做些什么事情;

### **jps 类似功能**
jcmd 命令不带任何选项或者使用 -l 选项, 都可以打印当前用户下运行的虚拟机进程;
``` bash
# jps
sudo -u xxx jps -l
# jcmd
sudo -u xxx jcmd [-l]
```

### **查看 jcmd 对指定虚拟机能做的事情**
jcmd 确实神通广大, 但是再厉害的大夫也得病人配合工作才行, 比如在低版本 jre 上跑的程序肯定无法使用 flight recorder 抓 dump;
当使用 jcmd 拿到了目标 vmid 后, 使用如下命令可以查看 jcmd 对目标 jvm 能够使用的功能:
``` bash
sudo -u xxx jcmd {vmid} help
```
输出可以使用的功能列举如下:
``` bash
# flight recorder 相关功能
JFR.stop
JFR.start
JFR.dump
JFR.check

# jmx 相关功能
ManagementAgent.stop
ManagementAgent.start_local
ManagementAgent.start

# jstack 相关功能
Thread.print

# jmap 相关功能
GC.class_stats
GC.class_histogram
GC.heap_dump

# jinfo 相关功能
VM.flags
VM.system_properties
VM.command_line
VM.version

# gc 相关
GC.run_finalization # System.runFinalization()
GC.run              # System.gc()
GC.rotate_log       # 切割 gc log

# 其他
VM.native_memory
VM.check_commercial_features
VM.unlock_commercial_features
VM.uptime

```

### **jstack 类似功能**
``` bash
sudo -u xxx jcmd {vmid} Thread.print
```
以上命令输出的内容与以下使用 jstack 命令的输出一致:
``` bash
sudo -u xxx jstack -l {vmid}
```

### **jmap 类似功能**
与 jmap 相关的功能主要是以下四类:
(1) 堆区对象的总体统计
``` bash
# jmap 的实现
sudo -u xxx jmap -heap {vmid}
```
jcmd 没有提供与 jmap -heap 类似的功能;

(2) 堆区对象的详细直方图统计
``` bash
# jcmd 的实现
sudo -u xxx jcmd {vmid} GC.class_histogram
# jmap 的实现
sudo -u xxx jmap -histo[:live] {vmid}
```

(3) metaspace 的信息统计
``` bash
# jcmd 的实现
sudo -u xxx jcmd {vmid} GC.class_stats
# jmap 的实现
sudo -u xxx jmap -clstats {vmid} 
```
虽然都是关于 jdk8 metaspace 的信息统计, 不过 jcmd GC.class_stats 与 jmap -clstats 的输出内容没什么关联;
另外, 使用 jcmd GC.class_stats 功能, 需要开启 jvm 选项 `UnlockDiagnosticVMOptions`;

(4) 堆区对象的 dump
``` bash
# jcmd 的实现
sudo -u xxx jcmd {vmid} GC.heap_dump {file_path}
# jmap 的实现
sudo -u xxx jmap -dump[:live],format=b,file={file_path} {vmid}
```

### **jinfo 类似功能**
与 jinfo 相关的功能主要是以下两类:
(1) 打印 jvm 的系统信息, 包括系统参数, 版本等
``` bash
# jcmd 的实现
sudo -u xxx jcmd {vmid} VM.system_properties
sudo -u xxx jcmd {vmid} VM.version
# jmap 的实现
sudo -u xxx jinfo -sysprops {vmid}
```
(2) 打印 jvm 的选项
``` bash
# jcmd 的实现
sudo -u xxx jcmd {vmid} VM.command_line
# jmap 的实现
sudo -u xxx jinfo -flags {vmid}
```
(3) 修改 jvm 的选项
``` bash
# jcmd 的部分实现
sudo -u xxx jcmd {vmid} VM.unlock_commercial_features
sudo -u xxx jcmd {vmid} VM.check_commercial_features
# jmap 的实现
sudo -u xxx jinfo -flag [+|-]{option_name} {vmid}
sudo -u xxx jinfo -flag {option_name}={value} {vmid}
```
关于修改 jvm 选项, 只能说 jcmd 几乎是没有相关的功能, 其只能操控与 flight recorder 配套的 `UnlockCommercialFeatures` 选项而已;

### **jcmd 使用总结**
往不好听的讲, 除了 java flight recorder 之外, jcmd 其余的功能只能说是 "鸡肋": 只有 jps, jstack 可以算完全覆盖了其相关功能, jmap 勉强可以算覆盖了其相关功能;
除此之外, jinfo 的部分功能没有实现, jstat 的所有功能都没有实现; 而且 jcmd 的选项名字一般都比较长, 不容易记住, 必须依赖 `jcmd {vmid} help` 打印相关内容, 给使用带来了不便;
总体来说, 除了 java flight recorder 必须要使用 jcmd 之外, 其余的功能暂时还是建议使用传统的工具来解决问题; jcmd 的野心还得继续培养, 等以后 oracle 发布新版本的时候再继续观察吧;

### **站内相关文章**
- [java flight recorder 的使用]()

### **参考链接**
- [jcmd命令详解](http://fengfu.io/2016/12/14/jcmd%E5%91%BD%E4%BB%A4%E8%AF%A6%E8%A7%A3/)

