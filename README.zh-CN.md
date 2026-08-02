<div align="center">

# Bennett UI Improvements for Codex++

**专为 BigPizzaV3 Codex++ 打造的界面与工作流增强脚本。**

[![Version](https://img.shields.io/badge/version-1.2.4-14b8a6)](https://github.com/JHees/bennett-ui-improvements-for-codexplusplus)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Runtime](https://img.shields.io/badge/runtime-Codex%2B%2B-111827)](https://github.com/BigPizzaV3/CodexPlusPlus)
[![Mode](https://img.shields.io/badge/mode-renderer--only-7c3aed)](#兼容性)

[English](README.md) · **简体中文**

</div>

Bennett UI Improvements 是适用于 [BigPizzaV3 Codex++](https://github.com/BigPizzaV3/CodexPlusPlus) 的 renderer-only 用户脚本。它将项目化侧栏、真实额度显示、Markdown 预览增强、原生会话查询上限设置和独立设置面板整合为一个可直接安装的脚本。

本项目将 [b-nnett/codex-plusplus-bennett-ui](https://github.com/b-nnett/codex-plusplus-bennett-ui) 迁移到 BigPizzaV3 用户脚本运行时，并保留原作者与 MIT 许可证声明。迁移版本由 [JHees](https://github.com/JHees) 维护。

## 功能亮点

| 领域 | 提供的能力 |
| --- | --- |
| 侧栏 | 项目颜色与分组背景、紧凑动作网格、可选方角和斜杠菜单优化。 |
| 额度 | 真实的 5 小时与 Weekly 额度、可选 Credit、重置时间提示和明确的 `API` 模式。 |
| 历史会话 | 将 Codex 原生近期会话查询上限由默认 50 条提高到可配置的 1–2000 条，不接管会话管理。 |
| Markdown | KaTeX 公式、数学表格、图片、相对图片路径和公式源码查看。 |
| 设置 | 独立 Bennett UI 设置页，集中管理功能开关和会话加载数量。 |
| 降低干扰 | 隐藏额度耗尽及 Plus/Pro 推广提示，同时保留输入框和 Codex 软件更新提示。 |

## 安装

### 通过 Codex++ Script Market

1. 打开 **Codex++ 管理工具**。
2. 搜索并安装 **Bennett UI Improvements**。
3. 启用脚本，然后点击 **重新加载用户脚本**。

Bennett UI 从 1.2.1 起已经内置原生会话加载器，**不需要**再单独安装 Codex List Pagebuster。

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
| 原生会话查询上限 | 自动 | 每次启动请求；可设置 1–2000 条并手动重试 |
| 侧栏方角 | 关闭 | 稳定 |

所有功能开关和会话加载入口都位于 **Codex++ 管理工具 → Bennett UI 设置**。设置保存在本地，重新加载脚本不会覆盖用户选择。

## 原生会话查询上限

内置功能现在严格限制为一项职责：请求 Codex 用更大的上限刷新自己的近期会话列表。

- 查询上限可设置为 **1–2000** 条，默认 **500** 条，用来替代 Codex 原生的 50 条默认值。
- 每次打开 Codex 后自动请求一次；启动阶段失败时会有限重试，也可点击 **重新加载历史** 手动请求。
- 插件只调用 Codex 原生的 `refresh-recent-conversations-for-host` 动作，并保存一个本地数字设置。
- 插件不会执行 `thread/list` 或 `thread/read`，不会扫描 JSONL/SQLite，不会合并或迁移 provider，也不会改写会话、摘要、置顶、归档或项目数据。
- 插件不会补水会话、维护历史快照、注入侧栏行、展开项目或重新渲染列表。项目内默认显示前几条、点击 **展开显示** 后再显示其余会话的行为完全由 Codex 负责。
- 已由 Codex/CC Switch 合并好的历史仍由它们自己索引、去重和选择 provider；Bennett 不再参与这部分流程。

如果旧环境仍启用了独立 Pagebuster，两个脚本会使用同一个全局入口并自动交接，只保留一个活动实例。确认 Bennett UI 工作正常后，可以卸载独立 Pagebuster。

启用 CC Switch 的“同步会话”后，历史合并仍由 CC Switch/Codex 管理；Bennett 既不读取会话文件，也不会创建第二份会话数据库。

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
- 根据当前文档解析本地和相对图片路径。
- 选择已渲染公式并查看对应 LaTeX 源码。

![Markdown 预览中的行内与块级公式渲染效果](docs/images/markdown-preview-math.png)

## 兼容性

Bennett UI 完全运行在 BigPizzaV3 renderer 用户脚本环境中。

| 能力 | 状态 |
| --- | --- |
| DOM、CSS、设置页与 renderer bridge 功能 | 支持 |
| Codex 原生近期会话刷新动作 | 支持 |
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

发布产物是一个 JavaScript 文件。使用下面的命令从迁移后的 Bennett 源码和两个内置功能源重新生成：

```powershell
.\tools\build-migrated-script.ps1
```

构建器会应用 BigPizzaV3 兼容转换，嵌入当前 Markdown 与原生会话功能源，检查必要的发布标记，然后输出 [`scripts/bennett-ui-improvements.js`](scripts/bennett-ui-improvements.js)。重复构建结果确定。[`tools/embed-native-history.ps1`](tools/embed-native-history.ps1) 仅保留用于替换已生成产物中的历史加载区块。

## 仓库结构

| 路径 | 用途 |
| --- | --- |
| `scripts/bennett-ui-improvements.js` | 可直接安装的单文件发布产物 |
| `features/native-history-loader.js` | 内置原生会话查询上限助手源码 |
| `features/markdown-preview-math.js` | Markdown 预览增强源码 |
| `scripts/hidden-user-message-visibility-fix.js` | 可选独立兼容脚本 |
| `tools/build-migrated-script.ps1` | 标准的一步式发布构建器 |
| `tools/embed-native-history.ps1` | 仅维护历史加载区块的辅助工具 |
| `market-entry.json` | Codex++ Script Market 元数据 |
| `NOTICE.md` | 上游来源与许可证声明 |

## 来源与许可

- 原始项目：[b-nnett/codex-plusplus-bennett-ui](https://github.com/b-nnett/codex-plusplus-bennett-ui)
- 目标运行时：[BigPizzaV3/CodexPlusPlus](https://github.com/BigPizzaV3/CodexPlusPlus)
- 脚本市场：[BigPizzaV3/CodexPlusPlusScriptMarket](https://github.com/BigPizzaV3/CodexPlusPlusScriptMarket)
- 迁移维护仓库：[JHees/bennett-ui-improvements-for-codexplusplus](https://github.com/JHees/bennett-ui-improvements-for-codexplusplus)

项目使用 [MIT License](LICENSE)。原始版权、来源与许可声明保留在发布脚本和 [`NOTICE.md`](NOTICE.md) 中。
