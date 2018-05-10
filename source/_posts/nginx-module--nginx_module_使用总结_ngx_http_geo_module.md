---
title: 'nginx module 使用总结: ngx_http_geo_module'
date: 2018-05-13 15:45:02
categories:
 - nginx
 - module
tags:
 - nginx:module
---

> 在处理与 ip 地址相关的 nginx 逻辑上, ngx_http_geo_module 往往能发挥一些有力的作用; 其封装了大量与 ip 地址相关的匹配逻辑, 使得处理问题更加便捷高效;

<!--more-->

------

ngx_http_geo_module 最主要的事情是作了一个 ip 地址到其他变量的映射; 一说到映射, 我们便会想起另一个模块: ngx_http_map_module; 从抽象上讲, geo 模块确实像是 map 模块在 ip (geography) 细分领域内的针对性功能实现;

### **geo 模块的安装**
ngx_http_geo_module 编译默认安装, 无需额外操作;

### **geo 模块的配置**
geo 模块的配置只能在 nginx.conf 中的 http 指令下, 这与 ngx_http_map_module 模块是一致的:
``` c
static ngx_command_t  ngx_http_geo_commands[] = {

    { ngx_string("geo"),
      NGX_HTTP_MAIN_CONF|NGX_CONF_BLOCK|NGX_CONF_TAKE12,
      ngx_http_geo_block,
      NGX_HTTP_MAIN_CONF_OFFSET,
      0,
      NULL },

      ngx_null_command
};
```

geo 模块的配置模式如下:
``` bash
geo [$address] $variable {
    default     0;
    127.0.0.1   1;
}
```
其中, \$address 可选, 默认从 `$remote_addr` 变量中获取目标 client ip address; 如果使用其他变量作为 ip 地址, 该变量须要是一个合法的 ip 地址, 否则将以 "255.255.255.255" 作为代替;
以下是一个典型的 geo 模块配置, \$address 已缺省默认为 `$remote_addr`:
``` bash
geo $flag {
    # 以下是一些设置项
    
    # 定义可信地址, 若 $remote_addr 匹配了其中之一, 将从 request header X-Forwarded-For 获得目标 client ip address
    proxy           192.168.100.0/24;
    delete          127.0.0.0/16;
    # 默认兜底逻辑
    default         -1;
    # 定义外部的映射内容
    include         conf/geo.conf;
    
    # 以下是具体的映射内容
    
    # 可以使用 CIDR 匹配
    192.168.1.0/24  0;
    # 精确匹配
    10.64.0.5       1;
}
```
除了以上的典型用法之外, geo 模块还有一种地址段范围的匹配模式:
``` bash
geo $flag {
    # 需放在第一行
    ranges;
    192.168.1.0-192.168.1.100       0;
    192.168.1.100-192.168.1.200     1;
    192.168.1.201-192.168.1.255     2;
}
```


### **参考链接**
- [Module ngx_http_geo_module](http://nginx.org/en/docs/http/ngx_http_geo_module.html)
- [nginx geo 使用方法](http://www.ttlsa.com/nginx/using-nginx-geo-method/)

