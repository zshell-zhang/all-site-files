---
title: ThreadLocal 相关知识全梳理
date: 2018-08-03 17:30:03
categories:
 - jdk
tags:
 - jdk
 - 面试考点
---

> 两年前在老东家, 我于 InheritableThreadLocal 上踩过一次坑, 可惜当时坑不算深, 就没有把相关的知识点总结下来; 结果两年后的今天我在新东家又遇到了类似问题, 似曾相识却又记不太清楚具体的情况了; 所以这一次一定要认真总结一下 (本文代码基于 jdk 1.8);

<!--more-->

------

## **原生 ThreadLocal 的使用注意点**
### **线程关联的原理**
ThreadLocal 并不是一个独立的存在, 它与 Thread 类是存在耦合的, java.lang.Thread 类针对 ThreadLocal 提供了如下支持:
``` java
/* ThreadLocal values pertaining to this thread. This map is maintained
 * by the ThreadLocal class. */
ThreadLocal.ThreadLocalMap threadLocals = null;
```
每个线程都将自己维护一个 `ThreadLocal.ThreadLocalMap` 类在上下文中; 所以, ThreadLocal 的 set 方法其实是将 target value 放到当前线程的 ThreadLocalMap 中, 而 ThreadLocal 类自己仅仅作为该 target value 所对应的 key:
``` java
public void set(T value) {
    Thread t = Thread.currentThread();
    ThreadLocalMap map = getMap(t);
    if (map != null)
        map.set(this, value);
    else
        createMap(t, value);
}
```
``` java
ThreadLocalMap getMap(Thread t) {
    return t.threadLocals;
}
```
``` java
void createMap(Thread t, T firstValue) {
    t.threadLocals = new ThreadLocalMap(this, firstValue);
}
```
get 方法也是类似的道理, 从线程的 ThreadLocalMap 中获取以当前 ThreadLocal 为 key 对应的 value:
``` java
public T get() { 
    Thread t = Thread.currentThread();
    ThreadLocalMap map = getMap(t);
    if (map != null) { 
        ThreadLocalMap.Entry e = map.getEntry(this);
        if (e != null) { 
            @SuppressWarnings("unchecked")
            T result = (T)e.value;
            return result;
        } 
    } 
    return setInitialValue();
} 
```
需要注意的是, 如果没有 set 过 value, 此处 get() 将返回 null, 不过 initialValue() 方法是一个 protected 方法, 所以子类可以重写逻辑实现自定义的初始默认值;
``` java
private T setInitialValue() {
    T value = initialValue();
    Thread t = Thread.currentThread();
    ThreadLocalMap map = getMap(t);
    if (map != null)
        map.set(this, value);
    else
        createMap(t, value);
    return value;
}
```
``` java
protected T initialValue() {
    return null;
}
```
综上所述: ThreadLocal 实现线程关联的原理是与 Thread 类绑定, 将数据存储在对应 Thread 的上下文中;

### **使用中的注意点**
ThreadLocal 中主要有两个使用中需要注意的地方;
#### **(1) 谨防 ThreadLocal 导致的内存泄露和 OOM**
讨论这个问题之前, 需要先介绍一下 ThreadLocal.ThreadLocalMap 类中维护了的一个自定义数据结构 Entry, 其定义如下:
``` java
static class Entry extends WeakReference<ThreadLocal<?>> {
    /** The value associated with this ThreadLocal. */
    Object value;
    
    Entry(ThreadLocal<?> k, Object v) {
        super(k);
        value = v;
    }
}
```
这里要注意的是, Entry 类继承了弱引用 `WeakReference`, 更具体的说, Entry 中的 key (ThreadLocal 类型) 使用弱引用, value 依旧使用强引用;
> To help deal with very large and long-lived usages, the hash table entries use WeakReferences for `keys`. 

**这其实是一个令初学者感到困惑的设计**:
假设 Entry 不继承 WeakReference, 令 key 也使用强引用, 那么结合上一节的内容, 只要该 thread 不退出, 通过 Thread -> ThreadLocal.ThreadLocalMap -> key 这条引用链, 该 key 就可以一直与 gc root 保持连通; 这时即便在外部这个 key 对应的 threadLocal 已经没有有效引用链了, 但只要该 thread 不退出, jvm 依旧会判定该 threadlocal 不可回收;
于是尴尬的事情发生了: 由于 ThreadLocal.ThreadLocalMap 这个内部类没有对外暴露 public 方法, 在 Thread 类里面 ThreadLocal.ThreadLocalMap 也是 package accessible 的, 这意味着我们已经没有任何方法访问到该 key 对应的 value 了, 可它就是无法被回收, 这便是一个典型的内存泄露;
而如果使用 WeakReference 这个问题就解决了: 当该 key 对应的 threadlocal 在外部已经失效后, 便仅存在 thread 里的 weak reference 指向它, 下次 gc 时这个 key 就会被回收掉;
针对这一特性, ThreadLocal.ThreadLocalMap 也配套了与之相适应的内部清理方法:
``` java
private int expungeStaleEntry(int staleSlot) {
    Entry[] tab = table;
    int len = tab.length;
    // expunge entry at staleSlot
    tab[staleSlot].value = null; 
    tab[staleSlot] = null; 
    size--; 
    // Rehash until we encounter null
    Entry e; 
    int i;  
    for (i = nextIndex(staleSlot, len);
         (e = tab[i]) != null;
         i = nextIndex(i, len)) { 
        ThreadLocal<?> k = e.get();
        if (k == null) { 
            e.value = null; 
            tab[i] = null; 
            size--; 
        } else {
            int h = k.threadLocalHashCode & (len - 1);
            if (h != i) { 
                tab[i] = null; 
                // Unlike Knuth 6.4 Algorithm R, we must scan until null because multiple entries could have been stale.
                while (tab[h] != null)
                    h = nextIndex(h, len);
                tab[h] = e;
            }       
        }       
    }
    return i;
}
```
在该方法里, 除了清理指定下标 staleSlot 的 entry 外, 还会遍历整个 entry table, 当发现有 key 为 null 时, 就会触发 rehash 压缩整个 table, 以达到清理的作用; 
下面就要提到这里的一个隐藏的坑, ThreadLocal 并没有配合使用 ReferenceQueue 来监听已经回收的 key 以实现自动回调 expungeStaleEntry 方法清理空间的功能; 所以 threadlocal 实例是回收了, 但是引用本身还在, 其所对应的 value 也就还在:
> However, since reference queues are not used, stale entries are guaranteed to be removed only when the table starts running out of space.

实际上, expungeStaleEntry 方法是被安插到了 ThreadLocal.ThreadLocalMap 中的 get, set, remove 等方法中, 并被 ThreadLocal 的 get, set, remove 方法间接调用, 必须显式得调用这些方法, 才能主动式地清理空间;
在某些极端场景下, 如果某些 threadlocal 设置的 value 是大对象, 而所涉及的 thread 却没来得及在 threadlocal 被 gc 前作 remove, 再加上之后也没有什么其他 threadlocal 去作 get / set 操作, 那这些大对象是没机会被回收的, 这将造成严重的内存泄露甚至是 OOM; **所以使用 ThreadLocal 要谨记一点: 用完主动 remove, 主动释放内存, 而且是放在 finally 块里面 remove, 以确保执行;**
在很多系统中, 我们会定义一个 static final 的全局 ThreadLocal, 这样其实就不存在 threadlocal 被回收的情况了, 上面说的 WeakReference 机制也将效用有限, 这种环境下我们就更加需要用完后主动作 remove 了;

#### **(2) 谨防线程复用组件下的 value 串位**
在下一节中我还会继续讲到 value 串位的问题; 这一节所讲的串位与下一节相比, 有相似之处也有不同的问题场景; 与此同时, 这一节的串位与上一小节的内容也有一丝关联;
通常而言, 我们的代码总是跑在应用容器里, 如 tomcat, jetty, 或者是 dubbo 这样的服务框架内; 这些基础组件都有一个共性: 线程池化复用; 在这种场景下, 线程被线程池托管, 在整个应用的生命周期中, 这些 worker 线程往往是不会轻易退出的;
试想一种极端场景: 在一个处理线程内, 我们条件性得 (并非每次都会) 使用 ThreadLocal.set 方法设置一个 value, 然后在后续逻辑中又使用 ThreadLocal.get 方法获取该值; 一个处理线程在上一个任务执行结束之前未作 ThreadLocal.remove 清理 value, 刚巧这个线程在接手下一个任务时未满足条件, 没有调用 ThreadLocal.set 方法设置 value, 此时它所绑定的是上一个任务的 value, 在后面调用 ThreadLocal.get 时, 拿到的就是串位的数据了;
**这也再一次提醒我们: 使用 ThreadLocal, 在逻辑处理完后, 一定要作 remove**;


## **InheritableThreadLocal 的特点及其使用问题**
首先要说的是, 上文所讲的 ThreadLocal 的问题与注意点, 对 InheritableThreadLocal 都是成立的, 这里便不再赘述;
与 ThreadLocal 类似, InheritableThreadLocal 类也不是独立存在的, Thread 类针对 InheritableThreadLocal 作了如下支持:
``` java
/*
 * InheritableThreadLocal values pertaining to this thread. This map is
 * maintained by the InheritableThreadLocal class.
 */
ThreadLocal.ThreadLocalMap inheritableThreadLocals = null;
```
只是, InheritableThreadLocal 要额外实现子线程传递 threadlocal 的任务, 所以 Thread 类在构造方法中还提供了额外的支持以将父线程的 ThreadLocalMap 传递给子线程:
``` java
public Thread() {
    init(null, null, "Thread-" + nextThreadNum(), 0);
}
```
``` java
private void init(ThreadGroup g, Runnable target, String name, long stackSize) {
    init(g, target, name, stackSize, null, true);
}

/*
 * @param inheritThreadLocals if {@code true}, inherit initial values for inheritable thread-locals from the constructing thread
 */
private void init(ThreadGroup g, Runnable target, String name, long stackSize, AccessControlContext acc,
                  boolean inheritThreadLocals) {
    ......
    if (inheritThreadLocals && parent.inheritableThreadLocals != null)
        this.inheritableThreadLocals = ThreadLocal.createInheritedMap(parent.inheritableThreadLocals);
}
```
下面要说的是 InheritableThreadLocal 在线程复用组件下的串位问题;
上一小节所讲的 ThreadLocal 的 value 串位问题, 对于 InheritableThreadLocal 来说也是存在的, 这点自不必说; 然对于 InheritableThreadLocal 所提供的额外功能 父子线程传递 value 来说, 还有一种线程复用场景, 会遇到类似的坑;
在 jdk 1.5 之前我们没有线程池的时候, 子线程的创建都是手工及时完成的, 那种场景下父子线程的关系是唯一绑定的, 绝对不会出现 value 串位的问题; 然而 Doug Lea 大神开发了 ThreadPoolExecutor, 这彻底改变了我们使用多线程的习惯, 它不仅仅在各种容器中出现, 我们的日常代码中凡涉及多线程的地方, 大多也会采用线程池的方式实现;
那么问题来了: 在线程池中, worker 线程是被复用的, worker 线程的父线程是谁并没有人关心, 反正 worker 线程的父线程大多数都比 worker 线程本身要短命许多; 而线程的初始化只发生在其创建的时候, 根据上面的内容, InheritableThreadLocal 传递 value 只发生在子线程初始化的时候, 也就是线程刚创建的时候; 所以, 往线程池中提交任务的时候, 除非是线程池刚好创建了一个新线程, 才能顺利得将 value 传递下去, 否则大多数时候都只是复用已经存在的线程, 那线程中的 value 早已不是当前线程想要传递的值;

### **改进 InheritableThreadLocal 的方案**
InheritableThreadLocal value 串位问题的根本原因在于它依赖 Thread 类本身的机制传递 value, 而 Thread 类由于其于线程池内 "复用存在" 的形式而导致 InheritableThreadLocal 的机制失效; 所以针对 InheritableThreadLocal 的改进, 突破点就在于如何摆脱对 Thread 类的依赖;
现在业界内比较好的解决思路是将对 Thread 类的依赖转移为对 Runnable / Callable 的依赖, 因为提交任务时 Runnable / Callable 是实时构造出来的, 父线程可以在其构造之时将 value 植入其中;

下面以阿里为例, 介绍一种典型的实现; 阿里巴巴开源了其对 InheritableThreadLocal 的改进方案: [alibaba/transmittable-thread-local](https://github.com/alibaba/transmittable-thread-local);
纵观其源码, TransmittableThreadLocal 的核心设计之一在于其自己维护了一个静态全局的 holder, 存储了所有的 TransmittableThreadLocal 实例:
``` java
static ThreadLocal<Map<TransmittableThreadLocal<?>, ?>> holder = new ThreadLocal<Map<TransmittableThreadLocal<?>, ?>>() {
    @Override
    protected Map<TransmittableThreadLocal<?>, ?> initialValue() {
        return new WeakHashMap<TransmittableThreadLocal<?>, Object>();
    }
};
```
这里的一个设计细节是, 其使用 WeakHashMap 作为存储 TransmittableThreadLocal 实例的容器; 这里与上文所讲的 ThreadLocal.ThreadLocalMap.Entry 使用 WeakReference 作为 key 的原理是类似的, 可以便捷得发现已经无效的 threadlocal, 而且 WeakHashMap 使用了 ReferenceQueue 去监听 key 的 gc 情况, 不用像 ThreadLocal 那样每次需要遍历全表以寻找 stale entries;
同时, TransmittableThreadLocal 提供一个 copy() 方法实时复制所有 TransmittableThreadLocal 实例及其在当前线程的 value:
``` java
static Map<TransmittableThreadLocal<?>, Object> copy() {
    Map<TransmittableThreadLocal<?>, Object> copy = new HashMap<TransmittableThreadLocal<?>, Object>();
    for (TransmittableThreadLocal<?> threadLocal : holder.get().keySet()) {
        copy.put(threadLocal, threadLocal.copyValue());
    }
    return copy;
}
```
TransmittableThreadLocal 的另一个核心设计是它封装了自己的 Runnable 和 Callable; 以其封装的 TtlRunnable 为例, 其提供了一个 private 类型的构造器:
``` java
private TtlRunnable(Runnable runnable, boolean releaseTtlValueReferenceAfterRun) {
    this.copiedRef = new AtomicReference<Map<TransmittableThreadLocal<?>, Object>>(TransmittableThreadLocal.copy());
    this.runnable = runnable;
    this.releaseTtlValueReferenceAfterRun = releaseTtlValueReferenceAfterRun;
}
```
可以发现, 在 TtlRunnable 构造之初, 除了包装原始的 Runnable 之外, 其复制了当前线程下所有的 TransmittableThreadLocal 实例及其对应的 value, 放到了一个 AtomicReference 包装的 map 之中, 这样就完成了由父线程向 Runnable 的 value 传递;
下面是最关键的 run() 方法的处理:
``` java
public void run() {
    Map<TransmittableThreadLocal<?>, Object> copied = copiedRef.get();
    // 非核心逻辑已省略
    ......
    Map<TransmittableThreadLocal<?>, Object> backup = TransmittableThreadLocal.backupAndSetToCopied(copied);
    try {
        runnable.run();
    } finally {
        TransmittableThreadLocal.restoreBackup(backup);
    }   
}
```
拿到父线程所有的 threadlocal -> value 键值对后, 需要将其一一设置到自己的 ThreadLocal 中:
``` java
static Map<TransmittableThreadLocal<?>, Object> backupAndSetToCopied(Map<TransmittableThreadLocal<?>, Object> copied) {
    Map<TransmittableThreadLocal<?>, Object> backup = new HashMap<TransmittableThreadLocal<?>, Object>();
    for (Iterator<? extends Map.Entry<TransmittableThreadLocal<?>, ?>> iterator = holder.get().entrySet().iterator();
         iterator.hasNext(); ) { 
        Map.Entry<TransmittableThreadLocal<?>, ?> next = iterator.next();
        TransmittableThreadLocal<?> threadLocal = next.getKey();
        backup.put(threadLocal, threadLocal.get());
        if (!copied.containsKey(threadLocal)) {
            iterator.remove();
            threadLocal.superRemove();
        }   
    }   
    // 将 runnable 携带的父线程 threadlocal -> value 键值对, 真正用 ThreadLocal.set 将 value 设置到子线程中去
    for (Map.Entry<TransmittableThreadLocal<?>, Object> entry : copied.entrySet()) {
        @SuppressWarnings("unchecked")
        TransmittableThreadLocal<Object> threadLocal = (TransmittableThreadLocal<Object>) entry.getKey();
        threadLocal.set(entry.getValue());
    }   
    doExecuteCallback(true);
    return backup;
}
```
接下来在调用原始 Runnable 的 run() 方法时, 便能够顺利 get 到父线程的 value 了;

## **参考链接**
- [ThreadLocal WeakReference和内存泄漏的思考](https://majiaji.coding.me/2017/03/27/threadLocal-WeakReference和内存泄漏的思考)
- [话说ReferenceQueue](https://hongjiang.info/java-referencequeue/)

