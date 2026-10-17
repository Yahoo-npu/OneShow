async function makeCards(source, title, accent) {
  document.documentElement.style.setProperty('--accent', accent);
  const paper = document.getElementById('paper');
  paper.replaceChildren(...sanitizedMarkdown(source).body.childNodes);
  for (const code of paper.querySelectorAll('pre > code')) {
    const lang = (code.className.match(/language-([\w+-]+)/) || [,''])[1];
    oneShowHighlight(code, lang, true);
  }
  const images = [...paper.querySelectorAll('img')];
  await Promise.all(images.map(img => new Promise(resolve => {
    const done = () => { if (!img.naturalWidth) { const label = document.createElement('p'); label.className = 'missing'; label.textContent = '图片加载失败：' + img.alt; img.replaceWith(label); } resolve(); };
    if (img.complete) return done();
    img.onload = done; img.onerror = done;
    setTimeout(done, 15000);
  })));
  await document.fonts.ready;
  document.getElementById('title').textContent = title;
  const count = Math.max(1, Math.ceil((paper.scrollWidth + 96) / 600));
  return {count, missing: document.querySelectorAll('.missing').length};
}
function showCard(index, count) {
  document.getElementById('paper').style.transform = `translateX(${-index * 600}px)`;
  document.getElementById('page').textContent = `${String(index + 1).padStart(2, '0')} / ${String(count).padStart(2, '0')}`;
}
