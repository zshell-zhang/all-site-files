---
title: "python 模块导入: 相关基础知识梳理"
date: 2017-03-12 21:35:04
categories:
 - python
tags:
 - python:module
---

> python 有一个关键字和 java 一样: `import`, 其功能也类似: 在代码中引入其他的依赖(模块)以使用;
不过, 不像 java 那么单纯, python 还要区分为 import module 和 import names 两大类; 作为一个 python 新手, 这些使用上的区别有时会令人感到迷惑;
python 包和 java 包在概念上也有类似之处, 不过 python 的 \__init\__.py 规范更讲究一些, java 的 package-info.java 重要性没有那么强, python 初学者在此也很容易栽跟头;
在使用了一段时间的 python 之后, 我突然发现, 关于模块引入相关的知识, 我还从来没有过一个系统性的整理; 故作此文以备将来查阅;

<!--more-->

------

下面所示的是一个 python 工程结构, 包括了一个父 package 和其下的子 package , 结构比较完整; 本文将以此工程结构为例, 展开内容;
``` python
MyPackage
    ├── connections.py
    ├── constants
    │   ├── CLIENT.py
    │   ├── CR.py
    │   ├── ER.py
    │   ├── FIELD_TYPE.py
    │   ├── FLAG.py
    │   ├── __init__.py
    │   ├── REFRESH.py
    ├── converters.py
    ├── cursors.py
    ├── __init__.py
    ├── release.py
    ├── times.py
```
其中, 假设 connections.py 中定义了 Connection 类:
``` python
# connections.py
import _mysql
class Connection(_mysql.connection):
    def __init__(self, *args, **kwargs):
        ...
```
下面开始本文的内容;

### **基础预备知识**
#### **对象的 \__name\__ 字段**
所有 python 程序的执行必须要有一个入口, 而我们经常见到的入口会有这么一行代码:
``` python
if __name__ == '__main__':
```
这里面涉及到了一个模块的属性: `__name__`:
当一个模块以主模块被执行时, 该模块的 \__name\__ 就被解释器设定为 '\__main\__';
当一个模块被其他模块引入时, 该模块的 \__name\__ 就被解释器设定为 '该模块的文件名';

#### **内建方法: dir()**
python 中有一个全局内建方法 `dir(p_object=None)` 可以返回目标作用域里所有的成员 (names);
当方法参数 p_object 为 None 时, 默认返回当前作用域内的所有成员:
``` python
# 在 python shell 里执行, 作用域为主模块, 展示模块属性
>>> import MyPackage
>>> dir()
['MyPackage', '__builtins__', '__doc__', '__name__', '__package__']
```

``` python
# 在方法内部执行, 作用域为方法内, 展示方法的字段
def print_dir(num=1, str=None):
    print dir()
    
if __name__ == '__main__':
    print_dir()

output:
['num', 'str']
```
如果指定了目标作用域(对象), 则无论在哪里指定 dir () 方法, 都只打印指定目标的成员;
``` python
from MyPackage.connections import Connection
# 指定作用域
def print_dir(obj=None):
    print dir(obj)

if __name__ == '__main__':
    conn = Connection()
    print_dir(conn)

output:
['__doc__', '__init__', '__module__']
```

#### **import 的规则语法**
python 导入其他模块分为两种: import module/package 与 import names (包括变量, 函数, 类等);
import module/package 的语法如下:
``` python
import MyPackage
import MyPackage.connections
```
import names 的语法如下:
``` python
# 引入类
from MyPackage.connections import Connection
# 引入方法
from MyPackage.connections import numeric_part
# 引入 __all__ 指定的所有 names
from MyPackage import *
```
对于不同的 package, 不同的 \__init\__.py 文件, 这些 import 语句所产生的效果都不尽相同, 详细的区别将在下一节描述;

### **\__init\__.py 文件的功能**
对于 python 的每一个包来说, \__init\__.py 是必须的, 它控制着包的导入行为, 并可以表达非常丰富的信息; 如果没有 \__init\__.py 文件, 那这个包只能算是一个普通目录, 目录下的任何 python 文件都不能作为模块被导入;
以下是几种常见的 \__init\__.py 文件的内容:

#### **\__init\__.py 文件内容为空**
\__init\__.py 文件必须有, 但可以是空文件, 这将是最简单的形式, 当然其所提供的功能也最简单: 标识这是一个 python 包, 仅此而已;
如果将该包作为一个模块导入, 其实是等于什么都没导入:
``` python
>>> import MyPackage
>>> dir()
['MyPackage', '__builtins__', '__doc__', '__name__', '__package__']
>>> dir(MyPackage)
['__builtins__', '__doc__', '__file__', '__name__', '__package__', '__path__']
```
通过 dir() 内建方法可以发现, 无论是当前主模块, 还是 MyPackage 包, 除了一些保留 names, 不再有其他任何自定义符号, 这时将无法直接使用 MyPackage 下的任何模块:
``` python
# 直接 使用 connections.py 下的 Connection 类
>>> conn = MyPackage.connections.Connection()
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
NameError: name 'MyPackage' is not defined
```

不过, 既然 \__init\__.py 已经标识了这是一个 python 包, 所以对于包下所有其他的模块文件, 我们可以主动引入它们, 这算是空 \__init\__.py 的唯一作用:
``` python
# 主动引入模块
>>> import MyPackage.connections
>>> dir(MyPackage)
['__builtins__', '__doc__', '__file__', '__name__', '__package__', '__path__', 'connections']
>>> dir(MyPackage.connections)
['Connection', '__builtins__', '__doc__', '__file__', '__name__', '__package__', 'numeric_part']
```
这时可以发现, dir(MyPackage) 列表里有了 connections 模块, dir(MyPackage.connections) 列表里有了 Connection 类; 这时带着 python 路径, 就可以使用 target name 了:
``` python
>>> conn = MyPackage.connections.Connection()
```
另外, 如果使用 from ... import ... 主动引入目标符号:
``` python
>>> from MyPackage.connections import Connection
>>> dir()
['Connection', '__builtins__', '__doc__', '__name__', '__package__']
```
便可以直接将目标符号引入当前作用域, 不需要使用模块路径, 就可以直接使用:
``` python
>>> conn = Connection()
```

#### **在 \__init\__.py 中 import 其他模块**
\__init\__.py 中自己主动 import 第三方模块是一种常见的操作:
``` python
# __init__.py
import connections
```
``` python
>>> import MyPackage
>>> dir(MyPackage)
['__builtins__', '__doc__', '__file__', '__name__', '__package__', '__path__', 'connections']
# 路径是 MyPackage.connections
>>> conn = MyPackage.connections.Connection()
```
或者使用 from ... import ... 语法:
``` python
# __init__.py
from connections import Connection
```
``` python
>>> import MyPackage
>>> dir(MyPackage)
['Connection', '__builtins__', '__doc__', '__file__', '__name__', '__package__', '__path__', 'connections']
# 路径是 MyPackage
>>> conn = MyPackage.Connection()
```
对于以上两种 import 方式, 结合 dir() 内建方法的展示, 可以发现在具体使用目标符号时所带路径的区别;

#### **\__init\__.py 中的保留字段**
(1) \__all\__ 字段:
如果在代码中使用了如下的引用方式:
``` python
from MyPackage import *
```
解释器便会试图去指定的模块中寻找 `__all__` 字段, 将该列表中列举的所有 names 全部引入:
``` python
__all__ = [ 'BINARY', 'Binary', 'Connect', 'Connection', 'DATE',
    'Date', 'Time', 'Timestamp', 'DateFromTicks', 'TimeFromTicks',
    'TimestampFromTicks', 'DataError', 'DatabaseError', 'Error',
    'FIELD_TYPE', 'IntegrityError', 'InterfaceError', 'InternalError',
    'MySQLError', 'NULL', 'NUMBER', 'NotSupportedError', 'DBAPISet',
    'OperationalError', 'ProgrammingError', 'ROWID', 'STRING', 'TIME',
    'TIMESTAMP', 'Warning', 'apilevel', 'connect', 'connections',
    'constants', 'converters', 'cursors', 'debug', 'escape', 'escape_dict',
    'escape_sequence', 'escape_string', 'get_client_info',
    'paramstyle', 'string_literal', 'threadsafety', 'version_info']
```
不过, 这种情况下不能完全清楚引入了什么 names, 有可能覆盖自己定义的 names, 最好谨慎使用;
(2) 其他信息, 如版本, 作者:
``` python
# 作者
__author__ = "Andy Dustman <farcepest@gmail.com>"
# 版本信息
version_info = (1,2,5,'final',1)
__version__ = "1.2.5"
```

#### **在 \__init\__.py 中定义方法/类**
\__init\__.py 也是 python 源文件, 在其中亦可以定义方法, 类, 或者执行代码段:
``` python
# MyPackage: __init__.py
def test_DBAPISet_set_equality():
    assert STRING == STRING
    
def Binary(x):
    return str(x)
```
此时, import 了 MyPackage 之后, 便可以正常使用定义的内容;

### **python 的工作/搜索路径**
当导入一个 python 模块时, 解释器的查找路径如下:

1. 在当前的包中查找;
2. 在 `__buildin__` 模块中查找;
3. 在 sys.path 给定的路径中中查找;

其中, 第一点自不必说;
关于 \__buildin\__ 模块, 更多的信息请参见另一篇文章: [python module 使用总结: \__buildin\__](); 上文描述的 dir() 方法其实就是 \__buildin\__ 模块中的内建方法, 不需要额外引入其他模块便能直接使用;
而关于 sys.path, 其初始构成内容又包含了以下几处地方:

1. 程序的主目录;
2. PYTHONPATH 中定义的路径;
3. 标准链接库, 例如: /usr/lib/python2.7, /usr/local/lib/python2.7 等;

``` python
>>> import sys
>>> sys.path
['', '/usr/lib64/python27.zip', '/usr/lib64/python2.7', '/usr/lib/python2.7/plat-linux2', '/usr/lib/python2.7/lib-tk', '/usr/lib/python2.7/lib-old', '/usr/lib/python2.7/lib-dynload', '/usr/lib/python2.7/site-packages', '/usr/lib/python2.7/site-packages']
```
如上所述, 从运行主模块的角度考虑:

1. 如果引入的模块是第三方模块, 那么大部分情况下, 所需要的模块在标准链接库 dist-packages 中都有, python 能够成功引到;
2. 如果引入的模块是自己的子模块, 由于子模块一定在主模块的子目录下, 所以 python 也能成功引到;
3. 如果引入的模块是自己的父模块或者兄弟模块, 这时 python 能否成功引到, 就得分情况了:

如果工程在自己创建的目录中运行, 引入父模块或者兄弟模块, 在默认的搜索路径里是找不到的;
这时要想成功引到目标模块, 有两种办法:
(1) 向 sys.path 中拓展添加目标路径:
``` python
import sys
sys.path.append(os.path.abspath('xxx/yyy/zzz'))
```
(2) 使用 PYTHONPATH, 向其中添加目标路径:
``` bash
# /etc/profile
export PATH=${PATH}:${target_path}
export PYTHONPATH=${PYTHONPATH}:${target_path}
```
至于这两种方法的好坏, 就是仁者见仁, 智者见智的问题了;
使用 sys.path.append, 比较灵活, 每个模块都可以自己定义, 但缺点是需要多添加两行代码, 比较繁琐;
使用 PYTHONPATH, 优点是不需要在自己的模块中添加额外的代码, 但是如果自己创建的工程路径比较零散, PYTHONPATH 就需要不停地补充新路径;
不过, 如果有诸如公司规范之类的, 将 python 项目都部署在约定的公共目录下, 那么 PYTHONPATH 只需要添加这一个公共路径即可, 这样问题便简单了;
&nbsp;
至此, 关于 python 模块导入的基础性问题就讲完了;
最后要说的是, 其实本文最开始所列出的那个自定义模块 MyPackage, 其原型是 `MySQLdb`;

### **站内相关文章**
- [python module 使用总结: \__buildin\__]()

### **参考链接**
- [Python 中 if \__name\__ == '\__main\__' 理解](http://www.cnblogs.com/huwang-sun/p/6993980.html)
- [Python 中的包 ImportError](https://www.cnblogs.com/AlwinXu/p/5658787.html)
- [python import 工程内模块显示错误](https://segmentfault.com/q/1010000007837183?_ea=1477413)
- [Python模块包中\__init\__.py文件的作用](http://blog.csdn.net/yxmmxy7913/article/details/4233420)
- [Be Pythonic: \__init\__.py](http://mikegrouchy.com/blog/2012/05/be-pythonic-__init__py.html)
- [Python类、模块、包的区别](https://www.cnblogs.com/kex1n/p/5977051.html)
- [Python环境变量PYTHONPATH设置](http://blog.csdn.net/qw_xingzhe/article/details/52695486)

