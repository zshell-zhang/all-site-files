---
title: JsonUtil 类 cheat sheet
date: 2016-08-11 15:01:17
categories:
 - ser/deser
 - jackson
tags:
 - jackson
 - cheat sheet
 - json
---

> 在日常工作中, json 的序列化/反序列化 是最频繁使用的动作; 拥有一个封装良好的 json 工具包能极大得提高工作效率;
本文的目的是总结日常工作经验, 并将其作为一个 cheat sheet, 在某些项目环境中, 方便快速获取;
jackson 是 java 世界里主流的 json 序列化/反序列化 框架, 本文所涉及的 json 工具类正是基于 jackson 实现的;

<!--more-->

------

首先要说的是, 本文不作过多关于 jackson 框架的描述, 其性质更偏向于 cheat sheet; 关于 jackson 及其使用方面的问题, 请参见另一篇文章: [对 jackson 浅层次的概念整理]();

### **相关的 maven 配置**
jackson-databind, jackson-core, jackson-annotations, 这三个构件对大部分人来说, 都是相当熟悉的: 但凡在工程内引 jackson 必定会引它们三个;
这里比较特殊的是第四个构件: jackson-datatype-joda; 这是 jackson 官方提供的针对 joda time 各种类 序列化/反序列化 的一个 'add-on module';
在 [Group: FasterXML Jackson Datatype](http://mvnrepository.com/artifact/com.fasterxml.jackson.datatype) 中有各种各样 jackson 官方提供的针对各个 organization 的插件, 包括了 guava, hibernate, 以及 joda time; 其他的插件在我日常的工作中很少使用, 而 joda time 由于其极高的使用频率, jackson-datatype-joda 也自然成为了 jackson 拓展模块中的使用常客;
``` xml
<dependency>
    <groupId>com.fasterxml.jackson.core</groupId>
    <artifactId>jackson-annotations</artifactId>
</dependency>
<dependency>
    <groupId>com.fasterxml.jackson.core</groupId>
    <artifactId>jackson-databind</artifactId>
</dependency>
<dependency>
    <groupId>com.fasterxml.jackson.core</groupId>
    <artifactId>jackson-core</artifactId>
</dependency>
<!-- joda time 的拓展模块 -->
<dependency>
    <groupId>com.fasterxml.jackson.datatype</groupId>
    <artifactId>jackson-datatype-joda</artifactId>
</dependency>
```
这里有一点需要注意的是, jackson-datatype-joda 的最低版本是 2.0.0;

### **JsonUtil 类代码**
本类在 static 代码块中设置了各种常用的 jackson 选项, 包括 JsonParser, SerializationFeature, DeserializationFeature, JsonInclude 等; 所有的选项上方都写明了注释, 以方便在使用时针对不同的场景作定制化的修改;
``` java
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.*;
import com.fasterxml.jackson.datatype.joda.JodaModule;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.util.List;
import java.util.Map;

/**
 * 针对 jackson 的工具封装类:
 * (1) 预设了 Jackson 常用的各种 Feature 选项;
 * (2) 封装了针对 normal object 的 ser / deser 方法;
 * (3) 封装了针对 List, Map 的常用 deser 情景;
 */
public class JsonUtil {

    private final static Logger logger = LoggerFactory.getLogger(JsonUtil.class);

    private final static ObjectMapper objectMapper = new ObjectMapper();
    
    // 常用的 Feature 设置
    static {
        /* json 解析相关选项 */

        // 允许 json 存在形如 // 或 /**/ 的注释
        objectMapper.configure(JsonParser.Feature.ALLOW_COMMENTS, true);
        // 允许 json 存在没用引号括起来的 field
        objectMapper.configure(JsonParser.Feature.ALLOW_UNQUOTED_FIELD_NAMES, true);
        // 允许 json 存在使用单引号括起来的 field
        objectMapper.configure(JsonParser.Feature.ALLOW_SINGLE_QUOTES, true);
        // 允许 json 存在没用引号括起来的 ascii 控制字符
        objectMapper.configure(JsonParser.Feature.ALLOW_UNQUOTED_CONTROL_CHARS, true);
        // 允许 json number 类型的数存在前导 0 (like: 0001)
        objectMapper.configure(JsonParser.Feature.ALLOW_NUMERIC_LEADING_ZEROS, true);
        // 允许 json 存在 NaN, INF, -INF 作为 number 类型
        objectMapper.configure(JsonParser.Feature.ALLOW_NON_NUMERIC_NUMBERS, true);

        /* json 序列化与反序列化的行为设置 */

        // 序列化时, 对于没有任何 public methods / properties 的类, 序列化不报错
        objectMapper.configure(SerializationFeature.FAIL_ON_EMPTY_BEANS, false);
        // 序列化时, 禁止自动缩进 (格式化) 输出的 json
        objectMapper.configure(SerializationFeature.INDENT_OUTPUT, false);
        // 序列化时, 将各种时间日期类型统一序列化为 timestamp 而不是其字符串表示
        objectMapper.configure(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS, true);
        // 序列化时, map, list 中的 null 值也要参与序列化
        objectMapper.configure(SerializationFeature.WRITE_NULL_MAP_VALUES, true);
        
        // 反序列化时, 忽略未知的字段
        objectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

        /* 字段的 include 设置 */

        // 所有实例中的空字段都要参与序列化
        objectMapper.setSerializationInclusion(JsonInclude.Include.NON_EMPTY);
        // 所有实例中的 null 字段都要参与序列化
        objectMapper.setSerializationInclusion(JsonInclude.Include.NON_NULL);

        /* jackson 模块拓展 */
        
        // 针对 joda time 定制的 ser/deser 模块
        objectMapper.registerModule(new JodaModule());
    }

    /* normal object */
    
    public static String encode(Object object) {
        try {
            return objectMapper.writeValueAsString(object);
        } catch (IOException e) {
            logger.error("jackson encode error, obj = {}", object, e);
            return "jackson encode error";
        }
    }

    public static <T> T decode(String json, Class<T> valueType) {
        try {
            return objectMapper.readValue(json, valueType);
        } catch (Exception e) {
            logger.error("jackson decode error, json = {}, class = {}", json, valueType.getName(), e);
            return null;
        }
    }

    public static JsonNode readTree(String json) throws IOException {
        try {
            return objectMapper.readTree(json);
        } catch (IOException e) {
            logger.error("jackson readTree error, json = {}", json, e);
            return null;
        }
    }

    /* decode list */

    // 方法1, 适用于已知泛型类型 T 的情况
    public static <T> List<T> decodeList(String json) throws IOException {
        try {
            return objectMapper.readValue(json, new TypeReference<List<T>>() {
            });
        } catch (IOException e) {
            logger.error("jackson decodeList(String) error, json = {}", json, e);
            return null;
        }
    }

    // 方法2, 适用于泛型类型未知的通用情况
    public static <T> List<T> decodeList(String json, Class<T> clazz) throws IOException {
        try {
            return objectMapper.readValue(json, objectMapper.getTypeFactory().constructCollectionType(List.class, clazz));
        } catch (IOException e) {
            logger.error("jackson decodeList(String, Class<T>) error, json = {}, class = {}", json, clazz.getName(), e);
            return null;
        }
    }

    /* decode map */

    // 方法1, 适用于已知泛型类型 <K, V> 的情况
    public static <K, V> Map<K, V> decodeMap(String json) throws IOException {
        try {
            return objectMapper.readValue(json, new TypeReference<Map<K, V>>() {
            });
        } catch (IOException e) {
            logger.error("jackson decodeMap(String) error, json = {}", json, e);
            return null;
        }
    }

    // 方法2, 使用于泛型类型未知的通用情况
    public static <K, V> Map<K, V> decodeMap(String json, Class<K> key, Class<V> value) throws IOException {
        try {
            return objectMapper.readValue(json, objectMapper.getTypeFactory().constructMapType(Map.class, key, value));
        } catch (IOException e) {
            logger.error("jackson decodeMap(String, Class<K>, Class<V>) error, json = {}, key = {}, value = {}",
                    json, key.getName(), value.getName(), e);
            return null;
        }
    }

}
```

### **站内相关文章**
- [对 jackson 浅层次的概念整理]()

### **参考链接**
- [How to serialize Joda DateTime with Jackson JSON processer](https://stackoverflow.com/questions/3269459/how-to-serialize-joda-datetime-with-jackson-json-processer)
- [Group: FasterXML Jackson Datatype](http://mvnrepository.com/artifact/com.fasterxml.jackson.datatype)

