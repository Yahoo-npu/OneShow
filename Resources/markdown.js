(function (global) {
  const engine = new marked.Marked({ gfm: true, breaks: false });
  engine.use({ extensions: [{
    name: 'highlight', level: 'inline',
    start(src) { return src.indexOf('=='); },
    tokenizer(src) {
      const m = /^==(?=\S)([^\n]+?\S|\S)==/.exec(src);
      if (m) return { type: 'highlight', raw: m[0], text: m[1], tokens: this.lexer.inlineTokens(m[1]) };
    },
    renderer(token) { return '<mark>' + this.parser.parseInline(token.tokens) + '</mark>'; }
  }] });
  function frontmatter(source) {
    const match = /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/.exec(source);
    return { body: match ? source.slice(match[0].length) : source,
      root: match?.[1].match(/^typora-root-url:\s*(.+?)\s*$/m)?.[1].replace(/^['"]|['"]$/g, '') || '' };
  }
  function numberHeadings(source) {
    const parsed = frontmatter(source);
    const prefix = source.slice(0, source.length - parsed.body.length);
    const tokens = engine.lexer(parsed.body); const stack = [];
    return prefix + tokens.map(token => {
      if (token.type !== 'heading') return token.raw;
      const depth = token.depth;
      while (stack.length && stack[stack.length - 1].depth > depth) stack.pop();
      if (stack.length && stack[stack.length - 1].depth === depth) stack[stack.length - 1].count++;
      else stack.push({depth, count: 1});
      const number = stack.map(item => item.count).join('.') + '.';
      const clean = token.text.replace(/^(?:\d+(?:\.\d+)*[.、](?:\s+|(?=[^\d]))|\d+(?:\.\d+)+\s+)/, '');
      // Normalize both ATX and Setext headings to ATX without touching body/code.
      const newlines = token.raw.match(/\n+$/)?.[0] || '';
      return '#'.repeat(depth) + ' ' + number + ' ' + clean + newlines;
    }).join('');
  }
  function protectPrivacyMasks(source, ranges) {
    const code = [];
    engine.walkTokens(engine.lexer(source), token => {
      if (token.type !== 'code' && token.type !== 'codespan') return;
      let index = 0;
      while ((index = source.indexOf(token.raw, index)) >= 0) {
        code.push([index, index + token.raw.length]); index += Math.max(1, token.raw.length);
      }
    });
    let result = source;
    for (const [start, length] of [...ranges].sort((a,b) => b[0]-a[0])) {
      if (code.some(([a,b]) => start >= a && start + length <= b)) continue;
      result = result.slice(0, start) + result.slice(start, start + length).replace(/\*/g, '\\*') + result.slice(start + length);
    }
    return result;
  }
  function attributes(tag) {
    const attrs = {};
    const pattern = /([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/g;
    let m; while ((m = pattern.exec(tag))) attrs[m[1].toLowerCase()] = (m[2] ?? m[3] ?? m[4]).replace(/&amp;/g, '&').replace(/&quot;/g, '"');
    return attrs;
  }
  function online(src) { return /^(https?:)?\/\//i.test(src); }
  function prepare(source) {
    const parsed = frontmatter(source); const blocks = engine.lexer(parsed.body);
    const images = new Set(); let highlights = 0, htmlImages = 0;
    // Track references, including reference-style images, through the Markdown lexer.
    engine.walkTokens(blocks, token => { if (token.type === 'image') images.add(token.href); if (token.type === 'html') {
      for (const match of token.raw.matchAll(/<img\b[^>]*>/gi)) { const attrs = attributes(match[0]); if (attrs.src) images.add(attrs.src); }
    } });
    function inline(raw, block) {
      const protectedParts = [];
      engine.walkTokens([block], token => { if (token.type === 'code' && token.raw && raw.includes(token.raw)) {
        const key = '`MOJIAN_CODE_' + protectedParts.length + '_' + Math.random().toString(36).slice(2) + '`';
        protectedParts.push([key, token.raw]); raw = raw.split(token.raw).join(key);
      } });
      const lexer = new marked.Lexer(engine.defaults); lexer.tokens.links = blocks.links;
      function rewrite(token) {
        if (token.type === 'codespan') return token.raw;
        if (token.type === 'highlight') { highlights++; return '**' + token.text + '**'; }
        if (token.type === 'html' && /^<img\b/i.test(token.raw)) {
          const attrs = attributes(token.raw); if (!attrs.src) return token.raw;
          htmlImages++; const alt = (attrs.alt || '').replace(/[\\\[\]]/g, '\\$&');
          const src = attrs.src.replace(/ /g, '%20').replace(/</g, '%3C').replace(/>/g, '%3E');
          return '![' + alt + '](<' + src + '>)';
        }
        if (!token.tokens) return token.raw;
        let pos = 0, result = '';
        for (const child of token.tokens) { const offset = token.raw.indexOf(child.raw, pos); if (offset < 0) return token.raw;
          result += token.raw.slice(pos, offset) + rewrite(child); pos = offset + child.raw.length;
        }
        return result + token.raw.slice(pos);
      }
      let result = lexer.inlineTokens(raw).map(rewrite).join('');
      for (const [key, original] of protectedParts) result = result.split(key).join(original);
      return result;
    }
    // Block and inline code are left intact, including examples of == and <img>.
    const body = blocks.map(token => token.type === 'code' || token.type === 'def' ? token.raw : inline(token.raw, token)).join('');
    return { body, highlights, htmlImages, localImages: [...images].filter(src => !online(src)), root: parsed.root };
  }
  global.MojianMarkdown = { render: source => engine.parse(frontmatter(source).body), prepare, frontmatter, attributes, numberHeadings, protectPrivacyMasks };
})(globalThis);
