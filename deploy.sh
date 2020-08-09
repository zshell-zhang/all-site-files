#!/bin/bash

target_commit_date=$1

echo -e "\nbegin hexo content generating...\n"
hexo clean
hexo generate

cp -a public/* .deploy_git/

echo -e "\nbegin deploy hexo content to github page...\n"
cd .deploy_git/
git add .

if [[ $target_commit_date == '' ]]; then
    target_commit_date=`date +%Y-%m-%d`
fi

git commit -m "Site updated: $target_commmit_date `date +%H:%m:%S`" --date="$target_commit_date"
git push origin master

echo -e "\nall done! let's request https://zshell.cc\n"

