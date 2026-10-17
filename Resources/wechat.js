function makeWechatArticle(source, accent, layout = 'classic') {
  const themes = {
    classic: {accent:'#2563a6', ink:'#303744', soft:'#eff5fc', code:'#202631', light:false, serif:false},
    journal: {accent:'#a65f36', ink:'#473e37', soft:'#faf3e9', code:'#faf3e9', light:true, serif:true},
    forest: {accent:'#26765e', ink:'#2d4039', soft:'#edf6f1', code:'#17392f', light:false, serif:false},
    minimal: {accent:'#242424', ink:'#333333', soft:'#f5f5f5', code:'#f5f5f5', light:true, serif:false}
  };
  const theme = themes[layout] || themes.classic;
  const color = theme.accent;
  const doc = sanitizedMarkdown(source);
  let localImages = 0, externalImages = 0;
  const references = [];
  const styles = {
    P:'margin:18px 0;line-height:1.9;text-align:justify;word-break:break-word;',
    H1:`margin:30px 0 20px;font-size:24px;line-height:1.5;font-weight:700;color:${color};`,
    H2:`margin:28px 0 16px;padding:0 0 8px;border-bottom:2px solid ${color};font-size:21px;line-height:1.5;font-weight:700;color:${color};`,
    H3:`margin:24px 0 12px;font-size:18px;line-height:1.6;font-weight:700;color:${color};`,
    H4:'margin:20px 0 12px;font-size:17px;font-weight:700;line-height:1.6;',
    H5:'margin:18px 0 10px;font-size:16px;font-weight:700;line-height:1.6;',
    H6:'margin:18px 0 10px;font-size:15px;font-weight:700;line-height:1.6;',
    BLOCKQUOTE:`margin:20px 0;padding:12px 18px;border-left:3px solid ${color};background-color:#f6f7f9;color:#596171;line-height:1.85;`,
    UL:'margin:15px 0;padding-left:26px;list-style-type:disc;', OL:'margin:15px 0;padding-left:26px;list-style-type:decimal;',
    LI:'margin:6px 0;line-height:1.9;', STRONG:'font-weight:700;', B:'font-weight:700;', EM:'font-style:italic;', I:'font-style:italic;',
    DEL:'text-decoration:line-through;color:#7b8492;', S:'text-decoration:line-through;',
    MARK:'background-color:#fff0a6;color:#282c34;padding:1px 3px;',
    SUP:'vertical-align:super;font-size:11px;', SUB:'vertical-align:sub;font-size:11px;',
    TABLE:'border-collapse:collapse;width:100%;margin:20px 0;font-size:13px;line-height:1.7;',
    TH:'border:1px solid #dce1e8;padding:8px;background-color:#f4f5f8;font-weight:700;text-align:left;',
    TD:'border:1px solid #dce1e8;padding:8px;text-align:left;',
    HR:'border:0;border-top:1px solid #e4e6ec;margin:28px 0;',
    PRE:'margin:20px 0;padding:16px;background-color:#202631;color:#e3e9f0;border-radius:8px;overflow-x:auto;white-space:pre;font-size:12px;line-height:1.7;'
  };
  for (const el of [...doc.body.querySelectorAll('*')]) {
    if (!doc.body.contains(el)) continue;
    const tag = el.tagName;
    // Only the formatter's allowlisted styles are exported, never arbitrary document CSS.
    const oldWidth = el.style.width, oldZoom = Number(el.style.zoom || '1');
    el.removeAttribute('style');
    if (styles[tag]) el.setAttribute('style', styles[tag]);
    if (tag === 'CODE') el.style.cssText = el.closest('pre') ? 'font-family:Menlo,Consolas,monospace;font-size:12px;white-space:pre;color:inherit;background:transparent;' : 'font-family:Menlo,Consolas,monospace;font-size:13px;background-color:#f1f3f6;color:#485366;padding:2px 5px;border-radius:3px;';
    if (tag === 'IMG') {
      const src = el.getAttribute('src') || '';
      if (!/^https?:\/\//i.test(src)) {
        localImages++;
        const note = doc.createElement('p'); note.style.cssText = 'margin:18px 0;padding:12px;background-color:#fff8ea;color:#936422;line-height:1.8;';
        note.textContent = '[图片需在公众号上传：' + (el.alt || '本地图片') + ']'; el.replaceWith(note); continue;
      }
      const host = new URL(src).hostname;
      if (!['mmbiz.qpic.cn','mmbiz.qlogo.cn'].includes(host)) externalImages++;
      el.style.cssText = 'display:block;max-width:100%;height:auto;margin:18px auto;border-radius:4px;';
      if (oldWidth) el.style.width = oldWidth;
      else if (oldZoom > 0 && oldZoom < 1) el.style.width = (oldZoom * 100) + '%';
      el.removeAttribute('height'); el.removeAttribute('width');
    }
    if (tag === 'INPUT') {
      const mark = doc.createElement('span'); mark.textContent = el.checked ? '☑ ' : '☐ '; el.replaceWith(mark);
    }
    if (tag === 'A') {
      const href = el.getAttribute('href') || '';
      let internal = false;
      try { internal = new URL(href).hostname === 'mp.weixin.qq.com'; } catch (_) {}
      if (internal) el.style.cssText = `color:${color};text-decoration:underline;`;
      else {
        const span = doc.createElement('span'); span.append(...el.childNodes);
        if (/^https?:\/\//i.test(href)) {
          let index = references.indexOf(href); if (index < 0) { references.push(href); index = references.length - 1; }
          const sup = doc.createElement('sup'); sup.style.cssText = `font-size:10px;color:${color};vertical-align:super;`; sup.textContent = '[' + (index + 1) + ']'; span.append(sup);
        }
        el.replaceWith(span);
      }
    }
  }
  // Highlight after sanitization and styling; token text is always inserted as text nodes.
  for (const code of doc.body.querySelectorAll('pre > code')) {
    const language = (code.className.match(/language-([\w+-]+)/) || [,''])[1];
    oneShowHighlight(code, language, theme.light);
    code.parentElement.style.backgroundColor = theme.code;
    code.parentElement.style.color = theme.light ? '#343b45' : '#e3e9f0';
  }
  for (const quote of doc.body.querySelectorAll('blockquote')) quote.style.backgroundColor = theme.soft;
  for (const heading of doc.body.querySelectorAll('h2')) {
    if (layout === 'forest') { heading.style.borderBottom = '0'; heading.style.borderLeft = '4px solid ' + color; heading.style.padding = '6px 12px'; heading.style.backgroundColor = theme.soft; }
    if (layout === 'journal') { heading.style.borderBottom = '1px solid ' + color; heading.style.fontFamily = 'Georgia,Songti SC,serif'; }
    if (layout === 'minimal') { heading.style.borderBottom = '0'; heading.style.paddingBottom = '0'; }
  }
  if (references.length) {
    const heading = doc.createElement('h3'); heading.style.cssText = styles.H3; heading.textContent = '参考链接'; doc.body.append(heading);
    references.forEach((url, index) => { const p = doc.createElement('p'); p.style.cssText = 'font-size:12px;line-height:1.8;color:#687387;word-break:break-all;margin:8px 0;'; p.textContent = '[' + (index + 1) + '] ' + url; doc.body.append(p); });
  }
  const section = doc.createElement('section'); section.style.cssText = 'font-family:-apple-system,BlinkMacSystemFont,Arial,sans-serif;font-size:16px;line-height:1.9;color:#303744;word-wrap:break-word;padding:0 6px;';
  section.style.color = theme.ink;
  if (theme.serif) section.style.fontFamily = 'Georgia,Songti SC,serif';
  section.append(...doc.body.childNodes);
  const plain = section.cloneNode(true);
  for (const block of plain.querySelectorAll('p,h1,h2,h3,h4,h5,h6,li,pre,blockquote,tr')) block.append(doc.createTextNode('\n'));
  return {html:section.outerHTML, text:plain.textContent, localImages, externalImages, referenceCount:references.length};
}

// Offline lexical highlighting. Unknown languages remain readable plain code.
