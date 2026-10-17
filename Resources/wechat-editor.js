function oneShowWechatEditors() {
  const visible = e => e && e.getBoundingClientRect().width > 0 && e.getBoundingClientRect().height > 0;
  const docs = [document];
  for (const frame of document.querySelectorAll('iframe')) { try { if (visible(frame) && frame.contentDocument) docs.push(frame.contentDocument); } catch (_) {} }
  const richTitle = document.querySelector('.title-editor__input .ProseMirror[contenteditable="true"]');
  const nativeTitle = document.querySelector('textarea#title,input#title') || [...document.querySelectorAll('input,textarea')].find(e => visible(e) && /标题/.test(e.getAttribute('placeholder') || ''));
  const title = visible(richTitle) ? richTitle : (visible(nativeTitle) ? nativeTitle : null);
  const areas = docs.flatMap(doc => [...doc.querySelectorAll('[contenteditable="true"]')]).filter(e => visible(e) && e !== title && !e.closest('.title-editor__input'));
  const body = areas.find(e => e.closest('.rich_media_content') || /edui-body|rich_media_content/.test(e.className)) || (areas.length === 1 ? areas[0] : null);
  return {title,body};
}
function oneShowWechatText(element) {
  if (!element) return '';
  if (['INPUT','TEXTAREA'].includes(element.tagName)) return element.value;
  const clone = element.cloneNode(true);
  for (const placeholder of clone.querySelectorAll('[contenteditable="false"],.editor_content_placeholder')) placeholder.remove();
  return clone.textContent || '';
}
function oneShowWechatState() {
  const {title,body} = oneShowWechatEditors();
  const pendingDialog = [...document.querySelectorAll('button,a')].some(e => e.textContent.trim() === '继续插入' && e.getBoundingClientRect().width > 0);
  return {found:!!title && !!body,title:oneShowWechatText(title),body:oneShowWechatText(body),hasMedia:!!body?.querySelector('img,video,audio'),pendingDialog};
}
function oneShowWechatPreflight() {
  const state = oneShowWechatState();
  if (!state.found) return '未找到唯一的标题和正文编辑区。请在网页确认登录完成，关闭窗口后可重新尝试。';
  if (state.pendingDialog) return '公众号正在校验粘贴排版。请在网页检查提示，关闭窗口后可重新尝试。';
  const normalize = s => s.replace(/[\s\u200b-\u200d\ufeff]+/g,'');
  if (state.title === articleTitle && normalize(state.body) === normalize(articlePlain)) return '标题和正文已核对一致。请继续检查图片、封面和手机预览，再由你在网页保存草稿或群发。';
  if (state.title.trim() || state.body.trim() || state.hasMedia) return '编辑器已有内容，为避免覆盖，请关闭窗口后重新点击发布，新建空白图文。';
  return {nativePaste:true};
}
function oneShowWechatFocus(which) {
  const element = oneShowWechatEditors()[which]; if (!element) return false;
  element.focus();
  if (['INPUT','TEXTAREA'].includes(element.tagName)) element.select();
  else {
    const doc = element.ownerDocument, range = doc.createRange(); range.selectNodeContents(element);
    const selection = doc.defaultView.getSelection(); selection.removeAllRanges(); selection.addRange(range);
  }
  return true;
}

// Confirm only the paste-format dialog, never generic confirmation or publishing dialogs.
function oneShowWechatConfirmFormat() {
  const visible = e => e && e.getBoundingClientRect().width > 0 && e.getBoundingClientRect().height > 0;
  const buttons = [...document.querySelectorAll('button,a')].filter(e => visible(e) && e.textContent.trim() === '继续插入');
  for (const button of buttons) {
    let parent = button.parentElement;
    for (let depth=0; parent && depth<7 && parent !== document.body; depth++,parent=parent.parentElement) {
      if (/内容结构检测|内容格式检查|粘贴格式/.test(parent.textContent)) { button.click(); return true; }
    }
  }
  return false;
}
function oneShowWechatOpenEditor() {
  if (location.hostname !== 'mp.weixin.qq.com') return 'waiting';
  if (oneShowWechatState().found) return 'editor';
  const token = new URL(location.href).searchParams.get('token');
  if (!token) return 'login';
  const link = [...document.querySelectorAll('a[href]')].find(e => {
    try { const url = new URL(e.href,location.href); return url.hostname === 'mp.weixin.qq.com' && /appmsg_edit/.test(url.search) && !url.searchParams.has('appmsgid'); } catch (_) { return false; }
  });
  if (link) { link.click(); return 'opening'; }
  const url = new URL('/cgi-bin/appmsg',location.origin);
  url.search = new URLSearchParams({t:'media/appmsg_edit',action:'edit',type:'77',isNew:'1',lang:'zh_CN',token}).toString();
  location.assign(url.href); return 'opening';
}
