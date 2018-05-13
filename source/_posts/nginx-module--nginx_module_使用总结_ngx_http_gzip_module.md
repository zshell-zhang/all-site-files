---
title: 'nginx module 使用总结: ngx_http_gzip_module'
date: 2017-12-21 15:13:33
categories:
 - nginx
 - module
tags:
 - nginx
 - nginx:module
---

> ngx_http_gzip_module 是十分有用的 nginx 模块, 其有效压缩了 http 请求大小, 节省了流量, 加快了传输速度, 提升了用户体验;
当然, 其在使用上也有一些坑, 本文将具体讨论一下相关内容;

<!--more-->

ngx_http_gzip_module 这个模块的名字其实是 [官方文档](http://nginx.org/en/docs/http/ngx_http_gzip_module.html) 里定义的; 然而在 nginx 源码里 (v1.11.2), 这个模块所在的源码文件名叫 `src/http/ngx_http_gzip_filter_module.c`;

### **gzip 模块的安装**
ngx_http_gzip_module 编译默认安装, 无需额外操作;

### **gzip 模块的配置**
gzip 模块的配置可以在如下位置:

1. nginx.conf 中的 http 指令域下;
2. 某个具体 vhost.conf 配置下的 server 指令域下;
3. 某个具体 server 指令下的 location 指令域下;

``` c
static ngx_command_t  ngx_http_gzip_filter_commands[] = {

    { ngx_string("gzip"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_HTTP_LIF_CONF
                        |NGX_CONF_FLAG,
      ngx_conf_set_flag_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_gzip_conf_t, enable),
      NULL },
      
    { ngx_string("gzip_buffers"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE2,
      ngx_conf_set_bufs_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_gzip_conf_t, bufs),
      NULL },
    
    ......
    
      ngx_null_command
};
```
以上代码片段列举了 `gzip` 指令与 `gzip_buffers`, 其余的指令与 `gzip_buffers` 在使用上下文设置上基本相同, 都是 `NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF`;
从源码中可以看出, 在 gzip 模块里, `gzip` 指令相比其他指令有一个特别的地方: 除了 http, server, location 之外, 还有一个地方可以使用 `gzip` 指令, `NGX_HTTP_LIF_CONF`, 即 location 指令域中的 if 配置下;

以下是一个典型完整的 gzip 配置:
``` bash
# 开启/关闭, 默认 off
gzip on | off;

# 当 response header 中包含 Via 头信息时, 根据 request header 中某些头信息决定是否需要开启 gzip, 默认 off
gzip_proxied off | expired | no-cache | no-store | private | no_last_modified | no_etag | auth | any;

# 根据 User-Agent 的值匹配, 针对部分请求不使用 gzip, 比如老旧的 IE6
gzip_disable "msie6";

# 在 response header 中添加 Vary: Accept-Encoding, 告诉 cache/cdn 同时缓存 压缩与非压缩两种版本的 response, 默认 off
gzip_vary on | off;

# 使用 gzip 的最小 size, size 值取决于 Content-length 的值, 默认 20 bytes
gzip_min_length 1k;

# 用于 gzip 压缩缓冲区的 num 与 size
# 建议 num 为 cpu 核心数, size 为 cpu cache page 大小
gzip_buffers 32 8k;

# 支持 gzip 模块的最低 http 版本, 默认 1.1
gzip_http_version 1.0;

# gzip 压缩级别, [1-9], 默认 1, 级别越高, 压缩率越高, 同时消耗的 cpu 资源越高
gzip_comp_level 1;

# 针对哪些 Content-type 使用 gzip, 默认是 text/html
# text/html 不需要设置到 gzip_types 中, 在其他条件满足时, text/html 会自动被压缩
# 若设置了 text/html 反而会输出 warn 
gzip_types text/css application/javascript application/json;
```

### **gzip 模块实践中遇到的坑**
**(1) gzip_comp_level 级别的选择**
在 [stackoverflow 上的一个问题](https://serverfault.com/questions/253074/what-is-the-best-nginx-compression-gzip-level) 里曾讨论到, gzip_comp_level 压缩级别, 虽然其越高压缩率越高, 但是压缩边际提升率在 level = 1 之后却是在下降的:
``` bash
# 针对 text/html
0    55.38 KiB (100.00% of original size)
1    11.22 KiB ( 20.26% of original size)
2    10.89 KiB ( 19.66% of original size)
3    10.60 KiB ( 19.14% of original size)
4    10.17 KiB ( 18.36% of original size)
5     9.79 KiB ( 17.68% of original size)
6     9.62 KiB ( 17.37% of original size)
7     9.50 KiB ( 17.15% of original size)
8     9.45 KiB ( 17.06% of original size)
9     9.44 KiB ( 17.05% of original size)

# 针对 application/x-javascript
0    261.46 KiB (100.00% of original size)
1     95.01 KiB ( 36.34% of original size)
2     90.60 KiB ( 34.65% of original size)
3     87.16 KiB ( 33.36% of original size)
4     81.89 KiB ( 31.32% of original size)
5     79.33 KiB ( 30.34% of original size)
6     78.04 KiB ( 29.85% of original size)
7     77.85 KiB ( 29.78% of original size)
8     77.74 KiB ( 29.73% of original size)
9     77.75 KiB ( 29.74% of original size)
```
随着压缩级别的提高, 更高的 cpu 消耗却换不来有效的压缩提升效率; 所以 gzip_comp_level 的最佳实践是将其设为 1, 便足够了;
&nbsp;

**(2) gzip_min_length 的陷阱**
一般经验上, 我们会将 gzip_min_length 设置为 1KB, 以防止 response size 太小, 压缩后反而变大;
只是, ngx_http_gzip_module 取决于 response headers 里的 Content-length; 如果 response 里面有这个 header, 那没有任何问题, 但是如果 response 里面没这个 header, gzip_min_length 设置就失效了;
这种情况其实并不少见: `Transfer-Encoding: chunked`; 

### **参考链接**
- [Module ngx_http_gzip_module](http://nginx.org/en/docs/http/ngx_http_gzip_module.html)
- [nginx の gzip 使用](http://www.jianshu.com/p/af6304f7cbd6)
- [加速nginx: 开启gzip和缓存](https://www.darrenfang.com/2015/01/setting-up-http-cache-and-gzip-with-nginx/)
- [标头 "Vary:Accept-Encoding" 指定方法及其重要性分析](http://www.webkaka.com/blog/archives/how-to-set-Vary-Accept-Encoding-header.html)
- [What is the best nginx compression gzip level](https://serverfault.com/questions/253074/what-is-the-best-nginx-compression-gzip-level)
- [关于 nginx 配置文件 gzip 的配置问题: 不太明白这个 gzip_proxied 的作用是什么, 应该如何正确配置](https://segmentfault.com/q/1010000002686639)

