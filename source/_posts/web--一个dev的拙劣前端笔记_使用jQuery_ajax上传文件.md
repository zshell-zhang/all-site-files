---
title: '一个 dev 的拙劣前端笔记: 使用 jQuery ajax 上传文件'
date: 2018-02-03 21:48:08
categories:
 - web
tags:
 - ajax
 - jQuery
 - 文件上传
---

> 从传统的刷新提交到 ajax 提交, 从间接的 iframe 刷新 ajax 提交到真正意义上的 ajax 提交, 关于前端文件上传的方法, 伴随着 web 技术与标准的演进, 不断推陈出新;
本文整理了从传统方式到 ajax 方式上传文件的各种方法;

<!--more-->

------

### **传统的上传文件方式**
form 表单有三种可能的 MIME 编码类型: 默认的 `application/x-www-form-urlencoded`, 不对字符编码而保留原始信息的 `multipart/form-data`, 以及纯文本 `text/plain`;
如果没有异步刷新的需求, 只需要将 form 表单的 enctype 属性设置为 `multipart/form-data`, 便可以二进制的方式提交表单内容, 以达到上传文件的目的:
``` html
<form id="form_id" enctype="multipart/form-data">  
    <input type="text" name="str" />  
    <input type="file" name="fileAttach" />  
    <input type="submit" value="upload" />  
</form> 
```
关于 MIME 类型 `multipart/form-data` 的更多内容, 请参见: [一个 dev 的拙劣前端笔记: content-type 之 multipart/form-data 规范整理]();
&nbsp;
**下面来讨论如何使用 ajax 实现文件上传;**

### **使用 jQuery ajaxFileUpload 插件实现文件上传**
ajax 默认使用的 MIME 类型是 `application/x-www-form-urlencoded`, 这种方式只适用于传输普通字符串类型的数据; 由于在 HTML4 时代, 没有对 javascript 提供文件读取的接口, 使用 `document.getElementById('field_id').value` 也只能获得文件的 name, 并不能拿到文件的二进制数据; 所以, 想直接使用 ajax 无刷新提交表单是无法做到的;
所以只能采用间接的方案, 比如基于 jQuery 拓展的 ajaxFileUpload 插件, 其代码逻辑大致如下: 

1. function createUploadIframe():
   创建一个独立的 iframe, 并追加到 body 中;
2. function createUploadForm(file_elem_id):
   创建一个独立的 form, 设置 enctype 为 `multipart/form-data`;
   根据 file_elem_id 找到页面里的目标 `<input type="file" />` 对象, 使用 jQuery.clone 方法, 将新的克隆对象替换到目标对象的位置, 而将原目标对象追加到新建的 form 中(偷梁换柱);
   最后将新创建的 form 追加到 body 中;
3. function addOtherRequestsToForm(data, new_form):
   将页面中目标表单的其他元素数据, 一并追加到新创建的 form 里;
4. function ajaxFileUpload: 
   调用 createUploadForm 方法创建新 form;
   调用 addOtherRequestsToForm 方法捎带除 file 之外的其余元素数据;
   调用 createUploadIFrame 方法创建 iframe;
   将新 form 的 target 属性设置为新创建 iframe 的 id, 以实现间接的无刷新;
   submit 提交新 form;

&nbsp;
ajaxFileUpload 的实现逻辑并不复杂, 类似这样的插件在 github 上有各种各样的版本, 我选取了一个比较典型的实现: [carlcarl/AjaxFileUpload/ajaxfileupload.js](https://github.com/carlcarl/AjaxFileUpload/blob/master/ajaxfileupload.js);
然后开发者在实际使用时需要调用的是 `jQuery.ajaxFileUpload` 方法, 设置一些参数与回调方法:
``` javascript
function ajax_submit(field_id) {
    $.ajaxFileUpload({
        fileElementId: field_id,    // <input id="field_id" type="file">, 对应元素的 id
        data: fetch_form_data('form_id'),   // 捎带其余元素的数据
        url: '/xxx/yyy/upload'
        type: 'post',
        dataType: 'json',
        secureuri: false,   //是否启用安全提交，默认为false
        async : true,   //是否是异步
        success: function(data) {
            if (data['status'] == 0) {
                window.location.reload();
                alert("提交成功");
            } else {
                window.location.reload();
                alert("提交失败:" + data['message']);
            }
        },
        error: function(data, status, e) {
            window.location.reload();
            alert("提交失败:" + data['message']);
        }
    });
}
// 将给定的表单数据转为对象
function fetch_form_data(form_id) {
    var params = $('#' + form_id).serializeArray();  
    var values = {};  
    for( x in params ) {  
        values[params[x].name] = params[x].value;  
    }  
    return values
}
```
抛开 iframe 的性能影响不谈, 看起来这样的 api 还是相当友好的, 与 jQuery.ajax 同样方便, 还解决了 ajax 不能传输二进制流的问题;
另外, 由于这种方式真正提交的表单完全是 javascript 创建出来的, 页面上自己写的那个表单, 只作为数据 clone 的载体, 所以只需要确保表单和其中的 file input 元素有自己的 id, 最后提交按钮的 onclick 事件指向了目标方法即可;
``` html
<form id="form_id">
    <input type="text" name="str" />
    <input id="file_attach" type="file" name="fileAttach" />
    <input type="button" onclick="ajax_submit('file_attach')"  value="upload" />
</form>
```

### **使用 jQuery ajax 结合 HTML5 API 实现文件上传**
使用 ajaxFileUplaod 插件, 无论怎么优化改造, 其需要使用 iframe 作间接无刷新的逻辑是没法绕开的; 而使用 iframe 必然会带来额外资源的消耗, 如果有更原生直接的解决方案, 我们一定乐于在项目中取代 ajaxFileUpload;
于是, 在 HTML5 时代, 出现了一个新的接口: `FormData`, 它给出了完美的解决方案;
``` javascript
var form_content = new FormData(document.getElementById("form_id"));
```
这行代码便拿到了目标表单对象的所有信息; 我们只需要确保表单的 enctype 属性为 `multipart/form-data`, 通过该接口获得的 FormData 对象, 便是完整的二进制序列化信息:
``` html
<form id="form_id" enctype="multipart/form-data">
    <input type="text" name="str" />
    <input type="file" name="fileAttach" />
    <input type="button" onclick="upload_file()"  value="upload" />
</form>
```
这样, 一个 onclick 事件触发 upload_file 方法, 使用原生的 jQuery ajax 就实现了上传文件的功能了, 同时表单内的其他字符串数据, 也一并以 multi part 的形式上传上去了;
对应的 javascript upload_file 方法如下: 
``` javascript
function uplaod_file() {
    var form_content = new FormData(document.getElementById('form_id'));
    $.ajax({
        type: 'POST',
        url: '/xxx/yyy/upload',
        data: form_content,
        processData: false,     // 阻止默认的 application/x-www-form-urlencoded 对象处理方法
        contentType: false,     // 与 processData 保持一直, 不使用默认的 application/x-www-form-urlencoded
        success: function (data) {
            if (data['status'] == 0) {
                window.location.reload();
                alert("提交成功");
            } else {
                window.location.reload();
                alert("提交失败:" + data['message']);
            }
        },
        fail: function (data) {
            window.location.reload();
            alert("提交失败:" + data['message']);
        }
    });
}
```
以上代码需要注意的是:
`processData` 参数默认为 true, 即将 data 转为 url 键值对形式, 这里已经是序列化后的二进制数据, 不需要再次处理,  所以应主动设置其为 false;
同时, `contentType` 默认为 `application/x-www-form-urlencoded`, 这里不应该使用默认值;
关于 jQuery ajax 方法, 更多的内容请参见: [jQuery ajax 阅读与理解]();
&nbsp;
这便是 HTML5 时代下,  ajax 异步上传文件的最佳实践;

### **站内相关文章**
- [一个 dev 的拙劣前端笔记: content-type 之 multipart/form-data 规范整理]()
- [jQuery ajax 阅读与理解]()

### **参考链接**
- [jquery Ajax提交表单(使用jquery Ajax上传附件)](http://blog.csdn.net/qq_33556185/article/details/51086114)
- [JQuery的ajaxFileUpload的使用](https://www.cnblogs.com/zhanghaoliang/p/6513964.html)
- [carlcarl/AjaxFileUpload/ajaxfileupload.js](https://github.com/carlcarl/AjaxFileUpload/blob/master/ajaxfileupload.js)
- [jquery插件--ajaxfileupload.js上传文件原理分析](http://blog.csdn.net/it_man/article/details/43800957)

