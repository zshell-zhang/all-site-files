---
title: elasticsearch 6.2 升级调研
date: 2018-02-27 22:11:48
categories:
 - elasticsearch
tags:
 - elasticsearch
---

> todo

<!--more-->

------

## **API 的兼容性**
### **索引创建的兼容性**
es 6.2 在索引创建方面, 有如下几点与 es 2.4 有区别:
&nbsp;
**首先是 settings 中的区别;**
&nbsp;
部分字段不能出现在索引创建语句中了, 只能由 elasticsearch 自动生成;
``` javascript
"settings":{
    "index":{
        // creation_date 不能出现在索引创建的定义语句里
        "creation_date": "1502713848656",
        "number_of_shards":"2",
        "analysis":{
            "analyzer":{
                "comma_analyzer":{
                    "type":"custom",
                    "tokenizer":"comma_tk"
                }   
            },  
            "tokenizer":{
                "comma_tk":{
                    "pattern":",",
                    "type":"pattern"
                }   
            }   
        },
        "number_of_replicas":"1",
        // uuid 不能出现在索引创建的定义语句里
        "uuid":"Oa0tz0x-SpSfuC591_ASIQ",
        // version.create, version.update 不能出现在索引创建的定义语句里
        "version":{
            "created":"1070399",
            "upgraded":"2040299"
        }
    }
}
```
这算是一个规范化, 这些字段原本就不该自己定义, 之前我们是复制的时候图省事, 懒得删掉, 现在不行了;
&nbsp;
**然后是 mappings 中的区别;**
&nbsp;
**(1) 布尔类型的取值内容规范化**
elasticsearch 索引定义的 settings/mappings 里有很多属性是布尔类型的开关; 在 6.x 之前的版本, elasticsearch 对布尔类型的取值内容限制很宽松: true, false, on, off, yes, no, 0, 1 都可以接受, 产生了一些混乱, 对初学者造成了困扰:
``` javascript
// elasticsearch 2.4.2
// xxx_idx/_mapping/field/xxx_field
{
    "xxx_idx":{
        "mappings":{
            "xxx_type":{
                "xxx_field":{
                    "full_name":"xxx_field",
                    "mapping":{
                        "xxx_field":{
                            "type":"string",
                            "index_name":"xxx_field",
                            // 以下属性都有布尔类型的含义, 但取值五花八门, 容易造成歧义
                            "index":"not_analyzed", 
                            "store":false,
                            "doc_values":false,
                            "term_vector":"no",
                            "norms":{
                                "enabled":false
                            },
                            "null_value":null,
                            "include_in_all":false
                        }
                    }
                }
            }
        }
    }
}
```
从 6.x 版本开始, 所有的布尔类型的属性 elasticsearch 只接受两个值: `true` 或 `false`;
*从当前 2.4.2 集群的使用状况来看, 这个改动对我们的影响不是特别大, 因为我们在定义索引创建 DSL 语句时, 很多布尔类型的选项都是用的默认值, 并未显式定义, 只有 `index` 属性可能会经常用到;*

**(2) 史诗级大改变: string 类型被废弃**
string 类型被废弃, 代替者是分词的 `text` 类型和不分词的 `keyword` 类型;
当前正在使用的 2.4.2 版本的集群里, string 类型大概是被使用最多的类型了; 保守估计, 一个普通的索引里, 60%  以上的字段类型都是 string; 现在 6.x 把这个类型废弃了, 就意味着几乎所有索引里的大多数字段都要修改;
*不过好在, 这种修改也只是停留在 index 的 schema 映射层面, 对 store 于底层的 document 而言是完全透明的, 所有原始数据都不需要有任何修改;*
经过搜索发现, 其实早在 elasticsearch 5.0 时, string 类型就已经被 deprecated 了, 然后在 6.1 时被彻底废弃, 详细的 changelog 见官方文档: [Changelog](https://github.com/elastic/elasticsearch-dsl-py/blob/master/Changelog.rst);
仔细一想, 这个改变是有道理的: elasticsearch 想要结束掉目前混乱的概念定义;
比如说, 在 5.0 之前的版本, 一个字符串类型的字段, 是这样定义的:
``` javascript
"xxx": {
    "type": "string",
    "index": "not_analyzed" // 不需要分词, 但要索引
},
"yyy": {
    "type": "string",
    "index": "no" // 不需要分词, 也不需要索引
},
"zzz": {
    "type": "string" // 默认情况, 需要索引, 也需要分词
}
```
`index` 的原本含义是定义是否需要索引, 是一个布尔概念; 但由于字符串类型的特殊性, 索引的同时还需要再区分是否需要分词, 结果 index 属性被设计为允许设置成 `not_analyzed`, `analyzed`, `no` 这样的内容; 然后其他诸如数值类型, 亦被其拖累, index 属性的取值也需要在 `not_analyzed`, `no` 中作出选择; 不得不说这非常混乱;
要把这块逻辑理清楚, 第一个选择是再引入一个控制分词的开关 word_split, 只允许字符串类型使用, 第二种选择就是把字符串类型拆分成 text 和 keyword;
至于 elasticsearch 为何选择了第二种方案, 我猜主要还是默认值不好确定; 对初学者而言, 一般都习惯于使用默认值, 但是究竟默认要不要分词? 以 elasticsearch 的宗旨和初衷来看, 要分词, search every where; 但是以实际使用者的情况来看, 很多的场景下都不需要分词; 如果是把类型拆分, 那么就得在 text 和 keyword 中二选一, 不存在默认值, 使用者自然会去思考自己真正的需求;
现在逻辑理清楚了, `index` 的取值类型, 也就如上一节所说的, 必须要在 `true` 或 `false` 中选择, 非常清晰;

**(3) mapping 中取消 multi types**
从 elasticsearch 6.1 开始, 同一个 index(mapping) 下不允许创建多个 type, index 与 type 必须一一对应; 从下一个 major 版本开始, elasticsearch 将废弃 type 的概念, 详见官方文档: [Removal of mapping types](https://www.elastic.co/guide/en/elasticsearch/reference/6.2/removal-of-types.html);
由于底层 Lucene 的限制, 同一个 index 下的不同 type 中的同名的字段, 其背后是共享的同一个 lucene segment; 这就意味着, 同一个 index 下不同 type 中的同名字段, 类型定义也必须相同; 原文如下:
> In an Elasticsearch index, fields that have the same name in different mapping types are backed by the same Lucene field internally; In other words, both fields must have the same mapping (definition) in both types.

*这个改变对我们是有些影响的, 我们有小一部分的索引都存在 multi types 的问题, 这就意味着需要新建索引来承接多出来的 type, 这些索引的使用者必须要修改代码, 使用新的索引名访问不同的 type;*

### **client 端访问的兼容性**
两个版本共存阶段 adapter 中 client 的选择: 
    (1) 6.2 版本从 transportClient 改为 highLevelClient: 
    (1) 采用 Jest rest client; 

## **底层索引数据的兼容性**
3. es2 升 es6 的数据兼容问题: 
    (1) 以 es5 为跳板, 逐步升级; (被证明不可行: [Reindex before upgrading](https://www.elastic.co/guide/en/elasticsearch/reference/6.2/reindex-upgrade.html ))
    (2) 使用 hdfs snapshot / restore 升级数据格式; (比较繁琐, 但是可以增量同步数据)
    (3) 用 es 6.2.2 的 reindex api; (简单, 但是必须全量同步) 
    建议: 只读索引, 写入少的索引, size 小的索引, 采用 reindex; 
             size 特别大, 且有实时写需求的索引, 采用 hdfs snapshot / restore; 

## **运维工具兼容性**
(1) 当前运行的 cerebro v0.6.1 不兼容 es 6.2.2, 需升级至 0.7.2; 
(2) head 插件兼容 es6; 

## **插件兼容性**
7. 目前生产环境中正在使用的插件是否在 es6 生态下继续兼容: 
    (1) elasticfence (源代码已被我深度改造, 可以基于 es6.2 的 api 再重新改一下, 官方支不支持都没关系) 
    (2) elasticsearch-analysis-ik 
    (3) licence 
    (4) marvel-agent (xpack 代替) 
    (5) repository-hdfs 
    (6) taskscore (曹飞写的, 需要他用 es6.2 的 api 重新改一下) 

## **性能检测**
(1) 与 2.4 的对比: index, update, query; 
(2) query 完全取代 filter; 
(3) load, gc 是否稳定; 

## **监控体系**
kibana, xpack 的部分免费功能 (待仔细研究); 
  
## **新特性研究**
(1) 类似 binlog 的行为日志, 可用于备份及恢复, 甚至实时同步索引;

## **参考链接**
- [Changelog](https://github.com/elastic/elasticsearch-dsl-py/blob/master/Changelog.rst)
- [Removal of mapping types](https://www.elastic.co/guide/en/elasticsearch/reference/6.2/removal-of-types.html)
- [Elasticsearch 6 新特性与重要变更解读](http://blog.csdn.net/napoay/article/details/79135136)

