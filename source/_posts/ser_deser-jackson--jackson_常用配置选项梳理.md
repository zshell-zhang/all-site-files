---
title: jackson 常用配置选项梳理
date: 2017-01-21 15:51:40
categories:
 - ser/deser
 - jackson
tags:
 - jackson
 - json
---

> jackson 有各种各样的配置选项 (Feature), 涵盖了包括 json 语法解析, 语句生成, 序列化 / 反序列化特征, 字段类型处理 等不同层面, 对初学者而言, 很容易造成困惑;
本文基于 jackson 2.8.x, 着手整理常用的 jackson 配置选项, 并给出一个便捷的工具类, 以友好的方式整合 jackson 的常用配置项;

<!--more-->

------
### **配置选项分类**
jackson 的配置选项丰富得可以让开发者自定义从 json 语句到 javabean 的方方面面, 总体来说有如下几类:
json 语句的生成与解析
``` java
// json 语句生成的选项
JsonGenerator.Feature
// json 语法解析的选项
JsonParser.Feature
```
javabean 的序列化与反序列化
``` java
// javabean 序列化选项
SerializationFeature
// javabean 反序列化选项
DeserializationFeature
```
javabean 字段
``` java
// javabean 字段是否参与序列化
JsonInclude.Include
```
上述各 Feature 或 Include 都是以枚举 (enum) 的形式定义的, 他们分布在 jackson 的如下包中:

* JsonGenerator.Feature: jackson-core
* JsonParser.Feature: jackson-core
* SerializationFeature: jackson-databind
* DeserializationFeature: jackson-databind
* JsonInclude.Include: jackson-annotations

这样的归类与它们的功能有关:
JsonGenerator 与 JsonParser 主管 json 的生成与解析, 当属 jackson 的核心功能, 所以归于 jackson-core 包中;
SerializationFeature 与 DeserializationFeature 主管 javabean 的序列化与反序列化, 属于数据实体绑定范畴, 所以归于 jackson-databind 包中;
JsonInclude.Include 比较特别, 它理应主管字段是否参与序列化, 是 javabean 序列化的控制细节, 但是它的外部类 JsonInclude 本身是一个注解, 故其被归于 jackson-annotations 包中;
&nbsp;
下面将分别总结各类 Feature 中具体的常用选项; 有一点要说的是, 以下选项有些本身就是默认设置, 这里只是拿出来总结一下, 我们需要了解这些设置的存在; 另外, 某些设置可能只针对普遍的情况, 在特殊场景下并不适用 (比如容错性, 在某些严格的环境下就是需要 fast fail, 不需要容错);
#### **JsonGenerator.Feature**
其实, JsonGenerator.Feature 是一个比较底层的设置, 在源码注释中被称为 `Low-level I/O / content features`;
关于 json 的生成的配置项, 主要是三个方面:
(1) 统一字段的 json 规范形式, 如对引号的要求;
``` java
// 必须以 "双引号" 的形式包装字段
objectMapper.configure(JsonGenerator.Feature.QUOTE_FIELD_NAMES, true);
```
(2) 加强 json 生成的容错性, 如 JsonToken (大括号与中括号) 的匹配;
``` java
// 允许 json 生成器自动补全未匹配的括号
objectMapper.configure(JsonGenerator.Feature.AUTO_CLOSE_JSON_CONTENT, true);
```
(3) 第三个可能比较少见, 因为大部分业务场景下, 我们只是使用 `objectMapper.writeValueAsString` 方法, 得到其返回的 json 字符串以作他用; 而如果使用 `objectMapper.writeValue` 方法, 则可能涉及到写入流的问题: 
``` java
// 允许 json 生成器在写入完成后自动关闭写入的流
objectMapper.configure(JsonGenerator.Feature.AUTO_CLOSE_TARGET, false);
```
这个选项默认是开启的, 那么会导致一个问题: 当你希望在往目标输出流里输出 json 之后再输出一些其他内容便会失败, 因为 jackson 已经自动帮你关闭该输出流了; 所以有些时候, 这个选项要设置成 false;
#### **JsonParser.Feature**
JsonParser 的配置项, 主要是加强 json 解析的容错性, 并主要体现在三方面:
(1) 降低字段的 json 规范形式, 如对引号的要求; 可以发现, 当自己生成 json 时, 我们要求严格规范引号的书写, 而当解析别人的 json 时, 却需要放宽规范与形式, 增强容错;
``` java
// 允许 json 存在没用引号括起来的 field
objectMapper.configure(JsonParser.Feature.ALLOW_UNQUOTED_FIELD_NAMES, true);
// 允许 json 存在使用单引号括起来的 field
objectMapper.configure(JsonParser.Feature.ALLOW_SINGLE_QUOTES, true);
// 允许 json 存在没用引号括起来的 ascii 控制字符
objectMapper.configure(JsonParser.Feature.ALLOW_UNQUOTED_CONTROL_CHARS, true);
```
(2) 扩大数值字段的表现形式, 如前导 0, 无限大等;
``` java
// 允许 json number 类型的数存在前导 0 (like: 0001)
objectMapper.configure(JsonParser.Feature.ALLOW_NUMERIC_LEADING_ZEROS, true);
// 允许 json 存在 NaN, INF, -INF 作为 number 类型
objectMapper.configure(JsonParser.Feature.ALLOW_NON_NUMERIC_NUMBERS, true);
```
(3) 允许出现注释;
``` java
// 允许 json 存在形如 // 或 /**/ 的注释
objectMapper.configure(JsonParser.Feature.ALLOW_COMMENTS, true);
```
#### **SerializationFeature**
SerializationFeature 的配置项, 主要是针对 javabean 字段序列化作规范与统一;
比如:
(1) 输出压缩的 json, 而不要缩进格式化, 浪费流量;
(2) 统一时间类型的输出为 timestamp, 消除歧义, 方便转换;
(3) 将空的集合类型以空的形式参与序列化, 而不是不展示它们, 从而始终能得到完整的数据结果;
``` java
// 序列化时, 禁止自动缩进 (格式化) 输出的 json (压缩输出)
objectMapper.configure(SerializationFeature.INDENT_OUTPUT, false);
// 序列化时, 将各种时间日期类型统一序列化为 timestamp 而不是其字符串表示
objectMapper.configure(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS, true);
// 序列化时, map, list 中的 null 值也要参与序列化
objectMapper.configure(SerializationFeature.WRITE_NULL_MAP_VALUES, true);
```
另外也有一些容错方面的设置:
``` java
// 序列化时, 对于没有任何 public methods / properties 的类, 序列化不报错
objectMapper.configure(SerializationFeature.FAIL_ON_EMPTY_BEANS, false);
```
#### **DeserializationFeature**
反序列化时配置项, 主要是考虑到容错性, 针对陌生的字段作忽略处理, 从而提高版本之间的兼容性(比如升级某个 api 版本增加字段后, 所有调用方并不需要保持同步升级, 反序列化时对新字段暂时忽略即可);
``` java
// 忽略未知的字段
objectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);
```
#### **JsonInclude.Include**
这与 `SerializationFeature.WRITE_NULL_MAP_VALUES` 有些相似: 就是针对所有的元素, 不管是不是 null, 都要参与序列化, 要展示所有元素的情况, 而不是对空值就忽略不展示了, 那会诱导发生潜在的 bug; 这算是对字段序列化作的规范统一;
``` java
// 所有实例中的 空字段, null 字段, 都要参与序列化
objectMapper.setSerializationInclusion(JsonInclude.Include.NON_EMPTY);
objectMapper.setSerializationInclusion(JsonInclude.Include.NON_NULL);
```

### **jackson 选项控制的良好实践**
公司的基础公共服务 api 中, 有一组关于 jackson 的良好封装, 旨在以更便捷友好的方式设置 jackson 配置选项, 当时该组件的作者是基础架构部的 [杨淼](mailto:miao.yang@qunar.com); 不过, 该组件源代码维护在 qunar 的私有 gitlab 仓库中, 并不对外开源; 出于与公司的保密协议, 我只能将我一个使用 scala 开发的个人项目中针对此重新编写的代码拿出来与大家分享: [便捷设置 jackson 配置选项的案例](https://github.com/spark-bypass-common/common-base/tree/master/src/main/scala/com/qunar/spark/base/json);
这个案例中, 有两点值得分享:
**(1) 利用重载方法统一选项设置入口**
关于 ObjectMapper 设置选项的 configure 方法, 我们可以发现, 它有很多重载方法:
``` java
public ObjectMapper configure(MapperFeature f, boolean state);
public ObjectMapper configure(JsonGenerator.Feature f, boolean state);
public ObjectMapper configure(JsonParser.Feature f, boolean state);
public ObjectMapper configure(SerializationFeature f, boolean state);
public ObjectMapper configure(DeserializationFeature f, boolean state);
```
以上五个重载方法已经涵盖了上一节中提到的五种 Feature 中的四种; 最后还有一个关于 JsonInclude.Include 的设置方法如下:
``` java
// 针对 JsonInclude.Include
public ObjectMapper setSerializationInclusion(JsonInclude.Include incl);
```
所以, 在我分享的例子中, 便抽出了一个统一设置各个 Feature 的方法:
``` scala
private def configure(mapper: ObjectMapper, feature: AnyRef, state: Boolean) {
  feature match {
    case feature: SerializationFeature => mapper.configure(feature.asInstanceOf[SerializationFeature], state)
    case feature: DeserializationFeature => mapper.configure(feature.asInstanceOf[DeserializationFeature], state)
    case feature: JsonParser.Feature => mapper.configure(feature.asInstanceOf[JsonParser.Feature], state)
    case feature: JsonGenerator.Feature => mapper.configure(feature.asInstanceOf[JsonGenerator.Feature], state)
    // 兜底逻辑, 针对其余的 Feature
    case feature: MapperFeature => mapper.configure(feature.asInstanceOf[MapperFeature], state)
    case feature: Include => if (state) mapper.setSerializationInclusion(feature.asInstanceOf[Include])
  }
}
```

**(2) 使用位运算符巧妙设置选项**
其实, 在 jackson 自己的源码中, 就已经蕴含着位运算的设计思路 (以 SerializationFeature 为例):
``` java
/* SerializationFeature */
public ObjectMapper configure(SerializationFeature f, boolean state) {
    _serializationConfig = state ? _serializationConfig.with(f) : _serializationConfig.without(f);
    return this;
}
/* SerializationConfig */
public SerializationConfig with(SerializationFeature feature) {
    int newSerFeatures = _serFeatures | feature.getMask();
    return (newSerFeatures == _serFeatures) ? this : new SerializationConfig(this, _mapperFeatures,
        newSerFeatures, _generatorFeatures, _generatorFeaturesToChange, _formatWriteFeatures,
        _formatWriteFeaturesToChange);
}
```
其中, `feature.getMask()` 方法便是得到目标 feature 的掩码 `_mask`, 一个在二进制上与其他 feature 相互错开的整数值:
``` java
private SerializationFeature(boolean defaultState) {
    _defaultState = defaultState;
    _mask = (1 << ordinal());
}

public int getMask() { return _mask; }
```
可以发现, `1 << ordinal()` 这个操作会给该枚举中的每个值, 依次对 1 作左移, 从而枚举内所有的值, 其二进制表示都只含有一个 1, 且两两错开 (但由于 `_mask` 是一个普通整型, 所以该枚举只能容纳不超过 32 个值);
那么位或运算 `_serFeatures | feature.getMask()` 便等于将该目标枚举值追加到掩码中了;
在我分享的例子中, 也是借鉴了这样巧妙的设计思想, 不同之处在于, 我的案例中是将所有常用的选项配置放在了一起, 组成了一个新的枚举, 并添加了一个 enableByDefault, 表示是否默认开启; 在这个新枚举中, 使用位操作对所有常用的配置编码, 统一设置:
``` java
val defaults: Long = {
  var flags = 0
  for (f <- values if f.enabledByDefault) {
    flags |= f.getMask
  }
  flags
}

sealed case class JsonFeatureValue (@BeanProperty feature: AnyRef, enabledByDefault: Boolean) extends Val {
  @BeanProperty val mask = 1 << id
  def isEnabled(flags: Long): Boolean = (flags & mask) != 0
  def enable(flags: Long): Long = flags | mask
  def disable(flags: Long): Long = flags & (~mask)
}
```
当不想使用默认设置时, 构建一个新的 ObjectMapper 实例也十分简洁, 只需传入一个掩码映射的数值即可:
``` java
private def buildMapperInternal(features: Long): ObjectMapper = {
  val mapper = new ObjectMapper
  for (jf <- JsonFeature.values) {
    configure(mapper, jf.getFeature, jf.isEnabled(features))
  }
  mapper
}
```
&nbsp;
以上便是该案例中两个值得学习的设计要点: 基于 jackson 原生代码, 利用方法重载, 位运算符, 整合分散的配置项, 聚集为一个便捷的工具类;

### **站内相关文章**
- [便捷设置 jackson 配置选项的案例](https://github.com/spark-bypass-common/common-base/tree/master/src/main/scala/com/qunar/spark/base/json)

### **参考链接**
- [How to avoid null values serialization in HashMap](https://stackoverflow.com/questions/3140563/how-to-avoid-null-values-serialization-in-hashmap)
- [Java program terminating after ObjectMapper.writeValue(System.out, responseData) - Jackson Library](https://stackoverflow.com/questions/8372549/java-program-terminating-after-objectmapper-writevaluesystem-out-responsedata)

