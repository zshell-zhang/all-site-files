#!/bin/bash

page_name=$1

if [[ "$page_name" == "" ]]; then
    echo "\nlack of page name!\n"
    exit 1
fi

cd /home/zshell/Documents/zshell.zhang.github.io/

hugo new post/$page_name.md

# 自动进入编辑状态
vim content/post/$page_name.md

