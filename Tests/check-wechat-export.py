from html.parser import HTMLParser
from pathlib import Path
import sys
import re
class ExportParser(HTMLParser):
    def __init__(self):
        super().__init__(); self.tags=[]; self.attrs=[]; self.text=[]
    def handle_starttag(self, tag, attrs):
        self.tags.append(tag); self.attrs.append((tag,dict(attrs)))
    def handle_data(self,data): self.text.append(data)
source=Path(sys.argv[1]).read_text(); parser=ExportParser();parser.feed(source)
text=''.join(parser.text)
css=re.sub(r'\s+', '', ' '.join(attrs.get('style','') for _,attrs in parser.attrs))
assert all(tag not in parser.tags for tag in ['script','iframe','object','input'])
assert all(not key.startswith('on') for _,attrs in parser.attrs for key in attrs)
assert all(not attrs.get('src','').startswith(('mojian-image:','file:','javascript:','data:')) for tag,attrs in parser.attrs if tag=='img')
assert 'never-run' not in source and 'blocked' not in source
assert '1. 公众号排版示例' in text and '1.1. 标题与排版' in text
assert 'mark' in parser.tags and 'background-color:#fff0a6' in css
assert 'pre' in parser.tags and 'white-space:pre' in css and 'Hello, OneShow' in text
assert 'table' in parser.tags and 'border-collapse:collapse' in css
assert '[图片需在公众号上传：本地示例图片]' in text
assert '☑' in text and '☐' in text
assert text.count('https://example.org/docs')==1
links=[attrs.get('href') for tag,attrs in parser.attrs if tag=='a']
assert links==['https://mp.weixin.qq.com/s/example']
assert any(tag=='img' and 'width: 50%' in attrs.get('style','') for tag,attrs in parser.attrs)
print('通过：实际 WebKit 导出HTML的编号、高亮、代码、表格、图片占位、外链去重、内链保留及脚本清理。')

assert any(tag=='code' and attrs.get('class')=='language-python' for tag,attrs in parser.attrs)
assert any(tag=='span' and 'color:' in attrs.get('style','') for tag,attrs in parser.attrs)
print('通过：代码语言标记和高亮内联颜色保留。')
