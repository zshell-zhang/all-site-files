#!/bin/bash

# this script is used to generate a standard hexo post with the given title pattern from 'mainCategory-subCategory-triCategory--title';
# run it and get the auto-categories-and-tags-generated post content, just write the real content itself without editing the boring categories and tags!

title=$1

final_categories=''
final_tag=''
real_title=''

# support multi levels of categories
function gen_categories() {
    origin_str=$1
    # real title
    real_title=${origin_str##*--}

    # categories
    categories=${origin_str%--*}

    categories_array=`echo ${categories} | awk '{
	size = split($0, categories, "-");
 	for (i=1; i<= size; i++) {
	    print categories[i]" "
	    result = (result"  - "categories[i]"\n");
	}
    }'`
    for category in ${categories_array}; do
	final_categories=${final_categories}"  - "${category}"\n"
    done
}

# only support one tag
function gen_tag() {
    origin_str=$1
    
    # tags
    tags=${origin_str%--*}
    
    final_tag=`echo ${tags} | awk '{
        size = split($0, tags, "-");
	result = tags[1];
 	for (i=2; i<= size; i++) {
            result = (result":"tags[i]);
	}
    } END {
        print "  - "result"\n";
    }'`

}

# below are the main process

cd ~/Documents/blogs

if [[ -e source/_posts/${title}.md ]]; then
    echo -e "the target post exists, edit it directly!"
    vim source/_posts/${title}.md
    exit 0
fi

hexo new post tmp-post

mv source/_posts/tmp-post.md source/_posts/${title}.md
echo -e "new post name is: source/_posts/${title}.md"

gen_categories ${title}
gen_tag ${title}

origin_blog_content="---\ntitle: ${real_title}\ndate: `date +%Y-%m-%d\ %H:%M:%S`\ncategories:\n${final_categories}tags:\n${final_tag}\n---\n<!--more-->"

echo -e ${origin_blog_content} > source/_posts/${title}.md
echo -e "initialization process done, now you can edit it!"

vim source/_posts/${title}.md
