<div align="center">

# Bennett UI Improvements for Codex++

**专为 BigPizzaV3 Codex++ 打造的界面与工作流增强脚本。**

[![Version](https://img.shields.io/badge/version-1.2.5-14b8a6)](https://github.com/JHees/bennett-ui-improvements-for-codexplusplus)
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
| 侧栏 | 项目和会话颜色、紧凑动作网格、可选方角和斜杠菜单优化。 |
| 额度 | 真实的 5 小时与 Weekly 额度、可选 Credit、重置时间提示和明确的 `API` 模式。 |
| 历史会话 | 将 Codex 原生近期会话查询上限由默认 50 条提高到可配置的 1–2000 条，不接管会话管理。 |
| Markdown | KaTeX 公式、数学表格、图片、相对图片路径和公式源码查看。 |
| 设置 | 独立 Bennett UI 设置页，集中管理功能开关和会话加载数量。 |
| 降低干扰 | 隐藏 Codex 额度耗尽提示和 Plus/Pro 升级提示，同时保留输入框和 Codex 软件更新提示。 |

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
| 会话项目着色 | 开启 | 已归属项目的会话稳定可用；普通对话保持默认样式 |
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

## 会话项目着色

- 普通侧栏、展开的项目列表以及有限筛选结果中的会话，会继承所属项目的颜色。
- 使用低对比度背景和左侧色条，保持标题、选中状态和未读提示清晰可读。
- 无法确认项目归属的会话保持 Codex 默认样式。
- 可在 **Codex++ 管理工具 → Bennett UI 设置** 中单独开启或关闭；项目颜色设置会自动同步到会话。
- 修改项目颜色后，当前已显示的会话颜色会立即同步更新。

## 原生会话查询上限

Bennett UI 可以让 Codex 显示更多近期会话，同时保留 Codex 原有的会话管理方式。

- 可将显示数量设置为 **1–2000** 条，默认 **500** 条，不再受默认 50 条限制。
- 每次打开 Codex 后会自动刷新会话列表。
- 需要时可在 Bennett UI 设置中点击 **重新加载历史** 手动刷新。
- Codex 和 CC Switch 继续负责历史合并、项目分组、排序以及 **展开显示** 行为。

如果旧环境仍启用了独立 Pagebuster，两个脚本会使用同一个全局入口并自动交接，只保留一个活动实例。确认 Bennett UI 工作正常后，可以卸载独立 Pagebuster。

启用 CC Switch 的“同步会话”后，历史合并仍由 CC Switch/Codex 管理；Bennett 既不读取会话文件，也不会创建第二份会话数据库。

## 额度数据规则

- 启动后不会把保存的旧额度快照当作当前数据展示。
- 只接受当前 `/wham/usage` 返回的主账户数据；不会使用旧快照、renderer 事件或页面文本作为额度来源。
- 5 小时和 Weekly 显示剩余百分比，悬停可查看重置时间。
- 额度控件只读取主账户 `rate_limit`；`additional_rate_limits`（例如 GPT-5.3 Codex 专属额度）不会被合并进主账户额度。
- 只有真实收到 Credit 数据时才显示点数。
- API 或纯 API provider 显示 `API`，不会伪造 ChatGPT 官方额度。
- `market-hide-usage-alert.js` 的功能已经内置，不再需要单独安装。

## 额度提示过滤

- 隐藏 Codex 额度耗尽提示和升级提示，同时保留会话正文、输入框及软件更新提示。
- 支持 Codex 主界面和内嵌 ChatGPT 页面中的相关提示。
- 可在 **Codex++ 管理工具 → Bennett UI 设置** 中启用或关闭。

## Markdown 预览增强

右侧 Markdown 预览支持：

- 行内与块级公式：`$...$`、`$$...$$`、`\(...\)` 和 `\[...\]`。
- 使用 Codex 内置 KaTeX，不依赖外部数学公式 CDN。
- Markdown 表格以及表格单元格中的数学内容。
- 根据当前文档解析本地和相对图片路径。
- 选择已渲染公式并查看对应 LaTeX 源码。

![Markdown 预览中的行内与块级公式渲染效果](docs/images/markdown-preview-math.png)

## 兼容性

Bennett UI 以 Codex++ 用户脚本运行，不会修改 Codex 官方安装文件。Codex 大版本更新后，依赖界面的功能可能需要适配；出现异常时，首先尝试重新加载用户脚本。

## 可选附加脚本

[`scripts/hidden-user-message-visibility-fix.js`](scripts/hidden-user-message-visibility-fix.js) 是独立的兼容性修复，用于恢复因会话压缩或 steering 渲染异常而被隐藏的用户消息，不属于 Bennett UI 主脚本。

## 来源与许可

- 原始项目：[b-nnett/codex-plusplus-bennett-ui](https://github.com/b-nnett/codex-plusplus-bennett-ui)
- 目标运行时：[BigPizzaV3/CodexPlusPlus](https://github.com/BigPizzaV3/CodexPlusPlus)
- 脚本市场：[BigPizzaV3/CodexPlusPlusScriptMarket](https://github.com/BigPizzaV3/CodexPlusPlusScriptMarket)
- 迁移维护仓库：[JHees/bennett-ui-improvements-for-codexplusplus](https://github.com/JHees/bennett-ui-improvements-for-codexplusplus)

项目使用 [MIT License](LICENSE)。原始版权、来源与许可声明保留在发布脚本和 [`NOTICE.md`](NOTICE.md) 中。
