export const SAMPLE_MARKDOWN = `# Welcome to Markdown Studio

A modern **dual-pane Markdown editor** that reads and writes local files with full support for **GitHub Flavored Markdown (GFM)** and **Mermaid diagrams**.

> [!TIP]
> Open any local \`.md\` file using **Open File**, browse a directory with **Open Folder**, or **drag & drop** a file right into the left editor pane!

---

## 1. GitHub Flavored Markdown (GFM)

### GitHub Alerts

> [!NOTE]
> Useful information that users should know, even when skimming content.

> [!IMPORTANT]
> Key information users need to know to achieve their goal.

> [!WARNING]
> Urgent info that needs immediate user attention to avoid problems.

> [!CAUTION]
> Advises about risks or negative outcomes of certain actions.

### Task Lists & Formatting

- [x] Read local Markdown files via File System Access API & Drag-and-Drop
- [x] Render GitHub Flavored Markdown (tables, alerts, task lists, strikethrough)
- [x] Live-render **Mermaid** diagrams (Flowcharts, Sequence, State, Class, ER)
- [ ] Try editing this checklist in the left pane!

Supports ~~strikethrough~~, **bold**, *italic*, inline \`code\`, and auto-linked URLs like https://github.com.

### Data Tables

| Feature | Left Pane (Editor) | Right Pane (Preview) | Status |
| :--- | :--- | :--- | :---: |
| **Local Files** | Open File / Folder / Drag & Drop | Live instant preview | ✅ |
| **GitHub Rendering** | Toolbar helpers & shortcuts | Alerts, Tables, Task lists, Code | ✅ |
| **Mermaid Diagrams** | \`\`\`mermaid fenced blocks | Auto-themed SVG diagrams | ✅ |
| **Scroll Sync** | Proportional line scroll | Synchronized preview position | ✅ |

---

## 2. Mermaid Diagrams Showcase

### Architecture Flowchart

\`\`\`mermaid
flowchart LR
    subgraph Local["Local File System"]
      A[".md File on Disk"]
      B["Directory / Drag & Drop"]
    end

    subgraph App["Markdown Studio"]
      C["Left Pane: Markdown Editor"]
      D["Marked GFM + Alert Parser"]
      E["Mermaid v11 SVG Engine"]
      F["Right Pane: Live Preview"]
    end

    A --> C
    B --> C
    C -->|"Debounced Input"| D
    D -->|"Sanitized HTML"| F
    C -->|"mermaid fences"| E
    E -->|"Vector Diagram"| F
\`\`\`

### Sequence Diagram

\`\`\`mermaid
sequenceDiagram
    autonumber
    actor User
    participant Editor as Left Pane (Editor)
    participant Parser as GFM + Sanitizer
    participant Mermaid as Mermaid Renderer
    participant Preview as Right Pane (Preview)

    User->>Editor: Opens local .md file or types Markdown
    Editor->>Parser: Parse GFM (Tables, Alerts, Code)
    Parser->>Preview: Update sanitized DOM
    Preview->>Mermaid: Render .mermaid-block elements
    Mermaid-->>Preview: Inject responsive SVG diagrams
\`\`\`

### State Diagram

\`\`\`mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Editing : Open Local File
    Editing --> Dirty : Modify Markdown
    Dirty --> Rendering : Live Parse (GFM + Mermaid)
    Rendering --> Dirty : Continue Editing
    Dirty --> Saved : Save to Disk (Cmd/Ctrl + S)
    Saved --> Editing
\`\`\`

---

## 3. Syntax Highlighted Code

\`\`\`javascript
// Opening a local file using the modern File System Access API
async function openLocalMarkdown() {
  const [handle] = await window.showOpenFilePicker({
    types: [{
      description: 'Markdown Files',
      accept: { 'text/markdown': ['.md', '.markdown'] }
    }]
  });
  const file = await handle.getFile();
  return await file.text();
}
\`\`\`
`;
