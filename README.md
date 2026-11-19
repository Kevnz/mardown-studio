# Markdown Studio

**Markdown Studio** is a native macOS dual-pane Markdown editor and live previewer built with Swift/AppKit and a bundled Vite + `WKWebView` engine. It supports full **GitHub Flavored Markdown (GFM)**, live **Mermaid v11** diagram rendering, syntax highlighting, section-anchored bidirectional scroll synchronization, and automatic session restoration of the last opened file and folder.

---

## Features

- **Native macOS Application**:
  - Unified AppKit `NSToolbar` with SF Symbols and native `NSSegmentedControl` view mode selector (*Editor Only*, *Split View*, *Preview Only*).
  - Native `NSOpenPanel` and `NSSavePanel` file/folder dialogs, Finder **"Open With"** and Dock drag-and-drop support, and native window proxy icon (`representedURL`) & edited state indicator.
  - Custom CoreGraphics-generated macOS `.icns` application icon.
- **Last-Opened Session Restoration**:
  - Automatically reopens the last edited file and folder on launch via macOS `UserDefaults` (with `localStorage` fallback for unsaved buffers and web mode).
- **GitHub Flavored Markdown (GFM)**:
  - Tables, strikethrough, autolinks, interactive task lists (clicking a checkbox in the preview updates the Markdown source), heading IDs, and GitHub-style alert callouts (`[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!CAUTION]`).
  - Code syntax highlighting powered by `highlight.js` and HTML sanitization via `DOMPurify`.
- **Live Mermaid v11 Diagrams**:
  - Client-side SVG rendering for flowcharts, sequence diagrams, state diagrams, class diagrams, ER diagrams, Gantt charts, quadrant charts, and more, automatically themed to match Light or Dark mode.
- **Section & Header-Anchored Scroll Sync**:
  - Piecewise-linear bidirectional scroll synchronization anchored on headings (`h1`–`h6`), fenced code/Mermaid blocks, and horizontal rules so editor lines stay aligned with tall diagrams and preview sections.
- **Flexible Workspace**:
  - Draggable split-pane divider with keyboard arrow support.
  - Collapsible Editor or Preview panes into compact vertical side rails.
  - Collapsible folder sidebar for browsing local `.md`, `.markdown`, `.mdx`, and `.txt` files.

---

## Requirements

To build and run the native macOS application, you need:

1. **macOS 12.0 (Monterey) or later** (configured via `LSMinimumSystemVersion` in `macos/Info.plist`).
2. **Xcode Command Line Tools** (provides `swift`, `swiftc`, `iconutil`, `sips`, and `codesign`):
   ```bash
   xcode-select --install
   ```
3. **Node.js 18+ and npm** (used to bundle the GFM + Mermaid web assets with Vite):
   ```bash
   node --version
   npm --version
   ```

---

## Building and Running

### 1. Install Dependencies

From the project root:

```bash
npm install
```

### 2. Build and Launch the Native macOS App

To generate the `.icns` app icon, build the production web bundle, compile the native Swift AppKit binary (`Cocoa`, `WebKit`, `UniformTypeIdentifiers`), assemble `build/Markdown Studio.app`, and launch it:

```bash
npm run open:mac
```

Or build the `.app` bundle without launching:

```bash
npm run build:mac
```

The compiled application bundle is output to:

```text
build/Markdown Studio.app
```

You can launch it from Finder, drag it to `/Applications`, or open it from the terminal:

```bash
open "./build/Markdown Studio.app"
```

### 3. Run in Local Web Development Mode (Optional)

You can also run the editor directly in a browser using the Vite dev server (uses the File System Access API / standard file inputs instead of the native AppKit bridge):

```bash
npm run dev
```

To preview the production static bundle in a browser:

```bash
npm run build
npm run preview
```

---

## Keyboard Shortcuts (macOS App)

| Shortcut | Action |
| :--- | :--- |
| `Cmd + N` | New Document |
| `Cmd + O` | Open Markdown File… |
| `Cmd + Shift + O` | Open Folder… |
| `Cmd + S` | Save |
| `Cmd + Shift + S` | Save As… |
| `Cmd + R` | Load Built-in Demo |
| `Cmd + 1` | Editor Only View |
| `Cmd + 2` | Split View (Dual Pane) |
| `Cmd + 3` | Preview Only View |
| `Cmd + Shift + L` | Toggle Dark / Light Theme |
| `Cmd + W` | Close Window |
| `Cmd + Q` | Quit Markdown Studio |

---

## Project Structure

```text
markdown-studio/
├── index.html                 # Main application shell & dual-pane DOM layout
├── package.json               # Dependencies and build scripts
├── vite.config.js             # Vite configuration for bundled assets
├── src/
│   ├── main.js                # Markdown/GFM/Mermaid renderer, scroll sync & native JS bridge
│   └── style.css              # Light/dark theme tokens, GFM typography & native UI styling
├── macos/
│   ├── main.swift             # Native AppKit window, NSToolbar, WKURLSchemeHandler & file I/O
│   ├── Info.plist             # macOS bundle metadata & Markdown document type associations
│   ├── generate_icon.swift    # CoreGraphics script that renders the 1024x1024 app icon
│   ├── AppIcon-1024.png       # Generated master 1024x1024 PNG icon
│   └── AppIcon.icns           # Generated multi-resolution macOS icon bundle
├── scripts/
│   └── build-mac-app.sh       # End-to-end build pipeline producing build/Markdown Studio.app
└── build/
    └── Markdown Studio.app    # Compiled standalone native macOS application
```
