<div align="center">

# Bennett UI Improvements for Codex++

**专为 BigPizzaV3 Codex++ 打造的界面与工作流增强脚本。**

[![Version](https://img.shields.io/badge/version-1.2.2-14b8a6)](https://github.com/JHees/bennett-ui-improvements-for-codexplusplus)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Runtime](https://img.shields.io/badge/runtime-Codex%2B%2B-111827)](https://github.com/BigPizzaV3/CodexPlusPlus)
[![Mode](https://img.shields.io/badge/mode-renderer--only-7c3aed)](#兼容性)

[English](README.md) · **简体中文**

</div>

Bennett UI Improvements 是适用于 [BigPizzaV3 Codex++](https://github.com/BigPizzaV3/CodexPlusPlus) 的 renderer-only 用户脚本。它将项目化侧栏、真实额度显示、Markdown 预览增强、原生会话历史加载和独立设置面板整合为一个可直接安装的脚本。

本项目将 [b-nnett/codex-plusplus-bennett-ui](https://github.com/b-nnett/codex-plusplus-bennett-ui) 迁移到 BigPizzaV3 用户脚本运行时，并保留原作者与 MIT 许可证声明。迁移版本由 [JHees](https://github.com/JHees) 维护。

## 功能亮点

| 领域 | 提供的能力 |
| --- | --- |
| 侧栏 | 项目颜色与分组背景、紧凑动作网格、可选方角和斜杠菜单优化。 |
| 额度 | 真实的 5 小时与 Weekly 额度、可选 Credit、重置时间提示和明确的 `API` 模式。 |
| 历史会话 | 自动将 1–2000 条会话加载进 Codex 原生缓存，不创建插件侧栏行。 |
| Markdown | KaTeX 公式、数学表格、图片、相对图片路径和公式源码查看。 |
| 设置 | 独立 Bennett UI 设置页，集中管理功能开关和会话加载数量。 |
| 降低干扰 | 隐藏额度耗尽及 Plus/Pro 推广提示，同时保留输入框和 Codex 软件更新提示。 |

## 安装

### 通过 Codex++ Script Market

1. 打开 **Codex++ 管理工具**。
2. 搜索并安装 **Bennett UI Improvements**。
3. 启用脚本，然后点击 **重新加载用户脚本**。

Bennett UI 1.2.1 已经内置原生会话加载器，**不需要**再单独安装 Codex List Pagebuster。

### 手动安装

将 [`scripts/bennett-ui-improvements.js`](scripts/bennett-ui-improvements.js) 复制到：

```text
%APPDATA%\Codex++\user_scripts\
```

在 Codex++ 管理工具中启用脚本并重新加载用户脚本。通常不需要重启 Codex。

## 功能清单

| 功能 | 默认状态 | 支持情况 |
| --- | ---: | --- |
| 项目背景和颜色 | 开启 | 稳定 |
| 5 小时 / Weekly / Credit 额度 | 开启 | 当前页面能提供额度数据时稳定可用 |
| 隐藏额度耗尽提示 | 开启 | 稳定 |
| 隐藏 Plus/Pro 升级提示 | 开启 | 稳定；保留 Codex 软件更新提示 |
| Markdown 预览增强 | 开启 | 对 `.md` 和 `.markdown` 预览稳定可用 |
| 设置搜索 | 开启 | 稳定 |
| 匹配设置页侧栏宽度 | 开启 | 稳定 |
| 紧凑侧栏动作网格 | 开启 | 稳定 |
| 斜杠菜单优化 | 开启 | 稳定 |
| 原生会话历史加载 | 自动 | 每次启动加载；可设置 1–2000 条并手动重试 |
| 侧栏方角 | 关闭 | 稳定 |

所有功能开关和会话加载入口都位于 **Codex++ 管理工具 → Bennett UI 设置**。设置保存在本地，重新加载脚本不会覆盖用户选择。

## 原生会话历史加载

内置的原生历史加载器支持：

- 保留数量可设置为 **1–2000** 条，默认 **500** 条。
- 每次打开 Codex 后自动加载一次；启动阶段失败时会有限重试，也可点击 **手动加载会话** 立即重试。
- 合并 CLI 会话 ID 与 renderer 已知摘要，并按会话 ID 去重。
- 缺失摘要通过 Codex 自身接口小批量补齐。
- 侧栏渲染与虚拟滚动仍完全由 Codex 负责。
- 不注入替代会话行、不拦截网络请求，也不使用全局 `MutationObserver` 持续扫描页面。

如果旧环境仍启用了独立 Pagebuster，两个脚本会使用同一个全局入口并自动交接，只保留一个活动实例。确认 Bennett UI 工作正常后，可以卸载独立 Pagebuster。

启用 cc-switch 的“同步会话”后，Bennett 读取的是同一 `.codex` 存储的两种运行时视图——CLI 索引与 renderer 摘要，不会创建第二份会话数据库。

## 额度数据规则

- 启动后不会把保存的旧额度快照当作当前数据展示。
- 只有收到当前 renderer 或 `/wham/usage` 数据后才更新控件。
- 5 小时和 Weekly 显示剩余百分比，悬停可查看重置时间。
- 只有真实收到 Credit 数据时才显示点数。
- API 或纯 API provider 显示 `API`，不会伪造 ChatGPT 官方额度。
- `market-hide-usage-alert.js` 的功能已经内置，不再需要单独安装。

## Markdown 预览增强

右侧 Markdown 预览支持：

- 行内与块级公式：`$...$`、`$$...$$`、`\(...\)` 和 `\[...\]`。
- 使用 Codex 内置 KaTeX，不依赖外部数学公式 CDN。
- Markdown 表格以及表格单元格中的数学内容。
- 根据当前文档解析本地和相对图片路径，并在图片接近视野时通过 Codex 原生媒体协议加载。
- 公式、图片和数学表格单元格均支持原位编辑源码。

## 兼容性

Bennett UI 完全运行在 BigPizzaV3 renderer 用户脚本环境中。

| 能力 | 状态 |
| --- | --- |
| DOM、CSS、设置页与 renderer bridge 功能 | 支持 |
| Codex 原生会话管理器集成 | 支持 |
| 旧版 main process 文件系统访问 | 不可用 |
| 旧版 Electron IPC 批量操作 | 部分可用或不可用 |
| 修改 Codex 官方安装文件 | 永不执行 |

依赖 DOM 的功能可能需要跟随 Codex 大版本界面更新进行适配。出现异常时，首先尝试重新加载用户脚本。

## 可选附加脚本

[`scripts/hidden-user-message-visibility-fix.js`](scripts/hidden-user-message-visibility-fix.js) 是独立的兼容性修复，用于恢复因会话压缩或 steering 渲染异常而被隐藏的用户消息，不属于 Bennett UI 主脚本。

## 调试接口

```js
// Bennett UI 实例和功能开关
window.__bennettUiImprovementsBigPizza
window.__bennettUiImprovementsBigPizza.setFeature("sidebar-action-grid", false)
window.__bennettUiImprovementsBigPizza.setFeature("render-markdown-preview-math", true)

// Markdown 预览诊断
window.__bennettMarkdownPreviewMath?.getStats()

// 内置原生会话加载器诊断
window.__bennettUiEmbeddedHistoryLoader?.status()
window.__codexListPagebuster?.status()
```

## 发布打包

发布产物是一个 JavaScript 文件。修改内置加载器源码后运行：

```powershell
.\tools\embed-native-history.ps1
```

打包工具会先删除现有嵌入区块，再追加当前 [`features/native-history-loader.js`](features/native-history-loader.js)，因此可重复执行且结果确定。输出文件为 [`scripts/bennett-ui-improvements.js`](scripts/bennett-ui-improvements.js)。

`tools/build-migrated-script.ps1` 仅保留用于重新生成历史 Bennett 迁移基线，不是当前发布产物的一步式构建入口。

## 仓库结构

| 路径 | 用途 |
| --- | --- |
| `scripts/bennett-ui-improvements.js` | 可直接安装的单文件发布产物 |
| `features/native-history-loader.js` | 内置原生会话历史加载器源码 |
| `features/markdown-preview-math.js` | Markdown 预览增强源码 |
| `scripts/hidden-user-message-visibility-fix.js` | 可选独立兼容脚本 |
| `tools/embed-native-history.ps1` | 幂等发布打包工具 |
| `market-entry.json` | Codex++ Script Market 元数据 |
| `NOTICE.md` | 上游来源与许可证声明 |

## 来源与许可

- 原始项目：[b-nnett/codex-plusplus-bennett-ui](https://github.com/b-nnett/codex-plusplus-bennett-ui)
- 目标运行时：[BigPizzaV3/CodexPlusPlus](https://github.com/BigPizzaV3/CodexPlusPlus)
- 脚本市场：[BigPizzaV3/CodexPlusPlusScriptMarket](https://github.com/BigPizzaV3/CodexPlusPlusScriptMarket)
- 迁移维护仓库：[JHees/bennett-ui-improvements-for-codexplusplus](https://github.com/JHees/bennett-ui-improvements-for-codexplusplus)

项目使用 [MIT License](LICENSE)。原始版权、来源与许可声明保留在发布脚本和 [`NOTICE.md`](NOTICE.md) 中。
