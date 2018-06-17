---
title: bash 结束死循环的方法
date: 2017-11-05
tags:
  - linux:shell
categories:
  - linux
  - shell
---

> linux 中有很多实用的工具, 采用了这样一种工作方式:
定时执行(1/s, 1/3s 等)一次指定逻辑, 当用户按下 ctrl + c 发出 SIGINT 信号时, 结束进程; 如果接收不到 SIGINT/SIGTERM 等信号, 进程则会一直执行下去;
类似的工具包括 iostat, dstat, jstat 等;
本文整理了实现上述逻辑的一些典型方法;

<!--more-->

------

一次偶然的机会, 我不小心写了一个 bash 脚本, 在一个 while 1 循环里调用一个命令; 结果执行的时候发现, 我按下 ctrl + c, 只结束了循环内的命令, 但结束不了 while 循环本身, 造成了该脚本停不下来了, 最后不得不打开另一个终端 kill 掉它;
这个事情突然引起了我的兴趣, 于是我总结了一下 bash 结束 while 1 死循环的几种方法;

### **方法1: 监听命令返回值**
根据 [GNU 相关规范](http://www.gnu.org/software/bash/manual/bashref.html#Exit-Status), 如果一个进程是由于响应信号 signal 而终止, 其返回码必须是 128 + signal_number;
那么, 可以通过判断其返回码 $? 是否大于 128 而判断 COMMAND 是否响应了信号;
```
while [ 1 ]; do
    COMMAND
    test $? -gt 128 && break
done
```
更精确的, 如果只想判断 COMMAND 是否响应了 SIGINT 信号, 可以直接判断:
```
# SIGINT = 2, 128 + SIGINT = 130
test $? -eq 130 && break
```
特殊的情况下, COMMAND 忽略了 SIGINT 信号, 可以使用 -e 选项强制其响应 SIGINT 信号:
```
while [ 1 ]; do
    COMMAND -e
    test $? -gt 128 && break
done
```

### **方法2: 命令返回值短路**
方法2 是方法1 的简化版本:
```
while [ 1 ]; do
    COMMAND -e || break
done
```
其本质是监听 COMMAND 的返回值 $? 是否为 0, 如果是 0, 那么 break 中断命令就被短路了; 如果是非 0, 便会执行 break, 跳出死循环;
这种方法巧妙得使用 || 逻辑运算符简化了代码, 但是有一个缺陷: 当 COMMAND 并非因为响应 ctrl + c 而是其他错误返回了非 0 的状态时, 循环也会结束;
这是方法2 相比 方法1 略显不精准的地方;

### **方法3: 使用 trap 捕获信号**

```
# 捕获到 SIGINT 即 exit 0 正常退出
trap "exit 0" SIGINT
while [ 1 ]; do
    COMMAND -e
done
```

### **方法4: 使用 ctrl + z 配合 SIGTERM 信号**
当命令运行在前台, 使用 ctrl + z 挂起进程, 会得到以下输出:
``` bash
# ^Z
[1]+  Stopped                 COMMAND

# 1 是挂起进程的作业号(job number), kill [job_number] 会向该作业发送 SIGTERM 信号
kill %1
# 发送 SIGTERM 信号给最近一次被挂起的进程
kill %%

# 执行的结果
[1]+ Terminated               COMMAND
```

### **方法5: 使用 -e 选项**
使用 set -e, 开启命令返回码校验功能, 一旦 COMMAND 返回非 0, 立即结束进程;
```
#!/bin/bash
set -e
while [ 1 ]; do
    COMMAND -e
done
```
或者作为 bash 的参数:
```
#!/bin/bash -e
while [ 1 ]; do
    COMMAND -e
done
```


### **参考链接**
- [Terminating an infinite loop](https://unix.stackexchange.com/questions/42287/terminating-an-infinite-loop)
- [3.7.5 Exit Status](http://www.gnu.org/software/bash/manual/bashref.html#Exit-Status)
- [How to stop the loop bash script in terminal](https://unix.stackexchange.com/questions/48425/how-to-stop-the-loop-bash-script-in-terminal/48465#48465)
- [Unix/Linux 脚本中 “set -e” 的作用](http://blog.csdn.net/todd911/article/details/9954961)

