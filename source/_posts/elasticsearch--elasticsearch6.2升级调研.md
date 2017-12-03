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
## **client 兼容性问题**
### **升级过渡期 client 端的技术选型**
关于 elasticsearch java 官方客户端, 除了 TransportClient 之外, 最近又新出了一个 HighLevelClient, 而且官方准备在接下来的一两个 major 版本中, 让 HighLevelClient 逐步取代 TransportClient, 官方原话是这样描述的:
> We plan on deprecating the `TransportClient` in Elasticsearch 7.0 and removing it completely in 8.0.

所以没有什么好对比的, 我们必须选择 HighLevelClient, 否则没两年 TransportClient 就要被淘汰了; 现在唯一需要考虑的是, 在升级过渡期, 怎么处理 es-adapter 中新 client 和旧 client的关系, 如何同时访问 6.2.2 与 2.4.2 两个集群;
值得注意的是, HighLevelClient 是基于 http 的 rest client, 这样一来, 在客户端方面, elasticsearch 将 java, python, php, javascript 等各种语言的底层接口就都统一起来了; 与此同时, 使用 rest api, 还可以屏蔽各版本之前的差异, 之前的 TransportClient 使用 serialized java object, 各版本之前的微小差异便会导致不兼容;
要使用 HighLevelClient, 其 maven 坐标需要引到如下三个包:
``` xml
<!-- elasticsearch core -->
<dependency>
    <groupId>org.elasticsearch</groupId>
    <artifactId>elasticsearch</artifactId>
    <version>6.2.2</version>
</dependency>
<!-- low level rest client -->
<dependency>
    <groupId>org.elasticsearch.client</groupId>
    <artifactId>elasticsearch-rest-client</artifactId>
    <version>6.2.2</version>
</dependency>
<!-- high level rest client -->
<dependency>
    <groupId>org.elasticsearch.client</groupId>
    <artifactId>elasticsearch-rest-high-level-client</artifactId>
    <version>6.2.2</version>
</dependency>
```
后两者没的说, 都是新引入的坐标; 但是第一个坐标, elasticsearch 的核心 package, 就无法避免与现在 es-adapter 引的 2.4.2 版本冲突了;
之前从 1.7.3 升 2.4.2 时, 由于 TransportClient 跨 major 版本不兼容, 导致 es-adapter 无法用同一个 TransportClient 访问两个集群, 只能苦苦寻找有没有 rest 的解决方案, 后来总算找到一个: Jest (github 地址: [searchbox-io/Jest](https://github.com/searchbox-io/Jest)), 基本囊括了 elasticsearch 各种类别的请求功能;
但这还是架不住各业务线种种小众的需求(比如 nested_filter, function_score 等等), 以致于对两个不同版本的集群, es-adapter 不能完美提供一致的功能;
这一次升 6.2.2, 又遇到了和上一次差不多的问题, 不过一个很大的不同是: 现在官方推荐的 HighLevelClient 是 rest client, 所以很有必要尝试验证下其向下兼容的能力;
我们经过 demo 快速测试验证, 初步得出了结论:
**6.2.2 版本的 RestHighLevelClient 可以兼容 2.4.2 版本的 elasticsearch;**
这也体现了 elasticsearch 官方要逐步放弃 TransportClient 并推荐 HighLevelClient 的原因: 基于 http 屏蔽底层差异, 最大限度地提升 client 端的兼容性;
所以, 本次升级过渡期就不需要像上次 1.7.3 升 2.4.2 那么繁琐, 还要再引入一个第三方的 rest client; 现在唯一需要做的就是直接把 client 升级到 6.2.2, 使用 HighLevelClient 同时访问 2.4.2 和 6.2.2 两个版本;

### **HighLevelClient 的使用注意事项**
**(1) 初始化的重要选项**
HighLevelClient 底层基于 apache httpcomponents, 一提起这个老牌 http client, 就不得不提起与它相关的几个关键 settings:

1. `CONNECTION_REQUEST_TIMEOUT`
2. `CONNECT_TIMEOUT`
3. `SOCKET_TIMEOUT`
4. `MAX_CONN_TOTAL`
5. `MAX_CONN_PER_ROUTE`

不过, HighLevelClient 关于这几个参数的设置有些绕人, 它是通过如下两个回调实现的:
``` java
List<HttpHost> httpHosts = Lists.newArrayList();
serverAddressList.forEach((server) -> httpHosts.add(new HttpHost(server.getAddr(), server.getPort(), "http")));
private RestHighLevelClient highLevelClient = new RestHighLevelClient(
        RestClient.builder(httpHosts.toArray(new HttpHost[0]))
                // timeout settings
                .setRequestConfigCallback((callback) -> callback
                        .setConnectTimeout(CONNECT_TIMEOUT_MILLIS)
                        .setSocketTimeout(SOCKET_TIMEOUT_MILLIS)
                        .setConnectionRequestTimeout(CONNECTION_REQUEST_TIMEOUT_MILLIS))
                // connections total and connections per host
                .setHttpClientConfigCallback((callback) -> callback
                        .setMaxConnPerRoute(MAX_CONN_PER_ROUTE)
                        .setMaxConnTotal(MAX_CONN_TOTAL)
                )
        );
```

**(2) request timeout 的设置**
对于 index, update, delete, bulk, query 这几个请求动作, HighLevelClient 与它们相关的 Request 类都提供了 timeout 设置, 都比较方便; 但是, 偏偏 get 与 multiGet 请求没有提供设置 timeout 的地方;
这就有点麻烦了, get 与 multiGet 是重要的请求动作, 绝对不能没有 timeout 机制: 之前遇到过的几次惨痛故障, 都无一例外强调了合理设置 timeout 的重要性;
那么, 这种就只能自己动手了, 还好 HighLevelClient 对每种请求动作都提供了 async 的 API, 我可以结合 CountDownLatch 的超时机制, 来实现间接的 timeout 控制;
首先需要定义一个 response 容器来盛装异步回调里拿到的 result:
``` java
class ResponseWrapper<T> {
    private T response;
    private Exception exception;
    public T getResponse() { return response; }
    public void setResponse(T response) { this.response = response; }
    public Exception getException() { return exception; }
    public void setException(Exception exception) { this.exception = exception;}
}
```
下面是使用 CountDownLatch 实现 timeout 的 get 请求具体逻辑:
``` java
/* get request with timeout */
final ResponseWrapper<GetResponse> wrapper = new ResponseWrapper<>();
final CountDownLatch latch = new CountDownLatch(1);
highLevelClient.getAsync(request, new ActionListener<GetResponse>() {
    @Override
    public void onResponse(GetResponse documentFields) {
        wrapper.setResponse(documentFields);
        latch.countDown();
    }
    @Override
    public void onFailure(Exception e) {
        wrapper.setException(e);
        wrapper.setResponse(null);
        latch.countDown();
    }
});
try {
    latch.await(getTimeOutTime(indexName, TimeUnit.MILLISECONDS);
} catch (InterruptedException e) {
    throw new ElasticsearchTimeoutException("timeout");
}
if (wrapper.getResponse() == null) { // 异常处理 } 
else { 处理 wrapper.getResponse() 的返回结果 }
```

## **基础兼容性问题**
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

**(2) _timestamp 字段被废弃**
*这个改变对我们的影响不是很大, 我们现在绝大部分索引都会自己定义 createTime / updateTime 字段, 用于记录该文档的创建 / 更新时间, 几乎不依赖系统自带的 _timestamp 字段;*
&nbsp;
况且, _timestamp 字段在 2.4.2 版本时, 就已经默认不自动创建了, 要想添加 _timestamp 字段, 必须这样定义:
``` javascript
"_timestamp": {
    "enabled": true
}
```
当然, 在 6.2.2 版本中, 以上定义就直接报 unsupported parameter 错误了;

**(3) _all 字段被 deprecated, include_in_all 属性被废弃**
在 elasticsearch 6.x, _all 字段被 deprecated 了, 与此同时, _all 字段的 enabled 属性默认值也由 true 改为了 false;
之前, 为了阻止 _all 字段生效, 我们都会不遗余力得在每个索引创建语句中加上如下内容:
``` javascript
"_all": {
    "enabled": false
}
```
从 6.0 版本开始, 这些语句就不需要再出现了, 出现了反而会导致 elasticsearch 打印 WARN 级别的日志, 告诉我们 _all 字段已经被 deprecated, 不要再对其作配置了;
与 _all 密切相关的属性是 include_in_all, 在 6.0 版本之前, 这个属性值默认也是 true; 不过不像 _all 的过渡那么温和, 从 6.0 开始, 我在 elasticsearch reference 官方文档里就找不到这个属性的介绍了, 直接被废弃; 而在其上一个版本 5.6 中, 我还能看到它, 也没有被 deprecated, 着实有些突然;
elasticsearch 放弃 _all 这个概念, 是希望让 query_string 时能够更加灵活, 其给出的替代者是 `copy_to` 属性:
``` javascript
"properties": {
    "first_name": {
        "type": "text",
        "copy_to": "full_name" 
    },
    "last_name": {
        "type": "text",
        "copy_to": "full_name" 
    },
    "full_name": {
        "type": "text"
    }
}
```
这样, 把哪些字段 merge 到一起, merge 到哪个字段里, 都是可以自定义的, 而不用束缚在固定的 _all 字段里;
&nbsp;
*无论如何, _all 与 include_in_all 的废弃对我们来说影响都是很小的, 首先我们就很少有全文检索的场景, 其次我们也没有使用 query_string 查询 merged_fields 的需求, 甚至将 _all 禁用已被列入了我们索引创建的规范之中;*

**(4) 史诗级大改变: string 类型被废弃**
string 类型被废弃, 代替者是分词的 `text` 类型和不分词的 `keyword` 类型;
当前正在使用的 2.4.2 版本的集群里, string 类型大概是被使用最多的类型了; 保守估计, 一个普通的索引里, 60%  以上的字段类型都是 string; 现在 6.x 把这个类型废弃了, 就意味着几乎所有索引里的大多数字段都要修改;
&nbsp;
*不过好在, 这种修改也只是停留在 index 的 schema 映射层面, 对 store 于底层的 document 而言是完全透明的, 所有原始数据都不需要有任何修改;*
&nbsp;
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

**(5) mapping 中取消 multi types**
从 elasticsearch 6.1 开始, 同一个 index(mapping) 下不允许创建多个 type, index 与 type 必须一一对应; 从下一个 major 版本开始, elasticsearch 将废弃 type 的概念, 详见官方文档: [Removal of mapping types](https://www.elastic.co/guide/en/elasticsearch/reference/6.2/removal-of-types.html);
由于底层 Lucene 的限制, 同一个 index 下的不同 type 中的同名的字段, 其背后是共享的同一个 lucene segment; 这就意味着, 同一个 index 下不同 type 中的同名字段, 类型定义也必须相同; 原文如下:
> In an Elasticsearch index, fields that have the same name in different mapping types are backed by the same Lucene field internally; In other words, both fields must have the same mapping (definition) in both types.

&nbsp;
*这个改变对我们是有些影响的, 我们有小一部分的索引都存在 multi types 的问题, 这就意味着需要新建索引来承接多出来的 type, 这些索引的使用者必须要修改代码, 使用新的索引名访问不同的 type;*

### **query dsl 的兼容性**
索引创建的兼容性调研只能算是一个热身, 按照以往经验, elasticsearch 一旦有 major 版本升级, query dsl 变动都不会小, 这次也不例外;
**(1) filtered query 被废弃**
其实早在 2.0 版本时, filtered query 就已经被 deprecated 了, 5.0 就彻底废弃了; 这的确是一个不太优雅的设计, 在本来就很复杂的 query dsl 中又增添了一个绕人的概念;
filtered query 原本的设计初衷是想在一个 query context 中引入一个 filter context 作前置过滤: 
> Exclude as many document as you can with a filter, then query just the documents that remain.

然而, filtered query 这样的命名方式, 让人怎么也联系不了上面的描述; 其实要实现上述功能, elasticsearch 有另一个更加清晰的语法: bool query, 详细的内容在接下来的第 (2) 小节介绍;
&nbsp;
*从目前 es-adapter 的使用情况来看, 依然有请求会使用到 filtered query; 好在 filtered 关键字一般出现在 dsl 的最外层, 比较固定, 这块可以在 es-adapter 中代理修改;*

**(2) filter context 被限定在 bool query 中使用**
如下所示, 以下 dsl 是 elasticsearch 6.x 中能够使用 filter context 的唯一方式, 用于取代第 (1) 小节所说的 filtered query:
``` javascript
{
  "query": {
    "bool": {
      "must": {...},
      "should": {...},
      "must_not": {...},
      // 引入 filter context 作前置过滤
      "filter": {...}
    }
  }
}
```
&nbsp;
*由于这个规范只是一个限定, 而不是废弃, 所以对目前生产环境肯定是没有影响, 只是需要各业务线慢慢将使用方式改成这种规范, 否则以后也会带来隐患;*

**(3) and/or/not query 被废弃**
与 filtered query 不同, and query, or query, not query 这三个是语义清晰, 见名知意的 query dsl, 但是依然被 elasticsearch 废弃了, 所有 and, or, not 逻辑, 现在只能使用 bool query 去实现, 如第 (2) 小节所示;
可以发现, elasticsearch 以前为了语法的灵活丰富, 定义了各种各样的关键字; 要实现同一个语义的查询, 可以使用几种不同的 query dsl; 很多时候, 这样导致的结果, 就是让新人感到眼花缭乱, 打击了学习热情;
现在 and query, or query, not query 被废弃, 干掉了冗余的设计, 精简了 query dsl 的体系, 不得不说这是一件好事;
但从另一个角度讲, 每逢 major 版本升级就来一次大动作, 破坏了前后版本的兼容性, 让使用者很头疼; 想想 java 为了兼容性到现在都还不支持真正的泛型, 要是换 elastic 公司来操作, 估计 JDK 1.6 就准备放弃兼容了;
&nbsp;
*从 es-adapter 的使用情况来看, 目前业务线基本没有 and/or/not query 的使用, 相关逻辑大家都使用的 bool query, 所以这一点对我们影响有限;*

**(4) missing query 被废弃**
要实现 missing 语义的 query, 现在必须统一使用 must_not exists:
``` javascript
GET /_search
{
    "query": {
        "bool": {
            "must_not": {
                "exists": {
                    "field": "xxx"
                }
            }
        }
    }
}
```
这也算是对 query dsl 体系的精简化: 可以用 exists query 实现的功能, 就不再支持冗余的语法了;
&nbsp;
*这个改动对我们是有一定影响的, 目前不少的 query 都还在使用 missing;*
*另外, 由于从 missing 改为 must_not exists 结构变化大, 而且 missing 的使用比较灵活, 在 dsl 中出现的位置不固定, 这两个因素叠加, 导致在 es-adapter 中代理修改的难度非常高, 基本不可行;*
*所以, 关于 missing , 必须由业务线自己来修改相关代码了;*

### **search api 的兼容性**
**(1) search_type scan 被废弃**
关于这一点, 我们早就作好了心理准备; 早在从 1.7.3 升 2.4.2 的时候, 我们就已经发现 scan 这种 search type 被 deprecated 了, 从 5.0 开始, 就要被彻底废弃了;
从类别上说, scan 只不过是 scroll 操作中的一种特例: 不作 sort, 不作 fetch 后的 merge; 从执行效果上看, scan 相比 scroll 可能稍微快一些, 并会获得 shards_num * target_size 数量的结果集大小; 除此之外, 没有其他什么区别;
&nbsp;
*所以说, 这个改变对我们来说只能算是尘埃落定, 并不会带来多大的影响;*
*我唯一要做的就是在 es-adapter 中忽略业务线传过来的 scan type, 然后把它当作一个普通的 scroll 操作去处理;*
*唯一需要注意的是, 在实际上已经是使用 scroll 的情况下, 最终返回的文档数量就是 query 时指定的 size, 而不是再乘以 shards_num, 某些具体的业务可能会对返回的结果数量比较敏感;*

**(2) search_type count 被废弃**
*从目前的情况看, 应该没有*

**(3) search_type query_and_fetch / dfs_query_and_fetch 被废弃**

### **底层索引数据的兼容性**
根据官方文档, 6.x 版本可以兼容访问 5.x 创建的索引; 5.x 版本可以兼容 2.x 创建的索引;
背后其实是 Lucene 版本的兼容性问题, 目前我们 2.4.2 版本的集群使用的 Lucene 版本是 5.5.2, 而 6.2.2 版本的 elasticsearch 使用的 Lucene 版本是 7.2.1;

* 由于主机资源有限, 没办法再弄出一组机器来搭建新集群, 我首先想到的是: 能否以 5.x 作跳板, 先原地升级到 5.x, 再从 5.x 升到 6.x;
但是看了官方文档, 这个想法是不可行的: [Reindex before upgrading](https://www.elastic.co/guide/en/elasticsearch/reference/6.2/reindex-upgrade.html ); elasticsearch 只认索引是在哪个版本的集群中创建的, 并不关心这个索引现在在哪个集群; 一个索引在 2.4.2 集群中创建, 现在运行在 5.x 版本的 elasticsearch 中, 这时候将 5.x 的集群升级到 6.x, 该索引是无法在 6.x 中访问的;
* 其次我想到的是使用 hdfs snapshot / restore 插件来升级索引; 这种方式曾在之前 1.7.3 升级 2.4.2 版本时大量使用, 总体来说速度比普通的 scroll / index 全量同步要快很多; 但是看了官方文档, 发现这个想法也是不可行的, (文档链接: [Snapshot And Restore](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-snapshots.html)):
> A snapshot of an index created in 5.x can be restored to 6.x.
A snapshot of an index created in 2.x can be restored to 5.x.
A snapshot of an index created in 1.x can be restored to 2.x.

* 接着我又想到了 elasticsearch 自带的 reindex 模块; reindex 模块也是官方文档推荐的从 5.x 升 6.x 时的索引升级方法; 经过 beta 测试, 我发现这个方法基本可行, 速度也尚可, 唯一需要注意的就是在 elasticsearch.yml 配置文件中要加上一段配置: `reindex.remote.whitelist: oldhost:port` 以允许连接远程主机作 reindex;
以下是 _reindex API 的使用方法:
``` javascript
POST _reindex
{
  "source": {
    "remote": {
      "host": "http://oldhost:9273"
    },
    "index": "source_idx",
    "type": "source_type",
    "query": {
      "match_all": {}
    }
  },
  "dest": {
    "index": "dest_idx",
    "type": "dest_type"
  }
}
```
* 除了 reindex 模块之外, 其实还有一种更保守的方法, 就是用基于 es-spark 的索引迁移工具来完成迁移, 这也是之前经常使用的工具;

## **工具兼容性问题**
### **http 访问工具兼容性**
目前我们经常使用的基于 http 的访问工具主要是 elasticsearch-head 和 cerebro;
关于 http 请求, elasticsearch 6.2.2 也有一个重大的改变: [Strict Content-Type Checking for Elasticsearch REST Requests](https://www.elastic.co/blog/strict-content-type-checking-for-elasticsearch-rest-requests);
现在所有带 body 的请求都必须要加上 `content-type` 头, 否则会被拒绝; 我们目前正在使用的 elasticsearch-head:2 和 cerebro v0.6.1 肯定是不支持这点的, head 是所有针对数据的 CRUD 请求使用不了, cerebro 甚至连接机器都会失败;
目前, cerebro 在 github 上已经发布了最新支持 elasticsearch 6.x 的 docker 版本: [yannart/docker-cerebro](https://github.com/yannart/docker-cerebro); 经过部署测试, 完全兼容 elasticsearch 6.2.2;
不过, elasticsearch-head 就没那么积极了, 目前最近的一次 commit 发生在半年之前, 那个时候 elasticsearch 的最新版本还是 v 5.5;

### **插件兼容性**
目前生产环境中正在使用的插件是否在 es6 生态下继续兼容: 
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
- [Strict Content-Type Checking for Elasticsearch REST Requests](https://www.elastic.co/blog/strict-content-type-checking-for-elasticsearch-rest-requests)
- [Elasticsearch 6 新特性与重要变更解读](http://blog.csdn.net/napoay/article/details/79135136)
 
