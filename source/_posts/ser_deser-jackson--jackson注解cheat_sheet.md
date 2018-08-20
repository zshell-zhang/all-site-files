---
title: "jackson 注解 cheat sheet"
date: 2017-02-15 18:13:20
categories:
 - ser/dser
 - jackson
tags:
 - cheat sheet
 - jackson
 - json
---

> 本文是 [JsonUtil 类 cheat sheet](https://zshell.cc/2016/08/11/tools-jackson--JsonUtil类cheat_sheet/) 的姊妹篇;
[JsonUtil 类 cheat sheet](https://zshell.cc/2016/08/11/tools-jackson--JsonUtil类cheat_sheet/) 侧重于代码层面对 jackson API 的使用, 是一个 "宏观" 的行为: 其设置对全局皆有效; 而本文则着重讨论 javabean 各成员上 jackson 注解的使用, 是一个 "微观" 的行为: 通过注解的约定, 可以精细化控制具体的类, 字段及方法 的序列化 / 反序列化行为, 使 jackson 能够定制化得处理各个 javabean;

<!--more-->

------

### **字段是否参与序列化**
控制字段是否参与序列化是精细化管理 jackson 行为的典型案例:
``` java
public class Bean {
    // 总是序列化, 默认情况
    @JsonInclude(JsonInclude.Include.ALWAYS)
    private String str1;

    // 只有不为 null 时才参与序列化
    @JsonInclude(JsonInclude.Include.NON_NULL)
    private String str2;

    /** 
      * 只有不为 "空" 时才参与序列化:
      * 1. 满足 NON_NULL 与 NON_ABSENT (guava Optional)
      * 2. Collection size 不为 0
      * 3. String != ""
      * 4. Integer != 0
      * 5. Boolean != false
      */
    @JsonInclude(JsonInclude.Include.NON_EMPTY)
    private String str3;
}
```

### **反序列化相关注解**
jackson 在序列化时使用反射, 故而其对目标类的构造器情况完全没有要求; 然而在反序列化时, jackson 默认使用无参构造器创建实例, 如果对象没有无参构造器, 也没有任何注解提示 jackson, 则会反序列化失败:
``` java
Caused by: com.fasterxml.jackson.databind.exc.InvalidDefinitionException: Cannot construct instance of `xxx` 
(no Creators, like default construct, exist): cannot deserialize from Object value (no delegate- or property-based Creator)
```
如果想提示 jackson 使用有参构造器, 需要注解如下:
``` java
@JsonCreator
public Bean(String str) {
    this.str = str;
}
```
不过, 在大部分场景下, 光靠一个 `@JsonCreator` 注解是不够的, 只要构造器含有多于一个的参数, jackson 便会报如下异常:
``` java
Caused by: com.fasterxml.jackson.databind.exc.InvalidDefinitionException: Argument #0 of constructor [constructor for xxx, annotations: 
{interface com.fasterxml.jackson.annotation.JsonCreator=@com.fasterxml.jackson.annotation.JsonCreator(mode=DEFAULT)}] has no property name annotation; must have name when multiple-parameter constructor annotated as Creator
```
此时需要另一个注解 `@JsonProperty` 放置在构造器的每一个参数上:
``` java
@JsonCreator
public Bean(@JsonProperty("str1") String str1,
            @JsonProperty("str2") String str2) {
    this.str1 = str1;
    this.str2 = str2;
}
```
其实, `@JsonProperty` 的使用是独立于 `@JsonCreator` 的, 其还可以作用于成员字段或成员方法上, 不过作用却是一致的, 均是用于反序列化时作为 json 字段与类成员字段的映射;
当然其中也有一个细微差别, 作用于字段或方法上的 `@JsonProperty` 的 value 是可以为空的: `@JsonProperty` 的 value 如果为空, 则 jackson 会寻找 json 字符串中与该字段名一致的 key; 如果 value 非空, 则 jackson 会寻找 json 字符串中与该 value 一致的 key;
而对于构造器方法, `@JsonProperty` 的 value 是不可以为空的, 毕竟构造器方法的参数名是可以与成员字段名不一样的;

### **多态反序列化**
有些特殊的场景下, 一串 json 可能对应于继承一个父类的多个子类, 然而究竟对应于哪个子类, 却无法在代码中提前确定下来, 只能以父类型作为 `valueType` 参与反序列化, 这种时候就需要使用 jackson 的多态反序列化功能:
``` java
@JsonTypeInfo(use = JsonTypeInfo.Id.CLASS, include = JsonTypeInfo.As.PROPERTY, property = "@class")
@JsonSubTypes({@JsonSubTypes.Type(value = Child1.class, name = "Child1"), @JsonSubTypes.Type(value = Child2.class, name = "Child2")})
class Parent {
    public String name;
    protected Parent() {}
}

class Child1 extends Parent {
    public double param1;
    public Child1() {}
}

class Child2 extends Parent {
    boolean param1;
    public int param2;
    public Child2() {}
}
```
对于以上配置, 以子类 Child1 为例, 相应的 json 字符串内容如下:
``` javascript
jsonStr = {
    // 指定子类类型为 Child1.class
    "@class": "Child1",
    "name": "child1",
    "param1": 3.14
}
```
要让 jackson 识别传入的 json 串究竟表示哪一个子类, json 中就必须要存在父类中定义 `@JsonTypeInfo` 时约定的 property name, 以上例子中的 property 是 "@class"; 另外, property "@class" 对应的值也必须是父类中定义 `@JsonSubTypes` 时约定的几个 name, jackson 以此确定究竟反序列化为哪个子类, 以上例子中, "Child1" 对应于 Child1.class, "Child2" 对应于 Child2.class;
现在, 使用以下代码便可以让 jackson 将刚才定义的 jsonStr 串反序列化为一个 Child1 实例, 而代码中我们仅仅需要指定 `valueType` 为 Parent.class:
``` java
objectMapper.readValue(jsonStr, Parent.class);
```

### **循环依赖的解除 (字段的排除)**
有时候会遇到蛋疼的问题: 两个类互相引用, 这时 jackson 会判定其发生循环依赖, 无法序列化; 对这种情况我们就需要手动解开循环依赖, 比较典型的方法是忽略涉及循环依赖的字段, 不过这样可能造成信息丢失:
``` java
public class Bean {
    // str1 序列化时会被忽略, 但反序列化时不会被忽略
    @JsonBackReference
    @JsonManagedReference
    private String str1;
    
    // str2 序列化与反序列化时都会被忽略, @JsonBackReference 单独使用效果同 @JsonIgnore
    @JsonBackReference
    private String str2;
    
    // str3 序列化与反序列化时都会被忽略
    @JsonIgnore
    private String str3;
    
    // 对于str4, 只有序列化时会被忽略, 反序列化时不会被忽略(单独作用于 getter, 不作用于 setter)
    private String str4;
    
    @JsonIgnore
    public String getStr4() { return str4; }
    public void setStr4(String str) { this.str4 = str; }
}
```

### **站内相关文章**
- [JsonUtil 类 cheat sheet](https://zshell.cc/2016/08/11/tools-jackson--JsonUtil类cheat_sheet/)

### **参考链接**
- [jackson annotations 注解详解](http://a52071453.iteye.com/blog/2175398)

