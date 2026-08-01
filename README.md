<div align="center">

# Bennett UI Improvements for Codex++

**A focused UI and workflow upgrade for BigPizzaV3 Codex++.**

[![Version](https://img.shields.io/badge/version-1.2.0-14b8a6)](https://github.com/JHees/bennett-ui-improvements-for-codexplusplus)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Runtime](https://img.shields.io/badge/runtime-Codex%2B%2B-111827)](https://github.com/BigPizzaV3/CodexPlusPlus)
[![Mode](https://img.shields.io/badge/mode-renderer--only-7c3aed)](#compatibility)

**English** · [简体中文](README.zh-CN.md)

</div>

Bennett UI Improvements is a renderer-only user script for [BigPizzaV3 Codex++](https://github.com/BigPizzaV3/CodexPlusPlus). It brings project-aware sidebar styling, reliable quota display, an enhanced Markdown preview, native conversation-history loading, and a dedicated settings panel into one installable script.

This project adapts [b-nnett/codex-plusplus-bennett-ui](https://github.com/b-nnett/codex-plusplus-bennett-ui) to the BigPizzaV3 user-script runtime while preserving the original authorship and MIT license notices. The migration is maintained by [JHees](https://github.com/JHees).

## Highlights

| Area | What it adds |
| --- | --- |
| Sidebar | Project colors and backgrounds, compact action grid, optional square corners, and slash-menu polish. |
| Usage | Real 5-hour and weekly quota data, optional Credit view, reset-time tooltips, and explicit `API` mode. |
| History | Manually load 1–2000 conversations into Codex's native cache without custom sidebar rows. |
| Markdown | KaTeX formulas, math tables, images, relative image paths, and source inspection in `.md` previews. |
| Settings | A dedicated Bennett UI panel with per-feature switches and a native-history load control. |
| Noise reduction | Hides quota-exhaustion and Plus/Pro upsell surfaces while preserving the composer and app-update notices. |

## Install

### Codex++ Script Market

1. Open **Codex++ Management Tools**.
2. Find and install **Bennett UI Improvements**.
3. Enable the script and select **Reload user scripts**.

The native history loader is bundled into Bennett UI 1.2.0. You do **not** need to install Codex List Pagebuster separately.

### Manual installation

Copy [`scripts/bennett-ui-improvements.js`](scripts/bennett-ui-improvements.js) to:

```text
%APPDATA%\Codex++\user_scripts\
```

Enable the script in Codex++ and reload user scripts. A full Codex restart is normally unnecessary.

## Features

| Feature | Default | Support |
| --- | ---: | --- |
| Project backgrounds and colors | On | Stable |
| 5-hour / Weekly / Credit usage | On | Stable when the current page exposes usage data |
| Hide quota-exhaustion prompts | On | Stable |
| Hide Plus/Pro upgrade prompts | On | Stable; Codex app-update notices remain visible |
| Enhanced Markdown preview | On | Stable for `.md` and `.markdown` previews |
| Settings search | On | Stable |
| Match settings-sidebar width | On | Stable |
| Compact sidebar action grid | On | Stable |
| Slash-menu polish | On | Stable |
| Cross-account history refresh | On | Provider-dependent |
| Native conversation-history load | Manual | Stable; configurable from 1 to 2000 conversations |
| Square sidebar corners | Off | Stable |
| Multi-select sidebar conversations | Off | Partial; legacy batch IPC actions are unavailable |
| Message token metrics | Off | Unsupported in the renderer-only runtime |
| Pinned-conversation project names | Off | Unsupported in the renderer-only runtime |

Feature switches and the history loader are available under **Codex++ Management Tools → Bennett UI Settings**. Preferences are stored locally and survive script reloads.

## Native conversation history

Version 1.2.0 embeds the native history loader directly in Bennett UI:

- Choose a retention target from **1–2000** conversations; the default is **500**.
- Loading starts only when you select **Load conversations manually**.
- CLI conversation IDs and renderer-known summaries are merged and deduplicated by conversation ID.
- Missing summaries are hydrated in small batches through Codex's own interfaces.
- Codex remains responsible for sidebar rendering and virtual scrolling.
- The loader does not inject replacement conversation rows, intercept network requests, or continuously scan the page with a global `MutationObserver`.

If a standalone Pagebuster installation is still enabled, both scripts use the same global entry point and hand off to a single active instance. Once Bennett UI 1.2.0 is working, the standalone Pagebuster script can be removed.

When cc-switch unified session history is enabled, Bennett reads two runtime views of the same `.codex` store—the CLI index and renderer summaries. It does not create a second conversation database.

## Usage-data behavior

- Saved quota snapshots are not presented as fresh data after startup.
- The widget updates only after receiving current renderer or `/wham/usage` data.
- Five-hour and weekly views show remaining percentage and reset-time tooltips.
- Credit appears only when actual credit data is available.
- API or pure-API providers show `API`; Bennett does not fabricate ChatGPT quota values.
- The standalone `market-hide-usage-alert.js` script is no longer needed because that behavior is built in.

## Markdown preview

The right-side Markdown preview supports:

- Inline and display math: `$...$`, `$$...$$`, `\(...\)`, and `\[...\]`.
- Codex's bundled KaTeX renderer—no external math CDN is required.
- Markdown tables, including math content inside cells.
- Local and relative image paths resolved from the current document.
- Selecting rendered math to inspect its LaTeX source.

## Compatibility

Bennett UI runs entirely in the BigPizzaV3 renderer user-script environment.

| Capability | Status |
| --- | --- |
| DOM, CSS, settings UI, and renderer bridge features | Supported |
| Native conversation-manager integration | Supported |
| Legacy main-process filesystem access | Not available |
| Legacy Electron IPC batch actions | Partially available or unavailable |
| Modification of official Codex installation files | Never performed |

DOM-dependent features may need updates after major Codex UI changes. Reloading user scripts is the first troubleshooting step.

## Optional companion script

[`scripts/hidden-user-message-visibility-fix.js`](scripts/hidden-user-message-visibility-fix.js) is an independent compatibility fix for user messages hidden by conversation compaction or steering-rendering issues. It is not part of the Bennett UI core script.

## Debugging

```js
// Bennett UI instance and feature controls
window.__bennettUiImprovementsBigPizza
window.__bennettUiImprovementsBigPizza.setFeature("sidebar-action-grid", false)
window.__bennettUiImprovementsBigPizza.setFeature("render-markdown-preview-math", true)

// Markdown preview diagnostics
window.__bennettMarkdownPreviewMath?.getStats()

// Embedded native-history loader diagnostics
window.__bennettUiEmbeddedHistoryLoader?.status()
window.__codexListPagebuster?.status()
```

## Release packaging

The release artifact is a single JavaScript file. After changing the embedded loader source, run:

```powershell
.\tools\embed-native-history.ps1
```

The packager removes an existing embedded block before appending the current [`features/native-history-loader.js`](features/native-history-loader.js), so repeated runs are deterministic. It writes the result to [`scripts/bennett-ui-improvements.js`](scripts/bennett-ui-improvements.js).

`tools/build-migrated-script.ps1` is retained for rebuilding the historical Bennett migration baseline; it is not the one-step release pipeline for the current artifact.

## Repository layout

| Path | Purpose |
| --- | --- |
| `scripts/bennett-ui-improvements.js` | Installable single-file release artifact |
| `features/native-history-loader.js` | Embedded native conversation-history loader source |
| `features/markdown-preview-math.js` | Markdown preview enhancement source |
| `scripts/hidden-user-message-visibility-fix.js` | Optional independent compatibility script |
| `tools/embed-native-history.ps1` | Idempotent release packager |
| `market-entry.json` | Codex++ Script Market metadata |
| `NOTICE.md` | Upstream attribution and license notices |

## Credits and license

- Original project: [b-nnett/codex-plusplus-bennett-ui](https://github.com/b-nnett/codex-plusplus-bennett-ui)
- Target runtime: [BigPizzaV3/CodexPlusPlus](https://github.com/BigPizzaV3/CodexPlusPlus)
- Script Market: [BigPizzaV3/CodexPlusPlusScriptMarket](https://github.com/BigPizzaV3/CodexPlusPlusScriptMarket)
- Migration repository: [JHees/bennett-ui-improvements-for-codexplusplus](https://github.com/JHees/bennett-ui-improvements-for-codexplusplus)

Released under the [MIT License](LICENSE). Original copyright, attribution, and permission notices are preserved in the distributed script and [`NOTICE.md`](NOTICE.md).
