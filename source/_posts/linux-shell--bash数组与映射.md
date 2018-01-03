---
title: bash 数组与映射
date: 2017-10-22 23:32:19
categories:
  - linux
  - shell
tags:
  - linux:shell
---

> 注: bash 映射 (map) 在文档里叫做 `关联数组 (associated array)`, 使用关联数组的最低 bash 版本是 4.1.2;

<!--more-->

## **数组/关联数组 的创建**
### **静态创建**
使用类型限定 declare 定义:
``` bash
# 数组
declare -a array1=('a' 'b' 'c')
declare -a array2=(a b c)
# 关联数组
declare -A map1=(["a"]="aa" ["b"]="bb" ["c"]="cc")
declare -A map2=([a]=aa [b]=bb [c]=cc)
```
如果不带类型限定, bash 不会自动推断 关联数组 类型:
``` bash
object1=(a b c)
object2=(["a"]="aa" ["b"]="bb" ["c"]="cc")
```
对于以上两者, bash 都将推断为 普通数组 类型, 其中 object2 中有三个 string 元素: ["a"]="aa", ["b"]="bb" 与 ["c"]="cc";

### **动态创建**
以上展示了 数组/动态数组 的静态创建方式;
更复杂的场景是, 由一段其他复杂命令的输出, 赋值构建一个数组类型:
``` bash
pair_array=(`sed -n -e '6,/}/p' -e '$d' ${formatted_curl_response_file} | awk -F ':' '{
    log_length = length($1);
    app_code_length = length($2);
    log_path = substr($1, 2, log_length - 2);
    app_code = substr($2, 2, app_code_length - 2);
    map[log_path] = app_code
} END {
    for (key in map) {
        printf ("%10s=%10s ", key, map[key])
    }
}'`)
```
以上逻辑, 由 sed 与 awk 两重管道输出目标内容, 作为创建数组的参数, 以达到动态创建的目的;
但是, 以上方式只适用于创建 数组, 而不适用于创建 关联数组, 原因与上一节 静态创建数组 中所表述的相同: 即使输出格式符合定义规范, bash 并不会自动推断为 关联数组;
&nbsp;
另外, 企图通过 declare 强制限定类型去动态创建, 也是不合法的:
``` bash
> declare -A map=(`last -n 1 | head -n 1 | awk '{map[$1]=$3} END{for (key in map) {printf ("[%10s]=%10s ", key, map[key])}}'`)
# 以上语句会报如下错误:
-bash: map: [: must use subscript when assigning associative array
-bash: map: zshell.z]=113.44.125.146: must use subscript when assigning associative array
```
因为, 通过 ``, $() 等命令代换, [zshell.z]=113.44.125.146 这样的输出内容被当作命令执行, 而 [ 这是一个 bash 的内置命令, 用于条件判断;
显然 zshell.z]=113.44.125.146 这样的语句是不符合条件判断的参数输入的;

## **数组/关联数组 的使用**
单独赋值:
``` bash
map['a']='aaa'
array[0]=aaa
```
获取数据:
``` bash
# 获得所有 values
echo ${map[@]}
echo ${array[@]}
# 获得某个单独的值
var=${map['a']}
var=${array[0]}
# 获得所有 keys (对于数组而言, 就是获得所有的索引下标)
for key in ${!map[@]}; do
    ...
done
for key in ${!array[@]}; do
    ...
done
```

## **参考链接**
- [shell中的map使用](http://blog.csdn.net/adermxl/article/details/41145019)

