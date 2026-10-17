const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ctx=vm.createContext({});vm.runInContext(fs.readFileSync(__dirname+'/../Resources/highlight.js','utf8'),ctx);
for(const [lang,source] of [['python','def hello():\n  # comment\n  return "世界" + 42'],['js','const answer = "safe"; // comment\nprint(42)'],['sql','SELECT name FROM users WHERE id = 42'],['swift','let name = "Show"'],['html','<!-- hi -->\n<img src="x">'],['unknown','<script>danger</script>']]) {
 const tokens=ctx.oneShowCodeTokens(source,lang);assert.equal(tokens.map(t=>t.text).join(''),source);
 if(lang!=='unknown') assert(tokens.some(t=>t.kind==='keyword'));
}
const tokens=ctx.oneShowCodeTokens('print("<script>alert(1)</script>")','python');assert(tokens.some(t=>t.kind==='string'));
const nodes=[];const code={textContent:'const a = "<img onerror=bad>";',ownerDocument:{createTextNode:text=>({text}),createElement:()=>({style:{},textContent:''})},replaceChildren:()=>nodes.splice(0),append:node=>nodes.push(node)};
ctx.oneShowHighlight(code,'javascript',false);assert.equal(nodes.map(n=>n.text??n.textContent).join(''),code.textContent);assert(nodes.some(n=>n.style?.color));
console.log('通过：代码语言别名、关键字、字符串、注释、数字、安全文本节点、未知语言与原文保真。');
