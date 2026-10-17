const vm = require('node:vm'), fs = require('node:fs'), assert = require('node:assert/strict');
const source = fs.readFileSync(__dirname + '/../Resources/csdn-editor.js','utf8');
let clicked = 0;
class Input { constructor() { this.v=''; this.tagName='INPUT'; } get value(){return this.v} set value(v){this.v=v} dispatchEvent(){} blur(){} }
const title = new Input();
let body = '';
const editable = {get textContent(){return body}, focus(){}, getBoundingClientRect(){return {width:100,height:100}}};
const button = {textContent:'发布文章',disabled:false,getBoundingClientRect(){return {width:10,height:10}},getAttribute(){return null},closest(){return null},click(){clicked++}};
const ctx = {URL, window:{getSelection(){return {removeAllRanges(){},addRange(){}}}},HTMLInputElement:Input,HTMLTextAreaElement:Input, Event:class {}, document:{
 querySelector(s){return s==='input.article-bar__title--input'?title:null},
 querySelectorAll(s){return s.includes('contenteditable')?[editable]:s==='button,a'?[button]:[]},
 createRange(){return {selectNodeContents(){}}}
}};
vm.createContext(ctx); vm.runInContext(source,ctx);
assert.equal(ctx.oneShowCSDNRead().ready,true);
assert.equal(ctx.oneShowCSDNFill('测试','正文\n'),'paste');
assert.equal(title.value,'测试');
assert.equal(ctx.oneShowCSDNPublish('测试','正文'),'mismatch'); assert.equal(clicked,0);
body='正文\n';assert.equal(ctx.oneShowCSDNPublish('测试','正文'),'opened'); assert.equal(clicked,1);
assert.equal(ctx.oneShowCSDNFill('其他','替换旧正文'),'paste');assert.equal(title.value,'其他');
assert.equal(ctx.oneShowCSDNPublish('其他','替换旧正文'),'mismatch');
title.value='测试';
button.closest=()=>({});assert.equal(ctx.oneShowCSDNPublish('测试','正文'),'missing');assert.equal(clicked,1);
console.log('通过：原生粘贴分支、正文回读核对、替换旧标题与正文、仅点击编辑器发布入口。');

assert.equal(ctx.oneShowCSDNNormalize('![原图](<https://example.org/a.png>)'), ctx.oneShowCSDNNormalize('![转存提示](https://img-home.csdnimg.cn/images/fail.png?origin_url=%3Chttps%3A%2F%2Fexample.org%2Fa.png%3E&pos_id=123)'));
assert.notEqual(ctx.oneShowCSDNNormalize('![a](https://example.org/a.png)'),ctx.oneShowCSDNNormalize('![a](https://example.org/b.png)'));
console.log('通过：识别 CSDN 图片 origin_url 转换，仍区分不同原图。');

let collapsed = 0;
const collapse = {textContent:'收起',disabled:false,getAttribute(){return null},getBoundingClientRect(){return {width:40,height:40}},click(){collapsed++;this.textContent='展开'}};
const originalQuery = ctx.document.querySelectorAll;
ctx.document.querySelectorAll = s => s === 'button,a,[role="button"]' ? [collapse] : originalQuery(s);
assert.equal(ctx.oneShowCSDNCollapseSidebar(),true);assert.equal(collapsed,1);
assert.equal(ctx.oneShowCSDNCollapseSidebar(),false);assert.equal(collapsed,1);
console.log('通过：自动收起右侧栏，不反向展开。');
