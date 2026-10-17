function sanitizedMarkdown(source) {
  const doc = new DOMParser().parseFromString(MojianMarkdown.render(source), 'text/html');
  const allowed = new Set('P BR HR H1 H2 H3 H4 H5 H6 BLOCKQUOTE PRE CODE STRONG B EM I DEL S MARK SUB SUP UL OL LI TABLE THEAD TBODY TFOOT TR TH TD A IMG DIV SPAN INPUT'.split(' '));
  for (const el of [...doc.body.querySelectorAll('*')]) {
    if (['SCRIPT','STYLE','IFRAME','OBJECT','EMBED','LINK','META','FORM','SVG','MATH'].includes(el.tagName)) { el.remove(); continue; }
    if (!allowed.has(el.tagName)) { el.replaceWith(...el.childNodes); continue; }
    const attrs = Object.fromEntries([...el.attributes].map(a => [a.name.toLowerCase(), a.value]));
    for (const a of [...el.attributes]) el.removeAttribute(a.name);
    if (el.tagName === 'CODE') {
      const language = (attrs.class || '').match(/(?:^|\s)language-([A-Za-z0-9_+-]+)(?:\s|$)/);
      if (language) el.className = 'language-' + language[1];
    }
    if (el.tagName === 'IMG') {
      let src = attrs.src || '';
      if (/^https?:\/\//i.test(src)) el.src = src;
      else if (/^\/\//.test(src)) el.src = 'https:' + src;
      else if (/^(data|javascript|vbscript|blob):/i.test(src)) { el.replaceWith(doc.createTextNode('不支持的图片地址')); continue; }
      else el.src = 'mojian-image://local/image?src=' + encodeURIComponent(src);
      el.alt = attrs.alt || '图片'; el.referrerPolicy = 'no-referrer';
      const zoom = (attrs.style || '').match(/(?:^|;)\s*zoom\s*:\s*(\d+(?:\.\d+)?)\s*(%?)/i);
      if (zoom) { const scale = Number(zoom[1]) / (zoom[2] ? 100 : 1); if (scale > 0 && scale <= 5) el.style.zoom = String(scale); }
      for (const dimension of ['width','height']) {
        const value = attrs[dimension] || (attrs.style || '').match(new RegExp('(?:^|;)\\s*' + dimension + '\\s*:\\s*(\\d+(?:\\.\\d+)?(?:px|%)?)','i'))?.[1];
        if (value && /^\d+(?:\.\d+)?(?:px|%)?$/.test(value)) el.style[dimension] = /^\d+(?:\.\d+)?$/.test(value) ? value + 'px' : value;
      }
    } else if (el.tagName === 'A') {
      if (/^(https?:|mailto:|#)/i.test(attrs.href || '')) el.href = attrs.href;
      el.title = attrs.title || '';
    } else if (el.tagName === 'INPUT') {
      if (attrs.type !== 'checkbox') { el.remove(); continue; } el.type = 'checkbox'; el.disabled = true; el.checked = 'checked' in attrs;
    } else if (['TH','TD'].includes(el.tagName) && /^(left|center|right)$/.test(attrs.align || '')) el.style.textAlign = attrs.align;
  }
  return doc;
}
function updatePreview(source) {
  const doc = sanitizedMarkdown(source);
  const paper = document.getElementById('paper'); paper.replaceChildren(...doc.body.childNodes);
  for (const code of paper.querySelectorAll('pre > code')) {
    const language = (code.className.match(/language-([\w+-]+)/) || ['', ''])[1];
    oneShowHighlight(code, language, false);
  }
  for (const img of paper.querySelectorAll('img')) {
    img.addEventListener('error', () => {
      const note = document.createElement('div'); note.className = 'image-error';
      note.textContent = '图片加载失败：' + img.alt + '。本地图片请检查图片目录；网络图片请检查地址、访问权限或防盗链。';
      img.replaceWith(note);
    }, {once:true});
  }
}
