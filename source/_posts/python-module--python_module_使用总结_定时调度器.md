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

## **sched**
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

### **sched 的局限性与解决方案**
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

### **sched 的调度原理**
sched 使用 `heapq` 优先队列来管理需要调度的任务(关于 heapq 的详细内容请参考: [python module 使用总结: heapq]()); 在调用了 scheduler 类的 enter 方法后, 其实是生成了一个任务的快照, 并放入了优先队列里:
``` python
event = Event(time, priority, action, argument)
heapq.heappush(self._queue, event)
```
在调用 scheduler.run() 方法后, sched 在一个死循环里, 不断得从优先队列里取出任务执行, 计算最近的下一个任务的等待时间并阻塞:
``` python
q = self._queue
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
总体来说, sched 的设计还是比较紧凑清晰的, 轻量化; 但是由于其固有的缺陷, 在复杂的场景中, 往往不能胜任, 我们需要功能更强大的调度框架;

## **schedule**
schedule 是一个广泛使用的 python 定时调度框架, 其 github 地址如下: [https://github.com/dbader/schedule](https://github.com/dbader/schedule), 目前 4k 多个 stars;
和 python 官方的 sched 相比, schedule 的 API 要人性化得多, 而且它基本实现了真正意义上的定时调度:
``` python
import schedule
import time

def do_task(time_str=time.time()):
    print('task run: %s' % time_str)

# 每 10 分钟执行一次任务
schedule.every(10).minutes.do(do_task)
# 每隔 5 到 10 分钟之间的任意一个时间执行一次任务
schedule.every(5).to(10).days.do(do_task)
# 每 1 小时执行一次任务
schedule.every().hour.do(do_task, time_str='1519351479.19554')
# 每天 10:30 执行一次任务
schedule.every().day.at("10:30").do(do_task)

while True:
    schedule.run_pending()
    time.sleep(1)
```

### **schedule 模块的 Scheduler 类**
其实, schedule 模块的整体设计, 是把任务的自我管理部分做的很详细, 而把上层的调度做的很轻很薄, 关键逻辑点采用回调的方式, 依赖任务的自我管理去实现;
而上一节所讲的 sched 模块, 则是在上层调度部分使用了复杂的逻辑 (优先队列) 去统一管理, 而任务本身携带的信息很少; sched 与 schedule 两个模块, 在整体设计上, 形成了鲜明的对比;
Scheduler 类的实例中, 维护了一个列表: jobs, 专门存储注册进来的任务快照;
``` python
Class Scheduler(object):
    def __init__(self):
        self.jobs = []
```
Scheduler 类最重要的方法是 `run_pending(self)`, 其主要逻辑是遍历 jobs 列表中的所有 job, 从中找出当前时间点需要调度的 job, 并执行;
这其中最重要的逻辑是判断一个 job 当前时间点是否需要被调度, 而这个过程是一个回调, 具体的逻辑则封装在 job.should_run 方法里, 下一小节将会详细介绍;
可以发现, 总共只用了三行代码, 以此可见其轻量化;
``` python
def run_pending(self):
    _jobs = (job for job in self.jobs if job.should_run)
    for job in sorted(runnable_jobs):
        self._run_job(job)
```
值得注意的是, schedule 模块中并没有专门的逻辑去定时执行 run_pending 方法, 要想让定时调度持续跑起来, 需要自己实现:
``` python
while True:
    schedule.run_pending()
    time.sleep(1)
```
相比 sched 模块的 '伪递归' 而言, 这样的设计算是比较人性化的了, 可以认为它基本实现了真正意义上的定时调度;

### **schedule 模块的 Job 类**
正如上一节所述, schedule 模块实现了非常详细的任务自我管理逻辑; 相比 sched 的 `Event` 类, schedule 定义了一个控制参数更丰富的 `Job` 类:
``` python
class Job(object):
    def __init__(self, interval, scheduler=None):
        self.interval = interval  # pause interval * unit between runs
        self.latest = None  # upper limit to the interval
        self.job_func = None  # the job job_func to run
        self.unit = None  # time units, e.g. 'minutes', 'hours', ...
        self.at_time = None  # optional time at which this job runs
        self.last_run = None  # datetime of the last run
        self.next_run = None  # datetime of the next run
        self.period = None  # timedelta between runs, only valid for
        self.start_day = None  # Specific day of the week to start on
        self.tags = set()  # unique set of tags for the job
        self.scheduler = scheduler  # scheduler to register with
```
Job 类的参数众多, 单个任务的调度肯定不可能涉及到所有的参数, 这些参数往往是以局部几个为组合, 控制调度节奏的; 但是无论什么组合, 往往都会以 `scheduler.every(interval=1)` 方法开始, 以 `Job.do(self, job_func, *args, **kwargs)` 方法结束:
(1) schedule.every 方法构造出一个 `Job` 实例, 并设置该实例的第一个参数 interval;
``` python
default_scheduler = Scheduler()

def every(interval=1):
    return default_scheduler.every(interval)

class Scheduler(object):
    def every(self, interval=1):
        job = Job(interval, self)
        return job
```
这里想吐槽的是, 这个方法出现在 Scheduler 类中有点突兀, 而且方法名叫 every, 只体现了设置 interval 参数的含义, 但并不能从中看出其新构造一个 Job 实例的意图;
(2) Job.do 方法包装了传递进来的任务函数, 将其设置为自己的 job_func 参数, 并将自己作为一个任务快照放进 scheduler 的任务列表里;
``` python
Class Job(object):
    def do(self, job_func, *args, **kwargs):
        self.job_func = functools.partial(job_func, *args, **kwargs)
        try:
            functools.update_wrapper(self.job_func, job_func)
        except AttributeError:
            pass
        # 计算下一次调度的时间
        self._schedule_next_run()
        self.scheduler.jobs.append(self)
        return self
```
在这两个方法之间, 就是通过建造者模式, 构造出其他控制参数的组合, 以实现各种各样的调度节奏;
下面来重点讲一下各参数组合如何实现调度节奏的控制;
从上一节关于 Scheduler 类的描述中可以看到, 上层调度中最关键的逻辑, 判断每一个注册的 job 是否应该被调度, 其实是 Job 类的一个回调方法 `should_run`:
``` python
def should_run(self):
    return datetime.datetime.now() >= self.next_run
```
而 should_run 方法中的判断的依据, 是当前时间有没有到达 `next_run` 这个实例字段给出的时间点;
next_run 字段的设置则通过在 `Job.do(self, job_func, *args, **kwargs)` 方法 (上文已给出) 和 `Job.run(self)` 方法中调用 `__schedule_next_run()` 方法来实现:
``` python
def run(self):
    logger.info('Running job %s', self)
    ret = self.job_func()
    self.last_run = datetime.datetime.now()
    # 计算下一次调度的时间
    self._schedule_next_run()
    return ret
```
所以, 所有的秘密就存在于 `_schedule_next_run()` 方法里了; 下面将结合几大类参数组合的设置, 拆开来分析 _schedule_next_run() 方法的逻辑;
这些 Job 类的参数组合, 大致可分为这几类:
#### **总基调: 指定调度的周期**
以下方法将会设置 unit 参数, 与 interval 参数结合, 定义调度区间间隔:
``` python
def second(self):   def seconds(self):  # self.unit = 'seconds'
def minute(self):   def minutes(self):  # self.unit = 'minutes'
def hour(self):     def hours(self):    # self.unit = 'hours'
def day(self):      def days(self):     # self.unit = 'days'
def week(self):     def weeks(self):    # self.unit = 'weeks'
```
其对应的 _schedule_next_run() 逻辑如下:
``` python
# def _schedule_next_run(self)
    assert self.unit in ('seconds', 'minutes', 'hours', 'days', 'weeks')
    if self.latest is not None:
        assert self.latest >= self.interval
        interval = random.randint(self.interval, self.latest)
    else:
        interval = self.interval

    self.period = datetime.timedelta(**{self.unit: interval})
    self.next_run = datetime.datetime.now() + self.period
```
先不管其中涉及到的 latest 字段 (下文描述), 其他的逻辑清晰可见: 使用 unit 和 interval 构造出一个指定的 timedelta, 加上当前时间得到下次调度的时间;
&nbsp;
这是最简单的一类, 定下了整个调度的总体节奏; 而下面几个类别的参数并不能单独决定调度周期, 而是在第一类参数的基础之上实施局部调整, 以达到综合控制;
#### **局部调整1: 指定调度的起始 weekday**
以下方法将会设置 start_day 参数, 确定调度开始的时间点; 同时统一设置 unit 参数为 'weeks':
``` python
def monday(self):       
    self.start_day = 'monday'
    self.unit = 'weeks'
def tuesday(self):      
    self.start_day = 'tuesday'
    self.unit = 'weeks'
def wednesday(self):    
    self.start_day = 'wednesday'
    self.unit = 'weeks'
def thursday(self):   
    self.start_day = 'thurday'
    self.unit = 'weeks'
def friday(self):       
    self.start_day = 'friday'
    self.unit = 'weeks'
def saturday(self):     
    self.start_day = 'saturday'
    self.unit = 'weeks'
def sunday(self):     
    self.start_day = 'sunday'
    self.unit = 'weeks'
```
其对应的 _schedule_next_run() 逻辑如下:
``` python
# def _schedule_next_run(self)
    if self.start_day is not None:
        assert self.unit == 'weeks'
        weekdays = ('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday')
        assert self.start_day in weekdays
        weekday = weekdays.index(self.start_day)
        days_ahead = weekday - self.next_run.weekday()
        if days_ahead <= 0:  # Target day already happened this week
            days_ahead += 7
        self.next_run += datetime.timedelta(days_ahead) - self.period
```
可以发现, start_day 只是在 next_run 原有的 weekday 基础上增加了一个 offset, 相当于是 delay time;
#### **局部调整2: 指定调度的起始时间**
以下方法将会设置 at_time 参数, 其针对 unit == 'hours' 只设置 minute 变量, 而对 unit == 'days' 或 'weeks' 才会设置 hour 变量;
``` python
def at(self, time_str):
    assert self.unit in ('days', 'hours') or self.start_day
    hour, minute = time_str.split(':')
    minute = int(minute)
    if self.unit == 'days' or self.start_day:
        hour = int(hour)
        assert 0 <= hour <= 23
    elif self.unit == 'hours':
        hour = 0
    assert 0 <= minute <= 59
    self.at_time = datetime.time(hour, minute)
    return self
```
其对应的 _schedule_next_run() 逻辑也与上面类似, 针对 unit == 'days' 或 'weeks' 才设 hour 字段, 否则只设置 minute 和 second;
``` python
# def _schedule_next_run(self)
    if self.at_time is not None:
        assert self.unit in ('days', 'hours') or self.start_day is not None
        kwargs = {
            'minute': self.at_time.minute,
            'second': self.at_time.second,
            'microsecond': 0
        }
        if self.unit == 'days' or self.start_day is not None:
            kwargs['hour'] = self.at_time.hour
        self.next_run = self.next_run.replace(**kwargs)
```
#### **局部调整3: 在给定范围内随机安排调度时刻**
对应的就是上文提及的 latest 参数:
``` python
def to(self, latest):
    self.latest = latest
    return self
```
其对应的 _schedule_next_run() 逻辑如下:
``` python
# def _schedule_next_run(self)
    if self.latest is not None:
        assert self.latest >= self.interval
        interval = random.randint(self.interval, self.latest)
    else:
        interval = self.interval
```
具体逻辑就是在给定的 [interval, latest) 区间内, 生成一个随机数作为下次调度的 interval;
&nbsp;
至此, Job 类的逻辑就都分析完了;

## **apscheduler**


## **celery**


## **站内相关文章**
- [python module 使用总结: heapq]()

## **参考链接**
- [8.8. sched — Event scheduler](https://docs.python.org/2/library/sched.html)
- [python sched模块学习](http://blog.csdn.net/leonard_wang/article/details/54017537)
- [python中的轻量级定时任务调度库: schedule](https://www.cnblogs.com/anpengapple/p/8051923.html)

