# Bennett UI Improvements for BigPizzaV3 Codex++

Bennett UI Improvements 是适用于 [BigPizzaV3 Codex++](https://github.com/BigPizzaV3/CodexPlusPlus) 的 renderer-only 用户脚本。它将原始的 [b-nnett/codex-plusplus-bennett-ui](https://github.com/b-nnett/codex-plusplus-bennett-ui) 迁移到 BigPizzaV3 Codex++ 的用户脚本运行时，并保留原项目来源、作者和 MIT 许可声明。

本项目的维护者和迁移适配作者是 [JHees](https://github.com/JHees)；这不是对原 Bennett UI 项目的重新署名或原创替代。

## 亮点

- **彩色项目管理界面**：为侧栏项目提供分组背景和颜色区分，让项目列表更容易扫描、定位和管理。
- **5 小时 / Weekly / Credit 额度显示**：左下角默认显示 5 小时额度，点击控件可切换 Weekly；只有实际获取到点数数据时才显示 Credit；API 登录模式直接显示 `API`，不会伪造官方额度。
- **额度到期时间**：5 小时和 Weekly 模式悬停时显示重置时间；Credit 模式显示点数本身，不用重置时间覆盖。
- **额度提示隐藏**：隐藏额度耗尽弹窗、重置提示和额度卡片，同时保留输入框和会话内容。额度提示隐藏功能已经合并进本插件，不需要额外安装 `market-hide-usage-alert.js`。
- **Markdown 预览公式显示**：在右侧 Markdown 文件预览中使用 Codex 内置 KaTeX 渲染 `$...$`、`$$...$$`、`\(...\\)` 和 `\[...\\]` 公式，并支持数学表格、图片预览和选中公式查看 LaTeX 源码。
- **独立中文设置页**：在 `Codex++ 管理工具 -> Bennett UI 设置` 中逐项启用或关闭功能，不需要手动修改脚本源码。

## 功能清单

| 功能 | 默认状态 | 说明 |
| --- | --- | --- |
| 项目背景和颜色 | 开启 | 为侧栏项目增加分组背景和颜色区分。 |
| 5 小时 / Weekly / Credit 额度 | 开启 | 默认显示 5 小时，点击切换 Weekly；只有真实点数数据存在时显示 Credit；API 模式显示 `API`。 |
| 隐藏额度耗尽提示 | 开启 | 隐藏额度耗尽横幅、重置提示和额度卡片，不隐藏输入框。 |
| 隐藏套餐升级提示 | 开启 | 隐藏 Plus/Pro 套餐的 Upgrade / Get Plus 提示；不把普通 Codex 软件更新提示当作套餐升级提示处理。 |
| Markdown 预览数学公式 | 开启 | 在右侧 `.md` / `.markdown` 预览中渲染 LaTeX 公式、数学表格和图片。 |
| 设置搜索 | 开启 | 在 Codex 设置页增加搜索框。 |
| 匹配设置页侧栏宽度 | 开启 | 让设置页侧栏宽度与主侧栏保持一致。 |
| 侧栏动作网格 | 开启 | 将新建任务、搜索、插件和自动化入口整理为紧凑网格。 |
| 斜杠菜单优化 | 开启 | 调整斜杠菜单行距、分组标题和选中状态。 |
| 跨账号会话刷新 | 开启 | 登录或切换账号后刷新云端会话列表；需要当前 provider 支持账号级历史会话查询。 |
| 侧栏方角 | 关闭 | 去除侧栏与主内容连接处的圆角。 |
| 侧栏会话多选 | 关闭 | 使用 `Cmd/Ctrl + 单击` 选择多个会话，并通过右键菜单执行批量操作。 |
| 消息 token 指标 | 关闭（不支持） | 旧实现依赖 main process 读取本地 Codex JSONL，BigPizzaV3 renderer-only 用户脚本无法访问该层。 |
| 固定会话项目名 | 关闭（不支持） | 旧实现依赖 main process 扫描本地会话文件。 |
所有功能都可以在 `Bennett UI 设置` 页面中单独开关。旧设置会保存在 Codex++ 用户脚本设置中，重新加载脚本时不会覆盖用户选择。

## 额度数据规则

- 插件启动时不会直接显示上一次保存的旧额度快照。
- 只有当前页面或 Codex renderer bridge 返回新数据后，额度控件才会更新。
- 5 小时和 Weekly 额度显示剩余百分比，并在悬停时显示重置时间。
- Credit 只有在实际拿到点数数据时才出现；拿不到点数时不会显示虚假的 Credit。
- 检测到 API 登录或纯 API provider 时显示 `API`，不会请求或推测 ChatGPT 官方额度。
- 如果独立安装过 `market-hide-usage-alert.js`，建议删除它，因为额度耗尽提示隐藏功能已经合并到本插件。

## 运行时兼容性

本插件运行在 BigPizzaV3 Codex++ 的 renderer-only 用户脚本环境中，因此可以稳定运行的功能主要集中在 DOM、设置页和 renderer bridge：

- **稳定支持**：项目着色、额度显示、额度耗尽提示隐藏、Markdown 预览公式/表格/图片、设置搜索、设置页侧栏宽度、侧栏动作网格、斜杠菜单优化、套餐升级提示隐藏和跨账号会话刷新。
- **部分支持**：侧栏会话多选可以显示和选择，但批量 Pin、Archive、mini window 等旧 Electron IPC 操作不可用，因此默认关闭。
- **当前不支持**：消息 token 指标和固定会话项目名。这些功能需要 main process 读取本地会话文件，已在设置页标记为不可用。

本插件不会修改 Codex 官方安装文件，也不会伪造 API 模式下的官方额度数据。
## 安装

### 从 Codex++ Script Market 安装

在 Codex++ 管理工具中搜索并安装 **Bennett UI Improvements**，然后重新加载用户脚本。

### 手动安装

将以下文件复制到 Codex++ 用户脚本目录：

```text
scripts\bennett-ui-improvements.js
```

Windows 用户脚本目录：

```text
%APPDATA%\Codex++\user_scripts\
```

复制完成后，在 Codex++ 管理工具中启用脚本，并点击“重新加载用户脚本”。通常不需要重启 Codex。

## 可选附加脚本

仓库中的 `scripts/hidden-user-message-visibility-fix.js` 是独立的用户消息显示修复脚本，不属于 Bennett UI 主插件。它用于恢复会话压缩或 steering 渲染异常造成的用户消息隐藏。

## 调试接口

```js
// 查看当前插件实例
window.__bennettUiImprovementsBigPizza

// 手动开关功能
window.__bennettUiImprovementsBigPizza.setFeature("sidebar-action-grid", false);
window.__bennettUiImprovementsBigPizza.setFeature("sidebar-action-grid", true);
window.__bennettUiImprovementsBigPizza.setFeature("render-markdown-preview-math", true);

// 查看 Markdown 公式预览状态
window.__bennettMarkdownPreviewMath?.getStats();
```

## 构建

```powershell
.\tools\build-migrated-script.ps1
```

构建脚本读取：

- `old-bennett-ui/index.js`：原始 Bennett UI 实现和来源代码。
- `features/markdown-preview-math.js`：Markdown 预览公式功能。

构建结果写入：

```text
scripts\bennett-ui-improvements.js
```

## 项目文件

- `scripts/bennett-ui-improvements.js`：可直接安装的 BigPizzaV3 Codex++ 用户脚本。
- `features/markdown-preview-math.js`：Markdown 预览数学公式功能。
- `scripts/hidden-user-message-visibility-fix.js`：可选的用户消息显示修复脚本。
- `tools/build-migrated-script.ps1`：单文件用户脚本构建工具。
- `market-entry.json`：Codex++ Script Market 元数据。
- `NOTICE.md`：原项目来源与许可证说明。

## 来源与许可

- 原始 Bennett UI 项目：[b-nnett/codex-plusplus-bennett-ui](https://github.com/b-nnett/codex-plusplus-bennett-ui)
- 运行时目标：[BigPizzaV3/CodexPlusPlus](https://github.com/BigPizzaV3/CodexPlusPlus)
- 官方脚本市场：[BigPizzaV3/CodexPlusPlusScriptMarket](https://github.com/BigPizzaV3/CodexPlusPlusScriptMarket)
- 迁移维护仓库：[JHees/bennett-ui-improvements-for-codexplusplus](https://github.com/JHees/bennett-ui-improvements-for-codexplusplus)

本项目使用 MIT License。原始项目的版权、来源和许可证声明保留在脚本及 `NOTICE.md` 中。
