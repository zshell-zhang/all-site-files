#!/bin/bash


echo -e "\nbegin hexo content generating...\n"
hexo generate

echo -e "\nbegin generating algolia index of site content...\n"
export HEXO_ALGOLIA_INDEXING_KEY=cc7f21b858a28bd550b63cc3cefbcb56
hexo algolia

echo -e "\nbegin deploy hexo content to github page...\n"
hexo deploy

