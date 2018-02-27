---
title: 'python module 使用总结: 定时调度器'
date: 2018-02-23 23:23:21
categories:
 - python
 - module
tags:
 - python:module
---

> 在 java 里, 第三方定时调度框架比较常用的是 quartz 和 springframework 提供的 schedule 功能; 不过在各大公司里, 一般都会开发自己能集中管理与灵活调控的调度组件; 这样一来, 第三方的调度框架反而就接触的少了;
我相信在以 python 为主要使用语言的公司里, 一定也有自己的调度中间件; 但是对于以 java 为主的公司里, 肯定不可能专为 python 维护一套调度系统, 所以就很有必要了解一下 python 里的定时调度模块; 本文将介绍几种常用的 python 定时调度框架:
1. 简单的实现: sched 与 schedule;
2. 功能增强版: apscheduler;
3. 分布式调度器: celery;

<!--more-->

------

### **sched**
sched 是 python 官方提供的定时调度模块, 其实现非常的简单, sched.py 的代码量只有一百多行, 且只有一个类: scheduler;
``` python
# sched.py
class scheduler:
    """
        @param timefunc     能够返回时间戳的计时函数, 要求该函数是一个无参函数
        @param delayfunc    能够阻塞给定时间的阻塞函数, 要求该函数能接收一个数值类型的参数
    """
    def __init__(self, timefunc, delayfunc);
    
    """
        @param delay        需要延迟的时间
        @param priority     当多个任务需要在同一个时间调度时的优先级
        @param action       需要调度的函数
        @param argument     需要调度函数的参数列表
    """
    def enter(self, delay, priority, action, argument);
```
如上所示, scheduler 是使用构造器传进来的计时函数与阻塞函数去实现调度逻辑的;

#### **sched 的局限性与解决方案**
不过说真的, 把 sched 定义为定时调度模块真的很牵强:
常规意义上, 我们所理解的定时调度器, 应该是能够像 cron 那样, 按给定的时间间隔或在指定的时间点上循环执行指定的任务; 但是 sched 并不能做到这一点, sched 所做的, 只是从某一个时间点开始, delay 一段我们给定的延时时间, 然后执行给定方法, 仅执行这一次;
``` python
import time
from sched import scheduler

def do_task(time_str):
    print('task run: %s' % time_str)

s = scheduler(time.time, time.sleep)
# delay 5 秒后执行 do_task 函数, 仅执行一次
s.enter(5, 0, do_task, (time.time(),))
s.run()
```
要想 sched 做到循环执行, 还需要在其基础上包装上一层类似'递归'的概念:
``` python
s = scheduler(time.time, time.sleep)
# 在任务函数中将自己再次用 sched 调度以实现循环
def do_task(time_str):
    s.enter(5, 0, do_task, (time.time(),))
    print('task run: %s' % time_str)
    
s.enter(5, 0, do_task, (time.time(),))
s.run()
```
当然, 这只是将函数自己的引用传给了 scheduler, 神似递归但并非递归, 所以也就不存在找不到递归出口而爆栈的问题了;
很明显, 采用这种方式才能实现真正的定时调度, 可谓非常麻烦而蹩脚;

#### **sched 的调度原理**
sched 使用 heapq 优先队列来管理需要调度的任务; 在调用了 scheduler 类的 enter 方法后, 其实是生成了一个任务的快照, 并放入了优先队列里:
``` python
event = Event(time, priority, action, argument)
heapq.heappush(self._queue, event)
```
在调用 scheduler.run() 方法后, sched 在一个死循环里, 不断得从优先队列里取出任务执行, 计算最近的下一个任务的等待时间并阻塞:
``` python
 while q:
    time, priority, action, argument = checked_event = q[0]
    now = timefunc()
    if now < time:
        delayfunc(time - now)
    else:
        event = pop(q)
        if event is checked_event:
            action(*argument)
            delayfunc(0)
        else:
            heapq.heappush(q, event)
```
总体来说, sched 的设计还是比较紧凑清晰的, 轻量级化, 但是由于其固有的缺陷, 在复杂的场景中, 往往不能胜任, 我们需要功能更强大的调度框架;

### **schedule**

### **apscheduler**


### **celery**

### **参考链接**
- [python sched模块学习](http://blog.csdn.net/leonard_wang/article/details/54017537)

