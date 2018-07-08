#!/bin/bash

target_commit_date=$1

echo -e "\nbegin hexo content generating...\n"
hexo generate

echo -e "\nbegin deploy hexo content to github page...\n"
cd .deploy_git/
git add .

if [[ $target_commit_date == '' ]]; then
    target_commit_date=`date +%Y-%m-%d`
fi

git commit -m "Site updated: $target_commmit_date `date +%H:%m:%S`" --date="$target_commit_date"

