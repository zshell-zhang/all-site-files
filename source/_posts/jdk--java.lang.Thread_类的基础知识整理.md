---
title: java.lang.Thread 类基础知识整理
date: 2020-08-09 18:19:09
categories: [jdk]
tags: [jdk,  面试考点]
---

> java 多线程操作是我们日常频繁使用的技术之一, 然而我们在熟练使用多线程开发的同时, 也要注意基础的夯实, 关于 java 线程在虚拟机层面及操作系统层面的技术支持, 也应当有一个清楚的了解;

<!--more-->

------

## **Thread 的状态定义及转移**
在 java.lang.Thread 类中定义了 6 种状态:
``` JAVA
public enum State {
    // 线程创建
    NEW,
    // 等待获取内置锁
    BLOCKED,
    // 无限期等待另一个线程执行特定动作唤醒自己
    WAITING,
    // 有时间期限地等待另一个线程执行特定动作唤醒自己
    TIMED_WAITING,
     // 包括正在运行的, 就绪状态等待被调度的, 
     // 以及除了 BLOCKED, WAITING, TIMED_WAITING 之外的其他阻塞状态
    RUNNABLE,
    // 线程结束
    TERMINATED;
}
```
从上面 Thread.State 枚举的注释中可以看出来, java 站在虚拟机的层面针对 java.lang.Thread 的状态设计了一套独立的体系, 其与 os 层面的线程状态没有直接的关联; 准确的说, java.lang.Thread 的状态只与 "java 语言层面的行为" 有关, 而与操作系统的调度, I/O, 事件, 中断等没有直接关系; 那么, 什么是 java 语言层面的行为? 对于不同的行为, 状态如何转移? 下面我就给出一个 Thread 状态转移大图:
![java.lang.Thread 状态转移](https://raw.githubusercontent.com/zshell-zhang/static-content/master/cs/jdk/java.lang.Thread类的基础知识整理/java.lang.Thread状态转移.png)

在上图中, 各个圆圈代表了线程的状态, 圆圈之间的箭头是状态转移的方向, 箭头上标注的是状态转移的条件, 其中每一行条件都是独立的, 箭头上有几行就代表该状态转移存在几种可能的情况;

### **RUNNABLE $\longleftrightarrow$ BLOCKED**
当要进入 `synchronized` 代码块或被 `synchronized` 关键字修饰的方法时, 如果目标对象的监视器已被其他线程持有, 则线程状态转为 BLOCKED, 并被挂到监视器的 _EntryList 队列中排队; BLOCKED 状态是无等待期限的, 在正在持有监视器的线程及 _EntryList 队列中排在自己前面的线程让出监视器之前, 该线程将一直处于睡眠状态, 且 BLOCKED 状态的线程不可中断;

### **RUNNABLE $\longleftrightarrow$ WAITING / TIMED_WAITING**
WAITING 与 TIMED\_WAITING 状态, 相同点在于, 它们都处于睡眠状态, 等待另一个线程执行**特定动作**以唤醒自己, 在等待过程中如果被其他线程中断则会抛出 `InterruptException` 异常; 不同点在于, WAITING 是无限期等待, 而 TIMED\_WAITING 是有时间期限地等待, 如果超时则放弃等待, 线程被唤醒并**继续执行** (混淆点注意: 这里的超时并不会抛出 `TimeoutException` 异常); 由这个不同点我们可以观察出从 RUNNING 转移到 WAITING / TIMED_WAITING 的条件差异:
(1) 转移到 WAITING 的条件是不带 timeout 参数的方法:
``` java
java.lang.Object#wait();
java.lang.Thread#join();
java.lang.LockSupport#park();
```
(2) 转移到 TIMED_WAITING 的条件是带 timeout 参数的方法:
``` java
java.lang.Thread#sleep(long);
java.lang.Thread#sleep(long, int);
java.lang.Object#wait(long);
java.lang.Object#wait(long, int);
java.lang.Thread#join(long);
java.lang.Thread#join(long, int);
java.util.concurrent.locks.LockSupport#parkNanos(Object, long);
java.util.concurrent.locks.LockSupport#parkUntil(Object, long);
```
对于以上不同的方法, 其所等待其他线程执行的 "特定动作" 分别如下:

* Object#wait 相关方法: 需要 Object#notify 或 Object#notifyAll 方法唤醒挂起线程;
* Thread#join 相关方法: 需要被 join 的线程结束方可唤醒挂起线程;
* LockSupport#park 相关方法: 需要 LockSupport#unpark 方法唤醒挂起线程;

有两个注意点需要额外补充一下:

1. Thread#sleep 属于特殊的 TIMED_WAITING 状态, 它并不会等待另一个线程执行特定动作, 而是只会在等待设定的时间后被唤醒, 或者在等待中被中断;
2. Object#wait 方法必须先持有调用对象的监视器 (即在 `synchronized(targetObject){}` 代码块内或被 `synchronized` 关键字修饰的目标对象方法内) 后才能调用, 否则会抛出如下异常:
``` java
java.lang.IllegalMonitorStateException: current thread not owner
```

### **WAITING / TIMED_WAITING $\longrightarrow$ BLOCKED**
上一节讲到了调用了 Object#wait 而进入 WAITING / TIMED_WAITING 状态的线程可由 Object#notify 或 Object#notifyAll 唤醒, 但唤醒后接下来会转移到什么状态还是要看具体的锁竞争情况:

1. 如果锁竞争不激烈, 唤醒的线程尝试获取目标对象的监视器成功了, 则状态转移到 RUNNABLE;
2. 如果锁竞争激烈, 唤醒的线程未获取到监视器, 那么该线程将转移到 BLOCKED 状态, 继续排队等待;

## **Thread.state 与 os 线程状态的对应关系**
上一小节已经提及, Thread.state 是独立于 os 线程状态而设计的, 不过这并不代表 java 线程与 os 线程完全没有关系; 我们知道, 当我们调用 Thread#start 方法启动一个线程时, jvm 底层会调用 pthread_create 方法在内核创建唯一一个与之对应的 os 线程; 事实上, 当 Thread 的状态发生变化时, 一般会引起对应 os 线程的状态变化, 而 os 线程的状态变化, 却未必会引起对应的 Thread 状态变化, 下面我给出一个关系对应大图:
![Thread 状态与 os 线程状态的对应关系](https://raw.githubusercontent.com/zshell-zhang/static-content/master/cs/jdk/java.lang.Thread类的基础知识整理/Thread状态与os线程状态的对应关系.png)

图中分为两大部分, 上方为 jvm 层面 (和上一小节中的 Thread 状态转移图是一样的), 下方为 os 层面, 上下两部分之间的双向箭头表示了 Thread 状态与 os 线程状态的对应关系;

### **java.lang.Thread RUNNABLE 状态与 os 线程状态的对应关系**
由上图可以看到, java Thread 的 RUNNABLE 状态对应了 os 的如下状态:

1. 全部的 Ready 就绪状态;
2. 全部的 Running 运行状态;
3. 全部的 Uninterruptible Sleep (Disk Sleep) 不可中断睡眠状态;
4. **部分**的 Interruptible Sleep 可中断睡眠状态;

Ready 与 Running 自不必说, 关键是后面两个状态, 也就是图中的两个绿色箭头, 容易引起混淆: 明明是 sleep 睡眠状态, 为什么 java Thread 会处于 RUNNABLE 状态? 其实可以参考上一小节, Thread 转移到 WAITING, TIMED_WAITING, BLOCKED 状态的条件皆是与线程协作, 线程竞争相关的操作, 而诸如磁盘 I/O 所引起 os 线程进入不可中断睡眠或与之类似的网络 I/O 所引起 os 线程进入可中断睡眠等动作, 皆与之完全没有关系, 如果不将其归类到 RUNNABLE 中, 我们会发现并没有其它合适的状态可以分给它们;
事实上, jvm 作为运行在操作系统之上的高层面的进程, 对于一个 java.lang.Thread 来说, 与之对应的底层操作系统线程, 无论是在运行中, 还是磁盘 I/O, 网络 I/O, 本质上都是在给它提供必要的服务, 那么将其当做 RUNNABLE 也就是合理的了;
另外还要注意到 Interruptible Sleep 可中断睡眠状态只有部分情况对应到 Thread 的 RUNNABLE 中, 在下一小节中将看到它对应到其它 java.lang.Thread 状态的情况;

### **os 线程 Interruptible Sleep 状态与 java.lang.Thread 状态的对应关系**
除了刚才所说的 RUNNABLE, 会部分对应到 os 的 Interruptible Sleep 状态之外, WAITING, TIMED_WAITING, BLOCKED 这三种 Thread 状态都与可中断睡眠对应; 这里的可中断要与 java 语言层面的中断区分开, 这也是容易引起混淆的点: 上文提及 WAITING 和 TIMED_WAITING 在 java 语言层面是可中断的, BLOCKED 在 java 语言层面是不可中断的, 而在操作系统层面上, 这三种状态对应的 os 线程都是可中断的;

### **站内相关文章**
- [jstack 命令使用经验总结](http://zshell.cc/2017/09/24/jvm-tools--jstack命令使用经验总结)

## **参考链接**
- [Java线程中wait状态和block状态的区别](https://www.zhihu.com/question/27654579)
- [Java线程状态与内核线程状态的对应关系](https://blog.csdn.net/qq_45859054/article/details/106749963)
- [Java线程状态与内核线程状态的对应关系(续)](https://blog.csdn.net/qq_45859054/article/details/106960247)
- [太逗了，面试官让我讲线程 WAITING 状态](https://mp.weixin.qq.com/s/MFbYWE7ItAYtAI8tVtVh_A)
- [面试官问：为什么 Java 线程没有 Running 状态](https://mp.weixin.qq.com/s/-JU5tDUaR7ZEALbCVW3jKA)

