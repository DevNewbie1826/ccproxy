# CCProxy

[한국어 README](./README.ko.md)

> [!IMPORTANT]
> **CCProxy is a small derivative of [automazeio/vibeproxy](https://github.com/automazeio/vibeproxy).**
> This project was created by taking `vibeproxy` as the base and making only a small set of modifications for this repository's needs. That origin is intentional and should be understood clearly.

CCProxy is a native macOS menu bar app that runs a local proxy for AI coding tools and manages authentication from a desktop UI.

It is designed for a simple local workflow:
- run a local proxy on `http://localhost:8317`
- manage the bundled backend from the menu bar
- configure provider authentication from the app
- optionally protect local proxy access with a shared secret

## Why this exists

This repository exists as a lightly modified fork-style derivative of [`automazeio/vibeproxy`](https://github.com/automazeio/vibeproxy).

The goal here is **not** to claim a ground-up rewrite. The goal is to keep the original approach, make a few repo-specific adjustments, and use it as the base for this project.

## What makes CCProxy different

CCProxy is about **opening up the provider layer**.

It is based on `automazeio/vibeproxy`, but extends that base by making it possible to connect **additional provider APIs such as Kimi and MiniMax** and by leaning into a **local proxy workflow** for Claude Code.

That means you are not limited to a single provider's model lineup. With the local proxy as the routing layer, CCProxy is aimed at a workflow where you can choose and combine models from different providers depending on the task.

The goal is simple:
**don’t be locked into one provider when you can route across several.**

## Origin / Attribution

This project should be understood as:
- based on `automazeio/vibeproxy`
- only lightly modified from that base
- still conceptually aligned with the original app structure and workflow

Please check the original project here:
- https://github.com/automazeio/vibeproxy

This project also continues to rely on the upstream backend/proxy approach used by the original project.

## Features

- Native macOS menu bar app
- SwiftUI settings window
- Start/stop bundled backend from the UI
- Local proxy endpoint for AI tooling
- Provider/account management from the app
- Launch at login support
- Sparkle-based app update support
- Optional shared secret check for local proxy requests
- Management dashboard access from the app menu

## Screenshots

### Menu bar
![CCProxy menu bar dropdown](./docs/images/menubar-dropdown.png)

### Settings window
![CCProxy settings window](./docs/images/settings-window.png)

## Requirements

- macOS 13.0 or later
- Xcode / Swift toolchain for local builds

## Installation

### Option 1: Build the app bundle

```bash
make release
```

Output:
- `CCProxy.app`

### Option 2: Install to Applications

```bash
make install
```

### Option 3: Run locally

```bash
make run
```

## Development

### Build

```bash
make build
```

### Test

```bash
make test
```

### Clean

```bash
make clean
```

## Project structure

```text
ccproxy/
├── Makefile
├── create-app-bundle.sh
├── CCProxy.app/                  # built artifact
└── src/
    ├── Package.swift
    ├── Info.plist
    ├── Sources/
    │   ├── main.swift
    │   ├── AppDelegate.swift
    │   ├── ServerManager.swift
    │   ├── SettingsView.swift
    │   ├── ThinkingProxy.swift
    │   ├── AuthStatus.swift
    │   ├── TunnelManager.swift
    │   ├── IconCatalog.swift
    │   ├── NotificationNames.swift
    │   └── Resources/
    └── Tests/
        └── CCProxyTests/
```

## Key components

- `src/Sources/AppDelegate.swift` — app lifecycle, menu bar, settings window, update integration
- `src/Sources/ServerManager.swift` — bundled backend lifecycle, config generation, auth-related state
- `src/Sources/ThinkingProxy.swift` — local proxy listener and request forwarding
- `src/Sources/SettingsView.swift` — SwiftUI settings and account management UI
- `src/Sources/AuthStatus.swift` — local auth/account state tracking

## Local proxy authentication

CCProxy can enforce a shared secret for local proxy requests.

Typical local configuration uses:

```json
{
  "ANTHROPIC_AUTH_TOKEN": "your-secret",
  "ANTHROPIC_BASE_URL": "http://localhost:8317"
}
```

When a secret key is configured in the app, local proxy requests are expected to provide:

```http
Authorization: Bearer <secret-key>
```

## Notes

- The backend management port and the local proxy port are different.
- This repository includes project-specific adjustments and should not be treated as the canonical upstream.
- If you want the original baseline project, use `automazeio/vibeproxy` directly.

## Credits

- Original base project: [automazeio/vibeproxy](https://github.com/automazeio/vibeproxy)
- Upstream proxy/backend foundation: the same upstream approach used by the original project
- Sparkle: https://sparkle-project.org/

## License

See `LICENSE` in this repository.
