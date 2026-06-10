param(
  [string]$Source = "old-bennett-ui\index.js",
  [string]$Out = "scripts\bennett-ui-improvements.js"
)

$ErrorActionPreference = "Stop"

$sourcePath = Resolve-Path -LiteralPath $Source
$outPath = Join-Path (Get-Location) $Out
$outDir = Split-Path -Parent $outPath
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$sourceText = Get-Content -LiteralPath $sourcePath -Raw -Encoding utf8
$sourceText = $sourceText -replace "\r\n", "`n"
$sourceText = $sourceText.Replace('"show-usage-in-sidebar": false', '"show-usage-in-sidebar": true')
$sourceText = $sourceText.Replace('"show-message-metrics-on-hover": true', '"show-message-metrics-on-hover": false')
$sourceText = $sourceText.Replace('"sidebar-chat-multi-select": true', '"sidebar-chat-multi-select": false')
$sourceText = $sourceText.Replace('"show-pinned-chat-project-names": true', '"show-pinned-chat-project-names": false')
$sourceText = $sourceText.Replace('let snapshot = readSnapshot(api);', 'let snapshot = null; // Do not render persisted quota data before this page fetches fresh usage.')
$sourceText = $sourceText.Replace('let bridgeRequestSeq = 0;', @'
let bridgeRequestSeq = 0;
    let lastMountedMode = null;
    let accountMode = "unknown"; // "official" | "api" | "unknown"
    let accountModeInFlight = false;
    let accountModeLastCheckedAt = 0;
    let accountModeLogged = false;
'@)
$sourceText = $sourceText.Replace(@'
      if (!partial?.fiveHour && !partial?.weekly) return false;
'@, @'
      if (!partial?.fiveHour && !partial?.weekly) return false;
      if (accountMode === "api") return false;
'@)
$sourceText = $sourceText.Replace(@'
    const remainingPercent = (usedPercent) => {
'@, @'
    const bridgePostJson = async (path, payload = {}, timeoutMs = 2_500) => {
      const bridge = window.__codexSessionDeleteBridge;
      if (typeof bridge !== "function") return null;
      return await Promise.race([
        bridge(path, payload),
        new Promise((resolve) => window.setTimeout(() => resolve(null), timeoutMs)),
      ]);
    };

    const activeRelayProfile = (settings) => {
      if (!settings || typeof settings !== "object") return null;
      const profiles = Array.isArray(settings.relayProfiles) ? settings.relayProfiles : [];
      const activeId =
        typeof settings.activeRelayId === "string" && settings.activeRelayId.trim()
          ? settings.activeRelayId
          : "default";
      return profiles.find((profile) => profile?.id === activeId) || profiles[0] || null;
    };

    const fieldValue = (object, ...keys) => {
      if (!object || typeof object !== "object") return undefined;
      for (const key of keys) {
        if (Object.prototype.hasOwnProperty.call(object, key)) return object[key];
      }
      return undefined;
    };

    const catalogLooksLikeApiMode = (catalog) => {
      if (!catalog || typeof catalog !== "object") return false;
      const provider = String(catalog.model_provider || catalog.provider_name || "").toLowerCase();
      if (!provider) return false;
      return !["openai", "chatgpt"].includes(provider);
    };

    const refreshAccountMode = async (force = false) => {
      if (accountModeInFlight) return accountMode;
      const now = Date.now();
      if (!force && accountModeLastCheckedAt && now - accountModeLastCheckedAt < 10_000) {
        return accountMode;
      }
      accountModeLastCheckedAt = now;
      accountModeInFlight = true;
      try {
        let nextMode = "unknown";
        let settingsMode = "unknown";
        const settings = await bridgePostJson("/settings/get", {});
        const profile = activeRelayProfile(settings);
        const relayMode = fieldValue(profile, "relayMode", "relay_mode");
        const officialMixApiKey = !!fieldValue(profile, "officialMixApiKey", "official_mix_api_key");
        const legacyApiConfigured = !!(
          String(fieldValue(settings, "relayApiKey", "relay_api_key") || "").trim() ||
          String(fieldValue(settings, "relayBaseUrl", "relay_base_url") || "").trim()
        );
        if (relayMode === "official" && !officialMixApiKey) {
          nextMode = "official";
        } else if (relayMode === "pureApi" || relayMode === "pure_api") {
          nextMode = "api";
        } else if (relayMode === "mixedApi" || relayMode === "mixed_api" || officialMixApiKey) {
          nextMode = "api";
        } else if (!relayMode && legacyApiConfigured) {
          nextMode = "api";
        }

        if (nextMode === "unknown") {
          const catalog = await bridgePostJson("/codex-model-catalog", {});
          if (catalogLooksLikeApiMode(catalog)) nextMode = "api";
          else if (catalog?.model_provider === "openai" || catalog?.provider_name === "openai") {
            nextMode = "official";
          }
        }
        if (nextMode === "unknown") nextMode = settingsMode;

        if (nextMode !== "unknown" && nextMode !== accountMode) {
          accountMode = nextMode;
          if (accountMode === "api") {
            snapshot = {
              fiveHour: { label: "API", pct: null, resetAt: null, apiMode: true },
              weekly: null,
              at: Date.now(),
              apiMode: true,
            };
          } else if (snapshot?.apiMode) {
            snapshot = null;
          }
          ensureMounted(true);
        }
        if (!accountModeLogged && accountMode !== "unknown") {
          accountModeLogged = true;
          log("account mode", accountMode);
        }
        return accountMode;
      } catch (e) {
        return accountMode;
      } finally {
        accountModeInFlight = false;
      }
    };

    const remainingPercent = (usedPercent) => {
'@)
$sourceText = $sourceText.Replace('now - directUsageLastAttemptAt < 60_000', 'now - directUsageLastAttemptAt < 15_000')
$sourceText = [regex]::Replace(
  $sourceText,
  '    const findSidebarSlot = \(\) => \{[\s\S]*?    \};\n\n    const ensureMounted',
  "    const ensureMounted",
  1
)
$sourceText = $sourceText.Replace(@'
    const findUsageSidebar = () => {
      const sidebar = document.querySelector(ASIDE_SELECTOR);
      if (!(sidebar instanceof HTMLElement)) return null;
      if (!isVisibleElement(sidebar)) return null;
      const rect = sidebar.getBoundingClientRect();
      return rect.width >= 180 ? sidebar : null;
    };
'@, @'
    const compactSidebarText = (node) =>
      (node?.textContent || "").replace(/\s+/g, " ").trim().toLowerCase();

    const looksLikeSettingsSidebar = (sidebar) => {
      if (!(sidebar instanceof HTMLElement)) return false;
      if (
        sidebar.matches(".window-fx-sidebar-surface.w-token-sidebar") ||
        sidebar.closest(".window-fx-sidebar-surface.w-token-sidebar") ||
        sidebar.querySelector("[data-codexpp-settings-search]")
      ) {
        return true;
      }
      const text = compactSidebarText(sidebar);
      const englishSettings =
        text.includes("general") &&
        text.includes("appearance") &&
        (text.includes("account") || text.includes("configuration"));
      const chineseSettings =
        text.includes("常规") &&
        text.includes("外观") &&
        (
          text.includes("配置") ||
          text.includes("个性化") ||
          text.includes("键盘快捷键") ||
          text.includes("mcp 服务器") ||
          text.includes("钩子") ||
          text.includes("连接") ||
          text.includes("环境") ||
          text.includes("工作树") ||
          text.includes("已归档")
        );
      return englishSettings || chineseSettings;
    };

    const looksLikeMainAppSidebar = (sidebar) => {
      const text = compactSidebarText(sidebar);
      const hasNewChat = /\bnew chat\b|\bquick chat\b|新建|新对话/.test(text);
      const hasSearch = /\bsearch\b|搜索/.test(text);
      const hasProjectOrHistory =
        /\bprojects?\b|\bhistory\b|\bchats?\b|项目|历史|会话/.test(text);
      return (hasNewChat && hasSearch) || (hasSearch && hasProjectOrHistory);
    };

    const findUsageSidebar = () => {
      const candidates = Array.from(document.querySelectorAll(ASIDE_SELECTOR))
        .filter((node) => node instanceof HTMLElement && isVisibleElement(node))
        .filter((sidebar) => {
          const rect = sidebar.getBoundingClientRect();
          return rect.width >= 180 && !looksLikeSettingsSidebar(sidebar);
        });
      return candidates.find(looksLikeMainAppSidebar) || null;
    };
'@)
$sourceText = $sourceText.Replace(@'
    const ensureMounted = (forceRebuild = false) => {
      if (!snapshot || (!snapshot.fiveHour && !snapshot.weekly)) return;
      const slot = findSidebarSlot();
'@, @'
    const controlText = (node) =>
      [
        node.getAttribute?.("aria-label"),
        node.getAttribute?.("title"),
        node.textContent,
      ]
        .filter(Boolean)
        .join(" ")
        .replace(/\s+/g, " ")
        .trim()
        .toLowerCase();

    const isSettingsOrDeviceButton = (button) => {
      const text = controlText(button);
      return (
        /\bsettings?\b|preferences?|设置|偏好/.test(text) ||
        /\bmobile\b|\bphone\b|\bdevice\b|手机|移动|设备|连接/.test(text)
      );
    };

    const nearestControlRow = (sidebar, button) => {
      const sidebarRect = sidebar.getBoundingClientRect();
      let row = button.parentElement;
      while (row && row !== document.body && row !== sidebar.parentElement) {
        if (!(row instanceof HTMLElement)) break;
        const rect = row.getBoundingClientRect();
        const style = window.getComputedStyle(row);
        const buttonCount = row.querySelectorAll('button, a, [role="button"]').length;
        const insideSidebar =
          rect.left >= sidebarRect.left - 8 &&
          rect.right <= sidebarRect.right + 8;
        const looksLikeControlLayer =
          insideSidebar &&
          rect.height > 0 &&
          rect.height <= 88 &&
          (style.display === "flex" || style.display === "grid" || buttonCount >= 2);
        if (looksLikeControlLayer) return row;
        row = row.parentElement;
      }
      return button.parentElement instanceof HTMLElement ? button.parentElement : null;
    };

    const createInlineSlot = (row, anchor) => {
      const existing = row.querySelector(':scope > [data-codexpp="usage-slot"]');
      if (existing instanceof HTMLElement) return existing;
      const slot = document.createElement("div");
      slot.dataset.codexpp = "usage-slot";
      slot.dataset.codexppUsageSlot = "controls-inline";
      slot.className = "flex shrink-0 items-center";
      if (anchor?.parentElement === row) row.insertBefore(slot, anchor);
      else row.appendChild(slot);
      return slot;
    };

    const findSidebarSlot = () => {
      const sidebar = findUsageSidebar();
      if (!sidebar) return null;
      const existingSlot = sidebar.querySelector('[data-codexpp="usage-slot"]');
      if (existingSlot instanceof HTMLElement) return existingSlot;

      const controls = Array.from(sidebar.querySelectorAll('button, a, [role="button"]'))
        .filter((button) => button instanceof HTMLElement && isVisibleElement(button));
      const preferredControls = controls.filter(isSettingsOrDeviceButton);
      const ordered = (preferredControls.length ? preferredControls : controls).sort((a, b) => {
        const ar = a.getBoundingClientRect();
        const br = b.getBoundingClientRect();
        return br.bottom - ar.bottom;
      });

      for (const button of ordered) {
        const row = nearestControlRow(sidebar, button);
        if (row) return createInlineSlot(row, button);
      }

      return null;
    };

    const displaySnapshot = () =>
      accountMode === "api"
        ? {
            fiveHour: { label: "API", pct: null, resetAt: null, apiMode: true },
            weekly: null,
            at: Date.now(),
            apiMode: true,
          }
        :
      snapshot && (snapshot.fiveHour || snapshot.weekly)
        ? snapshot
        : {
            fiveHour: { label: "5h", pct: null, resetAt: null },
            weekly: { label: "Weekly", pct: null, resetAt: null },
            at: 0,
          };

    const ensureMounted = (forceRebuild = false) => {
      const visibleSnapshot = displaySnapshot();
      const slot = findSidebarSlot();
      document.querySelectorAll('[data-codexpp="usage-floating-slot"]').forEach((node) => node.remove());
'@)
$sourceText = $sourceText.Replace('mounted._refresh?.(snapshot);', 'mounted._refresh?.(visibleSnapshot);')
$sourceText = $sourceText.Replace('mounted = renderUsageBox(api, snapshot);', 'mounted = renderUsageBox(api, visibleSnapshot);')
$sourceText = $sourceText.Replace(@'
    const refreshUsageFromApi = async () => {
'@, @'
    const refreshUsageFromApi = async () => {
      if ((await refreshAccountMode()) !== "official") return false;
'@)
$sourceText = $sourceText.Replace(@'
        refreshUsageFromApi();
'@, @'
        refreshAccountMode().then((mode) => {
          if (mode === "official") refreshUsageFromApi();
        });
'@)
$sourceText = $sourceText.Replace('        if (!directUsageAvailable) {', '        if (accountMode === "official" && !directUsageAvailable) {')
$sourceText = $sourceText.Replace(@'
  /** Pull the entry for `kind` out of the live snapshot. */
  const entryFor = (snap, k) => (k === "5h" ? snap.fiveHour : snap.weekly);
'@, @'
  /** Pull the entry for `kind` out of the live snapshot. */
  const entryFor = (snap, k) => (k === "5h" ? snap.fiveHour : snap.weekly);
  const isApiSnapshot = (snap) => !!snap?.apiMode || snap?.fiveHour?.apiMode;
'@)
$sourceText = $sourceText.Replace(@'
  const applyValueState = (snap) => {
    const entry = entryFor(snap, kind);
'@, @'
  const applyValueState = (snap) => {
    if (isApiSnapshot(snap)) {
      btn.classList.remove("bg-token-charts-red/10", "text-token-charts-red");
      btn.classList.add("bg-token-foreground/5", "text-token-text-primary");
      setText(left, "API");
      setClass(left, "truncate");
      right.replaceChildren();
      return;
    }
    const entry = entryFor(snap, kind);
'@)
$sourceText = $sourceText.Replace(@'
  const applyHoverState = (snap) => {
    const entry = entryFor(snap, kind);
'@, @'
  const applyHoverState = (snap) => {
    if (isApiSnapshot(snap)) {
      applyValueState(snap);
      return;
    }
    const entry = entryFor(snap, kind);
'@)
$sourceText = $sourceText.Replace(@'
    e.stopPropagation();
    const i = ORDER.indexOf(kind);
'@, @'
    e.stopPropagation();
    if (isApiSnapshot(currentSnap)) {
      suppressHover = true;
      applyValueState(currentSnap);
      return;
    }
    const i = ORDER.indexOf(kind);
'@)
$sourceText = $sourceText.Replace('slot.appendChild(mounted);', "slot.appendChild(mounted);`n      lastMountedMode = slot.dataset.codexppUsageSlot || `"unknown`";")
$sourceText = $sourceText.Replace('log("mounted usage box", {', "log(`"mounted usage box`", {`n        mode: lastMountedMode,")
$sourceText = $sourceText.Replace('slot.dataset.codexppUsageSlot === "settings-inline-windows"', 'slot.dataset.codexppUsageSlot === "settings-inline-windows" || slot.dataset.codexppUsageSlot === "controls-inline"')
$sourceText = $sourceText.Replace(@'
      for (const slot of document.querySelectorAll('[data-codexpp="usage-slot"]')) {
        if (slot instanceof HTMLElement && slot.children.length === 0) slot.remove();
      }
'@, @'
      for (const slot of document.querySelectorAll('[data-codexpp="usage-slot"]')) {
        if (slot instanceof HTMLElement && slot.children.length === 0) slot.remove();
      }
      for (const slot of document.querySelectorAll('[data-codexpp="usage-floating-slot"]')) {
        slot.remove();
      }
'@)

$prefix = @'
/*
 * Bennett UI Improvements for BigPizzaV3 Codex++
 *
 * Source project: https://github.com/b-nnett/codex-plusplus-bennett-ui
 * Original tweak id: co.bennett.ui-improvements
 * Original author: bennett
 * Original license: MIT License, Copyright (c) 2026 Bennett
 *
 * This file is a compatibility migration from the b-nnett Codex++ tweak
 * runtime to the BigPizzaV3 Codex++ renderer-only user script runtime.
 * The UI implementation below is not original work by the migrator; the
 * wrapper only adapts storage/logging/renderer lifecycle assumptions.
 *
 * MIT permission notice from the source project applies: permission is
 * granted to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies, provided the copyright notice and permission notice
 * are included in all copies or substantial portions of the Software.
 */

(() => {
  "use strict";

  const INSTALL_KEY = "__bennettUiImprovementsBigPizza";
  const VERSION = "1.0.5-bigpizza.1";
  const previous = window[INSTALL_KEY];
  if (previous && typeof previous.stop === "function") {
    try {
      previous.stop();
    } catch (error) {
      console.warn("[Bennett UI/BigPizza] previous stop failed", error);
    }
  }

  const module = { exports: {} };
  const exports = module.exports;

'@

$suffix = @'

  const tweak = module.exports;
  const api = createBigPizzaRendererApi();
  if (!tweak || typeof tweak.start !== "function") {
    throw new Error("Bennett UI tweak entrypoint was not found");
  }

  tweak.start.call(tweak, api);
  const features = [
    "hide-upgrade-prompts",
    "show-usage-in-sidebar",
    "square-sidebar",
    "settings-search",
    "match-sidebar-width",
    "sidebar-action-grid",
    "sidebar-project-backgrounds",
    "slash-menu-polish",
    "show-message-metrics-on-hover",
    "sidebar-chat-multi-select",
    "show-pinned-chat-project-names",
  ];
  const featureInfo = [
    {
      id: "hide-upgrade-prompts",
      title: "隐藏升级提示",
      detail: "隐藏侧栏和顶部栏中的 Upgrade / Get Plus 提示。",
      defaultEnabled: true,
      status: "可用",
    },
    {
      id: "show-usage-in-sidebar",
      title: "5 小时 / 周额度",
      detail: "优先通过 Codex renderer fetch bridge 读取 /wham/usage，失败时再解析页面里的额度 UI。点击可在 5h 和 Weekly 之间切换。",
      defaultEnabled: true,
      status: "当前页面暴露额度信号时可用",
    },
    {
      id: "square-sidebar",
      title: "侧栏方角",
      detail: "去掉侧栏与主内容之间的圆角。",
      defaultEnabled: false,
      status: "可用",
    },
    {
      id: "settings-search",
      title: "设置搜索",
      detail: "给 Codex 设置页增加搜索框。",
      defaultEnabled: true,
      status: "可用",
    },
    {
      id: "match-sidebar-width",
      title: "匹配设置页侧栏宽度",
      detail: "让设置页侧栏宽度与主侧栏对齐。",
      defaultEnabled: true,
      status: "可用",
    },
    {
      id: "sidebar-action-grid",
      title: "侧栏动作网格",
      detail: "把主要侧栏动作整理成紧凑网格。",
      defaultEnabled: true,
      status: "可用",
    },
    {
      id: "sidebar-project-backgrounds",
      title: "项目背景和颜色",
      detail: "为项目行增加分组背景，并保留旧的项目颜色偏好。",
      defaultEnabled: true,
      status: "可用",
    },
    {
      id: "slash-menu-polish",
      title: "斜杠菜单优化",
      detail: "压缩斜杠菜单行距，并强化选中状态。",
      defaultEnabled: true,
      status: "可用",
    },
    {
      id: "show-message-metrics-on-hover",
      title: "消息 token 指标",
      detail: "旧实现需要从 main process 读取本地 Codex JSONL，而 BigPizzaV3 用户脚本无法访问这一层。",
      defaultEnabled: false,
      status: "当前运行环境不支持",
      disabled: true,
    },
    {
      id: "sidebar-chat-multi-select",
      title: "侧栏会话多选",
      detail: "选择界面可以部分运行，但批量 Pin / Archive / mini window 操作依赖旧的 Electron IPC。",
      defaultEnabled: false,
      status: "部分支持，默认关闭",
    },
    {
      id: "show-pinned-chat-project-names",
      title: "固定会话项目名",
      detail: "旧实现需要从 main process 扫描本地会话文件。",
      defaultEnabled: false,
      status: "当前运行环境不支持",
      disabled: true,
    },
  ];
  const settingsObserver = new MutationObserver(installSettingsPanel);
  settingsObserver.observe(document.documentElement, { childList: true, subtree: true });
  installSettingsPanel();

  function featureDefault(id) {
    return featureInfo.find((item) => item.id === id)?.defaultEnabled ?? false;
  }

  function featureEnabled(id) {
    const meta = featureInfo.find((item) => item.id === id);
    if (meta?.disabled) return false;
    return !!api.storage.get(`feature:${id}`, featureDefault(id));
  }

  function setFeatureEnabled(id, enabled) {
    if (!features.includes(id)) {
      throw new Error(`Unknown Bennett UI feature: ${id}`);
    }
    api.storage.set(`feature:${id}`, !!enabled);
    const state = tweak._state;
    if (state && typeof activateFeature === "function" && typeof deactivateFeature === "function") {
      if (enabled) activateFeature(state, id);
      else deactivateFeature(state, id);
    }
    refreshSettingsPanel();
  }

  function installSettingsPanel() {
    const modal = document.querySelector(".codex-plus-modal-content");
    if (!modal || modal.dataset.bennettUiSettingsVersion === VERSION) return;
    const tabs = modal.querySelector(".codex-plus-tabs");
    const body = modal.querySelector(".codex-plus-modal-body");
    if (!tabs || !body) return;
    modal.dataset.bennettUiSettingsVersion = VERSION;

    tabs.querySelector('[data-codex-plus-tab="bennettUi"]')?.remove();
    body.querySelector('[data-codex-plus-panel="bennettUi"]')?.remove();

    const tab = document.createElement("button");
    tab.type = "button";
    tab.className = "codex-plus-tab-button";
    tab.dataset.codexPlusTab = "bennettUi";
    tab.dataset.active = "false";
    tab.textContent = "Bennett UI 设置";
    tabs.appendChild(tab);

    const panel = document.createElement("div");
    panel.className = "codex-plus-panel";
    panel.dataset.codexPlusPanel = "bennettUi";
    panel.hidden = true;
    panel.innerHTML = settingsPanelHtml();
    panel.addEventListener("click", (event) => {
      const target = event.target instanceof Element ? event.target : event.target?.parentElement;
      const toggle = target?.closest("[data-bennett-ui-feature]");
      if (!toggle) return;
      event.preventDefault();
      event.stopPropagation();
      const id = toggle.getAttribute("data-bennett-ui-feature");
      const meta = featureInfo.find((item) => item.id === id);
      if (!id || meta?.disabled) return;
      setFeatureEnabled(id, !featureEnabled(id));
    }, true);
    body.appendChild(panel);
    ensureSettingsStyle();
    refreshSettingsPanel();
  }

  function settingsPanelHtml() {
    return `
      <div class="codex-plus-row bennett-ui-settings-head">
        <div>
          <div class="codex-plus-row-title">Bennett UI Improvements</div>
          <div class="codex-plus-row-description">来源：b-nnett/codex-plusplus-bennett-ui。此迁移只保留能够在 BigPizzaV3 renderer-only 用户脚本环境中运行的功能。</div>
          <div class="bennett-ui-settings-note">切换会尽量立即生效。如果 Codex DOM 变动导致残留，可重新加载用户脚本或重启 Codex++。</div>
        </div>
      </div>
      ${featureInfo.map((item) => `
        <div class="codex-plus-row bennett-ui-feature-row" data-bennett-ui-row="${escapeAttr(item.id)}">
          <div>
            <div class="codex-plus-row-title">${escapeHtmlLocal(item.title)}</div>
            <div class="codex-plus-row-description">${escapeHtmlLocal(item.detail)}</div>
            <div class="bennett-ui-feature-status">${escapeHtmlLocal(item.status)}</div>
          </div>
          <button type="button" class="codex-plus-toggle bennett-ui-toggle" data-bennett-ui-feature="${escapeAttr(item.id)}" ${item.disabled ? "disabled" : ""}><span></span></button>
        </div>
      `).join("")}
    `;
  }

  function refreshSettingsPanel() {
    for (const item of featureInfo) {
      const row = document.querySelector(`[data-bennett-ui-row="${cssEscape(item.id)}"]`);
      const toggle = row?.querySelector("[data-bennett-ui-feature]");
      if (!toggle) continue;
      toggle.dataset.enabled = String(featureEnabled(item.id));
      toggle.dataset.support = item.disabled ? "unsupported" : "supported";
      row.dataset.enabled = String(featureEnabled(item.id));
    }
  }

  function ensureSettingsStyle() {
    if (document.getElementById("bennett-ui-settings-style")) return;
    const style = document.createElement("style");
    style.id = "bennett-ui-settings-style";
    style.textContent = `
      .bennett-ui-settings-note,
      .bennett-ui-feature-status {
        margin-top: 6px;
        color: var(--text-secondary, var(--color-token-text-secondary, #8b8b8b));
        font-size: 12px;
        line-height: 1.35;
      }
      .bennett-ui-feature-row[data-enabled="true"] .bennett-ui-feature-status {
        color: var(--text-primary, var(--color-token-text-primary, #f5f5f5));
      }
      .bennett-ui-toggle[disabled] {
        cursor: not-allowed;
        opacity: 0.45;
      }
      .bennett-ui-toggle[data-enabled="true"] span {
        transform: translateX(14px);
      }
    `;
    document.head.appendChild(style);
  }

  function escapeHtmlLocal(value) {
    return String(value ?? "").replace(/[&<>"']/g, (ch) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    })[ch]);
  }

  function escapeAttr(value) {
    return escapeHtmlLocal(value);
  }

  function cssEscape(value) {
    if (window.CSS && typeof window.CSS.escape === "function") return window.CSS.escape(value);
    return String(value).replace(/["\\]/g, "\\$&");
  }

  window[INSTALL_KEY] = {
    version: VERSION,
    api,
    features,
    featureInfo,
    setFeature(id, enabled, reload = true) {
      setFeatureEnabled(id, enabled);
      if (reload) window.location.reload();
    },
    stop() {
      settingsObserver.disconnect();
      document.querySelector('[data-codex-plus-tab="bennettUi"]')?.remove();
      document.querySelector('[data-codex-plus-panel="bennettUi"]')?.remove();
      if (typeof tweak.stop === "function") {
        tweak.stop.call(tweak);
      }
    },
  };

  function createBigPizzaRendererApi() {
    const storagePrefix = "bennett-ui-improvements:";
    const blockedFeatureKeys = new Set([
      "feature:show-message-metrics-on-hover",
      "feature:show-pinned-chat-project-names",
    ]);
    const noop = () => {};
    const logWith = (level) => (...args) => {
      const fn = console[level] || console.log || noop;
      fn.call(console, "[Bennett UI/BigPizza]", ...args);
    };

    const storage = {
      get(key, fallback) {
        if (blockedFeatureKeys.has(key)) return false;
        try {
          const raw = window.localStorage.getItem(storagePrefix + key);
          return raw == null ? fallback : JSON.parse(raw);
        } catch {
          return fallback;
        }
      },
      set(key, value) {
        try {
          window.localStorage.setItem(storagePrefix + key, JSON.stringify(value));
        } catch {
          // localStorage can be disabled; UI tweaks should still run.
        }
        return value;
      },
      delete(key) {
        try {
          window.localStorage.removeItem(storagePrefix + key);
        } catch {
          // Ignore storage failures.
        }
      },
    };

    return {
      process: "renderer",
      storage,
      settings: null,
      fs: null,
      log: {
        debug: logWith("debug"),
        info: logWith("info"),
        warn: logWith("warn"),
        error: logWith("error"),
      },
      ipc: {
        invoke(channel) {
          return Promise.reject(
            new Error(`BigPizza Codex++ user scripts do not expose b-nnett IPC channel: ${channel}`),
          );
        },
        handle: noop,
      },
    };
  }
})();
'@

$content = $prefix + $sourceText + $suffix
Set-Content -LiteralPath $outPath -Value $content -NoNewline -Encoding utf8
Write-Output $outPath

