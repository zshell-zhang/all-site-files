#!/bin/bash

page_name=$1
now_time=$(date "+%Y-%m-%d %H:%M:%S")

if [[ "$page_name" == "" ]]; then
    page_name="auto update my blog by bash - $now_time"
fi

echo $page_name

cd /home/zshell/Documents/zshell.zhang.github.io/

hugo --theme=hugo-icarus-theme --baseUrl="https://zshell-zhang.github.io/"

cd public
git add .
git commit -m "$page_name"
git push -u origin master:master

