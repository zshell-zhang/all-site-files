---
title: maven-assembly-plugin 使用总结
date: 2016-11-19 23:42:40
categories:
 - tools
 - maven
tags:
 - mvn:plugins
---

> 本文在 Apache Maven 的官方文档上, 结合自己的一些项目经历: [在 Apache Spark 中使用 springframework 的一次实践](), 总结了一些 assembly 插件的使用方式和一些注意事项, 以作备忘;
另外, 由于 assembly 的 核心配置文件中可配置项种类繁多, 为了体现直观性, 文本直接在一段 '丰富而典型' 的配置文件 case 上, 以注释的形式作为每个配置项的释义;

<!--more-->

------

### **pom.xml 中的配置项**
一段典型的 assembly 插件的 mvn 配置:
``` xml
<plugin>
    <artifactId>maven-assembly-plugin</artifactId>
    <version>${assembly.plugin.version}</version>
    
    <configuration>
        <!-- 打包后的包名是否需要追加 assembly 配置文件的 id -->
        <appendAssemblyId>false</appendAssemblyId>
        <!-- 最终生成的打包文件输出的路径 -->
        <outputDirectory>${project.build.directory}/target</outputDirectory>
        <!-- 定义核心配置文件的访问路径 -->
        <descriptors>
            <descriptor>${basedir}/src/main/assembly/client.xml</descriptor>
            <descriptor>${basedir}/src/main/assembly/server.xml</descriptor>
        </descriptors>
    </configuration>
    
    <executions>
        <execution>
            <!-- 一般运行在 package phase -->
            <phase>package</phase>
            <goals>
                <!-- assembly 插件中唯一的核心 goal, 另外一个 goal 是 assembly:help -->
                <goal>single</goal>
            </goals>
        </execution>
    </executions>
</plugin>
```

&nbsp;
### **核心配置文件**
以下 assembly 核心配置文件包含了最常用的几种配置项, 该文件习惯上放置在 `${basedir}/src/main/assembly/` 目录里, 并如上一节所示, 在 `configuration -> descriptors` 路径下定义加载:
``` xml
<assembly xmlns="http://maven.apache.org/ASSEMBLY/2.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/ASSEMBLY/2.0.0 http://maven.apache.org/xsd/assembly-2.0.0.xsd">
          
    <!-- assembly 配置文件id -->
    <id>deploy</id>
    <!-- 
        目标打包文件的格式, 支持格式如下:
            jar, war, zip, tar, tar.gz, tar.bz2 等 
    -->
    <formats>
        <format>jar</format>
    </formats>
    
    <!-- 是否以 ${project.build.finalName}, 作为所有被打包文件的基目录, 默认 true -->
    <includeBaseDirectory>false</includeBaseDirectory>
    <!-- 显式定义 所有被打包文件的基目录 -->
    <baseDirectory>${project.build.finalName}</baseDirectory>
    
    <!-- 独立文件的收集 -->
    <files>
        <file>
            <!-- 待收集的文件名 -->
            <source>LICENSE.txt</source>
            <!-- 收集到目标文件的相对路径 -->
            <outputDirectory>/</outputDirectory>
        </file>
        <file>
            <source>NOTICE.txt</source>
            <outputDirectory>/</outputDirectory>
            <!-- 将 ${...} 占位符 替换为实际的内容, 默认 false -->
            <filtered>true</filtered>
        </file>
    </files>
    
    <!-- 目录的收集 -->
    <fileSets>
        <fileSet>
            <!-- 目录名 -->
            <directory>${project.basedir}/src/main/resources</directory>
            <outputDirectory>/</outputDirectory>
        </fileSet>
        <fileSet>
            <directory>${project.basedir}/src/doc</directory>
            <!-- 是否使用默认的排除项, 排除范围包括版本控制程序产生的 metadata 等, 默认 true -->
            <useDefaultExcludes>true</useDefaultExcludes>
            <outputDirectory>/doc</outputDirectory>
        </fileSet>
    </fileSets>
    
    <!-- 依赖的收集 -->
    <dependencySets>
        <dependencySet>
            <outputDirectory>/lib</outputDirectory>
            <!-- 是否将本次构建过程中生成的 主构件 加入到依赖的收集中, 默认 true -->
            <useProjectArtifact>true</useProjectArtifact>
            <!-- 是否将本次构建过程中生成的 附加构件 也加入到依赖的收集中, 默认 false -->
            <useProjectAttachments>false</useProjectAttachments>
            <!-- 是否将依赖都解包为普通的目录文件放入 outputDirectory, 默认 false -->
            <unpack>false</unpack>
            <!--  -->
            <scope>runtime</scope>
            <!-- 是否让该 dependencySets 收集具有传递性, 即递归地将 dependency 间接依赖的 dependencies 都收集到打包文件中, 默认 true -->
            <useTransitiveDependencies>true</useTransitiveDependencies>
            <!-- 
                includes/excludes 的格式:
                    groupId:artifactId:type:classifier
                    groupId:artifactId
                    groupId:artifactId:type:classifier:version
                支持使用 * 通配, * 可以完整匹配由多个 ':' 分割的 section;
            -->
            <excludes>
                <exclude>org.apache.commons:commons-logging:jar</exclude>
                <exclude>*:war</exclude>
            </excludes>
            <!-- 是否让 includes/excludes 具有传递性, 即递归地让指定的 dependency 间接依赖的 dependencies 都被 include/exclude, 默认 false -->
            <useTransitiveFiltering>true</useTransitiveFiltering>
        </dependencySet>
    </dependencySets>
    
</assembly>
```

&nbsp;
### **使用 assembly 的一些注意事项**
* 使用 assembly 打包成需要独立运行的 jar 时, 若无特殊需要显式定义 CLASSPATH,  则在核心配置文件中不应该定义 `baseDirectory`, 并将 `includeBaseDirectory` 置为 `false`;
因为 assembly 生成的 jar 包在 `/META-INF/MANIFEST.MF` 文件中默认不会定义 `Class-Path`, 即 CLASSPATH 默认就是 jar 中的基目录;

``` bash
# assembly 生成的 /META-INF/MANIFEST.MF
Manifest-Version: 1.0
Archiver-Version: Plexus Archiver
Created-By: 25.151-b12 (Oracle Corporation)
```
* 核心配置文件中的 `outputDirectory` 皆是以目标打包文件的根为相对路径的; 无论是否在路径最前面添加 `/`, 都不会有影响;
* assembly 2.2 之前的版本, 在涉及到一些复杂第三方依赖, 多个不同的 jar 包中含有同名的文件 (如 org.springframework) 时, 使用 assembly 打包时会遇到一个 bug:
assembly 只把第一次遇到的同名文件加入目标打包文件, 其后遇到的同名文件, 则被 skip 掉 ( 详见官方 issue: [When using mulitple Spring dependencies, the files from META-INF (from the Spring jars) overwrite each other in an executable jar-with-dependencies](http://jira.codehaus.org/browse/MASSEMBLY-360) );
当然, 在这个 issue 当中, 触发此 bug 还有一个必要条件是将 dependencySet 中的 unpack 置为 true, 这样多个 spring artifact META-INF/ 中的 spring.handlers / spring.schemas / spring.tooling 等文件才会同名冲突;

&nbsp;
### **关于 assembly 命令**
除了上述以 配置文件 + maven core phase 回调的形式使用 assembly 插件之外, assembly 插件的 goals 也可以命令的形式执行:
``` bash
mvn clean assembly:single
mvn assembly:help
```
由于使用 assembly 命令的场景不多见, 此处不再详述, 详见 maven 官方介绍: [assembly:single](http://maven.apache.org/plugins/maven-assembly-plugin/single-mojo.html)

&nbsp;
### **站内相关文章**
- [在 Apache Spark 中使用 springframework 的一次实践]()

&nbsp;
### **参考链接**
- [Apache Maven Assembly Plugin: Assembly](http://maven.apache.org/plugins/maven-assembly-plugin/assembly.html)
- [Filtering Some Distribution Files](https://maven.apache.org/plugins/maven-assembly-plugin/examples/single/filtering-some-distribution-files.html)
- [8.5. Controlling the Contents of an Assembly](http://books.sonatype.com/mvnref-book/reference/assemblies-sect-controlling-contents.html)
- [Quick Note on All includes and excludes Patterns](https://maven.apache.org/plugins/maven-assembly-plugin/advanced-descriptor-topics.html)

