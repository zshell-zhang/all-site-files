---
title: http status code 典型问题总结
date: 2017-03-06 23:27:25
categories:
 - web
tags:
 - http
 - tomcat
 - spring
 - spring-mvc
---

> 本人根据自身的工作经历, 以一个 java dev 的视角, 总结了一些 http status code 的常见问题, 原因及解决办法;
这些问题涉及到的系统或技术栈包括了 nginx, tomcat, spring(springMVC), elasticsearch 等等;

<!--more-->

------

## **3XX 重定向系列**
### **301 Moved Permanently**
### **302 Found**
### **303 See Other**
### **304 Not Modified**
此状态码需要http header的配合:

### **307**
## **4XX 客户端错误系列**
4XX 为客户端请求错误相关的 status code;
以下为各种 4XX status code 的含义以及可能的对应于常用 web server tomcat 或常用 web 框架 springMVC, 返回此 code 的原因;
其中, tomcat 的版本为 7.0.47.0, springMVC 的版本为 4.1.8.RELEASE
&nbsp;
### **400 Bad Request**
一般是请求参数错误, 参数个数少了或者参数名与 api 要求不符;
&nbsp;
### **401 Unauthorized**
请求未认证, 如果服务端需要用户密码认证而 request 未携带相关 header 则会返回此 code;
如果是 chrome 收到 401, 便会弹出内置的登陆框, 让用户输入用户密码;
如果需要手动发送 http 请求作认证, 需加入如下header:
``` bash
# base64_encoded_content 是 username=password 被 BASE64 编码后的序列
Authorization: Basic base64_encoded_content
```
其中有两个注意点:

1. `Authentication` header 的 value 必须是以 Basic 为前缀, 空一格后跟着 BASE64 编码的内容;
2. BASE64 编码的内容是 username=password, 其中间的 `=` 不能少; 最方便的生成该编码的方法就是使用 chrome 或者 postman 自动生成, 然后查看 code 即可;

&nbsp;
### **403 Forbidden**
禁止访问(非法访问), 一般请求认证失败后返回此 code;
&nbsp;
### **404 Not Found**
找不到资源, 一般在 springMVC 工程里, 这种错误遇到的常见的情况是请求静态资源 (例如 healthcheck.html) 发生 404;
通常这种错误的原因是 springMVC 的 DispatcherServlet 拦截了所有的请求, 但是对静态资源的请求却又找不到路由处理器, 从而报出 404;
解决的方案主要有三种:
(1) web.xml 里配置 tomcat 的 default servlet:
``` xml
<servlet-mapping>
    <servlet-name>default</servlet-name>
    <url-pattern>*.html</url-pattern>
</servlet-mapping>
```
另外, 除了 *.html 之外, 其他静态资源亦可一并配置:
``` xml
    <servlet-mapping>
        <servlet-name>default</servlet-name>
        <url-pattern>*.js</url-pattern>
    </servlet-mapping>
    <servlet-mapping>
        <servlet-name>default</servlet-name>
        <url-pattern>*.css</url-pattern>
    </servlet-mapping>
    <servlet-mapping>
        <servlet-name>default</servlet-name>
        <url-pattern>*.jpg</url-pattern>
    </servlet-mapping>
```
此配置需放在 DispatcherServlet 前面从而在 springMVC 之前被拦截;

(2) 在 mvc-context.xml 中配置 mvc namespace 下的 default-servlet-handler 标签:
``` xml
<mvc:default-servlet-handler/> 
```

(3) 在 mvc-context.xml 中配置 mvc namespace 下的 resources 标签:
``` xml
<mvc:resources mapping="/**" location="/"/>
```
&nbsp;
### **405 Method Not Supported**
&nbsp;
### **406 Not Acceptable**
服务器端无法提供客户端在 `Accept` header 中给出的媒体类型; 在springMVC 工程里, 这种比较常见的情况, 一般和 json 有关, 往往还需要前端 (比如 ajax) 配合; 因为, 普通的请求, request 报文里一般不会指明 `Accept` header, 那么无论后端返回什么, 哪怕是报错也好, 都不至于造成 406; 而对于如下 ajax 请求:
``` javascript
$.ajaxFileUpload({
    data: fetch_form_data('form_id'),
    url: '/xxx/yyy/zzz'
    type: 'post',
    dataType: 'json',   // 指定了 Accept header 为 application/json
    success: function(data) { ... },
    error: function(data, status, e) { ... }
});
```
可以看到, 该 ajax 请求指定了 dataType 为 json, 这会在该 ajax 构造的 request 中追加 `Accept` header, value 为 `application/json`, 这就要求服务器端必须返回 json 类型的数据;
然后在后端 springMVC 工程里, 有如下几种情况可能会造成 web server 认为无法提供客户端指定的媒体类型:
(1) Controller 里的方法上没加 `@ResponseBody` 注解, 导致 springMVC 未能根据方法返回值正确推断媒体类型:
``` java
@RequestMapping(value = "/xxx", method = RequestMethod.POST)
@ResponseBody   // 该注解使得 springMVC 框架认为该请求需要转化为 json (should be bound to the web response body)
public WebResponse handleRequest(@RequestParam("xxx") String xxx) {
    ......
    return WebResponse.success(instance);
}    
```
或者更干脆的, 可以对该 Controller 直接使用 `@RestController` 注解, 相当于让所有的方法都被自动加上了 `@ResponseBody`:
``` java
/**
 * A convenience annotation that is itself annotated with {@link Controller @Controller}
 * and {@link ResponseBody @ResponseBody}.
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Controller
@ResponseBody
public @interface RestController { ... }
```
(2) mvc-context.xml 中, 没有注册 "注解驱动":
``` xml
<mvc:annotation-driven/>
```
这个注解驱动的功能是如此之强大以至于在一般的 springMVC 项目中都不会落下它, 顶多就是覆盖其中部分设置以作微调 (详细的内容请参考: [&lt;mvc:annotation-driven/&gt; 所做事情的详细梳理]());
当然, 如果不想被 &lt;mvc:annotation-driven/&gt; 支配而又要避免 406 错误, 就需要主动注入 `RequestMappingHandlerAdapter`, 而这是一个十分复杂的 bean, 所以并不建议这么搞;
(3) 如果第一点和第二点都没有问题却依然报 406 的话, 那么极有可能是 jackson 相关依赖的版本兼容性问题; 在默认的负责读写 json 的 `MappingJackson2HttpMessageConverter` 中 (v4.1.8.RELEASE), 有这么一句注释:
> Compatible with Jackson 2.1 and higher.

而我在更高的 spring 版本里(比如 master), jackson 的最低兼容版本已经到了 2.9; 可见, 如果项目里的 jackson 版本不能与 spring 保持同步, 便极有可能导致序列化/反序列化失败, 进而导致 406 错误;
&nbsp;
### **407**
### **408 Request Timeout**
### **409 Confilct**
### **410**
### **411**
### **412**
### **413 Entity Too Large**
### **414**
### **415 Not supported media type**
### **416**
### **417**
### **429 Too Many Requests**

