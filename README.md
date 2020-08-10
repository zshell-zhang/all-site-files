> 跨平台, 开箱即用!

### **下载 node**
https://nodejs.org/en/download/

### **下载 hexo**
``` bash
npm install -g hexo-cli
```

### **拉取远程资源**
找到合适的位置, 作为博客数据本地存放的目录;
(1) 拉取自动化脚本, js 框架, 文章原始内容:
``` bash
> git clone https://github.com/zshell-zhang/all-site-files.git
# 或者
> git clone https://github.com/zshell-zhang/all-site-files.git

> move all-site-files blogs
```
(2) 拉取图片资源(与 blogs 同父目录):
``` bash
> git clone https://github.com/zshell-zhang/static-content.git
# 或者
> git clone git@github.com:zshell-zhang/static-content.git
```
(3) 拉取 site 呈现内容:
``` bash
> cd blogs

> git clone https://github.com/zshell-zhang/zshell-zhang.github.io.git
# 或者
> git clone git@github.com:zshell-zhang/zshell-zhang.github.io.git

# 将 site 远程仓库改名
> mv zshell-zhang.github.io .deploy_git
```

### **使用方法**
新建编辑文章:
``` bash
> cd blogs
# 一级目录-二级目录--标题
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
- [使用LaTex添加公式到Hexo博客里](http://hrworkbench.alibaba.net/workbench/entry/applyV2?formNo=11063963)
