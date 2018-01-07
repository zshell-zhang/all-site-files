---
title: sed 命令整理
date: 2016-11-04 22:56:47
categories:
  - linux
  - text
tags:
  - linux:text
---

> stream editor: 流式文本编辑器;
sed 命令的侧重点在于对文本的编辑;

<!--more-->

### **sed 的基本模式**
``` bash
# 标准模式: 选项, 目标行范围, 命令
sed  [-nefri] '[target line]command' $file_path
# 正则模式: 选项, 正则匹配式, 命令
sed  [-nefri] '/regex/command' $file_path
# 混合模式: 选项, 目标行与正则式组合范围, 命令
sed [-nefri] 'line,/regex/command' $file_path
```
### **sed 的常用选项**
``` bash
1. -n:  silent 静默模式, 只输出被 sed 处理过的行;
2. -e:  --expression, 指定命令, 可以使用多个 -e 执行多个命令:
        sed -e '$d' -e '/regex/p' $file_path
3. -f:  执行给定文件里的命令;
4. -r:  --regexp-extended, 使 sed 支持拓展的正则表达式语法, 拓展的正则表达式较常规的正则表达式增加支持了如下语法:
        +, ?, |, ()
        由于这些拓展语法也非常常见, 所以推荐若使用 sed 的 regex 功能时带上 -r 选项;
5. -i:  直接在指定的文件里修改编辑, stdout 不输出任何内容;
```
### **sed 的 command**
``` bash
1. i:   insert 到 目标行的上一行
2. a:   append 到 目标行的下一行 
3. c:   replace, 不能使用正则表达式
4. s:   replace, 使用正则表达式, 一般需要与 -r 配合使用, 模式为:
        s/regex/new_str/g, 替换文件中所有的 regex;
        s/regex/new_str, 只替换每行第一个被匹配上的 regex;
        s/regex/new_str/p, 如果某行被匹配上了就打印出来, 常与 -n 选项一同使用;
5. d:   delete
6. p:   print, 一般需要与 -n 选项一同使用, 否则看不出打印效果
7. y:   按每个字符映射, 模式案例: y/1234567890/ABCDEFGHIJ/
```
### **典型示例**
``` bash
# 打印最后一行
sed -n '$p' $file_path
# 指定两种操作, 删除9到最后一行, 以及向1到3行后追加 'append' 字符串
sed -i -e '9,$d' -e '1,3a append' $file_path
# 正则表达式替换(替换全部 regex)
sed -ri 's/^(test|ping)[a-z]+.$/kill/g' $file_path
# 打印从第9行开始到以 test 结尾的行之间的每一行
sed -n '9,/test$/p' $file_path
```
``` bash
# 结合变量, 往最后一行添加一行内容
# 需使用"", 同时表示最后一行的 $ 需要转义
cron_str='5 * * * *  sh /home/q/tools/bin/log_collect.sh 1>/dev/null'
sed "\$a ${cron_str}" /var/spool/cron/root
```

### **参考链接**
- [linux之sed用法](http://www.cnblogs.com/dong008259/archive/2011/12/07/2279897.html)
- [linux sed命令详解](http://www.iteye.com/topic/587673)

