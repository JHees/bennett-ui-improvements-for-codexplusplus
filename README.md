# Bennett UI Improvements for BigPizzaV3 Codex++

This repository contains a BigPizzaV3 Codex++ user-script migration of
`b-nnett/codex-plusplus-bennett-ui`.

The UI implementation is not original work by this repository owner. The
original tweak was written by Bennett for the b-nnett Codex++ runtime. This
repository adapts the renderer-side parts of that tweak to the BigPizzaV3
Codex++ user-script environment.

## Install

Copy the user script into the Codex++ user script directory:

```text
%APPDATA%\Codex++\user_scripts\bennett-ui-improvements.js
```

Then reload user scripts from Codex++.

The ready-to-install file is:

```text
scripts/bennett-ui-improvements.js
```

## Features

- Hide upgrade prompts.
- Show a compact 5-hour / weekly quota control near the sidebar controls.
- Detect API mode and show `API` instead of requesting official account usage.
- Keep the quota control out of the Codex++ settings sidebar.
- Square the sidebar/main-surface corner.
- Add settings search.
- Match settings sidebar width to the main sidebar.
- Render sidebar actions in a compact grid.
- Add project row backgrounds.
- Polish the slash menu.

Some original b-nnett features depended on main-process APIs or Electron IPC
that BigPizzaV3 user scripts do not expose. Those features are disabled or
degraded intentionally.

## API Mode Behavior

In official ChatGPT account mode, the usage control reads Codex usage signals
and displays 5-hour / weekly remaining quota.

In pure API or mixed API mode, the control displays `API` and does not call
`/wham/usage` or parse stale quota UI.

## Build

The migration can be regenerated from the vendored source snapshot:

```powershell
.\tools\build-migrated-script.ps1
```

The build script reads:

```text
old-bennett-ui/index.js
```

and writes:

```text
scripts/bennett-ui-improvements.js
```

## Source And Attribution

- Original project: `https://github.com/b-nnett/codex-plusplus-bennett-ui`
- Original author: Bennett
- Original license: MIT
- Migration target: `https://github.com/BigPizzaV3/CodexPlusPlus`
- Script market target: `https://github.com/BigPizzaV3/CodexPlusPlusScriptMarket`

See `NOTICE.md` for attribution details.

## License

The original project is MIT licensed. The migrated wrapper and compatibility
changes are also provided under the MIT license. See `LICENSE`.
