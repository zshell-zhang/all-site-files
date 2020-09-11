> 我的轻量级跨平台 hexo 博客, 按照以下操作执行, 在任何机器上开箱即用!

### **下载 node**
https://nodejs.org/en/download/

### **下载 hexo**
``` bash
npm install -g hexo-cli
```

### **拉取远程资源**
(0) 初始化 .ssh 目录, 并加入代码托管网站的我的账户信任列表:
``` bash
ssh-keygen -t rsa -C "service_impl@163.com"
```
&nbsp;
找到合适的位置, 作为博客数据本地存放的目录;
(1) 拉取自动化脚本, js 框架, 文章原始内容:
``` bash
> git clone https://github.com/zshell-zhang/all-site-files.git
> move all-site-files blogs
```
(2) 拉取图片资源(与 blogs 同父目录):
``` bash
> git clone git@github.com:zshell-zhang/static-content.git
```
(3) 拉取 site 渲染内容:
``` bash
> cd blogs
> git clone git@github.com:zshell-zhang/zshell-zhang.github.io.git

# 将 site 远程仓库改名
> mv zshell-zhang.github.io .deploy_git
```

### **使用方法**
新建编辑文章:
``` bash
> cd blogs
# 示例: 一级目录-二级目录--标题
> ./new_post.sh zookeeper-curator--curator_使用注意点总结
```
调试预览文章:
``` bash
> cd blogs
> hexo server
```
发布文章:
``` bash
> cd blogs
> ./deploy.sh
```

### **参考链接**
- [使用LaTex添加公式到Hexo博客里](https://www.jianshu.com/p/68e6f82d88b7)
