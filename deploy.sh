#!/bin/bash

target_commit_date=$1

random_end_date='2017-12-22'


if [[ $target_commit_date = '' ]]; then
    sudo date -s $random_end_date
    let "random_value = $RANDOM % 226"
    target_commit_date=`date +%Y-%m-%d -d "$random_value days ago"`
fi

echo "target commit date = "$target_commit_date
sudo date -s $target_commit_date

########## 以下为原始内容, commit 均衡后可删除
echo -e "\nbegin hexo content generating...\n"
hexo generate

echo -e "\nbegin deploy hexo content to github page...\n"
hexo deploy
########## 以上为原始内容, commit 均衡后可删除


# 恢复当前时间
sudo ntpdate 0.asia.pool.ntp.org
