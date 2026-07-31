# Bennett UI Improvements for BigPizzaV3 Codex++

A renderer-only BigPizzaV3 Codex++ user script migrated from [b-nnett/codex-plusplus-bennett-ui](https://github.com/b-nnett/codex-plusplus-bennett-ui). The migration keeps the original project attribution and adapts the UI features to the BigPizzaV3 user-script runtime.

## Highlights

- **彩色项目管理界面**：为侧栏项目提供分组背景和颜色区分，项目列表更容易扫描和管理。
- **额度显示**：在左下角显示 5 小时额度，点击可切换 Weekly；只有实际拿到点数数据时才显示 Credit，API 登录显示 `API`，鼠标悬停 5 小时或 Weekly 时显示重置时间。
- **Markdown 预览公式显示**：在右侧 Markdown 文件预览中使用 Codex 内置 KaTeX 渲染 LaTeX 公式，也支持数学表格和图片预览。

## Features

| Feature | Default | Description |
| --- | --- | --- |
| Markdown preview math | On | Renders LaTeX formulas, math tables, and images in right-side `.md` and `.markdown` previews. |
| Project backgrounds and colors | On | Adds grouped backgrounds and color separation to sidebar projects. |
| 5-hour / weekly / Credit quota | On | Shows 5-hour by default, switches to Weekly on click, and shows Credit only when real points data is available. |
| Cross-account history refresh | On | Refreshes the cloud conversation list after login or account switching. |
| Hide usage exhaustion alerts | On | Hides quota-exhausted cards and reset prompts without hiding the composer input. |
| Hide upgrade prompts | On | Hides Upgrade and Get Plus prompts in the sidebar and top bar. |
| Settings search | On | Adds a search field to Codex Settings. |
| Matched settings sidebar width | On | Keeps the Settings sidebar aligned with the main sidebar width. |
| Slash-menu polish | On | Refines row spacing, section labels, and selected states in the slash menu. |
| Sidebar action grid | On | Arranges common sidebar actions in a compact grid. |
| Square sidebar corners | Off | Removes the inner rounded corners between the sidebar and main content. |
| Multi-select sidebar chats | Off | Uses `Cmd/Ctrl + click` to select multiple sidebar chats. |

Every feature can be toggled independently from `Codex++ Manager -> Bennett UI 设置`.

## Install

Copy `scripts\bennett-ui-improvements.js` to:

```text
%APPDATA%\Codex++\user_scripts\
```

Enable the script in Codex++ Manager and reload user scripts. The script can also be installed from the Codex++ Script Market after the market entry is merged.

## Build

```powershell
.\tools\build-migrated-script.ps1
```

The build reads `old-bennett-ui/index.js` and `features/markdown-preview-math.js`, then writes `scripts/bennett-ui-improvements.js`.

## Attribution

- Original UI project: [b-nnett/codex-plusplus-bennett-ui](https://github.com/b-nnett/codex-plusplus-bennett-ui)
- Runtime target: [BigPizzaV3/CodexPlusPlus](https://github.com/BigPizzaV3/CodexPlusPlus)
- Maintainer and migration work: [JHees](https://github.com/JHees)

## License

MIT. See `LICENSE` and `NOTICE.md`.
