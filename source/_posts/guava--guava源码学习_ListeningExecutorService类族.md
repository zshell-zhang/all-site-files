---
title: 'guava 源码学习: ListeningExecutorService 类族'
date: 2016-04-22 00:00:57
categories:
 - guava
tags:
 - guava
 - juc
 - 线程池
---

> 带有 listenable 回调功能的 guava 线程池是 `com.google.common.util.concurrent` 包里十分重要的概念, 它们实现了任务执行完异步回调指定逻辑的功能, 在很大程度上解决了 java 原生组件 Future / FutureTask 阻塞获取结果的尴尬, 在生产实践中有着广泛的应用;

<!--more-->

------

## **类族相关成员列举**
guava 中与 ListeningExecutorService 相关的类都集中在 util.concurrent 包中, 主要分为三类:
(1) 包装返回 ListenableFutureTask 的 ExecutorService:
``` java
ListeningExecutorService extends ExecutorService;
AbstractListeningExecutorService extends AbstractExecutorService implements ListeningExecutorService;
MoreExecutors.ListeningDecorator extends AbstractListeningExecutorService;
```
(2) 与 ListenableFutureTask 相关的类, 实现异步回调的关键逻辑:
``` java
ListenableFuture extends Future;
ListenableFutureTask extends FutureTask implements ListenableFuture;
ExecutionList;
```
(3) 便捷工具类, 主要是方便开发者以友好的方式使用 ListeningExecutorService 和 ListenableFutureTask:
``` java
MoreExecutors;
Futures;
FutureCallback;
```

## **ListenableFutureTask 的异步回调原理**
### **java 原生组件的关键支持**
guava ListenableFuture 得以实现任务完成后异步回调指定逻辑的关键就在于 java.util.concurrent.FutureTask 留白了一个空方法:
``` java
/**
 * Protected method invoked when this task transitions to state
 * {@code isDone} (whether normally or via cancellation). The 
 * default implementation does nothing.  Subclasses may override
 * this method to invoke completion callbacks or perform
 * bookkeeping. Note that you can query status inside the 
 * implementation of this method to determine whether this task
 * has been cancelled.
 */  
protected void done() { }
```
可以发现, 注释中说明了该方法将留给子类去重写以实现 "invoke completion callbacks";

下面来看下这个空方法是如何被回调的:
(1) FutureTask 的 run 方法, 当任务跑完后会根据结果调用 set / setException 方法更新 state 状态;
``` java
public void run() {
    ...
    try {
        Callable<V> c = callable;
        if (c != null && state == NEW) {
            V result;
            boolean ran;
            try {
                result = c.call();
                ran = true;
            } catch (Throwable ex) {
                result = null;
                ran = false;
                setException(ex); // 任务失败更新 state 为 EXCEPTIONAL
            }   
            if (ran)
                set(result); // 任务成功更新 state 为 COMPLETING
        }
    } finally {...}
}
```
(2) 以 set 方法为例, 更新完状态后会调用 finishCompletion() 方法;
``` java
protected void set(V v) {
    if (UNSAFE.compareAndSwapInt(this, stateOffset, NEW, COMPLETING)) {
        outcome = v;
        UNSAFE.putOrderedInt(this, stateOffset, NORMAL);
        finishCompletion(); // 状态更新完, 回调 finish 逻辑
    }   
}
```
另外除了 set 与 setException 方法之外, 还有 cancel(boolean mayInterruptIfRunning) 方法也回调了 finishCompletion() 方法;
(3) 在 finishCompletion() 方法中, 回调了留白的 done() 方法;
``` java
private void finishCompletion() {
    // assert state > COMPLETING;
    for (WaitNode q; (q = waiters) != null;) {
        if (UNSAFE.compareAndSwapObject(this, waitersOffset, q, null)) {
            for (;;) {
                Thread t = q.thread;
                if (t != null) {
                    q.thread = null;
                    LockSupport.unpark(t);
                }   
                WaitNode next = q.next;
                if (next == null)
                    break;
                q.next = null;
                q = next;
            }   
            break;
        }   
    }
    done(); // 此处的回调留待实现
    callable = null;
}
```
ListenableFutureTask 正是继承了 FutureTask 并重写了 done() 方法, 实现了异步回调指定逻辑的功能;

### **ListenableFutureTask 的具体实现**
在 ListenableFutureTask 中对 done() 方法的实现是这样的:
``` java
/**
 * Internal implementation detail used to invoke the listeners.
 */
@Override
protected void done() {
    executionList.execute();
}
```
其中, 类成员 executionList 的 execute() 方法逻辑如下:
``` java
public void execute() { 
    RunnableExecutorPair list;
    // 因为涉及到链表反转, 所以需要同步工具保证线程安全
    synchronized (this) { 
        if (executed) { 
            return;
        } 
        executed = true;
        list = runnables;
        runnables = null;
    } 
    RunnableExecutorPair reversedList = null;
    // 反转链表, 调整执行次序
    while (list != null) { 
        RunnableExecutorPair tmp = list;
        list = list.next;
        tmp.next = reversedList;
        reversedList = tmp;
    }
    // 挨个执行链表上的每个回调任务
    while (reversedList != null) { 
        executeListener(reversedList.runnable, reversedList.executor);
        reversedList = reversedList.next;
    } 
}
```
``` java
/*
 * 内部类, 表示一个链表的节点
 */
private static final class RunnableExecutorPair {
    final Runnable runnable;
    final Executor executor;
    @Nullable RunnableExecutorPair next;

    RunnableExecutorPair(Runnable runnable, Executor executor, RunnableExecutorPair next) {
        this.runnable = runnable;
        this.executor = executor;
        this.next = next;
    }
}
```
其中, RunnableExecutorPair 是个链表节点, 存储了待执行的回调任务及执行任务的 executor; ExecutionList.execute 方法的内容就是将链表中的每个任务按照 **原始入队的顺序** 遍历执行;
所谓入队, 其实就是指我们得到一个 ListenableFuture 实例后为其添加的回调逻辑, 通常我们会调用 addListener(Runnable listener, Executor executor) 方法以实现异步回调;
而这里所说的 "原始入队的顺序", 便是指 ListenableFuture 调用 addListener 方法添加回调任务的顺序;
ListenableFutureTask 实现的 addListener 方法是调用 executionList.add 方法:
``` java
/* ExecutionList */
/* public void add(Runnable runnable, Executor executor) */
synchronized (this) {
    if (!executed) {
        runnables = new RunnableExecutorPair(runnable, executor, runnables);
        return;
    }
}
```
可以发现, add 方法是将新的 RunnableExecutorPair 插在了链表头上, 使得遍历链表的顺序与插入顺序相反, 所以 execute 方法中需要先反转链表才能执行;
&nbsp;
以上内容便是 ListenableFutureTask 实现异步回调的基本原理;

## **guava 顺手实现的一些便捷工具类**
虽然上文已描述了 ListenableFutureTask 异步回调的原理, 但这离我们的实际使用仍然相距甚远, 我们并不会主动构造 ListenableFutureTask, 也很少直接调用一个 ListenableFuture 实例的 addListener 方法, 这些都太不方便了;
guava 基于 ListenableFuture 又编写了一系列的工具类, 这些工具类简化了我们使用 ListenableFuture 的方式, 在生产环境中被普遍使用;

### **MoreExecutors**
首先是入口 MoreExecutors, 我们通常使用 listeningDecorator 方法构造一个能够生产 ListenableFutureTask 的 ListeningExecutorService 实例:
``` java
public static ListeningExecutorService listeningDecorator(ExecutorService delegate) {
    return (delegate instanceof ListeningExecutorService)
        ? (ListeningExecutorService) delegate
        : (delegate instanceof ScheduledExecutorService)
        ? new ScheduledListeningDecorator((ScheduledExecutorService) delegate)
        : new ListeningDecorator(delegate);
}
```
重点看最后一行, 这是我们代码里经常走到的一行逻辑: ListeningDecorator 使用了一个装饰器, 修饰了 ExecutorService 中一些重要的方法:
``` java
private static class ListeningDecorator extends AbstractListeningExecutorService;
```
ListeningDecorator 本身没有什么特殊的地方, 关键看它的父类 AbstractListeningExecutorService:
``` java
@Override 
protected final <T> ListenableFutureTask<T> newTaskFor(Runnable runnable, T value) {
    return ListenableFutureTask.create(runnable, value);
}
@Override
public <T> ListenableFuture<T> submit(Runnable task, @Nullable T result) {
    return (ListenableFuture<T>) super.submit(task, result);
}
```
``` java
/* ListenableFutureTask */
public static <V> ListenableFutureTask<V> create(Runnable runnable, @Nullable V result) {
    return new ListenableFutureTask<V>(runnable, result);
}
```
所以说, 这里就是生产 ListenableFutureTask 的地方了, MoreExecutors.listeningDecorator 返回的实例将被这些方法包装, 以能够构造出合适的 ListenableFutureTask 实例;

### **Futures**
能够以友好方式构造 ListenableFutureTask 其实是不够的, 如果我们要主动调用其 addListener 方法, 就得自己处理回调任务中的各种异常, 类似下面这种模式:
``` java
listenableFuture.addListener(() -> {
    try {
        xxx = listenableFuture.get();
        ...
    } catch (ExecutionException e) {
        ...
    } catch (RuntimeException e) {
        ...
    }
}, Executors.newSingleThreadExecutor());
```
很明显, 不是非常友好, 这种固化的逻辑完全是可以抽出来的, 于是 guava 提供了 Futures 类, 其中有一个方法 addCallback:
``` java
public static <V> void addCallback(ListenableFuture<V> future, FutureCallback<? super V> callback) { 
    addCallback(future, callback, MoreExecutors.sameThreadExecutor());
}
```
``` java
public static <V> void addCallback(final ListenableFuture<V> future,
                                   final FutureCallback<? super V> callback, Executor executor) { 
    Preconditions.checkNotNull(callback);
    Runnable callbackListener = () -> { 
        final V value;
        try {
            value = getUninterruptibly(future);
        } catch (ExecutionException e) { 
            callback.onFailure(e.getCause());
            return;
        } catch (RuntimeException e) { 
            callback.onFailure(e);
            return;
        } catch (Error e) { 
            callback.onFailure(e);
            return;
        } 
        callback.onSuccess(value);
    };
    future.addListener(callbackListener, executor);
}
```
这段代码有两点:
(1) 使用 MoreExecutors.sameThreadExecutor() 构造执行回调的 executor;
MoreExecutors.sameThreadExecutor() 返回了一个自定义的 SameThreadExecutorService 实例, 这个类的特点是单线程, 回调任务都放在 executor.execute 所在线程里处理; 这样做十分得轻量化, 而如果使用 jdk 的 ThreadPoolExecutor, 很多时候都是为一个方法的执行付出创建一个线程池的开销;
(2) 抽象出一个 FutureCallback 留给使用者实现回调的特定逻辑, 其余的 future.get(), 异常处理等都封装到 addCallback 方法里了, 对于 addCallback 方法里遇到异常或是执行成功, 都只是回调 FutureCallback 的接口而已:
``` java
public interface FutureCallback<V> {
  void onSuccess(@Nullable V result);
  void onFailure(Throwable t);
}
```
如此一来, 我们为 ListenableFutureTask 添加回调的方法就简洁多了:
``` java
Futures.addCallback(listenableFuture, new FutureCallback<String>() {
    @Override
    public void onSuccess(String result) {
        ...
    }
    @Override
    public void onFailure(Throwable t) {
        ...
    }
});
```

