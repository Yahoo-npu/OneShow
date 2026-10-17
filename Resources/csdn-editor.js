function oneShowCSDNControls() {
  const visible = e => e && e.getBoundingClientRect().width > 0 && e.getBoundingClientRect().height > 0;
  const title = document.querySelector('input.article-bar__title--input') || [...document.querySelectorAll('input,textarea')].find(e => /标题|title/i.test(e.getAttribute('placeholder') || ''));
  const editable = [...document.querySelectorAll('.editor__inner[contenteditable="true"], .editor [contenteditable="true"]')].find(visible);
  const cm = document.querySelector('.CodeMirror')?.CodeMirror;
  const models = window.monaco?.editor?.getModels() || [];
  const textarea = [...document.querySelectorAll('.editor textarea')].find(e => visible(e) && e !== title);
  return {title, editable, cm, model: models.length === 1 ? models[0] : null, textarea};
}
function oneShowCSDNRead() {
  const c = oneShowCSDNControls();
  const body = c.editable ? c.editable.textContent : c.cm ? c.cm.getValue() : c.model ? c.model.getValue() : c.textarea?.value;
  return {ready: !!c.title && body !== undefined, title: c.title?.value || '', body: body || ''};
}
function oneShowCSDNNormalize(s) {
  return s.replace(/\r\n/g,'\n').replace(/\n+$/, '').replace(/!\[[^\]\n]*\]\((<[^>\n]*>|[^\n]*?)\)/g, (whole, destination) => {
    let url = (destination || '').trim();
    try {
      const address = new URL(url.replace(/^<|>$/g, ''));
      if (address.hostname === 'img-home.csdnimg.cn' && address.searchParams.has('origin_url')) url = address.searchParams.get('origin_url');
    } catch (_) {}
    url = url.replace(/^<|>$/g, '');
    return '![' + url + ']';
  });
}
function oneShowCSDNCollapseSidebar() {
  const controls = [...document.querySelectorAll('button,a,[role="button"]')];
  const visible = e => e.getBoundingClientRect().width > 0 && e.getBoundingClientRect().height > 0;
  const labels = e => [e.getAttribute('aria-label'), e.getAttribute('title'), e.textContent].filter(Boolean).map(s => s.trim());
  const button = controls.find(e => visible(e) && !e.disabled && labels(e).some(s => /^(收起侧边栏|收起右侧栏|收起)$/.test(s)));
  if (!button) return false;
  button.click(); return true;
}
function oneShowCSDNFill(title, body) {
  oneShowCSDNCollapseSidebar();
  const c = oneShowCSDNControls(), state = oneShowCSDNRead();
  if (!state.ready) return 'waiting';
  document.querySelector('.article-bar__title:not(input):not(textarea)')?.click();
  Object.getOwnPropertyDescriptor(c.title.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype, 'value').set.call(c.title, title);
  c.title.dispatchEvent(new Event('input', {bubbles:true})); c.title.dispatchEvent(new Event('change', {bubbles:true})); c.title.blur();
  if (oneShowCSDNNormalize(state.body) === oneShowCSDNNormalize(body)) return 'verify';
  if (c.editable) {
    const fileInput = document.querySelector('#import-markdown-file-input');
    if (fileInput) {
      const transfer = new DataTransfer();
      transfer.items.add(new File([body], title.replace(/[\\/]/g, '_') + '.md', {type:'text/markdown'}));
      fileInput.files = transfer.files; fileInput.dispatchEvent(new Event('change', {bubbles:true}));
      return 'verify';
    }
    c.editable.focus(); const range = document.createRange(); range.selectNodeContents(c.editable);
    const selection = window.getSelection(); selection.removeAllRanges(); selection.addRange(range);
    return 'paste';
  }
  if (c.cm) c.cm.setValue(body);
  else if (c.model) c.model.setValue(body);
  else { Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype,'value').set.call(c.textarea,body); c.textarea.dispatchEvent(new Event('input',{bubbles:true})); }
  return 'verify';
}
function oneShowCSDNPublish(title, body) {
  oneShowCSDNCollapseSidebar();
  const state = oneShowCSDNRead();
  if (!state.ready || state.title !== title || oneShowCSDNNormalize(state.body) !== oneShowCSDNNormalize(body)) return 'mismatch';
  // Only the editor's first-step publish entry, never the dialog's final confirmation.
  const buttons = [...document.querySelectorAll('button,a')].filter(e => /^(发布文章|发布博客)$/.test(e.textContent.trim()) && e.getBoundingClientRect().width > 0 && !e.disabled && !e.closest('[role="dialog"],.el-dialog,.modal'));
  if (buttons.length !== 1) return 'missing';
  buttons[0].click(); return 'opened';
}
