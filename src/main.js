import { Marked } from 'marked';
import markedAlert from 'marked-alert';
import { gfmHeadingId } from 'marked-gfm-heading-id';
import { markedHighlight } from 'marked-highlight';
import hljs from 'highlight.js';
import mermaid from 'mermaid';
import { SAMPLE_MARKDOWN } from './sample.js';

// --- DOM Elements ---
const editor = document.getElementById('markdown-input');
const lineNumbers = document.getElementById('line-numbers');
const preview = document.getElementById('markdown-preview');
const previewContainer = document.getElementById('preview-container');
const filenameBadge = document.getElementById('current-filename');
const dirtyIndicator = document.getElementById('dirty-indicator');
const mermaidStatus = document.getElementById('mermaid-status');
const statLines = document.getElementById('stat-lines');
const statWords = document.getElementById('stat-words');
const statChars = document.getElementById('stat-chars');
const fileSourceType = document.getElementById('file-source-type');

const btnOpenFile = document.getElementById('btn-open-file');
const btnOpenFolder = document.getElementById('btn-open-folder');
const btnSaveFile = document.getElementById('btn-save-file');
const btnSample = document.getElementById('btn-sample');
const fileInput = document.getElementById('file-input');
const folderInput = document.getElementById('folder-input');
const chkSyncScroll = document.getElementById('chk-sync-scroll');
const btnThemeToggle = document.getElementById('btn-theme-toggle');

const fileSidebar = document.getElementById('file-sidebar');
const fileList = document.getElementById('file-list');
const btnCloseSidebar = document.getElementById('btn-close-sidebar');

const editorDropzone = document.getElementById('editor-dropzone');
const dropOverlay = document.getElementById('drop-overlay');
const splitter = document.getElementById('pane-splitter');
const workspace = document.getElementById('workspace');

const btnViewEditor = document.getElementById('btn-view-editor');
const btnViewSplit = document.getElementById('btn-view-split');
const btnViewPreview = document.getElementById('btn-view-preview');
const btnToggleEditorPane = document.getElementById('btn-toggle-editor-pane');
const btnTogglePreviewPane = document.getElementById('btn-toggle-preview-pane');

// --- State ---
let currentFileHandle = null;
let currentFileName = 'welcome.md';
let isDirty = false;
let directoryFiles = []; // Array of { name, path, loadText: async () => string, handle? }
let activeFileIndex = -1;
let renderTimer = null;
let mermaidCounter = 0;

// --- Lazy-load DOMPurify fallback per sanitize-untrusted-html guidance ---
let domPurifyPromise;
function loadDOMPurify() {
  domPurifyPromise ??= import('dompurify').then((mod) => mod.default ?? mod);
  return domPurifyPromise;
}

const SANITIZE_ELEMENTS = [
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
  'p', 'br', 'hr', 'blockquote', 'pre', 'code',
  'ul', 'ol', 'li', 'dl', 'dt', 'dd',
  'table', 'thead', 'tbody', 'tfoot', 'tr', 'th', 'td',
  'strong', 'b', 'em', 'i', 'del', 's', 'ins', 'mark', 'sub', 'sup', 'small', 'kbd',
  'a', 'img', 'figure', 'figcaption', 'details', 'summary',
  'div', 'span', 'input', 'svg', 'path'
];

const SANITIZE_ATTRIBUTES = [
  'class', 'id', 'href', 'src', 'alt', 'title', 'width', 'height', 'loading',
  'align', 'colspan', 'rowspan', 'type', 'checked', 'disabled', 'open',
  'tabindex', 'aria-hidden', 'aria-label', 'viewBox', 'd', 'fill', 'stroke',
  'stroke-width', 'stroke-linecap', 'stroke-linejoin'
];

async function safeRenderHTML(container, html) {
  if ('setHTML' in Element.prototype) {
    container.setHTML(html, {
      sanitizer: {
        elements: SANITIZE_ELEMENTS,
        attributes: SANITIZE_ATTRIBUTES
      }
    });
  } else {
    const DOMPurify = await loadDOMPurify();
    container.innerHTML = DOMPurify.sanitize(html, {
      ALLOWED_TAGS: [...SANITIZE_ELEMENTS, '#text'],
      ALLOWED_ATTR: SANITIZE_ATTRIBUTES,
      ALLOW_ARIA_ATTR: false,
      ALLOW_DATA_ATTR: false,
      KEEP_CONTENT: false
    });
  }
}

// --- Configure Marked with GFM, GitHub Alerts, Syntax Highlighting, and Mermaid ---
let currentMermaidBlocks = [];

const marked = new Marked(
  markedHighlight({
    emptyLangClass: 'hljs',
    langPrefix: 'hljs language-',
    highlight(code, lang) {
      if (lang === 'mermaid') {
        return code;
      }
      const language = hljs.getLanguage(lang) ? lang : 'plaintext';
      return hljs.highlight(code, { language }).value;
    }
  }),
  markedAlert(),
  gfmHeadingId()
);

marked.use({
  gfm: true,
  breaks: false,
  renderer: {
    code({ text, lang }) {
      const normalizedLang = (lang || '').trim().toLowerCase();
      if (normalizedLang === 'mermaid') {
        const index = currentMermaidBlocks.length;
        currentMermaidBlocks.push(text);
        return `<div class="mermaid-block" id="mermaid-slot-${index}"></div>`;
      }
      const validLang = hljs.getLanguage(normalizedLang) ? normalizedLang : 'plaintext';
      const highlighted = hljs.highlight(text, { language: validLang }).value;
      return `<pre tabindex="0"><code class="hljs language-${validLang}">${highlighted}</code></pre>`;
    }
  }
});

// --- Theme Detection & Toggle (following dark-mode & dark-mode-toggle guides) ---
const darkMediaQuery = window.matchMedia('(prefers-color-scheme: dark)');

function getEffectiveScheme() {
  const meta = document.querySelector('meta[name="color-scheme"]');
  const content = meta?.content || 'light dark';
  if (content === 'dark' || content === 'light') {
    return content;
  }
  return darkMediaQuery.matches ? 'dark' : 'light';
}

function initMermaidTheme() {
  const scheme = getEffectiveScheme();
  mermaid.initialize({
    startOnLoad: false,
    theme: scheme === 'dark' ? 'dark' : 'default',
    securityLevel: 'strict',
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif'
  });
}

btnThemeToggle.addEventListener('click', () => {
  const meta = document.querySelector('meta[name="color-scheme"]');
  const systemScheme = darkMediaQuery.matches ? 'dark' : 'light';
  const currentRendered = getEffectiveScheme();
  const targetScheme = currentRendered === 'dark' ? 'light' : 'dark';

  try {
    if (targetScheme !== systemScheme) {
      localStorage.setItem('color-scheme', targetScheme);
      meta.content = targetScheme;
    } else {
      localStorage.removeItem('color-scheme');
      meta.content = 'light dark';
    }
  } catch (e) {
    meta.content = targetScheme;
  }

  initMermaidTheme();
  renderMarkdown();
});

darkMediaQuery.addEventListener('change', () => {
  initMermaidTheme();
  renderMarkdown();
});

window.addEventListener('storage', (e) => {
  if (e.key === 'color-scheme') {
    const meta = document.querySelector('meta[name="color-scheme"]');
    meta.content = e.newValue ?? 'light dark';
    initMermaidTheme();
    renderMarkdown();
  }
});

// --- Markdown + Mermaid Rendering ---
async function renderMarkdown() {
  const raw = editor.value;
  updateStatsAndLineNumbers(raw);

  currentMermaidBlocks = [];
  const rawHtml = await marked.parse(raw);
  await safeRenderHTML(preview, rawHtml);

  // Interactive task-list checkboxes inside preview
  const checkboxes = preview.querySelectorAll('li > input[type="checkbox"]');
  checkboxes.forEach((checkbox, idx) => {
    checkbox.removeAttribute('disabled');
    checkbox.addEventListener('change', () => toggleMarkdownCheckbox(idx, checkbox.checked));
  });

  // Render Mermaid blocks if present
  if (currentMermaidBlocks.length === 0) {
    mermaidStatus.textContent = 'GFM Ready';
    rebuildScrollSyncMap();
    if (chkSyncScroll.checked) {
      lockScrollSource('editor');
      syncEditorToPreview();
    }
    return;
  }

  mermaidStatus.textContent = `Rendering ${currentMermaidBlocks.length} diagram${currentMermaidBlocks.length > 1 ? 's' : ''}...`;
  initMermaidTheme();

  let hasErrors = false;
  for (let i = 0; i < currentMermaidBlocks.length; i++) {
    const slot = document.getElementById(`mermaid-slot-${i}`);
    if (!slot) continue;

    const code = currentMermaidBlocks[i].trim();
    const renderId = `mermaid-svg-${++mermaidCounter}`;
    try {
      const { svg } = await mermaid.render(renderId, code);
      slot.innerHTML = svg;
    } catch (err) {
      hasErrors = true;
      // Clean up any stray error element Mermaid might have appended
      const stray = document.getElementById(`d${renderId}`) || document.getElementById(renderId);
      if (stray) stray.remove();

      const errBox = document.createElement('div');
      errBox.className = 'mermaid-error';
      errBox.textContent = `Mermaid Syntax Error:\n${err?.message || String(err)}`;
      slot.replaceChildren(errBox);
    }
  }

  rebuildScrollSyncMap();
  if (chkSyncScroll.checked) {
    lockScrollSource('editor');
    syncEditorToPreview();
  }

  mermaidStatus.textContent = hasErrors
    ? 'Mermaid syntax warning'
    : `${currentMermaidBlocks.length} Mermaid diagram${currentMermaidBlocks.length > 1 ? 's' : ''}`;
}

function scheduleRender() {
  clearTimeout(renderTimer);
  renderTimer = setTimeout(renderMarkdown, 120);
}

// Toggle corresponding `- [ ]` or `- [x]` in editor when user clicks a task list checkbox in preview
function toggleMarkdownCheckbox(targetIndex, isChecked) {
  let currentIndex = 0;
  const taskRegex = /^(\s*(?:[-*+]|\d+\.)\s+\[)([ xX])(\])/gm;
  const updated = editor.value.replace(taskRegex, (match, prefix, state, suffix) => {
    if (currentIndex++ === targetIndex) {
      return `${prefix}${isChecked ? 'x' : ' '}${suffix}`;
    }
    return match;
  });

  if (updated !== editor.value) {
    editor.value = updated;
    setDirty(true);
    scheduleRender();
  }
}

function updateStatsAndLineNumbers(text) {
  const lines = text.split('\n').length;
  const words = text.trim() ? text.trim().split(/\s+/).length : 0;
  const chars = text.length;

  statLines.textContent = `${lines} ${lines === 1 ? 'line' : 'lines'}`;
  statWords.textContent = `${words} ${words === 1 ? 'word' : 'words'}`;
  statChars.textContent = `${chars} ${chars === 1 ? 'char' : 'chars'}`;

  // Update line number gutter efficiently
  const currentCount = lineNumbers.dataset.count ? Number(lineNumbers.dataset.count) : 0;
  if (currentCount !== lines) {
    const nums = Array.from({ length: lines }, (_, i) => i + 1).join('\n');
    lineNumbers.textContent = nums;
    lineNumbers.dataset.count = String(lines);
  }
}

function setDirty(dirty) {
  isDirty = dirty;
  dirtyIndicator.hidden = !dirty;
}

function setDocument(name, content, sourceLabel = 'Local file', handle = null) {
  currentFileName = name;
  currentFileHandle = handle;
  filenameBadge.textContent = name;
  fileSourceType.textContent = sourceLabel;
  editor.value = content;
  editor.scrollTop = 0;
  previewContainer.scrollTop = 0;
  setDirty(false);
  renderMarkdown();
}

// --- Local File Reading & Saving ---

// 1. Open Single Local File
btnOpenFile.addEventListener('click', async () => {
  if ('showOpenFilePicker' in window) {
    try {
      const [handle] = await window.showOpenFilePicker({
        types: [
          {
            description: 'Markdown Documents',
            accept: {
              'text/markdown': ['.md', '.markdown', '.mdx'],
              'text/plain': ['.txt']
            }
          }
        ],
        multiple: false
      });
      const file = await handle.getFile();
      const content = await file.text();
      setDocument(file.name, content, 'File System Access API', handle);
      return;
    } catch (err) {
      if (err.name === 'AbortError') return;
    }
  }
  fileInput.click();
});

fileInput.addEventListener('change', async (e) => {
  const file = e.target.files?.[0];
  if (!file) return;
  const content = await file.text();
  setDocument(file.name, content, 'Local File Input', null);
  fileInput.value = '';
});

// 2. Open Local Folder of Markdown Files
btnOpenFolder.addEventListener('click', async () => {
  if ('showDirectoryPicker' in window) {
    try {
      const dirHandle = await window.showDirectoryPicker();
      const entries = [];
      for await (const entry of dirHandle.values()) {
        if (entry.kind === 'file' && /\.(md|markdown|mdx|txt)$/i.test(entry.name)) {
          entries.push({
            name: entry.name,
            handle: entry,
            loadText: async () => {
              const f = await entry.getFile();
              return f.text();
            }
          });
        }
      }
      entries.sort((a, b) => a.name.localeCompare(b.name));
      populateFileSidebar(entries, `Folder: ${dirHandle.name}`);
      return;
    } catch (err) {
      if (err.name === 'AbortError') return;
    }
  }
  folderInput.click();
});

folderInput.addEventListener('change', (e) => {
  const files = Array.from(e.target.files || []).filter((f) =>
    /\.(md|markdown|mdx|txt)$/i.test(f.name)
  );
  files.sort((a, b) => a.name.localeCompare(b.name));
  const entries = files.map((file) => ({
    name: file.webkitRelativePath || file.name,
    handle: null,
    loadText: () => file.text()
  }));
  populateFileSidebar(entries, 'Local Folder');
  folderInput.value = '';
});

function populateFileSidebar(entries, sourceLabel) {
  directoryFiles = entries;
  fileList.replaceChildren();

  if (entries.length === 0) {
    const emptyLi = document.createElement('li');
    emptyLi.textContent = 'No .md files found';
    emptyLi.style.padding = '8px';
    emptyLi.style.color = 'var(--fg-muted)';
    fileList.appendChild(emptyLi);
    fileSidebar.hidden = false;
    return;
  }

  entries.forEach((item, index) => {
    const li = document.createElement('li');
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'file-item-btn';
    btn.textContent = item.name;
    btn.addEventListener('click', () => selectSidebarFile(index, sourceLabel));
    li.appendChild(btn);
    fileList.appendChild(li);
  });

  fileSidebar.hidden = false;
  selectSidebarFile(0, sourceLabel);
}

async function selectSidebarFile(index, sourceLabel) {
  const item = directoryFiles[index];
  if (!item) return;
  activeFileIndex = index;

  Array.from(fileList.querySelectorAll('.file-item-btn')).forEach((btn, idx) => {
    if (idx === index) {
      btn.setAttribute('aria-current', 'true');
    } else {
      btn.removeAttribute('aria-current');
    }
  });

  const text = await item.loadText();
  setDocument(item.name, text, sourceLabel, item.handle);
}

btnCloseSidebar.addEventListener('click', () => {
  fileSidebar.hidden = true;
});

// 3. Save File to Disk
async function saveCurrentFile() {
  const content = editor.value;

  if (currentFileHandle && 'createWritable' in currentFileHandle) {
    try {
      const writable = await currentFileHandle.createWritable();
      await writable.write(content);
      await writable.close();
      setDirty(false);
      fileSourceType.textContent = 'Saved to disk';
      return;
    } catch (err) {
      if (err.name === 'AbortError') return;
    }
  }

  if ('showSaveFilePicker' in window) {
    try {
      const handle = await window.showSaveFilePicker({
        suggestedName: currentFileName || 'document.md',
        types: [
          {
            description: 'Markdown File',
            accept: { 'text/markdown': ['.md'] }
          }
        ]
      });
      const writable = await handle.createWritable();
      await writable.write(content);
      await writable.close();
      currentFileHandle = handle;
      currentFileName = handle.name;
      filenameBadge.textContent = handle.name;
      setDirty(false);
      fileSourceType.textContent = 'Saved to disk';
      return;
    } catch (err) {
      if (err.name === 'AbortError') return;
    }
  }

  // Fallback download
  const blob = new Blob([content], { type: 'text/markdown;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = currentFileName || 'document.md';
  a.click();
  URL.revokeObjectURL(url);
  setDirty(false);
  fileSourceType.textContent = 'Downloaded .md';
}

btnSaveFile.addEventListener('click', saveCurrentFile);

btnSample.addEventListener('click', () => {
  setDocument('welcome.md', SAMPLE_MARKDOWN, 'Built-in Demo', null);
});

// 4. Drag and Drop Local Files into Editor
editorDropzone.addEventListener('dragover', (e) => {
  e.preventDefault();
  dropOverlay.hidden = false;
});

editorDropzone.addEventListener('dragleave', (e) => {
  if (!editorDropzone.contains(e.relatedTarget)) {
    dropOverlay.hidden = true;
  }
});

editorDropzone.addEventListener('drop', async (e) => {
  e.preventDefault();
  dropOverlay.hidden = true;

  const item = e.dataTransfer?.items?.[0];
  if (item && 'getAsFileSystemHandle' in item) {
    try {
      const handle = await item.getAsFileSystemHandle();
      if (handle && handle.kind === 'file') {
        const file = await handle.getFile();
        const text = await file.text();
        setDocument(file.name, text, 'Dropped Local File', handle);
        return;
      }
    } catch (_) {
      // Fall back to DataTransfer.files
    }
  }

  const file = e.dataTransfer?.files?.[0];
  if (file) {
    const text = await file.text();
    setDocument(file.name, text, 'Dropped Local File', null);
  }
});

// --- Editor Interactions, Formatting Toolbar & Section/Header-Anchored Scroll Sync ---
let activeScrollSource = null;
let scrollLockTimer = null;
let scrollAnchors = []; // Sorted array of { editorY, previewY, line }

function lockScrollSource(source) {
  activeScrollSource = source;
  clearTimeout(scrollLockTimer);
  scrollLockTimer = setTimeout(() => {
    activeScrollSource = null;
  }, 100);
}

/**
 * Extracts source line numbers for all top-level Markdown blocks, prioritizing headers
 * (ATX `#` and Setext `===`/`---`) and structural blocks (fenced code/Mermaid, tables,
 * blockquotes/alerts, horizontal rules) so scroll sync aligns each document section.
 */
function extractMarkdownBlockLines(raw) {
  const lines = raw.split('\n');
  const blockAnchors = [];
  let inFence = false;
  let fenceMarker = '';

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    if (inFence) {
      if (trimmed.startsWith(fenceMarker)) {
        inFence = false;
      }
      continue;
    }

    // Fenced code or Mermaid block start
    const fenceMatch = line.match(/^ {0,3}(`{3,}|~{3,})/);
    if (fenceMatch) {
      inFence = true;
      fenceMarker = fenceMatch[1];
      blockAnchors.push({ line: i, type: 'fence' });
      continue;
    }

    // ATX Heading (# H1 .. ###### H6)
    const headingMatch = line.match(/^ {0,3}(#{1,6})\s+(.*)$/);
    if (headingMatch) {
      blockAnchors.push({ line: i, type: 'heading' });
      continue;
    }

    // Setext Heading (underlined with === or ---)
    if (
      i > 0 &&
      lines[i - 1].trim().length > 0 &&
      !/^ {0,3}(?:[-*+]|\d+\.|>)/.test(lines[i - 1]) &&
      /^ {0,3}(?:=+|-+)\s*$/.test(line)
    ) {
      blockAnchors.push({ line: i - 1, type: 'heading' });
      continue;
    }

    // Horizontal Rule
    if (/^ {0,3}(?:(?:\*\s*){3,}|(?:-\s*){3,}|(?:_\s*){3,})$/.test(line)) {
      blockAnchors.push({ line: i, type: 'hr' });
    }
  }

  return blockAnchors;
}

/**
 * Rebuilds the piecewise-linear scroll mapping between editor scroll offsets
 * and preview scroll offsets anchored on every document heading (`h1`-`h6`),
 * horizontal rule (`hr`), and fenced block (`pre` / `.mermaid-block`).
 */
function rebuildScrollSyncMap() {
  const maxEditorScroll = Math.max(0, editor.scrollHeight - editor.clientHeight);
  const maxPreviewScroll = Math.max(0, previewContainer.scrollHeight - previewContainer.clientHeight);

  const computed = getComputedStyle(editor);
  const lineHeight = parseFloat(computed.lineHeight) || 21.6;
  const paddingTop = parseFloat(computed.paddingTop) || 16;

  const sourceAnchors = extractMarkdownBlockLines(editor.value);
  const sourceHeadings = sourceAnchors.filter((a) => a.type === 'heading');

  const previewHeadings = Array.from(preview.querySelectorAll('h1, h2, h3, h4, h5, h6'));
  const containerRect = previewContainer.getBoundingClientRect();
  // Read margin-top on headings so scrolled header lands cleanly near the top of the pane
  const headingTopMargin = 16;

  const points = [{ editorY: 0, previewY: 0, line: 0 }];

  // Pair every source heading with its corresponding rendered heading in the preview
  const headingCount = Math.min(sourceHeadings.length, previewHeadings.length);
  for (let i = 0; i < headingCount; i++) {
    const src = sourceHeadings[i];
    const domHeading = previewHeadings[i];

    const rawEditorY = Math.max(0, paddingTop + src.line * lineHeight - headingTopMargin);
    const rawPreviewY = Math.max(
      0,
      domHeading.getBoundingClientRect().top -
        containerRect.top +
        previewContainer.scrollTop -
        headingTopMargin
    );

    points.push({
      editorY: Math.min(maxEditorScroll, rawEditorY),
      previewY: Math.min(maxPreviewScroll, rawPreviewY),
      line: src.line
    });
  }

  // Also anchor on fenced code / Mermaid diagrams so tall diagrams interpolate accurately
  const sourceFences = sourceAnchors.filter((a) => a.type === 'fence');
  const previewFences = Array.from(preview.querySelectorAll('pre, .mermaid-block'));
  if (sourceFences.length === previewFences.length) {
    for (let i = 0; i < sourceFences.length; i++) {
      const src = sourceFences[i];
      const domFence = previewFences[i];
      const rawEditorY = Math.max(0, paddingTop + src.line * lineHeight - headingTopMargin);
      const rawPreviewY = Math.max(
        0,
        domFence.getBoundingClientRect().top -
          containerRect.top +
          previewContainer.scrollTop -
          headingTopMargin
      );
      points.push({
        editorY: Math.min(maxEditorScroll, rawEditorY),
        previewY: Math.min(maxPreviewScroll, rawPreviewY),
        line: src.line
      });
    }
  }

  // Sort by source line order and ensure monotonic non-decreasing scroll positions
  points.sort((a, b) => a.line - b.line);
  points.push({
    editorY: maxEditorScroll,
    previewY: maxPreviewScroll,
    line: editor.value.split('\n').length
  });

  const monotonic = [points[0]];
  for (let i = 1; i < points.length; i++) {
    const prev = monotonic[monotonic.length - 1];
    const curr = points[i];
    const editorY = Math.max(prev.editorY, curr.editorY);
    const previewY = Math.max(prev.previewY, curr.previewY);
    if (editorY === prev.editorY && previewY === prev.previewY) continue;
    monotonic.push({ editorY, previewY, line: curr.line });
  }

  scrollAnchors = monotonic;
}

/**
 * Piecewise-linear interpolation across document section anchors.
 */
function interpolateScroll(value, fromKey, toKey) {
  if (scrollAnchors.length < 2) {
    rebuildScrollSyncMap();
  }
  if (scrollAnchors.length < 2) return 0;

  if (value <= scrollAnchors[0][fromKey]) {
    return scrollAnchors[0][toKey];
  }

  for (let i = 0; i < scrollAnchors.length - 1; i++) {
    const start = scrollAnchors[i];
    const end = scrollAnchors[i + 1];
    if (value >= start[fromKey] && value <= end[fromKey]) {
      const span = end[fromKey] - start[fromKey];
      if (span <= 0) return end[toKey];
      const t = (value - start[fromKey]) / span;
      return start[toKey] + t * (end[toKey] - start[toKey]);
    }
  }

  return scrollAnchors[scrollAnchors.length - 1][toKey];
}

function syncEditorToPreview() {
  previewContainer.scrollTop = interpolateScroll(editor.scrollTop, 'editorY', 'previewY');
}

function syncPreviewToEditor() {
  editor.scrollTop = interpolateScroll(previewContainer.scrollTop, 'previewY', 'editorY');
  lineNumbers.scrollTop = editor.scrollTop;
}

editor.addEventListener('input', () => {
  setDirty(true);
  scheduleRender();
});

editor.addEventListener(
  'scroll',
  () => {
    lineNumbers.scrollTop = editor.scrollTop;

    if (!chkSyncScroll.checked || activeScrollSource === 'preview') return;
    lockScrollSource('editor');
    syncEditorToPreview();
  },
  { passive: true }
);

previewContainer.addEventListener(
  'scroll',
  () => {
    if (!chkSyncScroll.checked || activeScrollSource === 'editor') return;
    lockScrollSource('preview');
    syncPreviewToEditor();
  },
  { passive: true }
);

chkSyncScroll.addEventListener('change', () => {
  if (chkSyncScroll.checked) {
    rebuildScrollSyncMap();
    lockScrollSource('editor');
    syncEditorToPreview();
  }
});

window.addEventListener('resize', () => {
  rebuildScrollSyncMap();
});

editor.addEventListener('keydown', (e) => {
  // Cmd/Ctrl + S to save
  if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 's') {
    e.preventDefault();
    saveCurrentFile();
    return;
  }

  // Tab indentation support
  if (e.key === 'Tab') {
    e.preventDefault();
    const start = editor.selectionStart;
    const end = editor.selectionEnd;
    editor.setRangeText('  ', start, end, 'end');
    setDirty(true);
    scheduleRender();
  }
});

// Quick Formatting Toolbar Snippets
const SNIPPETS = {
  bold: (sel) => `**${sel || 'bold text'}**`,
  italic: (sel) => `*${sel || 'italic text'}*`,
  code: (sel) => `\n\`\`\`javascript\n${sel || 'console.log("Hello GFM!");'}\n\`\`\`\n`,
  table: () =>
    `\n| Column 1 | Column 2 | Column 3 |\n| :--- | :---: | ---: |\n| Left | Center | Right |\n| Data A | Data B | Data C |\n`,
  alert: () => `\n> [!NOTE]\n> Highlight important information with GitHub-flavored alerts.\n`,
  mermaid: () =>
    `\n\`\`\`mermaid\nflowchart TD\n    Start["Start Idea"] --> Build["Write Markdown"]\n    Build --> Render["Live GFM + Mermaid Preview"]\n\`\`\`\n`
};

document.querySelectorAll('[data-insert]').forEach((btn) => {
  btn.addEventListener('click', () => {
    const type = btn.dataset.insert;
    const generator = SNIPPETS[type];
    if (!generator) return;

    const start = editor.selectionStart;
    const end = editor.selectionEnd;
    const selected = editor.value.slice(start, end);
    const replacement = generator(selected);

    editor.focus();
    editor.setRangeText(replacement, start, end, 'end');
    setDirty(true);
    scheduleRender();
  });
});

// --- Pane Minimize / Restore Controls ---
/**
 * Sets which pane (if any) is minimized:
 * - null: Dual-pane Split View
 * - 'editor': Editor minimized into left vertical rail, Preview maximized
 * - 'preview': Preview minimized into right vertical rail, Editor maximized
 */
function setMinimizedPane(minimizedTarget) {
  if (!minimizedTarget) {
    delete workspace.dataset.minimized;
  } else {
    workspace.dataset.minimized = minimizedTarget;
  }

  const isEditorMin = minimizedTarget === 'editor';
  const isPreviewMin = minimizedTarget === 'preview';
  const isSplit = !minimizedTarget;

  btnViewEditor.setAttribute('aria-pressed', String(isPreviewMin));
  btnViewSplit.setAttribute('aria-pressed', String(isSplit));
  btnViewPreview.setAttribute('aria-pressed', String(isEditorMin));

  btnToggleEditorPane.setAttribute(
    'aria-label',
    isEditorMin ? 'Restore Markdown Editor pane' : 'Minimize Markdown Editor pane'
  );
  btnToggleEditorPane.title = isEditorMin
    ? 'Restore Markdown Editor pane'
    : 'Minimize Markdown Editor pane';

  btnTogglePreviewPane.setAttribute(
    'aria-label',
    isPreviewMin ? 'Restore Preview pane' : 'Minimize Preview pane'
  );
  btnTogglePreviewPane.title = isPreviewMin
    ? 'Restore Preview pane'
    : 'Minimize Preview pane';

  // Rebuild section scroll anchors once layout settles
  requestAnimationFrame(() => {
    rebuildScrollSyncMap();
    if (isSplit && chkSyncScroll.checked) {
      lockScrollSource('editor');
      syncEditorToPreview();
    }
  });
}

btnToggleEditorPane.addEventListener('click', () => {
  const current = workspace.dataset.minimized;
  setMinimizedPane(current === 'editor' ? null : 'editor');
});

btnTogglePreviewPane.addEventListener('click', () => {
  const current = workspace.dataset.minimized;
  setMinimizedPane(current === 'preview' ? null : 'preview');
});

btnViewEditor.addEventListener('click', () => setMinimizedPane('preview'));
btnViewSplit.addEventListener('click', () => setMinimizedPane(null));
btnViewPreview.addEventListener('click', () => setMinimizedPane('editor'));

// --- Resizable Dual-Pane Splitter ---
let isResizing = false;

splitter.addEventListener('pointerdown', (e) => {
  isResizing = true;
  splitter.setPointerCapture(e.pointerId);
  document.body.style.userSelect = 'none';
});

splitter.addEventListener('pointermove', (e) => {
  if (!isResizing) return;
  const rect = workspace.getBoundingClientRect();
  const sidebarWidth = fileSidebar.hidden ? 0 : fileSidebar.getBoundingClientRect().width;
  const availableWidth = rect.width - sidebarWidth;
  const offsetX = e.clientX - rect.left - sidebarWidth;
  const percentage = Math.min(80, Math.max(20, (offsetX / availableWidth) * 100));
  document.documentElement.style.setProperty('--editor-ratio', `${percentage}%`);
});

splitter.addEventListener('pointerup', (e) => {
  if (!isResizing) return;
  isResizing = false;
  splitter.releasePointerCapture(e.pointerId);
  document.body.style.userSelect = '';
  rebuildScrollSyncMap();
});

// Keyboard support for splitter accessibility
splitter.addEventListener('keydown', (e) => {
  const current = parseFloat(
    getComputedStyle(document.documentElement).getPropertyValue('--editor-ratio') || '50'
  );
  if (e.key === 'ArrowLeft') {
    e.preventDefault();
    document.documentElement.style.setProperty('--editor-ratio', `${Math.max(20, current - 3)}%`);
  } else if (e.key === 'ArrowRight') {
    e.preventDefault();
    document.documentElement.style.setProperty('--editor-ratio', `${Math.min(80, current + 3)}%`);
  }
});

// --- Initialize App ---
initMermaidTheme();
setDocument('welcome.md', SAMPLE_MARKDOWN, 'Built-in Demo', null);
