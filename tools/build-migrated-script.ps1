param(
  [string]$Source = "old-bennett-ui\index.js",
  [string]$Out = "scripts\bennett-ui-improvements.js"
)

$ErrorActionPreference = "Stop"

$sourcePath = Resolve-Path -LiteralPath $Source
$outPath = Join-Path (Get-Location) $Out
$outDir = Split-Path -Parent $outPath
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$previewMathFeaturePath = Resolve-Path -LiteralPath "features\markdown-preview-math.js"
$nativeHistoryFeaturePath = Resolve-Path -LiteralPath "features\native-history-loader.js"

$sourceText = Get-Content -LiteralPath $sourcePath -Raw -Encoding utf8
$sourceText = $sourceText -replace "\r\n", "`n"
$sourceText = $sourceText.Replace('"show-usage-in-sidebar": false', '"show-usage-in-sidebar": true')
$sourceText = $sourceText.Replace(
  '"sidebar-project-backgrounds": true',
  '"sidebar-project-backgrounds": true,' + "`n" + '        "render-markdown-preview-math": true'
)
$previewMathFeature = Get-Content -LiteralPath $previewMathFeaturePath -Raw -Encoding utf8
$previewMathFeature = $previewMathFeature -replace "\r\n", "`n"
$nativeHistoryFeature = Get-Content -LiteralPath $nativeHistoryFeaturePath -Raw -Encoding utf8
$nativeHistoryFeature = $nativeHistoryFeature -replace "\r\n", "`n"
$sourceText = $sourceText.Replace("const FEATURES = {", "const FEATURES = {`n$previewMathFeature")
$sourceText = [regex]::Replace($sourceText, '    const ASIDE_SELECTOR = \[[\s\S]*?    \]\.join\(", "\);\n', @'
    const ASIDE_SELECTOR = [
      "aside.pointer-events-auto.relative.flex.overflow-hidden",
      "aside.pointer-events-auto.relative.flex.overflow-visible",
      "aside.pointer-events-auto.relative.flex",
    ].join(", ");
    const SIDEBAR_CANDIDATE_SELECTOR = [
      ASIDE_SELECTOR,
      "aside",
      "nav",
      "[role='navigation']",
      "[data-testid*='sidebar' i]",
      "[data-test*='sidebar' i]",
      "[class*='sidebar' i]",
    ].join(", ");

'@, 1)
$sourceText = $sourceText.Replace(@'
    let bridgeRequestSeq = 0;
    let disposed = false;
'@, @'
    let bridgeRequestSeq = 0;
    let disposed = false;
    let lastMountedMode = null;
    let accountMode = "unknown"; // "official" | "api" | "unknown"
    let accountModeInFlight = false;
    let accountModeLastCheckedAt = 0;
    let accountModeLogged = false;
    let accountModeCandidate = "unknown";
    let accountModeCandidateCount = 0;
    let accountModeCandidateAt = 0;
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
      if (disposed || typeof bridge !== "function") return null;
      let timeout = 0;
      try {
        return await Promise.race([
          bridge(path, payload),
          new Promise((resolve) => {
            timeout = window.setTimeout(() => resolve(null), timeoutMs);
          }),
        ]);
      } finally {
        if (timeout) window.clearTimeout(timeout);
      }
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
        let explicitMode = false;
        const settings = await bridgePostJson("/settings/get", {});
        if (disposed) return accountMode;
        const profile = activeRelayProfile(settings);
        const relayMode = fieldValue(profile, "relayMode", "relay_mode");
        const officialMixApiKey = !!fieldValue(profile, "officialMixApiKey", "official_mix_api_key");
        const legacyApiConfigured = !!(
          String(fieldValue(settings, "relayApiKey", "relay_api_key") || "").trim() ||
          String(fieldValue(settings, "relayBaseUrl", "relay_base_url") || "").trim()
        );
        if (relayMode === "official" && !officialMixApiKey) {
          nextMode = "official";
          explicitMode = true;
        } else if (relayMode === "pureApi" || relayMode === "pure_api") {
          nextMode = "api";
          explicitMode = true;
        } else if (relayMode === "mixedApi" || relayMode === "mixed_api" || officialMixApiKey) {
          nextMode = "api";
          explicitMode = true;
        } else if (!relayMode && legacyApiConfigured) {
          nextMode = "api";
          explicitMode = true;
        }

        if (nextMode === "unknown") {
          const catalog = await bridgePostJson("/codex-model-catalog", {});
          if (disposed) return accountMode;
          if (catalogLooksLikeApiMode(catalog)) nextMode = "api";
          else if (catalog?.model_provider === "openai" || catalog?.provider_name === "openai") {
            nextMode = "official";
          }
        }
        if (nextMode === "unknown") return accountMode;

        // Catalog responses can briefly reflect the previous provider while
        // Codex is switching accounts. Require two matching non-explicit
        // observations before changing the visible mode.
        if (nextMode === accountMode) {
          accountModeCandidate = "unknown";
          accountModeCandidateCount = 0;
          accountModeCandidateAt = 0;
          return accountMode;
        }
        if (accountMode !== "unknown" || !explicitMode) {
          if (
            accountModeCandidate === nextMode &&
            now - accountModeCandidateAt < 45_000
          ) {
            accountModeCandidateCount += 1;
          } else {
            accountModeCandidate = nextMode;
            accountModeCandidateCount = 1;
            accountModeCandidateAt = now;
          }
          if (accountModeCandidateCount < 2) return accountMode;
        }

        accountModeCandidate = "unknown";
        accountModeCandidateCount = 0;
        accountModeCandidateAt = 0;
        accountMode = nextMode;
        if (accountMode === "api") {
          snapshot = {
            fiveHour: { label: "API", pct: null, resetAt: null, apiMode: true },
            weekly: null,
            at: Date.now(),
            apiMode: true,
          };
        } else {
          // Keep the last stable value visible while the official snapshot
          // refreshes. Clearing here caused the control to flash "—".
          directUsageAvailable = false;
          directUsageLastAttemptAt = 0;
        }
        ensureMounted(true);
        if (!accountModeLogged) {
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

    const quickControlText = (node) =>
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

    const isSidebarGeometry = (node) => {
      if (!(node instanceof HTMLElement) || !isVisibleElement(node)) return false;
      const rect = node.getBoundingClientRect();
      const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 0;
      const viewportWidth = window.innerWidth || document.documentElement.clientWidth || 0;
      return (
        rect.width >= 180 &&
        rect.width <= Math.min(520, Math.max(320, viewportWidth * 0.55)) &&
        rect.height >= Math.max(360, viewportHeight * 0.45) &&
        rect.left <= Math.max(96, viewportWidth * 0.12) &&
        rect.top <= Math.max(96, viewportHeight * 0.18)
      );
    };

    const hasBottomControl = (sidebar) => {
      const sidebarRect = sidebar.getBoundingClientRect();
      const controls = Array.from(sidebar.querySelectorAll('button, a, [role="button"], [role="status"], [aria-live], span, div'));
      return controls.some((control) => {
        if (!(control instanceof HTMLElement) || !isVisibleElement(control)) return false;
        const rect = control.getBoundingClientRect();
        const text = quickControlText(control);
        const nearBottom = rect.bottom >= sidebarRect.bottom - 260;
        const compact = rect.width > 0 && rect.width <= 64 && rect.height > 0 && rect.height <= 64;
        const downloadStatus = text.length <= 80 && /\bdownloading\b|\bdownload\b|\bupdating\b|\binstalling\b|正在下载|下载中|更新中|正在更新|安装中/.test(text);
        return nearBottom && (compact || downloadStatus || /\bmobile\b|\bphone\b|\bdevice\b|\bsettings?\b|手机|移动|设备|连接|设置/.test(text));
      });
    };

    const addSidebarAncestorsForBottomControls = (candidates) => {
      const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 0;
      const controls = Array.from(document.querySelectorAll('button, a, [role="button"], [role="status"], [aria-live], span, div'));
      for (const control of controls) {
        if (!(control instanceof HTMLElement) || !isVisibleElement(control)) continue;
        const rect = control.getBoundingClientRect();
        if (rect.left > 560 || rect.bottom < viewportHeight - 280) continue;
        const text = quickControlText(control);
        const compact = rect.width > 0 && rect.width <= 64 && rect.height > 0 && rect.height <= 64;
        const downloadStatus = text.length <= 80 && /\bdownloading\b|\bdownload\b|\bupdating\b|\binstalling\b|正在下载|下载中|更新中|正在更新|安装中/.test(text);
        if (!compact && !downloadStatus && !/\bmobile\b|\bphone\b|\bdevice\b|\bsettings?\b|手机|移动|设备|连接|设置/.test(text)) continue;
        let node = control.parentElement;
        while (node && node !== document.body) {
          if (isSidebarGeometry(node) && !looksLikeSettingsSidebar(node)) candidates.add(node);
          node = node.parentElement;
        }
      }
    };

    const sidebarScore = (sidebar) => {
      if (!isSidebarGeometry(sidebar) || looksLikeSettingsSidebar(sidebar)) return -Infinity;
      const rect = sidebar.getBoundingClientRect();
      let score = 0;
      if (rect.left <= 16) score += 4;
      else if (rect.left <= 80) score += 2;
      if (rect.width >= 220 && rect.width <= 420) score += 3;
      if (rect.height >= (window.innerHeight || 0) * 0.75) score += 3;
      if (looksLikeMainAppSidebar(sidebar)) score += 6;
      if (hasBottomControl(sidebar)) score += 5;
      if (/^(aside|nav)$/i.test(sidebar.tagName) || sidebar.getAttribute("role") === "navigation") score += 2;
      return score;
    };

    const findUsageSidebar = () => {
      const primarySidebar = Array.from(document.querySelectorAll(ASIDE_SELECTOR))
        .find((sidebar) => {
          if (!(sidebar instanceof HTMLElement) || !isVisibleElement(sidebar)) return false;
          if (looksLikeSettingsSidebar(sidebar)) return false;
          const rect = sidebar.getBoundingClientRect();
          return rect.width >= 150 && rect.height >= 300;
        });
      if (primarySidebar instanceof HTMLElement) return primarySidebar;
      const candidates = new Set(
        Array.from(document.querySelectorAll(SIDEBAR_CANDIDATE_SELECTOR))
          .filter((node) => node instanceof HTMLElement),
      );
      addSidebarAncestorsForBottomControls(candidates);
      return Array.from(candidates)
        .map((sidebar) => ({ sidebar, score: sidebarScore(sidebar) }))
        .filter((item) => item.score > 0)
        .sort((a, b) => b.score - a.score || a.sidebar.getBoundingClientRect().left - b.sidebar.getBoundingClientRect().left)[0]?.sidebar || null;
    };
'@)
$sourceText = $sourceText.Replace(@'
    const ensureMounted = (forceRebuild = false) => {
      if (disposed) return;
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

    const controlLabelText = (node) =>
      [node.getAttribute?.("aria-label"), node.getAttribute?.("title")]
        .filter(Boolean)
        .join(" ")
        .replace(/\s+/g, " ")
        .trim()
        .toLowerCase();

    const isDeviceButton = (button) => {
      const label = controlLabelText(button);
      if (/\bmobile\b|\bphone\b|\bdevice\b|手机|移动|设备|连接/.test(label)) return true;
      const text = controlText(button);
      return text.length <= 28 && /\bmobile\b|\bphone\b|\bdevice\b|手机|移动|设备|连接/.test(text);
    };

    const isDownloadStatusNode = (node) => {
      const text = controlText(node);
      if (!text || text.length > 80) return false;
      return /\bdownloading\b|\bdownload\b|\bupdating\b|\binstalling\b|正在下载|下载中|更新中|正在更新|安装中/.test(text);
    };

    const isSettingsButton = (button) => {
      const text = controlText(button);
      return /\bsettings?\b|preferences?|设置|偏好/.test(text);
    };

    const isNearSidebarBottom = (sidebar, node) => {
      if (!(sidebar instanceof HTMLElement) || !(node instanceof HTMLElement)) return false;
      const sidebarRect = sidebar.getBoundingClientRect();
      const rect = node.getBoundingClientRect();
      const bottomBand = Math.min(Math.max(sidebarRect.height * 0.22, 120), 240);
      const visibleBottom = Math.min(
        sidebarRect.bottom,
        window.innerHeight || document.documentElement.clientHeight || sidebarRect.bottom,
      );
      return (
        rect.top < visibleBottom &&
        rect.bottom <= visibleBottom + 8 &&
        rect.bottom >= visibleBottom - bottomBand
      );
    };

    const isCompactIconControl = (control) => {
      const rect = control.getBoundingClientRect();
      const text = controlText(control);
      return rect.width > 0 && rect.width <= 56 && rect.height > 0 && rect.height <= 56 && text.length <= 32;
    };

    const isUsageControlNode = (node) =>
      node.closest?.('[data-codexpp="usage-slot"], [data-codexpp="usage-box"], [data-codexpp="usage-boxes"]');

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
        const nearBottom = isNearSidebarBottom(sidebar, row);
        const looksLikeControlLayer =
          insideSidebar &&
          nearBottom &&
          rect.height > 0 &&
          rect.height <= 128 &&
          (style.display === "flex" || style.display === "grid" || buttonCount >= 2);
        if (looksLikeControlLayer) return row;
        row = row.parentElement;
      }
      return null;
    };

    const nearestBottomStatusRow = (sidebar, node) => {
      const sidebarRect = sidebar.getBoundingClientRect();
      let row = node.parentElement;
      while (row && row !== document.body && row !== sidebar.parentElement) {
        if (!(row instanceof HTMLElement)) break;
        const rect = row.getBoundingClientRect();
        const style = window.getComputedStyle(row);
        const insideSidebar =
          rect.left >= sidebarRect.left - 8 &&
          rect.right <= sidebarRect.right + 8;
        const nearBottom = isNearSidebarBottom(sidebar, row);
        const compactStatusLayer =
          insideSidebar &&
          nearBottom &&
          rect.height > 0 &&
          rect.height <= 96 &&
          (style.display === "flex" || style.display === "grid" || isDownloadStatusNode(row));
        if (compactStatusLayer) return row;
        row = row.parentElement;
      }
      return null;
    };

    const createInlineSlot = (row, anchor) => {
      const existing = row.querySelector(':scope > [data-codexpp="usage-slot"]');
      if (existing instanceof HTMLElement) return existing;
      const slot = document.createElement("div");
      slot.dataset.codexpp = "usage-slot";
      slot.dataset.codexppUsageSlot = "controls-inline";
      slot.className = "flex shrink-0 items-center";
      if (anchor?.parentElement === row) {
        row.insertBefore(slot, anchor.nextSibling);
      }
      else row.appendChild(slot);
      return slot;
    };

    const createFallbackSlot = (sidebar) => {
      const existing = sidebar.querySelector(':scope > [data-codexpp="usage-slot"]');
      if (existing instanceof HTMLElement) return existing;
      const slot = document.createElement("div");
      slot.dataset.codexpp = "usage-slot";
      slot.dataset.codexppUsageSlot = "sidebar-floating-fallback";
      slot.className = "flex items-center";
      slot.style.position = "absolute";
      slot.style.right = "0.75rem";
      slot.style.bottom = "0.75rem";
      slot.style.zIndex = "30";
      sidebar.appendChild(slot);
      return slot;
    };

    const findSidebarSlot = () => {
      const sidebar = findUsageSidebar();
      if (!sidebar) return null;
      for (const slot of sidebar.querySelectorAll('[data-codexpp="usage-slot"]')) {
        if (
          !(slot instanceof HTMLElement) ||
          !(slot.parentElement instanceof HTMLElement) ||
          !slot.isConnected
        ) {
          slot.remove();
        }
      }
      const existingSlot = Array.from(sidebar.querySelectorAll('[data-codexpp="usage-slot"]'))
        .find((slot) =>
          slot instanceof HTMLElement &&
          slot.parentElement instanceof HTMLElement &&
          slot.isConnected,
        );
      if (existingSlot instanceof HTMLElement) return existingSlot;

      const controls = Array.from(sidebar.querySelectorAll('button, a, [role="button"]'))
        .filter((button) =>
          button instanceof HTMLElement &&
          isVisibleElement(button) &&
          isNearSidebarBottom(sidebar, button) &&
          !isUsageControlNode(button),
        );
      const deviceControls = controls.filter(isDeviceButton);
      const settingsControls = controls.filter(isSettingsButton);
      const compactControls = controls.filter(isCompactIconControl);
      const preferredControls = deviceControls.length
        ? deviceControls
        : compactControls.length
          ? compactControls
          : settingsControls;
      const ordered = (preferredControls.length ? preferredControls : controls).sort((a, b) => {
        const ar = a.getBoundingClientRect();
        const br = b.getBoundingClientRect();
        return br.right - ar.right || br.bottom - ar.bottom;
      });

      for (const button of ordered) {
        const row = nearestControlRow(sidebar, button);
        if (row) return createInlineSlot(row, button);
      }

      const statusAnchors = Array.from(
        sidebar.querySelectorAll('[role="status"], [aria-live], [aria-label], [title], span, div'),
      )
        .filter((node) =>
          node instanceof HTMLElement &&
          isVisibleElement(node) &&
          isNearSidebarBottom(sidebar, node) &&
          !isUsageControlNode(node) &&
          isDownloadStatusNode(node),
        )
        .sort((a, b) => {
          const ar = a.getBoundingClientRect();
          const br = b.getBoundingClientRect();
          return br.bottom - ar.bottom || br.right - ar.right;
        });

      for (const anchor of statusAnchors) {
        const row = nearestBottomStatusRow(sidebar, anchor);
        if (row) return createInlineSlot(row, anchor);
      }

      return createFallbackSlot(sidebar);
    };

    const displaySnapshot = () =>
      accountMode === "api"
        ? {
            fiveHour: { label: "API", pct: null, resetAt: null, apiMode: true },
            weekly: null,
            points: null,
            at: Date.now(),
            apiMode: true,
          }
        :
      snapshot && (snapshot.fiveHour || snapshot.weekly)
        ? snapshot
        : {
            fiveHour: { label: "5h", pct: null, resetAt: null },
            weekly: { label: "Weekly", pct: null, resetAt: null },
            points: null,
            at: 0,
          };

    const ensureMounted = (forceRebuild = false) => {
      if (disposed) return;
      const visibleSnapshot = displaySnapshot();
      const slot = findSidebarSlot();
'@)
$sourceText = $sourceText.Replace('mounted._refresh?.(snapshot);', 'mounted._refresh?.(visibleSnapshot);')
$sourceText = $sourceText.Replace('mounted = renderUsageBox(api, snapshot);', 'mounted = renderUsageBox(api, visibleSnapshot);')
$sourceText = $sourceText.Replace(@'
    const refreshUsageFromApi = async () => {
      if (disposed) return false;
'@, @'
    const refreshUsageFromApi = async () => {
      if (disposed) return false;
      if ((await refreshAccountMode()) === "api" || disposed) return false;
'@)
$sourceText = $sourceText.Replace(@'
      if (disposed) return;
      await refreshUsageFromApi();
      if (disposed) return;
      if (!directUsageAvailable) {
'@, @'
      if (disposed) return;
      const mode = await refreshAccountMode();
      if (disposed) return;
      if (mode !== "api") await refreshUsageFromApi();
      if (disposed) return;
      if (accountMode !== "api" && !directUsageAvailable) {
'@)
$sourceText = $sourceText.Replace(@'
        refreshUsageFromApi();
'@, @'
        refreshAccountMode().then((mode) => {
          if (mode !== "api") refreshUsageFromApi();
        });
'@)
$sourceText = $sourceText.Replace('        if (!directUsageAvailable) {', '        if (accountMode !== "api" && !directUsageAvailable) {')
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
$requiredGeneratedMarkers = [ordered]@{
  "usage default" = '"show-usage-in-sidebar": true'
  "Markdown preview feature" = '"render-markdown-preview-math"(api)'
  "sidebar candidate discovery" = 'const SIDEBAR_CANDIDATE_SELECTOR = ['
  "account mode state" = 'let accountMode = "unknown"'
  "account mode refresh" = 'const refreshAccountMode = async (force = false) => {'
  "stable visible snapshot" = 'const displaySnapshot = () =>'
  "visible snapshot refresh" = 'mounted._refresh?.(visibleSnapshot);'
  "API snapshot renderer" = 'const isApiSnapshot = (snap) =>'
  "disposed quota guard" = 'if ((await refreshAccountMode()) === "api" || disposed) return false;'
  "mounted slot mode" = 'lastMountedMode = slot.dataset.codexppUsageSlot || "unknown";'
}
foreach ($entry in $requiredGeneratedMarkers.GetEnumerator()) {
  if (-not $sourceText.Contains($entry.Value)) {
    throw "Required migration transform failed: $($entry.Key)"
  }
}

$singletonMarkers = @(
  '"render-markdown-preview-math"(api)',
  'const displaySnapshot = () =>',
  'const isApiSnapshot = (snap) =>'
)
foreach ($marker in $singletonMarkers) {
  if ([regex]::Matches($sourceText, [regex]::Escape($marker)).Count -ne 1) {
    throw "Migration marker must occur exactly once: $marker"
  }
}
if ($sourceText.Contains('let snapshot = null; // Do not render persisted quota data')) {
  throw "Persisted quota snapshot was unexpectedly disabled"
}

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
  const VERSION = "1.2.4";
  const HISTORY_TARGET_STORAGE_KEY = "__codexListPagebusterTarget";
  const HISTORY_TARGET_DEFAULT = 500;
  const HISTORY_TARGET_MIN = 1;
  const HISTORY_TARGET_MAX = 2000;
  const SCRIPT_LOAD_ID = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  const lifecycleTimers = new Set();
  const lifecycleSignatures = new Set();

  function reportLifecycle(event, detail = {}) {
    const signature = `${event}:${JSON.stringify(detail)}`;
    if (event === "usage-mounted" && lifecycleSignatures.has(signature)) return;
    lifecycleSignatures.add(signature);
    const payload = {
      event: `bennett-ui.${event}`,
      version: VERSION,
      scriptLoadId: SCRIPT_LOAD_ID,
      ...detail,
    };
    window.__bennettUiLastLifecycle = payload;
    try {
      const bridge = window.__codexSessionDeleteBridge;
      if (typeof bridge === "function") {
        Promise.resolve(bridge("/diagnostics/log", payload)).catch(() => {});
      }
    } catch (_) {}
  }

  function scheduleLifecycle(callback, delay) {
    const timer = window.setTimeout(() => {
      lifecycleTimers.delete(timer);
      callback();
    }, delay);
    lifecycleTimers.add(timer);
    return timer;
  }

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
    "render-markdown-preview-math",
    "slash-menu-polish",
    "hide-usage-alert",
  ];
  const featureInfo = [
    {
      id: "hide-upgrade-prompts",
      title: "隐藏升级提示",
      detail: "隐藏 Plus/Pro 套餐升级提示，但保留 Codex 软件更新提示。",
      defaultEnabled: true,
      status: "可用",
    },
    {
      id: "show-usage-in-sidebar",
      title: "5 小时 / 周 / Credit 额度",
      detail: "优先通过 Codex renderer fetch bridge 读取 /wham/usage；默认显示 5h，点击可切换 Weekly；只有实际收到点数数据时才显示 Credit，API 模式显示 API。",
      defaultEnabled: true,
      status: "当前页面暴露额度信号时可用",
    },
    {
      id: "hide-usage-alert",
      title: "隐藏额度耗尽提示",
      detail: "隐藏额度用完后的弹窗、重置提示和额度卡片。",
      defaultEnabled: true,
      status: "可用",
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
      id: "render-markdown-preview-math",
      title: "Markdown 预览增强",
      detail: "在右侧 .md 文件预览中渲染 LaTeX、数学表格和图片；相对图片路径以当前文档为基准，点击内容可原位编辑源码。",
      defaultEnabled: true,
      status: "支持 $…$、$$…$$、\\(…\\) 和 \\[…\\]",
    },
    {
      id: "slash-menu-polish",
      title: "斜杠菜单优化",
      detail: "压缩斜杠菜单行距，并强化选中状态。",
      defaultEnabled: true,
      status: "可用",
    },
  ];
  let settingsScanTimer = 0;
  const scheduleSettingsPanelInstall = () => {
    if (settingsScanTimer) return;
    settingsScanTimer = window.setTimeout(() => {
      settingsScanTimer = 0;
      installSettingsPanel();
    }, 100);
  };
  const settingsObserver = new MutationObserver(scheduleSettingsPanelInstall);
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
    if (!modal) return;
    const tabs = modal.querySelector(".codex-plus-tabs");
    const body = modal.querySelector(".codex-plus-modal-body");
    if (!tabs || !body) return;
    const currentTab = tabs.querySelector('[data-codex-plus-tab="bennettUi"]');
    const currentPanel = body.querySelector('[data-codex-plus-panel="bennettUi"]');
    if (
      modal.dataset.bennettUiSettingsLoadId === SCRIPT_LOAD_ID &&
      currentTab &&
      currentPanel
    ) {
      return;
    }
    modal.dataset.bennettUiSettingsVersion = VERSION;
    modal.dataset.bennettUiSettingsLoadId = SCRIPT_LOAD_ID;

    tabs.querySelectorAll('[data-codex-plus-tab="bennettUi"]').forEach((node) => node.remove());
    body.querySelectorAll('[data-codex-plus-panel="bennettUi"]').forEach((node) => node.remove());

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
      const historyLoad = target?.closest("[data-bennett-ui-history-load]");
      if (historyLoad) {
        event.preventDefault();
        event.stopPropagation();
        void loadHistoryFromSettings(panel);
        return;
      }
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
          <div class="codex-plus-row-title">Bennett UI Improvements ${escapeHtmlLocal(VERSION)}</div>
          <div class="codex-plus-row-description">项目侧栏、额度显示、Markdown 预览与原生会话查询上限设置。</div>
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
      <div class="codex-plus-row bennett-ui-history-row" data-bennett-ui-history-row="true">
        <div class="bennett-ui-history-copy">
          <div class="codex-plus-row-title">会话历史加载</div>
          <div class="codex-plus-row-description">仅提高 Codex 原生近期会话查询上限，不扫描、合并、补写或重新渲染会话。每次打开 Codex 后自动请求一次，也可手动重试。范围 ${HISTORY_TARGET_MIN}–${HISTORY_TARGET_MAX} 条。</div>
          <div class="bennett-ui-feature-status" data-bennett-ui-history-status="true">由 Codex 原生读取和渲染；启动后自动请求</div>
        </div>
        <div class="bennett-ui-history-controls">
          <input type="number" min="${HISTORY_TARGET_MIN}" max="${HISTORY_TARGET_MAX}" step="50" value="${readHistoryTarget()}" inputmode="numeric" aria-label="历史会话查询上限" data-bennett-ui-history-limit="true">
          <button type="button" class="bennett-ui-history-load" data-bennett-ui-history-load="true">重新加载历史</button>
        </div>
      </div>
    `;
  }

  function normalizeHistoryTarget(value, fallback = HISTORY_TARGET_DEFAULT) {
    const parsed = Number.parseInt(String(value ?? ""), 10);
    if (!Number.isFinite(parsed)) return fallback;
    return Math.max(HISTORY_TARGET_MIN, Math.min(HISTORY_TARGET_MAX, parsed));
  }

  function readHistoryTarget() {
    try {
      return normalizeHistoryTarget(window.localStorage.getItem(HISTORY_TARGET_STORAGE_KEY));
    } catch {
      return HISTORY_TARGET_DEFAULT;
    }
  }

  function writeHistoryTarget(value) {
    const normalized = normalizeHistoryTarget(value);
    try {
      window.localStorage.setItem(HISTORY_TARGET_STORAGE_KEY, String(normalized));
    } catch {
      // The loader can still use the value for this run when storage is unavailable.
    }
    return normalized;
  }

  async function loadHistoryFromSettings(panel) {
    const input = panel.querySelector("[data-bennett-ui-history-limit]");
    const button = panel.querySelector("[data-bennett-ui-history-load]");
    const status = panel.querySelector("[data-bennett-ui-history-status]");
    const limit = writeHistoryTarget(input?.value);
    if (input) input.value = String(limit);
    if (button) button.disabled = true;
    if (status) status.textContent = `正在请求 Codex 原生历史，上限 ${limit} 条…`;
    try {
      const loader = window.__bennettUiEmbeddedHistoryLoader || window.__codexListPagebuster;
      if (!loader || typeof loader.refresh !== "function") {
        throw new Error("内置会话加载器尚未就绪，请稍后重试");
      }
      loader.setLimit?.(limit);
      await loader.refresh(limit);
      if (status) {
        status.textContent = `已请求 Codex 原生历史，上限 ${limit} 条；侧栏由 Codex 自己渲染`;
      }
    } catch (error) {
      if (status) status.textContent = `加载失败：${error?.message || String(error)}`;
    } finally {
      if (button) button.disabled = false;
    }
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
      [data-codex-plus-panel="bennettUi"] {
        color: #f3f4f6 !important;
        color-scheme: dark;
      }
      [data-codex-plus-panel="bennettUi"] .codex-plus-row-title {
        color: #f3f4f6 !important;
      }
      [data-codex-plus-panel="bennettUi"] .codex-plus-row-description {
        color: #a1a1aa !important;
      }
      .bennett-ui-settings-note,
      .bennett-ui-feature-status {
        margin-top: 6px;
        color: #a1a1aa !important;
        font-size: 12px;
        line-height: 1.35;
      }
      .bennett-ui-feature-row[data-enabled="true"] .bennett-ui-feature-status {
        color: #d1d5db !important;
      }
      .bennett-ui-toggle[disabled] {
        cursor: not-allowed;
        opacity: 0.45;
      }
      .bennett-ui-toggle[data-enabled="true"] span {
        transform: translateX(14px);
      }
      .bennett-ui-history-row {
        align-items: center;
        gap: 18px;
      }
      .bennett-ui-history-copy {
        min-width: 0;
        flex: 1 1 auto;
      }
      .bennett-ui-history-controls {
        display: flex;
        flex: 0 0 auto;
        align-items: center;
        gap: 10px;
      }
      .bennett-ui-history-controls input {
        box-sizing: border-box;
        width: 130px;
        min-height: 34px;
        border: 1px solid var(--border-default, rgba(127, 127, 127, 0.45));
        border-radius: 8px;
        background: var(--background-primary, color-mix(in srgb, currentColor 6%, transparent));
        color: #f3f4f6;
        padding: 5px 10px;
      }
      .bennett-ui-history-load {
        min-height: 34px;
        border: 1px solid var(--border-default, rgba(127, 127, 127, 0.45));
        border-radius: 8px;
        background: var(--background-secondary, color-mix(in srgb, currentColor 9%, transparent));
        color: #f3f4f6;
        cursor: pointer;
        padding: 5px 12px;
      }
      .bennett-ui-history-load:hover:not(:disabled) {
        background: var(--background-tertiary, color-mix(in srgb, currentColor 15%, transparent));
      }
      .bennett-ui-history-load:disabled {
        cursor: wait;
        opacity: 0.55;
      }
      @media (max-width: 720px) {
        .bennett-ui-history-row,
        .bennett-ui-history-controls {
          align-items: stretch;
          flex-direction: column;
        }
        .bennett-ui-history-controls input {
          width: 100%;
        }
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
    scriptLoadId: SCRIPT_LOAD_ID,
    api,
    features,
    featureInfo,
    setFeature(id, enabled, reload = false) {
      setFeatureEnabled(id, enabled);
      if (reload) window.location.reload();
    },
    stop() {
      for (const timer of lifecycleTimers) window.clearTimeout(timer);
      lifecycleTimers.clear();
      const embeddedHistory = window.__bennettUiEmbeddedHistoryLoader;
      if (embeddedHistory && typeof embeddedHistory.stop === "function") {
        try {
          embeddedHistory.stop();
        } catch (error) {
          console.warn("[Bennett UI/BigPizza] history stop failed", error);
        }
      }
      if (window.__bennettUiEmbeddedHistoryLoader === embeddedHistory) {
        delete window.__bennettUiEmbeddedHistoryLoader;
      }
      if (window.__codexListPagebuster === embeddedHistory) {
        delete window.__codexListPagebuster;
      }
      settingsObserver.disconnect();
      if (settingsScanTimer) window.clearTimeout(settingsScanTimer);
      document.querySelectorAll('[data-codex-plus-tab="bennettUi"]').forEach((node) => node.remove());
      document.querySelectorAll('[data-codex-plus-panel="bennettUi"]').forEach((node) => node.remove());
      const settingsModal = document.querySelector(".codex-plus-modal-content");
      if (settingsModal?.dataset.bennettUiSettingsLoadId === SCRIPT_LOAD_ID) {
        delete settingsModal.dataset.bennettUiSettingsLoadId;
        delete settingsModal.dataset.bennettUiSettingsVersion;
      }
      document.getElementById("bennett-ui-settings-style")?.remove();
      if (typeof tweak.stop === "function") {
        tweak.stop.call(tweak);
      }
    },
  };

  reportLifecycle("script-loaded", {
    readyState: document.readyState,
    activeFeatures: Array.from(tweak._state?.features?.keys?.() || []),
  });
  scheduleLifecycle(() => {
    const usageBox = document.querySelector('[data-codexpp="usage-box"], [data-codexpp="usage-boxes"]');
    reportLifecycle("script-settled", {
      activeFeatures: Array.from(tweak._state?.features?.keys?.() || []),
      usageMounted: Boolean(usageBox),
      usageSlotMode: usageBox?.parentElement?.dataset?.codexppUsageSlot || "",
      asideCount: document.querySelectorAll("aside").length,
    });
  }, 1500);

  function createBigPizzaRendererApi() {
    const storagePrefix = "bennett-ui-improvements:";
    const blockedFeatureKeys = new Set([
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

$content = $prefix + $sourceText + $suffix + @"


/* BEGIN BENNETT EMBEDDED NATIVE HISTORY LOADER */
$nativeHistoryFeature
/* END BENNETT EMBEDDED NATIVE HISTORY LOADER */
"@
$content = [regex]::Replace($content, "`n{4,}(?=  const tweak = module\.exports;)", "`n`n")
if ([regex]::Matches($content, 'BEGIN BENNETT EMBEDDED NATIVE HISTORY LOADER').Count -ne 1) {
  throw "Embedded native history loader must occur exactly once"
}
if (-not $content.Contains('window.__bennettUiEmbeddedHistoryLoader = window[SCRIPT_KEY];')) {
  throw "Embedded native history loader export is missing"
}
$requiredReleaseMarkers = @(
  'const VERSION = "1.2.4";',
  'data-bennett-ui-history-load="true"',
  'scheduleScriptLoadHistoryRefresh();',
  'if ((await refreshAccountMode()) === "api" || disposed) return false;'
)
foreach ($marker in $requiredReleaseMarkers) {
  if (-not $content.Contains($marker)) {
    throw "Required release marker is missing: $marker"
  }
}
Set-Content -LiteralPath $outPath -Value $content -NoNewline -Encoding utf8
Write-Output $outPath
