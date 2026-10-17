function oneShowCodeTokens(source, language) {
  const aliases = {py:'python',js:'javascript',ts:'javascript',typescript:'javascript',jsx:'javascript',tsx:'javascript',sh:'bash',shell:'bash',zsh:'bash',yml:'yaml',html:'xml',c:'cpp','c++':'cpp',h:'cpp',cs:'java',csharp:'java',kt:'java',kotlin:'java',rs:'rust'};
  const lang = aliases[language.toLowerCase()] || language.toLowerCase();
  const words = {
    python:'def class return import from as if elif else for while in is not and or try except finally with yield lambda pass raise async await True False None print self',
    javascript:'const let var function return class new if else for while do switch case break continue try catch finally throw import export from default async await typeof instanceof null undefined true false this extends interface type public private',
    swift:'import class struct enum protocol extension func let var return if else guard for while in switch case default break throw throws try catch async await actor static private public nil true false self',
    java:'package import class interface public private protected static final void new return if else for while switch case break try catch throw throws null true false extends implements int double boolean String',
    cpp:'include define namespace using class struct template const auto void int float double char bool return if else for while switch case break new delete nullptr true false public private virtual static',
    go:'package import func var const type struct interface return if else for range switch case default defer go chan map make nil true false',
    rust:'fn let mut pub impl struct enum trait use mod return if else for while loop match Some None Ok Err self true false async await',
    sql:'select from where join left right inner outer on as insert into values update set delete create table alter drop group by order having limit distinct union all null and or not in is asc desc count',
    bash:'if then else elif fi for do done while case esac function export local return echo cd source sudo',
    json:'true false null', yaml:'true false null yes no'
  };
  if (lang === 'xml') {
    const pattern = /<!--[\s\S]*?-->|<\/?[A-Za-z][^>]*>/g;
    const result = []; let pos = 0;
    for (const m of source.matchAll(pattern)) { if(m.index>pos) result.push({text:source.slice(pos,m.index)}); result.push({text:m[0],kind:m[0].startsWith('<!--')?'comment':'keyword'}); pos=m.index+m[0].length; }
    if(pos<source.length) result.push({text:source.slice(pos)}); return result;
  }
  if (!words[lang]) return [{text:source}];
  const keywords = new Set(words[lang].split(' '));
  const hashComments = ['python','bash','yaml'].includes(lang);
  const slashComments = ['javascript','swift','java','cpp','go','rust'].includes(lang);
  const pattern = /"""[\s\S]*?"""|'''[\s\S]*?'''|"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*'|`(?:\\[\s\S]|[^`\\])*`|\/\*[\s\S]*?\*\/|\/\/[^\r\n]*|\#[^\r\n]*|--[^\r\n]*|\b(?:0x[0-9a-fA-F]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)\b|[$A-Za-z_][$\w]*/g;
  const result=[]; let pos=0;
  for(const m of source.matchAll(pattern)) {
    if(m.index>pos) result.push({text:source.slice(pos,m.index)});
    const value=m[0]; let kind;
    if (/^["'`]/.test(value)) kind='string';
    else if ((hashComments && value.startsWith('#')) || (slashComments && /^\/[/\*]/.test(value)) || (lang==='sql' && value.startsWith('--'))) kind='comment';
    else if (/^\d/.test(value)) kind='number';
    else if (keywords.has(lang==='sql'?value.toLowerCase():value)) kind='keyword';
    else if (/^[$A-Za-z_][$\w]*$/.test(value) && /^\s*\(/.test(source.slice(m.index+value.length))) kind='function';
    result.push({text:value,kind}); pos=m.index+value.length;
  }
  if(pos<source.length) result.push({text:source.slice(pos)});
  return result;
}
function oneShowHighlight(code, language, light) {
  const palette = light ? {keyword:'#8f2f9b',string:'#246b39',comment:'#6b7280',number:'#a04c12',function:'#1f62a4'} : {keyword:'#d6a2ff',string:'#a7dbad',comment:'#a3b2c2',number:'#ffc78c',function:'#8dcfff'};
  const tokens = oneShowCodeTokens(code.textContent, language);
  code.replaceChildren();
  for (const token of tokens) {
    if (!token.kind) { code.append(code.ownerDocument.createTextNode(token.text)); continue; }
    const span=code.ownerDocument.createElement('span'); span.style.color=palette[token.kind]; span.textContent=token.text; code.append(span);
  }
}
