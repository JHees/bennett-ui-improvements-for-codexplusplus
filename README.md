<div align="center">

# Bennett UI Improvements for Codex++

**A focused UI and workflow upgrade for BigPizzaV3 Codex++.**

[![Version](https://img.shields.io/badge/version-1.2.4-14b8a6)](https://github.com/JHees/bennett-ui-improvements-for-codexplusplus)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Runtime](https://img.shields.io/badge/runtime-Codex%2B%2B-111827)](https://github.com/BigPizzaV3/CodexPlusPlus)
[![Mode](https://img.shields.io/badge/mode-renderer--only-7c3aed)](#compatibility)

**English** · [简体中文](README.zh-CN.md)

</div>

Bennett UI Improvements is a renderer-only user script for [BigPizzaV3 Codex++](https://github.com/BigPizzaV3/CodexPlusPlus). It brings project-aware sidebar styling, reliable quota display, an enhanced Markdown preview, a native-history query-limit control, and a dedicated settings panel into one installable script.

This project adapts [b-nnett/codex-plusplus-bennett-ui](https://github.com/b-nnett/codex-plusplus-bennett-ui) to the BigPizzaV3 user-script runtime while preserving the original authorship and MIT license notices. The migration is maintained by [JHees](https://github.com/JHees).

## Highlights

| Area | What it adds |
| --- | --- |
| Sidebar | Project colors and backgrounds, compact action grid, optional square corners, and slash-menu polish. |
| Usage | Real 5-hour and weekly quota data, optional Credit view, reset-time tooltips, and explicit `API` mode. |
| History | Raise Codex's native recent-history query limit from 50 to a configurable 1–2000 without taking over conversation management. |
| Markdown | KaTeX formulas, math tables, images, relative image paths, and source inspection in `.md` previews. |
| Settings | A dedicated Bennett UI panel with per-feature switches and a native-history load control. |
| Noise reduction | Hides the Codex quota aside and Plus/Pro upsell surfaces while preserving the composer and app-update notices. Uses event-driven observers without periodic polling. |

## Install

### Codex++ Script Market

1. Open **Codex++ Management Tools**.
2. Find and install **Bennett UI Improvements**.
3. Enable the script and select **Reload user scripts**.

The native history loader has been bundled into Bennett UI since 1.2.1. You do **not** need to install Codex List Pagebuster separately.

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
| Native history query limit | Automatic | Requested once at startup; configurable from 1 to 2000 with manual retry |
| Square sidebar corners | Off | Stable |

Feature switches and the history loader are available under **Codex++ Management Tools → Bennett UI Settings**. Preferences are stored locally and survive script reloads.

## Native history query limit

The embedded helper now has exactly one responsibility: ask Codex to refresh its own recent-conversation list with a larger limit.

- Set a query limit from **1–2000**; the default is **500**, replacing Codex's native default of 50.
- The request runs once whenever Codex starts. Startup failures receive limited retries, and **Reload history** provides a manual retry.
- The plugin only invokes Codex's native `refresh-recent-conversations-for-host` action and stores one local numeric preference.
- It does not call `thread/list` or `thread/read`, scan JSONL/SQLite, merge or migrate providers, or modify conversations, summaries, pins, archives, or projects.
- It does not hydrate conversations, maintain history snapshots, inject sidebar rows, expand projects, or render the list. Codex alone controls the initial project rows and the **Show more** behavior.
- History already unified by Codex/CC Switch remains indexed, deduplicated, and provider-selected by those systems; Bennett no longer participates in that workflow.

If a standalone Pagebuster installation is still enabled, both scripts use the same global entry point and hand off to a single active instance. Once Bennett UI is working, the standalone Pagebuster script can be removed.

When CC Switch unified session history is enabled, CC Switch/Codex still own the merge. Bennett neither reads session files nor creates a second conversation database.

## Usage-data behavior

- Saved quota snapshots are not presented as fresh data after startup.
- The widget updates only after receiving current renderer or `/wham/usage` data.
- Five-hour and weekly views show remaining percentage and reset-time tooltips.
- Credit appears only when actual credit data is available.
- API or pure-API providers show `API`; Bennett does not fabricate ChatGPT quota values.
- The standalone `market-hide-usage-alert.js` script is no longer needed because that behavior is built in.

## Quota-prompt filtering

- The filter targets Codex's known quota-exhaustion aside (`aside:has(h3):has(button)`) and pricing dialog surfaces, then confirms quota, reset, and upgrade text before hiding them.
- The main page uses its existing DOM mutation observer. Embedded ChatGPT webviews receive one scoped observer when they become ready or navigate, so later prompt insertion is handled without a timer.
- The filter does not scan every text node, poll every 1.5 seconds, or touch conversation articles, the composer, or Codex update notices.

## Markdown preview

The right-side Markdown preview supports:

- Inline and display math: `$...$`, `$$...$$`, `\(...\)`, and `\[...\]`.
- Codex's bundled KaTeX renderer—no external math CDN is required.
- Markdown tables, including math content inside cells.
- Local and relative image paths resolved from the current document.
- Selecting rendered math to inspect its LaTeX source.

![Markdown preview with rendered inline and display math](docs/images/markdown-preview-math.png)

## Compatibility

Bennett UI runs entirely in the BigPizzaV3 renderer user-script environment.

| Capability | Status |
| --- | --- |
| DOM, CSS, settings UI, and renderer bridge features | Supported |
| Native recent-conversation refresh action | Supported |
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

The release artifact is a single JavaScript file. Rebuild it from the migrated Bennett source and both embedded feature sources with:

```powershell
.\tools\build-migrated-script.ps1
```

The builder applies the BigPizzaV3 compatibility transforms, embeds the current Markdown and native-history feature sources, validates required release markers, and writes [`scripts/bennett-ui-improvements.js`](scripts/bennett-ui-improvements.js). Repeated builds are deterministic. [`tools/embed-native-history.ps1`](tools/embed-native-history.ps1) remains available only for replacing the history block in an already generated artifact.

## Repository layout

| Path | Purpose |
| --- | --- |
| `scripts/bennett-ui-improvements.js` | Installable single-file release artifact |
| `features/native-history-loader.js` | Embedded native-history query-limit helper source |
| `features/markdown-preview-math.js` | Markdown preview enhancement source |
| `scripts/hidden-user-message-visibility-fix.js` | Optional independent compatibility script |
| `tools/build-migrated-script.ps1` | Canonical one-step release builder |
| `tools/embed-native-history.ps1` | History-block-only maintenance helper |
| `market-entry.json` | Codex++ Script Market metadata |
| `NOTICE.md` | Upstream attribution and license notices |

## Credits and license

- Original project: [b-nnett/codex-plusplus-bennett-ui](https://github.com/b-nnett/codex-plusplus-bennett-ui)
- Target runtime: [BigPizzaV3/CodexPlusPlus](https://github.com/BigPizzaV3/CodexPlusPlus)
- Script Market: [BigPizzaV3/CodexPlusPlusScriptMarket](https://github.com/BigPizzaV3/CodexPlusPlusScriptMarket)
- Migration repository: [JHees/bennett-ui-improvements-for-codexplusplus](https://github.com/JHees/bennett-ui-improvements-for-codexplusplus)

Released under the [MIT License](LICENSE). Original copyright, attribution, and permission notices are preserved in the distributed script and [`NOTICE.md`](NOTICE.md).
