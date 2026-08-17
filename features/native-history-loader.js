/*
 * Bennett UI native history limit helper.
 *
 * Its only responsibility is to ask Codex to refresh its own recent
 * conversation list with a larger limit. Codex remains responsible for
 * provider selection, storage, indexing, project grouping, pagination,
 * pin/archive state, and sidebar rendering.
 */
(() => {
  const DEFAULT_TARGET = 500;
  const MIN_TARGET = 1;
  const MAX_TARGET = 2000;
  const SCRIPT_KEY = "__codexListPagebuster";
  const TARGET_STORAGE_KEY = "__codexListPagebusterTarget";
  const SCRIPT_LOAD_REFRESH_DELAYS_MS = [0, 1200, 3000, 6000];
  const SIGNALS_MODULE_RE = /(?:\.\/)?(?:assets\/)?(?:app-server-manager-signals|app-initial)-[A-Za-z0-9_-]+\.js/g;
  const SIGNALS_MODULE_FALLBACKS = [
    "./assets/app-server-manager-signals-Csopz8aM.js",
    "./assets/app-server-manager-signals-zAr_ejg8.js"
  ];

  if (window[SCRIPT_KEY]?.stop) {
    window[SCRIPT_KEY].stop();
  }

  const state = {
    stopped: false,
    internalActionModulePromise: null,
    startupTimers: new Set(),
    startupAttempts: 0,
    startupCompleted: false,
    refreshInFlight: null,
    refreshAttempts: 0,
    lastRequestedLimit: 0,
    lastRefreshAt: 0,
    lastRefreshError: ""
  };

  function normalizeTarget(value, fallback = DEFAULT_TARGET) {
    const parsed = Number.parseInt(String(value ?? ""), 10);
    if (!Number.isFinite(parsed)) return fallback;
    return Math.max(MIN_TARGET, Math.min(MAX_TARGET, parsed));
  }

  function readTarget() {
    try {
      return normalizeTarget(localStorage.getItem(TARGET_STORAGE_KEY));
    } catch {
      return DEFAULT_TARGET;
    }
  }

  function writeTarget(value) {
    const target = normalizeTarget(value);
    try {
      localStorage.setItem(TARGET_STORAGE_KEY, String(target));
    } catch {
      // The value can still be used for the current refresh.
    }
    return target;
  }

  function log(...args) {
    try {
      console.info("[Bennett history limit]", ...args);
    } catch {}
  }

  function isLocalScriptSource(src) {
    const value = String(src || "").trim();
    if (!value) return false;
    if (/^app:/i.test(value)) return true;
    if (/^[a-z][a-z0-9+.-]*:/i.test(value)) return false;
    return !/^(?:\/\/|\\\\)/.test(value);
  }

  function normalizeSignalsModulePath(path) {
    const value = String(path || "").trim();
    if (!isLocalScriptSource(value)) return "";
    if (/^app:/i.test(value)) return value;
    const relative = value.replace(/^(?:\.\/|\/)/, "");
    if (relative.startsWith("assets/")) return `./${relative}`;
    if (/^(?:app-server-manager-signals|app-initial)-[A-Za-z0-9_-]+\.js$/.test(relative)) {
      return `./assets/${relative}`;
    }
    return "";
  }

  function collectModuleNames(text, candidates) {
    if (typeof text !== "string" || !text) return;
    for (const match of text.matchAll(SIGNALS_MODULE_RE)) {
      const candidate = normalizeSignalsModulePath(match[0]);
      if (candidate) candidates.add(candidate);
    }
  }

  function collectInternalActionModuleCandidates() {
    const candidates = new Set();
    const add = (value) => {
      if (!isLocalScriptSource(value)) return;
      const candidate = normalizeSignalsModulePath(value);
      if (candidate) candidates.add(candidate);
    };

    for (const script of document.querySelectorAll("script[src]")) {
      const src = script.getAttribute("src") || "";
      if (!isLocalScriptSource(src)) continue;
      add(src);
      collectModuleNames(src, candidates);
    }

    try {
      for (const entry of performance.getEntriesByType("resource")) {
        const name = String(entry.name || "");
        if (!isLocalScriptSource(name)) continue;
        if (/(?:app-server-manager-signals|app-initial)-/.test(name)) add(name);
        collectModuleNames(name, candidates);
      }
    } catch {}

    return Array.from(candidates);
  }

  async function discoverInternalActionModuleCandidates() {
    const candidates = new Set(collectInternalActionModuleCandidates());

    // Codex loads a tiny hashed entry module whose source names the current
    // app-initial module. Read only that local app:// entry; do not crawl or
    // fetch conversation resources.
    for (const script of document.querySelectorAll("script[src]")) {
      const src = script.getAttribute("src") || "";
      if (!isLocalScriptSource(src)) continue;
      try {
        const response = await fetch(src);
        if (response.ok) collectModuleNames(await response.text(), candidates);
      } catch {}
    }

    for (const fallback of SIGNALS_MODULE_FALLBACKS) candidates.add(fallback);
    return Array.from(candidates);
  }

  function findInternalRequestHelper(mod) {
    const preferred = ["oht", "ts", "It", "ln"];
    const keys = [...preferred, ...Object.keys(mod || {})];
    const checked = new Set();

    for (const key of keys) {
      if (checked.has(key)) continue;
      checked.add(key);
      const value = mod?.[key];
      if (typeof value !== "function" || isClassConstructor(value)) continue;
      try {
        if (/sendRequest\s*\(/.test(Function.prototype.toString.call(value))) {
          return value.bind(mod);
        }
      } catch {}
    }
    return null;
  }

  function isClassConstructor(value) {
    try {
      return /^\s*class\s/.test(Function.prototype.toString.call(value));
    } catch {
      return false;
    }
  }

  async function loadInternalActionModule() {
    if (!state.internalActionModulePromise) {
      state.internalActionModulePromise = (async () => {
        let lastError = null;
        for (const candidate of await discoverInternalActionModuleCandidates()) {
          try {
            const mod = await import(candidate);
            const helper = findInternalRequestHelper(mod);
            if (helper) return helper;
          } catch (error) {
            lastError = error;
          }
        }
        throw lastError || new Error("未找到 Codex 原生历史刷新接口");
      })().catch((error) => {
        state.internalActionModulePromise = null;
        throw error;
      });
    }
    return state.internalActionModulePromise;
  }

  async function callInternalAction(type, payload) {
    const sendRequest = await loadInternalActionModule();
    return sendRequest(type, payload);
  }

  async function refresh(limit = readTarget()) {
    const target = writeTarget(limit);
    if (state.refreshInFlight && state.lastRequestedLimit === target) {
      return state.refreshInFlight;
    }

    state.lastRequestedLimit = target;
    state.refreshAttempts += 1;
    state.lastRefreshError = "";

    const request = callInternalAction("refresh-recent-conversations-for-host", {
      hostId: "local",
      mode: "expanded",
      sortKey: "updated_at",
      limit: target,
      pageSize: target,
      page_size: target
    }).then(() => {
      state.lastRefreshAt = Date.now();
      log(`requested up to ${target} native conversations`);
      return target;
    }).catch((error) => {
      state.lastRefreshError = error?.message || String(error);
      throw error;
    }).finally(() => {
      if (state.refreshInFlight === request) state.refreshInFlight = null;
    });

    state.refreshInFlight = request;
    return request;
  }

  function stop() {
    state.stopped = true;
    for (const timer of state.startupTimers) window.clearTimeout(timer);
    state.startupTimers.clear();
  }

  function scheduleScriptLoadHistoryRefresh() {
    SCRIPT_LOAD_REFRESH_DELAYS_MS.forEach((delay) => {
      const timer = window.setTimeout(async () => {
        state.startupTimers.delete(timer);
        if (state.stopped || state.startupCompleted) return;
        state.startupAttempts += 1;
        try {
          await refresh(readTarget());
          state.startupCompleted = true;
          for (const pending of state.startupTimers) window.clearTimeout(pending);
          state.startupTimers.clear();
        } catch (error) {
          log("startup refresh failed", error?.message || String(error));
        }
      }, delay);
      state.startupTimers.add(timer);
    });
  }

  window[SCRIPT_KEY] = {
    embeddedBy: "bennett-ui-improvements",
    refresh,
    getLimit: readTarget,
    setLimit: writeTarget,
    stop,
    status: () => ({
      configuredLimit: readTarget(),
      lastRequestedLimit: state.lastRequestedLimit,
      refreshAttempts: state.refreshAttempts,
      lastRefreshAt: state.lastRefreshAt,
      lastRefreshError: state.lastRefreshError,
      startupAttempts: state.startupAttempts,
      startupCompleted: state.startupCompleted,
      renderer: "codex-native",
      operation: "refresh-recent-conversations-for-host",
      sessionQueries: false,
      sessionReads: false,
      sessionWrites: false,
      providerMutation: false,
      summaryHydration: false,
      sidebarMutation: false,
      projectExpansion: false,
      href: location.href
    })
  };

  window.__bennettUiEmbeddedHistoryLoader = window[SCRIPT_KEY];
  scheduleScriptLoadHistoryRefresh();
})();
