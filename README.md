### **下载 node**
https://nodejs.org/en/download/

### **下载 hexo**
``` bash
npm install -g hexo-cli
```

### **clone 远程仓库**
自动化脚本, js 框架, 文章原始内容:
``` bash
git clone https://github.com/zshell-zhang/all-site-files.git
git clone https://github.com/zshell-zhang/all-site-files.git
```
图片资源:
``` bash
git clone https://github.com/zshell-zhang/static-content.git
git clone git@github.com:zshell-zhang/static-content.git
```
site 呈现内容:
``` bash
git clone https://github.com/zshell-zhang/zshell-zhang.github.io.git
git clone git@github.com:zshell-zhang/zshell-zhang.github.io.git
```
将 site 远程仓库改名:
``` bash
mv zshell-zhang.github.io .deploy_git
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
