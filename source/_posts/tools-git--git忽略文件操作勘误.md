---
title: git忽略文件操作勘误
date: 2016-07-14 23:17:24
categories:
 - tools
 - git
tags:
 - tools:git
---

> todo

<!--more-->

------

### **永远忽略已被跟踪的文件**
适用于手误上传了不必要的文件;
``` bash
# first step
git rm --cached file_path/
# second step
update .gitignore to exclude target file
```
&nbsp;
### **临时忽略已被跟踪的文件**
适用场景:
目标文件庞大, 每次修改保存时, git 计算文件的变化并更新 working directory, 触发磁盘IO瓶颈;
所以需要临时忽略文件, 待修改完成 commit 时恢复跟踪;
``` bash
# first step
git update-index --assume-unchanged file_path/
# 编辑文件...
# seconde step
git update-index --no-assume-unchanged file_path/
```
&nbsp;
### **参考链接**
- [git忽略已经被提交的文件](https://segmentfault.com/q/1010000000430426)

