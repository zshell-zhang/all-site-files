#!/bin/bash

page_name=$1

# 校验page name合法性
case $page_name in
    *.*) echo "page name could not contains \".\"!" 
	 exit 1 ;;
     "") echo "\nlack of page name!\n"
    	 exit 1 ;;
esac

cd /home/zshell/Documents/zshell.zhang.github.io/

#hugo new post/$page_name.md

# 自动进入编辑状态
vim content/post/$page_name.md

