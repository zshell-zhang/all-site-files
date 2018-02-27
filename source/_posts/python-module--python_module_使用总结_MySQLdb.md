---
title: 'python module 使用总结: MySQLdb'
date: 2017-08-01 23:06:08
categories:
 - python
 - module
tags:
 - python:module
---

> `MySQLdb` 模块是 python 与 mysql 交互的较为底层的接口, 不过它依然是在更为底层的 `_mysql` 模块之上又作了一层包装;
`_mysql` 才是真正的直接面向 mysql 原生 C 接口的简单适配层, 而 `MySQLdb` 则在 `_mysql` 之上作了更多的关于类型转换等抽象包装;
考虑到 `MySQLdb` 模块与一些 python ORM 框架的关系, `MySQLdb` 与 python 的关系可以类比为 jdbc 之于 java;
如果是复杂的系统, 我们肯定会选择 ORM 框架, 不过对于一些简单的小工具, 定时小任务等, 本身没什么复杂的数据库操作, 那就用 MySQLdb 最方便了;
本文基于 `MySQL-python 1.2.5` 对 MySQLdb 作一些使用上的总结;

<!--more-->

------

### **MySQLdb 的基本操作**
``` python
import MySQLdb
# 获得 mysql 的一个连接
conn = MySQLdb.connect(host='10.64.0.11', user='xxx', passwd='yyy', db="zzz", port=3306, charset="utf8")
try:
    # cursor 游标, 是 MySQLdb 中与 mysql 增删改查数据交互的对象
    cur = conn.cursor()
    # 数据库操作
    cur.execute("...sql...")
    ...
    # 提交事务
    conn.commit()
except Exception, e:
    # 回滚
    conn.rollback()
finally:
    # 关闭连接, 释放资源
    conn.close()
```
以上是一个 MySQLdb 使用的完整流程, 下面是具体的使用细节与注意点总结;

### **MySQLdb cursor.execute / cursor.executemany 方法**
#### **cursor.execute 方法**
MySQLdb 执行数据操纵的关键点就在于 cursor.execute 方法, 所有包括增删改查在内皆是以此方法执行的, 以下是该方法的代码:
``` python
def execute(self, query, args=None):
    del self.messages[:]
    db = self._get_db()
    if isinstance(query, unicode):
        query = query.encode(db.unicode_literal.charset)
    if args is not None:
        # 针对 args 为 dict 的特殊情况处理
        if isinstance(args, dict):
            query = query % dict((key, db.literal(item)) for key, item in args.iteritems())
        # 其余的情况: args 为 tuple 或单个 value
        else:
            query = query % tuple([db.literal(item) for item in args])
    try:
        r = None
        r = self._query(query)
    except TypeError, m:
        if m.args[0] in ("not enough arguments for format string", "not all arguments converted"):
            self.messages.append((ProgrammingError, m.args[0]))
            self.errorhandler(self, ProgrammingError, m.args[0])
        else:
            self.messages.append((TypeError, m)) 
            self.errorhandler(self, TypeError, m)
    except (SystemExit, KeyboardInterrupt):
        raise
    except:
        exc, value, tb = sys.exc_info()
        del tb
        self.messages.append((exc, value))
        self.errorhandler(self, exc, value)
    self._executed = query
    if not self._defer_warnings: self._warning_check()
    return r
```
该方法接收一个名为 `query` 的 sql 字符串, 另外还可选附带参数 `args`, 所以该方法存在两种主要的用法:
1.预先格式化好 sql 字符串, 然后不带参数直接 execute:
``` python
sql = "select * from xxx where update_time = %s" % datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
cursor.execute(sql)
```
这种是保守的方法, 参数处理完全由 python 原生的格式化字符串完成, cursor.execute 方法只管执行 sql 就好;
这种方法的优点是省事, 坑少;
&nbsp;
2.将参数传给 execute 方法的 `args`, 这种使用方法有几个坑, 需要注意一下;
该方法有一段注释, 我单独提了出来, 注释中对 args 参数有如下描述:
``` python
"""
    args -- optional sequence or mapping, parameters to use with query.

    Note: If args is a sequence, then %s must be used as the
    parameter placeholder in the query. If a mapping is used,
    %(key)s must be used as the placeholder.
"""
```
(1) 注释中提到的坑, 就是说无论传的参数是一个 list/tuple, 还是 dict, 参数占位符类型都必须是字符串(%s | %(key)s ):
``` python
# 不能是 id = %d, 只能是 id = %s
sql = 'select * from xxx where id  = %s'
```
因为 execute 方法里处理参数时, 会对参数作 `db.literal(item)` 处理, 将参数首先转为字符串, 这时占位符如果是 %d 等其他类型, 就报错了;

&nbsp;
(2) 注释中另一个隐型的坑, 是这个 `args` 必须是 list / tuple / dict 中的一个, 哪怕只有一个占位数据, 也必须写成 list 或 tuple 类型:
``` python
cursor.execute(sql, (2,))
cursor.execute(sql, [2])
```
如果希望以 tuple 形式表示唯一一个参数, 必须注意加上 逗号, 因为不加逗号就算外面包了括号也会识别为其本身的类型:
``` python
>>> print type((1))
<type 'int'>
>>> print type(('1'))
<type 'str'>
>>> print type((1,))
<type 'tuple'>
>>> print type(('1',))
<type 'tuple'>
```
其实这个坑是在 MySQL-python 1.2.5 版本中出现的问题; 在 1.2.3 版本中, execute 方法的逻辑是这么写的:
``` python
if args is not None:
    query = query % db.literal(args)
```
只要 args 非空, 就一律把它 to string; 而至于参数怎么转, 转成什么样, 就看参数自己了;
这么做确实灵活了, 但是也可能带来一些不确定性, 1.2.5 的版本将参数限定为 list / tuple / dict, 然后对集合内的每个元素再针对性 to string, 一定程度上控制了参数的规范性;
&nbsp;
#### **cursor.executemany 方法**
executemany 方法是 execute 方法的批量化, 这个方法的有效使用范围其实很狭窄, 仅针对 insert 操作有性能提升, 其余操作在性能上均与 execute 无异;
下面是该方法的代码:
``` python
        del self.messages[:]
        db = self._get_db()
        if not args: return
        if isinstance(query, unicode):
            query = query.encode(db.unicode_literal.charset)
        # 正则匹配 insert 操作
        m = insert_values.search(query)
        # 不是 insert 操作, 那就 for 循环挨个执行而已
        if not m:
            r = 0
            for a in args:
                r = r + self.execute(query, a)
            return r
        p = m.start(1)
        e = m.end(1)
        qv = m.group(1)
        # 下面是针对 insert 的处理
        try:
            q = []
            for a in args:
                if isinstance(a, dict):
                    q.append(qv % dict((key, db.literal(item))
                                       for key, item in a.iteritems()))
                else:
                    q.append(qv % tuple([db.literal(item) for item in a]))
        except TypeError, msg:
            if msg.args[0] in ("not enough arguments for format string",
                               "not all arguments converted"):
                self.errorhandler(self, ProgrammingError, msg.args[0])
            else:
                self.errorhandler(self, TypeError, msg)
        except (SystemExit, KeyboardInterrupt):
            raise
        except:
            exc, value, tb = sys.exc_info()
            del tb
            self.errorhandler(self, exc, value)
        # 批量化执行, 提高处理性能
        r = self._query('\n'.join([query[:p], ',\n'.join(q), query[e:]]))
        if not self._defer_warnings: self._warning_check()
        return r
```
从代码里可以看到, 方法先对传入的 sql 语句作一次匹配, 判断其是否是 insert 操作, 其中 insert_values 是一个 regex, 专门匹配 insert 语句:
``` python
restr = r"\svalues\s*(\([^()']*(?:(?:(?:\(.*\))|'[^\\']*(?:\\.[^\\']*)*')[^()']*)*\))"
insert_values = re.compile(restr, re.S | re.I | re.X)
```
针对 insert 语句, 其最后的执行是批量的, 以提高执行效率:
``` python
r = self._query('\n'.join([query[:p], ',\n'.join(q), query[e:]]))
```
但是而其他的语句, 却只能在一个 for 循环里, 挨个执行 execute 方法, 这就没什么优势了;
不过这个方法还有一个大坑: 对于 update 和 delete 操作, 使用 executemany 至少不会比 execute 差, 但是对于 query, 它批量执行完一堆 query 操作后去 fetch 结果集, 只能拿到最后执行的 query 的结果, 前面的都被覆盖了; 所以, query 操作不能使用 executemany 方法;
&nbsp;
在使用方面, executemany 的坑和 execute 是差不多的, 下面是一个例子:
``` python
# executemany 传入的 args 可以是 list 也可以是 tuple
cur.executemany('select * from xxx where yyy = %s', [(1,), (2,)])
```

### **MySQLdb 的 query 结果集操作**
MySQLdb 的 query 操作, 主要有以下三种结果集的获取方法:
``` python
cursor.execute("...sql...")

# 获得所有的 tuple 结果集的一个 list
@return list[tuple(elem1, elem2, elem3 ...)]
tuple_data_list = cursor.fetchall()
for tuple_data in tuple_data_list:
    xxx = tuple_data[0]
    yyy = tuple_data[1]
    ...
    

# 采用迭代器的方式, 返回当前游标所对应的 tuple 结果集, 迭代到最后方法返回 None
@return tuple(elem1, elem2, elem3 ...)
tuple_data = cursor.fetchone()
while tuple_data:
    # deal with tuple_data
    ...
    tuple_data = cursor.fetchone()
    
    
# 折中的一种方法, 指定返回 size 个 tuple 结果集 组成一个 list;
# 若 指定 size 小于 总的结果集数量, 则返回全部数据集;
@return list[tuple(elem1, elem2, elem3 ...)]
tuple_data_list = cursor.fetchmany(size)
...
```

### **MySQLdb 的事务操作**
MySQLdb 默认不会自动 commit, 所有的增删改操作都必须手动 commit 才能真正写回数据库;
``` python
conn = MySQLdb.connect(host='10.64.0.11', user='xxx', passwd='yyy', db="zzz", port=3306, charset="utf8")
SQL = 'update xxx set yyy = zzz'
cur = conn.cursor()
try:
    cur.execute(SQL,(2,))
    # 手动 commit 提交事务
    conn.commit()
except Exception, e:
    # 手动回滚
    conn.rollback()
finally:
    cur.close()
    conn.close()
```

### **参考链接**
- [MySQLdb的安装与使用](https://www.cnblogs.com/franknihao/p/7267182.html)

