---
title: git 忽略文件的特殊场景
date: 2016-07-14 23:17:24
categories:
 - tools
 - git
tags:
 - tools:git
---

> git 忽略文件, 其实有两种场景: 永久忽略 与 临时忽略;
使用 `.gitignore` 在最刚开始时永久忽略指定文件是最常见的处理, 但是偶尔也会遇到特殊情况:
1.一时疏忽, 将本该忽略的文件提交追踪了;
2.需要临时忽略某指定文件, 一段时间后再继续追踪;
本文将讨论以上两种情况下的 git 处理;

<!--more-->

------

### **永远忽略已被跟踪的文件**
适用场景:
手误上传了不需要上传的文件, 希望斩草除根, 以后不让 git 追踪该文件;
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

