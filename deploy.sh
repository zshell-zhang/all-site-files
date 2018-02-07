#!/bin/bash

echo -e "\nbegin hexo content generating...\n"
hexo generate

echo -e "\nbegin deploy hexo content to github page...\n"
hexo deploy

