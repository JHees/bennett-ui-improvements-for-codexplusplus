  /**
   * Render LaTeX inside Codex's right-side Markdown file preview.
   *
   * The preview is a CodeMirror editor. Formula source ranges are replaced by
   * native CodeMirror widgets so math participates in the editor's own layout,
   * scrolling, clipping, selection, and lifecycle.
   */
  "render-markdown-preview-math"(api) {
    const STYLE_ID = "bennett-markdown-preview-math-style";
    const FORMULA_ATTR = "data-bennett-markdown-preview-math";
    const TABLE_ATTR = "data-bennett-markdown-preview-math-table";
    const CELL_ATTR = "data-bennett-markdown-preview-math-cell";
    const EDITOR_ATTR = "data-bennett-markdown-preview-math-editor";
    const EDITING_ATTR = "data-bennett-markdown-preview-math-editing";
    const MARKDOWN_EXTENSION = /\.(?:md|markdown|mdown|mkd)$/i;
    const states = new Map();
    let disposed = false;
    let scanFrame = 0;
    let scanning = false;
    let scanRequested = false;
    let katexPromise = null;
    let mainModuleUrl = null;
    let lastError = null;

    const style = document.createElement("style");
    style.id = STYLE_ID;
    style.textContent = `
      [${FORMULA_ATTR}] {
        box-sizing: border-box;
        color: var(--color-token-text-primary, currentColor);
        vertical-align: baseline;
      }
      [${FORMULA_ATTR}="inline"] {
        display: inline-block;
        max-width: 100%;
        padding-inline: 1px;
        white-space: nowrap;
      }
      [${FORMULA_ATTR}="display-inline"] {
        display: inline-block;
        width: 100%;
        max-width: 100%;
        overflow-x: auto;
        overflow-y: hidden;
        vertical-align: middle;
      }
      [${FORMULA_ATTR}="display-block"] {
        display: block;
        width: 100%;
        max-width: 100%;
        min-height: 1.5em;
        margin: 0.35em 0;
        overflow-x: auto;
        overflow-y: hidden;
        text-align: center;
      }
      [${FORMULA_ATTR}] > .katex-display {
        width: 100%;
        margin: 0;
      }
      [${FORMULA_ATTR}] {
        cursor: text;
      }
      [${TABLE_ATTR}] {
        display: block;
        width: 100%;
        max-width: 100%;
        margin: 0.5em 0;
        overflow-x: auto;
      }
      [${TABLE_ATTR}] table {
        width: max-content;
        min-width: min(100%, 36rem);
        max-width: none;
        border-collapse: collapse;
        border-spacing: 0;
        color: var(--color-token-text-primary, currentColor);
        font: inherit;
      }
      [${TABLE_ATTR}] th,
      [${TABLE_ATTR}] td {
        min-width: 5em;
        padding: 0.45em 0.75em;
        border-bottom: 1px solid var(
          --color-token-border-default,
          color-mix(in srgb, currentColor 12%, transparent)
        );
        text-align: left;
        vertical-align: top;
        white-space: nowrap;
      }
      [${TABLE_ATTR}] th {
        font-weight: 600;
      }
      [${TABLE_ATTR}] tr:last-child td {
        border-bottom-color: transparent;
      }
      [${TABLE_ATTR}] [${CELL_ATTR}] {
        cursor: text;
        outline: none;
      }
      [${TABLE_ATTR}] [${CELL_ATTR}]:hover,
      [${TABLE_ATTR}] [${CELL_ATTR}]:focus-visible {
        background: color-mix(in srgb, currentColor 5%, transparent);
      }
      [${TABLE_ATTR}] [${CELL_ATTR}][${EDITING_ATTR}] {
        background: color-mix(
          in srgb,
          var(--color-token-main-surface-primary, Canvas) 88%,
          currentColor 12%
        );
        box-shadow: 0 0 0 1px var(
          --color-token-focus-border,
          color-mix(in srgb, currentColor 28%, transparent)
        ) inset;
      }
      [${EDITOR_ATTR}] {
        display: block;
        box-sizing: border-box;
        width: 100%;
        min-width: 6em;
        margin: 0;
        border: 0;
        outline: 0;
        background: transparent;
        color: inherit;
        font: inherit;
        line-height: inherit;
      }
      [${TABLE_ATTR}] [${EDITOR_ATTR}] {
        min-width: 0;
        max-width: 100%;
      }
      textarea[${EDITOR_ATTR}] {
        min-height: 3.2em;
        resize: vertical;
        white-space: pre;
      }
    `;
    document.head.appendChild(style);

    function escapedAt(text, index) {
      let slashes = 0;
      for (let i = index - 1; i >= 0 && text[i] === "\\"; i -= 1) slashes += 1;
      return slashes % 2 === 1;
    }

    function blankRange(chars, start, end) {
      for (let i = start; i < end; i += 1) {
        if (chars[i] !== "\n" && chars[i] !== "\r") chars[i] = " ";
      }
    }

    function maskCode(text) {
      const chars = text.split("");
      const linePattern = /.*(?:\r\n|\n|\r|$)/g;
      let fence = null;
      for (const match of text.matchAll(linePattern)) {
        if (!match[0]) continue;
        const start = match.index;
        const end = start + match[0].length;
        const body = match[0].replace(/(?:\r\n|\n|\r)$/, "");
        const opener = body.match(/^(?: {0,3})(`{3,}|~{3,})/);
        if (fence) {
          blankRange(chars, start, end);
          const closer = body.match(/^(?: {0,3})(`{3,}|~{3,})\s*$/);
          if (
            closer &&
            closer[1][0] === fence.character &&
            closer[1].length >= fence.length
          ) {
            fence = null;
          }
          continue;
        }
        if (opener) {
          fence = { character: opener[1][0], length: opener[1].length };
          blankRange(chars, start, end);
          continue;
        }
        if (/^(?: {4}|\t)/.test(body)) blankRange(chars, start, end);
      }

      const fencedMasked = chars.join("");
      for (let i = 0; i < chars.length; i += 1) {
        if (
          fencedMasked[i] !== "`" ||
          fencedMasked[i] === " " ||
          escapedAt(fencedMasked, i)
        ) {
          continue;
        }
        let ticks = 1;
        while (fencedMasked[i + ticks] === "`") ticks += 1;
        const delimiter = "`".repeat(ticks);
        const close = fencedMasked.indexOf(delimiter, i + ticks);
        if (close < 0) break;
        blankRange(chars, i, close + ticks);
        i = close + ticks - 1;
      }
      return chars.join("");
    }

    function findClosing(text, delimiter, from, allowNewline) {
      for (let i = from; i <= text.length - delimiter.length; i += 1) {
        if (!allowNewline && (text[i] === "\n" || text[i] === "\r")) return -1;
        if (text.startsWith(delimiter, i) && !escapedAt(text, i)) return i;
      }
      return -1;
    }

    function parseMath(text) {
      const masked = maskCode(text);
      const formulas = [];
      for (let i = 0; i < masked.length; i += 1) {
        if (masked[i] === " " || masked[i] === "\n" || escapedAt(masked, i)) continue;

        let opener = null;
        let closer = null;
        let display = false;
        let allowNewline = false;

        if (masked.startsWith("$$", i)) {
          opener = "$$";
          closer = "$$";
          display = true;
          allowNewline = true;
        } else if (masked.startsWith("\\[", i)) {
          opener = "\\[";
          closer = "\\]";
          display = true;
          allowNewline = true;
        } else if (masked.startsWith("\\(", i)) {
          opener = "\\(";
          closer = "\\)";
        } else if (masked[i] === "$" && masked[i + 1] !== "$") {
          const next = masked[i + 1];
          if (next == null || /\s/.test(next)) continue;
          opener = "$";
          closer = "$";
        }

        if (!opener) continue;
        const contentStart = i + opener.length;
        const close = findClosing(masked, closer, contentStart, allowNewline);
        if (close < 0) continue;
        if (opener === "$" && (masked[close - 1] == null || /\s/.test(masked[close - 1]))) {
          continue;
        }

        const content = text.slice(contentStart, close).trim();
        if (!content) {
          i = close + closer.length - 1;
          continue;
        }

        formulas.push({
          start: i,
          end: close + closer.length,
          content,
          display,
        });
        i = close + closer.length - 1;
      }
      return formulas;
    }

    function currentMainModuleUrl() {
      if (mainModuleUrl) return mainModuleUrl;
      const scripts = Array.from(document.scripts);
      const script = scripts.find((item) => /\/app-initial-[^/]+\.js(?:$|[?#])/.test(item.src));
      if (script?.src) {
        mainModuleUrl = script.src;
        return mainModuleUrl;
      }
      const preload = Array.from(document.querySelectorAll('link[rel="modulepreload"][href]'))
        .find((item) => /\/app-initial-[^/]+\.js(?:$|[?#])/.test(item.href));
      if (preload?.href) {
        mainModuleUrl = preload.href;
        return mainModuleUrl;
      }
      const resource = performance
        .getEntriesByType("resource")
        .map((entry) => entry.name)
        .find((url) => /\/app-initial-[^/]+\.js(?:$|[?#])/.test(url));
      mainModuleUrl = resource || null;
      return mainModuleUrl;
    }

    async function discoverKatexUrl() {
      const loaded = performance
        .getEntriesByType("resource")
        .map((entry) => entry.name)
        .find((url) => /\/katex-[^/]+\.js(?:$|[?#])/.test(url));
      if (loaded) return loaded;

      const mainUrl = currentMainModuleUrl();
      if (!mainUrl) throw new Error("Codex main renderer module was not found");
      const response = await fetch(mainUrl);
      if (!response.ok) throw new Error(`Could not inspect Codex renderer (${response.status})`);
      const source = await response.text();
      const match = source.match(/import\((?:`|"|')\.\/(katex-[^"'`]+\.js)(?:`|"|')\)/);
      if (!match) throw new Error("Codex native KaTeX chunk was not found");
      return new URL(match[1], mainUrl).href;
    }

    function loadNativeKatex() {
      if (katexPromise) return katexPromise;
      if (typeof window.katex?.renderToString === "function") {
        katexPromise = Promise.resolve(window.katex);
        return katexPromise;
      }
      katexPromise = discoverKatexUrl()
        .then((url) => import(url))
        .then((module) => module?.default || module)
        .then((katex) => {
          if (typeof katex?.renderToString !== "function") {
            throw new Error("Codex KaTeX module has no renderToString export");
          }
          return katex;
        })
        .catch((error) => {
          lastError = String(error?.message || error);
          katexPromise = null;
          throw error;
        });
      return katexPromise;
    }

    function markdownFileNameFor(root) {
      let current = root;
      for (let depth = 0; current && depth < 8; depth += 1, current = current.parentElement) {
        const nav = Array.from(current.children || []).find(
          (child) => child instanceof HTMLElement && child.tagName === "NAV",
        ) || current.querySelector(":scope > nav");
        const lastCrumb = nav?.querySelector("ol > li:last-child");
        const fileName = (lastCrumb?.textContent || "").replace(/\s+/g, " ").trim();
        if (fileName) return fileName;
      }
      return "";
    }

    function findPreviewEditors() {
      const editors = [];
      for (const surface of document.querySelectorAll("[data-editor-search-surface]")) {
        const editor = surface.querySelector(":scope > .cm-editor, .cm-editor");
        if (!(editor instanceof HTMLElement)) continue;
        const fileName = markdownFileNameFor(surface);
        if (!MARKDOWN_EXTENSION.test(fileName)) continue;
        editors.push(editor);
      }
      return editors;
    }

    function controllerFromValue(value, editor) {
      if (!value || (typeof value !== "object" && typeof value !== "function")) return null;
      if (value.editorView?.dom === editor) return value;
      if (value.current?.editorView?.dom === editor) return value.current;
      return null;
    }

    function findEditorController(editor) {
      const fibers = [];
      let node = editor;
      for (let depth = 0; node && depth < 8; depth += 1, node = node.parentElement) {
        for (const key of Object.getOwnPropertyNames(node)) {
          if (key.startsWith("__reactFiber$")) fibers.push(node[key]);
        }
      }

      const visited = new Set();
      for (const initialFiber of fibers) {
        for (let fiber = initialFiber, depth = 0; fiber && depth < 24; fiber = fiber.return, depth += 1) {
          if (visited.has(fiber)) continue;
          visited.add(fiber);
          let hook = fiber.memoizedState;
          for (let index = 0; hook && index < 120; hook = hook.next, index += 1) {
            const direct = controllerFromValue(hook.memoizedState, editor)
              || controllerFromValue(hook.baseState, editor);
            if (direct) return direct;
            const memo = hook.memoizedState;
            if (Array.isArray(memo)) {
              for (const item of memo) {
                const nested = controllerFromValue(item, editor);
                if (nested) return nested;
              }
            }
          }
        }
      }
      return null;
    }

    function decorationClassFromValue(value) {
      let constructor = value?.constructor;
      for (let depth = 0; constructor && depth < 6; depth += 1) {
        if (
          typeof constructor.replace === "function" &&
          typeof constructor.set === "function"
        ) {
          return constructor;
        }
        constructor = Object.getPrototypeOf(constructor);
      }
      return null;
    }

    function discoverDecorationClass(view) {
      const sets = [
        ...(Array.isArray(view.viewState?.stateDeco) ? view.viewState.stateDeco : []),
        ...view.plugins.map((wrapper) => wrapper?.value?.decorations).filter(Boolean),
      ];
      let found = null;
      const end = view.state.doc.length;
      for (const set of sets) {
        if (typeof set?.between !== "function") continue;
        try {
          set.between(0, end, (_from, _to, value) => {
            found ||= decorationClassFromValue(value);
          });
        } catch {
          // Continue with the other decoration providers.
        }
        if (found) return found;
      }
      return null;
    }

    function extensionValues(root) {
      const values = [];
      const queue = [root];
      const visited = new Set();
      while (queue.length && visited.size < 5000) {
        const value = queue.shift();
        if (
          value == null ||
          (typeof value !== "object" && typeof value !== "function") ||
          visited.has(value)
        ) {
          continue;
        }
        visited.add(value);
        values.push(value);
        if (Array.isArray(value)) {
          queue.push(...value);
          continue;
        }
        if (value.inner && value.inner !== value) queue.push(value.inner);
        if (value.extension && value.extension !== value) queue.push(value.extension);
        if (Array.isArray(value.baseExtensions)) queue.push(...value.baseExtensions);
      }
      return values;
    }

    function discoverStateFieldClass(view) {
      for (const value of extensionValues(view.state.config?.base)) {
        const StateField = value?.constructor;
        if (
          typeof StateField?.define === "function" &&
          typeof value?.create === "function" &&
          typeof value?.slot === "function" &&
          typeof value?.init === "function" &&
          value.extension === value
        ) {
          return StateField;
        }
      }
      return null;
    }

    function discoverDecorationsFacet(view) {
      for (const wrapper of view.plugins) {
        const decorationSet = wrapper?.value?.decorations;
        if (!decorationSet) continue;
        for (const extension of extensionValues(wrapper.plugin?.baseExtensions)) {
          if (!extension?.facet || typeof extension.value !== "function") continue;
          try {
            if (extension.value(view) === decorationSet) return extension.facet;
          } catch {
            // This provider belongs to another view-plugin capability.
          }
        }
      }
      return null;
    }

    function discoverCodeMirrorRuntime(controller) {
      const view = controller?.editorView;
      if (!view?.state?.doc || !view.dom) return null;
      const Decoration = discoverDecorationClass(view);
      const StateField = discoverStateFieldClass(view);
      const DecorationsFacet = discoverDecorationsFacet(view);
      const existingCompartment = controller.readOnlyCompartment
        || controller.selectionEditCompartment
        || Array.from(view.state.config?.compartments?.keys?.() || [])[0];
      if (!Decoration || !StateField || !DecorationsFacet || !existingCompartment) return null;

      const Compartment = existingCompartment.constructor;
      const StateEffect = existingCompartment.reconfigure([]).constructor;
      if (
        typeof Compartment !== "function" ||
        typeof StateEffect?.appendConfig?.of !== "function"
      ) {
        return null;
      }
      return {
        view,
        Decoration,
        StateField,
        DecorationsFacet,
        Compartment,
        StateEffect,
      };
    }

    function formulaRange(formula, state) {
      if (!formula.display) return { from: formula.start, to: formula.end, block: false };
      const firstLine = state.doc.lineAt(formula.start);
      const lastLine = state.doc.lineAt(Math.max(formula.start, formula.end - 1));
      const before = state.sliceDoc(firstLine.from, formula.start);
      const after = state.sliceDoc(formula.end, lastLine.to);
      if (!before.trim() && !after.trim()) {
        return { from: firstLine.from, to: lastLine.to, block: true };
      }
      return { from: formula.start, to: formula.end, block: false };
    }

    function splitTableRow(lineText, lineFrom = 0) {
      let contentFrom = 0;
      let contentTo = lineText.length;
      while (contentFrom < contentTo && /\s/.test(lineText[contentFrom])) {
        contentFrom += 1;
      }
      while (contentTo > contentFrom && /\s/.test(lineText[contentTo - 1])) {
        contentTo -= 1;
      }
      if (!lineText.slice(contentFrom, contentTo).includes("|")) return null;
      if (lineText[contentFrom] === "|") contentFrom += 1;
      if (
        lineText[contentTo - 1] === "|" &&
        !escapedAt(lineText, contentTo - 1)
      ) {
        contentTo -= 1;
      }

      const cells = [];
      let start = contentFrom;
      let codeTicks = 0;
      let mathDelimiter = null;
      const pushCell = (from, to) => {
        while (from < to && /\s/.test(lineText[from])) from += 1;
        while (to > from && /\s/.test(lineText[to - 1])) to -= 1;
        cells.push({
          text: lineText.slice(from, to),
          from: lineFrom + from,
          to: lineFrom + to,
        });
      };
      for (let i = contentFrom; i < contentTo; i += 1) {
        if (lineText[i] === "`" && !escapedAt(lineText, i)) {
          let ticks = 1;
          while (lineText[i + ticks] === "`") ticks += 1;
          if (!codeTicks) codeTicks = ticks;
          else if (codeTicks === ticks) codeTicks = 0;
          i += ticks - 1;
          continue;
        }
        if (codeTicks) continue;
        if (lineText[i] === "$" && !escapedAt(lineText, i)) {
          const delimiter = lineText[i + 1] === "$" ? "$$" : "$";
          if (!mathDelimiter) mathDelimiter = delimiter;
          else if (mathDelimiter === delimiter) mathDelimiter = null;
          i += delimiter.length - 1;
          continue;
        }
        if (lineText[i] === "|" && !mathDelimiter && !escapedAt(lineText, i)) {
          pushCell(start, i);
          start = i + 1;
        }
      }
      pushCell(start, contentTo);
      return cells.length >= 2 ? cells : null;
    }

    function delimiterAlignment(cell) {
      const value = cell.text.trim();
      if (!/^:?-{3,}:?$/.test(value)) return null;
      const left = value.startsWith(":");
      const right = value.endsWith(":");
      return left && right ? "center" : right ? "right" : left ? "left" : "";
    }

    function parseMathTables(state) {
      const tables = [];
      for (let lineNumber = 1; lineNumber < state.doc.lines; lineNumber += 1) {
        const headerLine = state.doc.line(lineNumber);
        const delimiterLine = state.doc.line(lineNumber + 1);
        const header = splitTableRow(headerLine.text, headerLine.from);
        const delimiter = splitTableRow(delimiterLine.text, delimiterLine.from);
        if (
          !header ||
          !delimiter ||
          header.length !== delimiter.length
        ) {
          continue;
        }
        const alignments = delimiter.map(delimiterAlignment);
        if (alignments.some((alignment) => alignment == null)) continue;

        const rows = [header];
        let lastLine = delimiterLine;
        let nextLineNumber = lineNumber + 2;
        while (nextLineNumber <= state.doc.lines) {
          const line = state.doc.line(nextLineNumber);
          const cells = splitTableRow(line.text, line.from);
          if (!cells || cells.length !== header.length) break;
          rows.push(cells);
          lastLine = line;
          nextLineNumber += 1;
        }

        const from = headerLine.from;
        const to = lastLine.to;
        const source = state.sliceDoc(from, to);
        if (parseMath(source).length) {
          tables.push({
            from,
            to,
            source,
            rows,
            alignments,
          });
        }
        lineNumber = nextLineNumber - 1;
      }
      return tables;
    }

    function selectionTouches(range, state) {
      return state.selection.ranges.some((selection) => (
        selection.empty
          ? selection.from >= range.from && selection.from <= range.to
          : selection.from < range.to && selection.to > range.from
      ));
    }

    function createFormulaWidgetClass(katex) {
      return class FormulaWidget {
        constructor(content, display, block, source, editFrom, editTo) {
          this.content = content;
          this.display = display;
          this.block = block;
          this.source = source;
          this.editFrom = editFrom;
          this.editTo = editTo;
        }

        eq(other) {
          return (
            other instanceof this.constructor &&
            other.content === this.content &&
            other.display === this.display &&
            other.block === this.block &&
            other.source === this.source &&
            other.editFrom === this.editFrom &&
            other.editTo === this.editTo
          );
        }

        updateDOM() {
          return false;
        }

        compare(other) {
          return this === other || (
            this.constructor === other?.constructor &&
            this.eq(other)
          );
        }

        get estimatedHeight() {
          if (!this.block) return -1;
          const contentLines = this.content
            .split(/\r\n|\n|\r/)
            .filter((line) => line.trim()).length;
          return Math.max(40, contentLines * 18 + 16);
        }

        get lineBreaks() {
          return 0;
        }

        ignoreEvent() {
          return true;
        }

        coordsAt() {
          return null;
        }

        get isHidden() {
          return false;
        }

        get editable() {
          return false;
        }

        destroy() {}

        toDOM(view) {
          const ownerDocument = view.dom.ownerDocument;
          const element = ownerDocument.createElement(this.block ? "div" : "span");
          element.setAttribute(
            FORMULA_ATTR,
            this.block ? "display-block" : this.display ? "display-inline" : "inline",
          );
          element.setAttribute("contenteditable", "false");
          element.setAttribute("role", "math");
          element.setAttribute("aria-label", this.content);
          element.tabIndex = 0;
          element.title = "单击编辑公式，Enter 或 Ctrl+Enter 提交，Esc 取消";

          const renderFormula = () => {
            element.removeAttribute(EDITING_ATTR);
            element.replaceChildren();
            try {
              element.innerHTML = katex.renderToString(this.content, {
                displayMode: this.display,
                strict: "ignore",
                throwOnError: false,
              });
            } catch {
              element.textContent = this.content;
            }
          };
          const beginEdit = (event) => {
            if (event?.button != null && event.button !== 0) return;
            if (element.hasAttribute(EDITING_ATTR)) return;
            event?.preventDefault();
            event?.stopPropagation();

            const multiline = this.block || /[\r\n]/.test(this.source);
            const editor = ownerDocument.createElement(multiline ? "textarea" : "input");
            if (!multiline) editor.type = "text";
            editor.value = this.source;
            editor.setAttribute(EDITOR_ATTR, "");
            editor.setAttribute("aria-label", "公式 LaTeX 源码");
            editor.spellcheck = false;
            element.setAttribute(EDITING_ATTR, "");
            element.replaceChildren(editor);

            let finished = false;
            const finish = (commit) => {
              if (finished) return;
              finished = true;
              const nextSource = editor.value;
              if (
                commit &&
                nextSource !== this.source &&
                !view.destroyed
              ) {
                view.dispatch({
                  changes: {
                    from: this.editFrom,
                    to: this.editTo,
                    insert: nextSource,
                  },
                });
                return;
              }
              renderFormula();
            };
            editor.addEventListener("mousedown", (inputEvent) => {
              inputEvent.stopPropagation();
            });
            editor.addEventListener("keydown", (inputEvent) => {
              if (inputEvent.key === "Escape") {
                inputEvent.preventDefault();
                finish(false);
                return;
              }
              if (
                inputEvent.key === "Enter" &&
                (!multiline || inputEvent.ctrlKey || inputEvent.metaKey)
              ) {
                inputEvent.preventDefault();
                finish(true);
              }
            });
            editor.addEventListener("blur", () => finish(true), { once: true });
            ownerDocument.defaultView?.setTimeout(() => {
              editor.focus();
              editor.select();
            }, 0);
          };
          element.addEventListener("mousedown", beginEdit);
          element.addEventListener("keydown", (event) => {
            if (event.key === "Enter" || event.key === " ") beginEdit(event);
          });
          renderFormula();
          return element;
        }
      };
    }

    function appendMathContent(ownerDocument, parent, text, katex) {
      const formulas = parseMath(text);
      let offset = 0;
      for (const formula of formulas) {
        if (formula.start > offset) {
          parent.appendChild(ownerDocument.createTextNode(text.slice(offset, formula.start)));
        }
        const math = ownerDocument.createElement("span");
        math.setAttribute(FORMULA_ATTR, formula.display ? "display-inline" : "inline");
        math.setAttribute("role", "math");
        math.setAttribute("aria-label", formula.content);
        try {
          math.innerHTML = katex.renderToString(formula.content, {
            displayMode: formula.display,
            strict: "ignore",
            throwOnError: false,
          });
        } catch {
          math.textContent = formula.content;
        }
        parent.appendChild(math);
        offset = formula.end;
      }
      if (offset < text.length) {
        parent.appendChild(ownerDocument.createTextNode(text.slice(offset)));
      }
    }

    function closingMarker(text, marker, from) {
      let index = text.indexOf(marker, from);
      while (index >= 0) {
        if (!escapedAt(text, index)) return index;
        index = text.indexOf(marker, index + marker.length);
      }
      return -1;
    }

    function appendTableCellContent(ownerDocument, cell, text, katex) {
      let offset = 0;
      while (offset < text.length) {
        const candidates = [
          { marker: "**", tag: "strong" },
          { marker: "__", tag: "strong" },
          { marker: "~~", tag: "del" },
          { marker: "`", tag: "code" },
        ]
          .map((candidate) => ({
            ...candidate,
            index: text.indexOf(candidate.marker, offset),
          }))
          .filter((candidate) => (
            candidate.index >= 0 && !escapedAt(text, candidate.index)
          ))
          .sort((left, right) => left.index - right.index);
        const token = candidates[0];
        if (!token) {
          appendMathContent(ownerDocument, cell, text.slice(offset), katex);
          return;
        }
        if (token.index > offset) {
          appendMathContent(
            ownerDocument,
            cell,
            text.slice(offset, token.index),
            katex,
          );
        }
        const close = closingMarker(
          text,
          token.marker,
          token.index + token.marker.length,
        );
        if (close < 0) {
          appendMathContent(ownerDocument, cell, text.slice(token.index), katex);
          return;
        }
        const node = ownerDocument.createElement(token.tag);
        const content = text.slice(token.index + token.marker.length, close);
        if (token.tag === "code") {
          node.textContent = content;
        } else {
          appendTableCellContent(ownerDocument, node, content, katex);
        }
        cell.appendChild(node);
        offset = close + token.marker.length;
      }
    }

    function createMathTableWidgetClass(katex) {
      return class MathTableWidget {
        constructor(table) {
          this.table = table;
        }

        eq(other) {
          return (
            other instanceof this.constructor &&
            other.table.source === this.table.source
          );
        }

        updateDOM() {
          return false;
        }

        compare(other) {
          return this === other || (
            this.constructor === other?.constructor &&
            this.eq(other)
          );
        }

        get estimatedHeight() {
          return Math.max(72, this.table.rows.length * 38 + 12);
        }

        get lineBreaks() {
          return 0;
        }

        ignoreEvent() {
          return true;
        }

        coordsAt() {
          return null;
        }

        get isHidden() {
          return false;
        }

        get editable() {
          return false;
        }

        destroy() {}

        toDOM(view) {
          const ownerDocument = view.dom.ownerDocument;
          const wrapper = ownerDocument.createElement("div");
          wrapper.setAttribute(TABLE_ATTR, "");
          wrapper.setAttribute("contenteditable", "false");

          const tableElement = ownerDocument.createElement("table");
          const head = ownerDocument.createElement("thead");
          const body = ownerDocument.createElement("tbody");
          const headRow = ownerDocument.createElement("tr");
          const renderCell = (cell, cellData) => {
            cell.setAttribute(CELL_ATTR, "");
            cell.setAttribute("contenteditable", "false");
            cell.setAttribute("aria-label", cellData.text || "空单元格");
            cell.tabIndex = 0;
            cell.title = "单击编辑此单元格，Enter 提交，Esc 取消";
            appendTableCellContent(ownerDocument, cell, cellData.text, katex);

            const beginEdit = (event) => {
              if (event?.button != null && event.button !== 0) return;
              if (cell.hasAttribute(EDITING_ATTR)) return;
              event?.preventDefault();
              event?.stopPropagation();

              const cellStyle = ownerDocument.defaultView?.getComputedStyle(cell);
              const horizontalPadding = cellStyle
                ? (Number.parseFloat(cellStyle.paddingLeft) || 0)
                  + (Number.parseFloat(cellStyle.paddingRight) || 0)
                : 0;
              const contentWidth = Math.max(
                1,
                Math.floor(cell.clientWidth - horizontalPadding),
              );
              const editor = ownerDocument.createElement("input");
              editor.type = "text";
              editor.value = cellData.text;
              editor.setAttribute(EDITOR_ATTR, "");
              editor.setAttribute("aria-label", "Markdown 表格单元格源码");
              editor.spellcheck = false;
              editor.style.width = `${contentWidth}px`;
              editor.style.maxWidth = `${contentWidth}px`;
              editor.style.minWidth = "0";
              cell.setAttribute(EDITING_ATTR, "");
              cell.replaceChildren(editor);

              let finished = false;
              const restore = () => {
                cell.removeAttribute(EDITING_ATTR);
                cell.replaceChildren();
                appendTableCellContent(ownerDocument, cell, cellData.text, katex);
              };
              const finish = (commit) => {
                if (finished) return;
                finished = true;
                const nextText = editor.value;
                if (
                  commit &&
                  nextText !== cellData.text &&
                  !view.destroyed
                ) {
                  view.dispatch({
                    changes: {
                      from: cellData.from,
                      to: cellData.to,
                      insert: nextText,
                    },
                  });
                  return;
                }
                restore();
              };
              editor.addEventListener("mousedown", (inputEvent) => {
                inputEvent.stopPropagation();
              });
              editor.addEventListener("keydown", (inputEvent) => {
                if (inputEvent.key === "Escape") {
                  inputEvent.preventDefault();
                  finish(false);
                  return;
                }
                if (inputEvent.key === "Enter") {
                  inputEvent.preventDefault();
                  finish(true);
                }
              });
              editor.addEventListener("blur", () => finish(true), { once: true });
              ownerDocument.defaultView?.setTimeout(() => {
                editor.focus();
                editor.select();
              }, 0);
            };
            cell.addEventListener("mousedown", beginEdit);
            cell.addEventListener("keydown", (event) => {
              if (event.key === "Enter" || event.key === " ") beginEdit(event);
            });
          };

          this.table.rows[0].forEach((cellData, index) => {
            const cell = ownerDocument.createElement("th");
            cell.scope = "col";
            if (this.table.alignments[index]) {
              cell.style.textAlign = this.table.alignments[index];
            }
            renderCell(cell, cellData);
            headRow.appendChild(cell);
          });
          head.appendChild(headRow);

          for (const row of this.table.rows.slice(1)) {
            const rowElement = ownerDocument.createElement("tr");
            row.forEach((cellData, index) => {
              const cell = ownerDocument.createElement("td");
              if (this.table.alignments[index]) {
                cell.style.textAlign = this.table.alignments[index];
              }
              renderCell(cell, cellData);
              rowElement.appendChild(cell);
            });
            body.appendChild(rowElement);
          }

          tableElement.append(head, body);
          wrapper.appendChild(tableElement);
          return wrapper;
        }
      };
    }

    function createMathExtension(runtime, katex) {
      const { Decoration, StateField, DecorationsFacet } = runtime;
      const FormulaWidget = createFormulaWidgetClass(katex);
      const MathTableWidget = createMathTableWidgetClass(katex);

      function buildDecorations(state) {
        const source = state.doc.toString();
        const ranges = [];
        const mathTables = parseMathTables(state);
        for (const table of mathTables) {
          ranges.push(
            Decoration.replace({
              widget: new MathTableWidget(table),
              block: true,
            }).range(table.from, table.to),
          );
        }
        for (const formula of parseMath(source)) {
          if (
            mathTables.some((table) => (
              formula.start >= table.from && formula.end <= table.to
            ))
          ) {
            continue;
          }
          const range = formulaRange(formula, state);
          if (selectionTouches(range, state)) continue;
          const widget = new FormulaWidget(
            formula.content,
            formula.display,
            range.block,
            state.sliceDoc(formula.start, formula.end),
            formula.start,
            formula.end,
          );
          let decoration;
          try {
            decoration = Decoration.replace({
              widget,
              block: range.block,
            }).range(range.from, range.to);
          } catch {
            decoration = Decoration.replace({ widget }).range(formula.start, formula.end);
          }
          ranges.push(decoration);
        }
        return Decoration.set(ranges, true);
      }

      return StateField.define({
        create(state) {
          return buildDecorations(state);
        },
        update(decorations, transaction) {
          if (transaction.docChanged || transaction.selection) {
            return buildDecorations(transaction.state);
          }
          return decorations;
        },
        provide(field) {
          return DecorationsFacet.from(field);
        }
      });
    }

    function removeState(state) {
      states.delete(state.editor);
      if (!state.view.destroyed) {
        try {
          state.view.dispatch({
            effects: state.compartment.reconfigure([]),
          });
        } catch (error) {
          api.log.warn("Could not remove Markdown preview math extension", error);
        }
      }
    }

    async function installForEditor(editor, katex) {
      if (states.has(editor) || !editor.isConnected || disposed) return;
      const controller = findEditorController(editor);
      const runtime = discoverCodeMirrorRuntime(controller);
      if (!runtime) return;

      const compartment = new runtime.Compartment();
      const extension = createMathExtension(runtime, katex);
      runtime.view.dispatch({
        effects: runtime.StateEffect.appendConfig.of(compartment.of(extension)),
      });
      states.set(editor, {
        editor,
        view: runtime.view,
        compartment,
      });
    }

    async function scanEditors() {
      scanFrame = 0;
      if (disposed) return;
      if (scanning) {
        scanRequested = true;
        return;
      }
      scanning = true;
      scanRequested = false;
      try {
        const editors = findPreviewEditors();
        const liveEditors = new Set(editors);
        for (const state of Array.from(states.values())) {
          if (
            !liveEditors.has(state.editor) ||
            !state.editor.isConnected ||
            state.view.destroyed
          ) {
            removeState(state);
          }
        }

        let katex;
        try {
          katex = await loadNativeKatex();
        } catch (error) {
          api.log.warn("Markdown preview math unavailable", error);
          return;
        }
        for (const editor of editors) await installForEditor(editor, katex);
      } finally {
        scanning = false;
        if (scanRequested && !disposed) scheduleScan();
      }
    }

    function scheduleScan() {
      if (disposed || scanFrame) return;
      scanFrame = requestAnimationFrame(() => void scanEditors());
    }

    const observer = new MutationObserver(scheduleScan);
    observer.observe(document.documentElement, {
      childList: true,
      subtree: true,
    });

    window.__bennettMarkdownPreviewMath = {
      getStats() {
        return {
          enabled: !disposed,
          previewEditors: states.size,
          renderedFormulas: Array.from(states.values()).reduce(
            (count, state) => (
              count + state.editor.querySelectorAll(`[${FORMULA_ATTR}]`).length
            ),
            0,
          ),
          nativeKatexLoaded: !!katexPromise && !lastError,
          implementation: "CodeMirror state-field replacement widgets",
          lastError,
          scope: "right-side Markdown file preview only",
        };
      },
      refresh: scheduleScan,
    };
    scheduleScan();

    return () => {
      disposed = true;
      if (scanFrame) cancelAnimationFrame(scanFrame);
      observer.disconnect();
      for (const state of Array.from(states.values())) removeState(state);
      style.remove();
      delete window.__bennettMarkdownPreviewMath;
    };
  },
