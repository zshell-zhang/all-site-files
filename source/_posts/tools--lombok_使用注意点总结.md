---
title: lombok 使用注意点总结
date: 2019-10-11 22:10:45
categories:
 - tools
tags:
 - lombok
 - jackson
---

> lombok 绝对是开发者的好朋友, 其帮助我们节省了大量枯燥的重复代码量, 节约了开发时间; 使用 lombok 有很多技巧, 同时也会存在一些问题, 本文就着重总结一下;

<!--more-->

------

## **lombok 使用小技巧**

### **@Builder 与 @Singular 的使用**
在认识 lombok 之前, 我们一直使用 idea 自带的生成工具构建 getter, setter, 甚至还有拓展插件支持构建 builder 代码; 但自从 lombok 出现后, 包括 builder 在内, 所有这些代码自动生成工具都 "失宠" 了, 毕竟工具再方便那也要生成一大堆代码, 这肯定没有简洁的几个注解看着舒服呀!
关于 @Builder, 有一些小技巧:

1. 当使用 @Builder 的类中存在集合类型 (或者 Map 类型) 时, 可以在对应字段上使用 @Singular 实现单个元素的添加逻辑, 同时也保留了 collection 整体赋值的方法, 增强了灵活性;
2. @Builder 有一个选项 toBuilder, 如果将其置为 true, 可以生成一个实例方法 toBuilder(), 并以当前实例的字段值初始化该 builder, 在有些场景中大有用处;

@Builder 还有一个大坑需要注意, 我在下面小节中讨论: [@Builder 易踩的坑](#builder_scam);

### **@Getter 的使用技巧**
一般情况下我们会直接在 @Value / @Data 里打包一众 getter, 不过有的时候我们也可能会对某个字段的 getter 作一些特别定制, 比如以下操作:
``` java
@Getter(value = lombok.AccessLevel.PRIVATE, lazy = true)
```
这里涉及到了 @Getter 的两个选项, value 用以设置该 getter 的访问属性, lazy 用以设置该 getter 是否需要懒加载; value 选项自不用多说, 而 lazy 选项则需要详细讨论一下, 先看一个例子:
``` java
// lombok 增强前
@Getter(lazy = true)
private String str = lazyGetStr();
    
private String lazyGetStr() {
    // heavy cpu compute ignore...
    return "";
}
```
``` java
// lombok 增强后
private final java.util.concurrent.atomic.AtomicReference<Object> str = new java.util.concurrent.atomic.AtomicReference<Object>();

private String lazyGetStr() {return "";}

public String getStr() {
    Object value = this.str.get();
    if (value == null) {
        synchronized (this.str) {
            value = this.str.get();
            if (value == null) {
                final String actualValue = lazyGetStr();
                value = actualValue == null ? this.str : actualValue;
                this.str.set(value);
            }
        }
    }
    return (String) (value == this.str ? null : value);
}
```
可以看见, 使用 lazy = true 选项之后, lombok 直接将目标字段包装成了一个 AtomicReference, 并在 getter 中使用双重检查确保了并发安全, 并调用加载方法实现了 lazy get;
与 guava Supplier 等相比, 虽然其最终生成的代码并不算太简洁, 但毕竟编译之前的源码使用 lombok 注解完全屏蔽了这些逻辑, 考虑到其保证了并发安全, 并且确实实现了懒加载的功能, 所以用 @Getter(lazy = true) 作为懒加载实现方案也是一种不错的选择;

### **maven 引入 lombok 的最佳实践**
lombok 理论上是不应该被打包的, 因为它的任务都在编译阶段 annotation-processing 做完了, 运行时跑的是早就生成好的字节码, 所以使用 `provided` scope 便足矣:
``` xml
 <dependency>
    <groupId>org.projectlombok</groupId>
    <artifactId>lombok</artifactId>
    <version>${lombok.version}</version>
    <scope>provided</scope>
</dependency>
```

### **使用 lombok-maven-plugin** <span id = "use_lombok-maven-plugin">
对于一个 client-server 结构的系统来说, 我们需要给调用者暴露我们的 client api; 在 client 端那些被 lombok 注解修饰过的代码, 会在 annotation processing 下生成与本身源码 "不匹配" 的字节码; 当调用者引入了我们的 jar 包在 idea 中打开源码, 便会在第一行看到如下非常刺眼的提示:
``` bash
Library source does not match the bytecode for class XXX
```
正常情况下, 这不会造成什么实质影响, 但是确实给人一种不舒服的感觉, 总想把这个提示消灭掉才好! 也有的情况下, 调用者可能引用了我们的 client 包后直接编译报错, 如下面小节所提及的问题: [maven-compile-plugin 与 lombok 的版本匹配](#maven-compile-plugin_lombok), 这么一看, 把 lombok 暴露给 client 端的问题就有点严重了!
那么, lombok-maven-plugin 就提供了这样的一种解决方案: 帮我们输出 annotation-processing 中生成的中间代码, 并移除所有的 lombok 注解, 让 lombok 对调用方透明:
``` xml
<properties>
    <src.dir>${project.build.directory}/generated-sources/delombok</src.dir>
</properties>

<build>
    <!-- 让 maven-source-plugin 打包 lombok-maven-plugin 生成的源码 -->
    <sourceDirectory>${src.dir}</sourceDirectory>
    <plugins>
        <plugin>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok-maven-plugin</artifactId>
            <version>${lombok.plugin.version}</version>
            <configuration>
                <encoding>UTF-8</encoding>
            </configuration>
            <executions>
                <execution>
                    <phase>generate-sources</phase>
                    <goals>
                        <goal>delombok</goal>
                    </goals>
                    <configuration>
                        <addOutputDirectory>false</addOutputDirectory>
                        <sourceDirectory>src/main/java</sourceDirectory>
                        <formatPreferences>
                            <pretty/>
                        </formatPreferences>
                    </configuration>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```
以上插件配置的核心是 delombok, 其作用是处理 `sourceDirectory` 标签下的源码, 将 lombok 生成的增强后的源码输出到 `${project.build.directory}/generated-sources/delombok` 目录下; 所以光有以上配置是不够的, 因为我们需要让 maven-source-plugin 去这个 delombok 目录下, 这样才能真正将其打包到源码 jar 包中; 而 maven-source-plugin 只认 `sourceDirectory` 标签指定的源文件路径, 这个标签的默认值是 `src/main/java`, 于是我们需要覆盖它:
``` xml
<build>
    <sourceDirectory>${project.build.directory}/generated-sources/delombok</sourceDirectory>
</build>
```
这样打出的 sources.jar 便是被 delombok 加强处理后的代码了;
这里需要注意的是, 业内还存在一种说法: 如果不使用 lombok-maven-plugin, 只含有 lombok 注解的代码文件会导致调试的时候断点与实际代码行位置不匹配; 事实上这个说法是不准确的, 虽然 idea 的确告诉了我们源码和字节码不匹配, 但是 idea 只是将 .class 文件反编译后和源码作的对比, 那自然是对不上的; 可我们知道编译 java 源代码生成 .class 文件时, javac 是根据最开始的源文件而不是 annotation-processing 生成的中间代码去生成行号映射表, 所以只要我们确定拿来调试的代码和用来编译的代码是相同的, 就一定可以让断点断到正确的位置上;
与此论调恰巧相反的是, 如果我们使用 lombok-maven-plugin 的方式不正确, 反倒是有可能导致断点与源码匹配不上; 在下面的小节 [lombok-maven-plugin 灵活指定 sourceDirectory](#lombok-maven-plugin_sourceDirectory) 中我将继续讨论与之相关的 lombok-maven-plugin 引起的 sourceDirectory 混乱的解决方案;

### **使用 lombok.config 全局配置** <span id = "lombok_config">
我们可以在工程的根目录下面创建一个 lombok.config 文件, 用作 lombok 的全局配置, 举例如下:
``` properties
# 在类构造器上自动添加 @java.bean.ConstructorProperties 注解
lombok.anyConstructor.addConstructorProperties = true
# 生成链式 setter, 将 setter 的返回值由 void 改为 this
lombok.accessors.chain = true
lombok.singular.auto = true
lombok.singular.useGuava = true
```
更多详细的选项可以使用如下命令查询:
``` bash
java -jar lombok.jar config -g --verbose
```

## **lombok 使用问题**

### **@Data 与 @Value 的问题**
@Data 与 @Value 都能够帮助我们生成一个标准 java 类的众多基础方法, 包括:
``` java
toString();
equals(final Object o);
hashCode();
getter
```
那么这两者的区别是什么呢? 宽泛得概括一下: @Data 生成的是可变的 pojo, 而 @Value 生成的是一个不可变的 pojo; 详细得看, 主要有如下区别:
**区别之一**在于其生成的构造器:

1. @Data 采用的构造器策略是 @RequiredArgsConstructor, 其只有 final, @NonNull (lombok) 字段才会加入构造器参数, 否则将生成一个 public 无参构造器 (当存在 final 与 @NonNull 时, 会同时生成 private 无参构造器);
2. @Value 采用的构造器策略是 @AllArgsConstructor, 其默认所有字段都加入构造器参数 (final 且已经默认赋值的字段不会加入);

**区别之二**在于 @Value 还打包了一个 @FieldDefaults(makeFinal=true, level=AccessLevel.PRIVATE), 主要是用于自动添加 final / private 关键字, 也就是说 @Value 修饰的类所有的字段默认都会给我们加上 private final, 除非主动在字段上设置属性才会改变:
``` java
@FieldDefaults(makeFinal=false, level=AccessLevel.PUBLIC)
```
这一细节我们一定要知悉, 正因此 @Value 默认是不生成 setter 的 (全是 final, 常规操作不能改变), 而 @Data 则会为所有非 final 字段生成 setter;
另外, 由于 @Value 修饰的字段都是 private final 的, 如果我们需要对 @Value 修饰的类使用 json 反序列化工具, 需要尤其注意:

1. jackson: jackson 的反序列化默认是调用无参构造器实例化对象之后再去赋值, 虽然 jackson 的 MapperFeature.ALLOW_FINAL_FIELDS_AS_MUTATORS 默认配置是有能力修改被 final 修饰的字段, 但这毕竟是违背正常语义的;
2. fastjson: 研究不多, 但在默认配置下, 无法对 @Value 修饰的对象正常赋值, 字段均被初始化为 null;

但这并不是说 @Value 就不适用于反序列化, 以 jackson 为例: jackson 有一个注解叫做 `@JsonCreator`, 其作用是调用指定的有参构造器去初始化对象; 所以针对被 @Value 修饰的类, 可以使用 @JsonCreator 配合 @JsonProperty 实现属性的值注入; 不过, 如果每个类都要自己去实现 @JsonCreator 逻辑未免显得太繁琐, 还好 jackson 还支持 javabean 标准注解 `@java.bean.ConstructorProperties`, 其功能等效于 @JsonCreator, 那么在 [上一小节](#lombok_config) 中已经提到了, 可以在 lombok.config 中添加 `lombok.anyConstructor.addConstructorProperties = true` 以实现自动为每个类添加 `@java.bean.ConstructorProperties` 注解;

**区别之三**在于 @Value 生成的类也是被 final 修饰的, 意味着其不可被继承;

### **@Builder 易踩的坑** <span id = "builder_scam">

我们可能有这样的场景: 为一个类使用 lombok 生成 builder 方法, 其中有部分字段我们预设了默认值, 最自然的写法可能如下:
``` java
@Builder
public class Test {
    private String str = "default";
}
```
然而以上代码会被渲染成如下样子:
``` java
public class Test {
    private String str = "default";
    
    Test(final String str) {this.str = str;}
    
    public static class TestBuilder {
        private String str;
        
        TestBuilder() {}
        
        public TestBuilder str(final String str) {
            this.str = str;
            return this;
        }
        
        public Test build() {return new Test(str);}
    }

    public static TestBuilder builder() {return new TestBuilder();}
}
```
很显然, 如果在使用 builder 方法构建对象时没有为 str 赋值, str 就是个 null, 而不是给定的默认值, 对此 lombok 给出的解决的办法是, 为需要默认值的字段添加 @Builder.Default 注解:
``` java
@Builder
public class Test {
    @Builder.Default
    private String str = "default";
}
```
以上代码确实能使默认值在 builder 中生效, 但是又导致另一个坑: 如果不使用 builder 而是自己 new 出对象, 默认值依旧不生效, 这里需要特别注意;

### **maven-compile-plugin 与 lombok 的版本匹配** <span id = "maven-compile-plugin_lombok"> 
有的项目一旦引入了 lombok 或间接引入 lombok 的 jar 包, 使用 maven-compile-plugin 编译时会报如下奇怪的错误:
``` bash
XXX.java:[xx,yy] error: cannot find symbol
```
看起来像是编译时没有正常做 annotation-processing, 导致调用本该是 lombok 生成的方法时找不到了; 经过搜索, 发现了 lombok 低版本的一个 bug: [stackoverflow 地址](http://stackoverflow.com/questions/34358689), 这个 bug 导致 2.3.2 版本以下的 maven-compiler-plugin 与 lombok 1.14 ~ 1.16 版本发生冲突! 这个 stackoverflow 提问引起了 lombok 官方注意, 并于 lombok 1.16.9 版本修复了该问题: [always return ShadowClassLoader. #1138](https://github.com/rzwitserloot/lombok/pull/1138);
所以从当前来看, 解决这个问题的最好办法就是将 lombok 版本升级到 1.16.9+; 当然, 我们在上面的小节中已经提及了该问题: [使用 lombok-maven-plugin](#use_lombok-maven-plugin), 如果我们有办法消除素有的 lombok 注解, 也就不存在这个问题了;

### **解决 lombok-maven-plugin 的后遗症** <span id = "lombok-maven-plugin_sourceDirectory">
在上面的小节中已经提到, 如果使用 lombok-maven-plugin 的方式不正确, 就有可能导致断点与源码匹配不上; 具体来说, 就是当我们重新以 delombok 目录覆盖了默认的 sourceDirectory 配置之后, javac 便以新的路径作为源码目录生成对应的行号映射表, 这对于 client 端来说是没问题的, 但是对于 server 端的代码, 我们在调试时用的是 lombok 增强之前我们自己写的代码, 这便与编译使用的代码不一致了, 自然就导致了调试走不到断点里去的问题, 为了能正确调试 server 端的代码, 我们需要配置其在 server 模块不使用 delombok, 从而让 javac 去我们自己的源文件目录编译:
``` xml
<!-- server 模块覆盖父 pom 的 properties 配置 -->
<properties>
    <src.dir>src/main/java</src.dir>
</properties>
```
另外, 使用 lombok-maven-plugin 还有一个副作用, 其在 `${project.build.directory}/generated-sources/delombok` 目录中生成了与我们自己源文件相同签名的源代码, idea 会检测到重复类并导致大量红色波浪线错误提示, 本地无法正常构建, 无法单元测试; 要想解决这个问题, 我们只能使用 profile 来区分不同的编译环境, 本地编译我们使用一套特殊 profile, 不作 delombok, 线上打包发布使用另一套 (不指定 profile 即可), 引导其使用 delombok 作代码增强:
``` xml
<profiles>
    <!-- mvn -U clean compile -Dmaven.test.skip=true -Denforce.skip=true -P ide -->
    <!-- 本地环境用以上命令编译, 可以避免 lombok-maven-plugin 导致的 sourceDirectory 混乱 -->
    <profile>
        <id>ide</id>
        <properties>
            <src.dir>src/main/java</src.dir>
        </properties>
        <build>
            <plugins>
                <plugin>
                    <groupId>org.projectlombok</groupId>
                    <artifactId>lombok-maven-plugin</artifactId>
                    <version>1.16.22.0</version>
                    <configuration>
                        <!-- 本地环境下编译不用 delombok -->
                        <skip>true</skip>
                    </configuration>
                </plugin>
            </plugins>
        </build>
    </profile>
</profiles>
```

### **lombok 与 aspectj 的冲突处理**
其实不仅仅是 aspectj, 只要是需要在编译上做手脚的工具, 都可能与 lombok 发生冲突; 毕竟 lombok 的工作时机也是在编译期, 如果不协调出一个执行顺序, 就有可能互相覆盖, 导致编译错误;
lombok 与 aspectj 的冲突属于比较典型的场景, 因为这两者都比较常用, stackoverflow 上有很多遇到类似问题的人; 鉴于这个问题的解决主要在于 aspectj 的配置改变, 本文便不过多讨论, 相关内容请见另一篇文章: [asepctj 使用总结]();

## **站内相关文章**
- [asepctj 使用总结]()

## **参考链接**
- [Lombok 实战 —— @NoArgsConstructor, @RequiredArgsConstructor, @AllArgsConstructor](https://blog.csdn.net/weixin_41540822/article/details/86606513)
- [lombok-maven-plugin delombok你的源码](https://www.jianshu.com/p/5411e9efd577)
- [Maven build cannot find symbol when accessing project lombok annotated methods](http://stackoverflow.com/questions/34358689)
- [always return ShadowClassLoader. #1138](https://github.com/rzwitserloot/lombok/pull/1138)
- [Lombok @Builder.Default 之坑](https://www.firegod.cn/2019/07/lombok-builder-default-之坑)
- [Configuration system](https://www.projectlombok.org/features/configuration)

