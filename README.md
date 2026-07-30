# Bennett UI Improvements for BigPizzaV3 Codex++

Bennett UI Improvements is a BigPizzaV3 Codex++ user script for Markdown preview, sidebar, quota, and settings-page enhancements.

## Highlights

- **Markdown math preview** renders formulas and math tables with Codex's built-in KaTeX in the right-side Markdown file preview. Formulas and individual table cells can be edited in place without changing the surrounding layout.
- **Project colors** add grouped backgrounds and color separation to sidebar projects for faster visual navigation.
- **Quota display** keeps the 5-hour and weekly remaining quota in one compact sidebar control and switches values on click.

## All features

| Feature | Default | Description |
| --- | --- | --- |
| Markdown preview math | On | Renders `$...$`, `$$...$$`, `\(...\)`, and `\[...\]` in right-side `.md` and `.markdown` file previews using Codex's built-in KaTeX. Formulas and math-table cells remain in the document layout and support in-place source editing. |
| Cross-account history refresh | On | Refreshes the cloud conversation list after login or account switching. |
| Project backgrounds and colors | On | Adds grouped backgrounds and color separation to sidebar projects. |
| 5-hour / weekly quota | On | Shows remaining quota in the sidebar and switches between 5-hour and weekly values on click. API mode displays `API`. |
| Sidebar action grid | On | Arranges New task, Search, Plugins, and Automations in a compact 2×2 grid. |
| Hide upgrade prompts | On | Hides Upgrade and Get Plus prompts in the sidebar and top bar. |
| Settings search | On | Adds a search field to Codex Settings. |
| Matched settings sidebar width | On | Keeps the Settings sidebar aligned with the main sidebar width. |
| Slash-menu polish | On | Refines row spacing, section labels, and selected states in the slash menu. |
| Square sidebar corners | Off | Removes the inner rounded corners between the sidebar and main content. |
| Multi-select sidebar chats | Off | Uses `Cmd/Ctrl + click` to select multiple sidebar chats and opens batch actions from the context menu. |

Every feature can be toggled independently from `Codex++ Manager → Bennett UI Settings`.

## Install

Copy the ready-to-install script:

```text
scripts\bennett-ui-improvements.js
```

to the Codex++ user-script directory:

```text
%APPDATA%\Codex++\user_scripts\
```

Enable the script in Codex++ Manager and reload user scripts.

## Console API

```js
window.__bennettUiImprovementsBigPizza.setFeature("sidebar-action-grid", false);
window.__bennettUiImprovementsBigPizza.setFeature("sidebar-action-grid", true);
window.__bennettUiImprovementsBigPizza.setFeature("render-markdown-preview-math", true);
window.__bennettMarkdownPreviewMath.getStats();
```

## Build

```powershell
.\tools\build-migrated-script.ps1
```

The build reads:

```text
old-bennett-ui/index.js
features/markdown-preview-math.js
```

and writes:

```text
scripts/bennett-ui-improvements.js
```

## Source

- Bennett UI: `https://github.com/b-nnett/codex-plusplus-bennett-ui`
- Codex++: `https://github.com/BigPizzaV3/CodexPlusPlus`
- Codex++ Script Market: `https://github.com/BigPizzaV3/CodexPlusPlusScriptMarket`

## License

MIT. See `LICENSE` and `NOTICE.md`.
