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

In practical terms, this is the kind of setup CCProxy is meant to enable: using one provider's GPT-class model for an Opus-like route, GLM for a Sonnet-like route, and MiniMax for a Haiku-like route, all within the same local workflow.

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

### Option 1: Install from GitHub Releases

1. Download the latest `CCProxy.app.zip` from the project's GitHub Releases page.
2. Extract the archive.
3. Move `CCProxy.app` to `/Applications`.
4. Launch the app.

**macOS Gatekeeper notice**

If macOS blocks the app on first launch with a message like "cannot be opened because it is from an unidentified developer":

1. Open **System Settings** → **Privacy & Security**.
2. Scroll down to the **Security** section.
3. Find the message about CCProxy being blocked and click **Open Anyway**.
4. In the confirmation dialog, click **Open**.

After that, the app is saved as an exception and you should not need to repeat this for the same app.

### Option 2: Build from source

Build the app bundle:

```bash
make release
```

Output:
- `CCProxy.app`

Install to Applications:

```bash
make install
```

Run locally:

```bash
make run
```

### Updates

You can manually check for updates from the app menu with `Check for Updates...`.

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
    │   ├── ExternalModelCatalog.swift
    │   ├── TunnelManager.swift
    │   ├── IconCatalog.swift
    │   ├── NotificationNames.swift
    │   └── Resources/
    │       └── model-catalog-snapshot.json
    └── Tests/
        └── CCProxyTests/
```

## Key components

- `src/Sources/AppDelegate.swift` — app lifecycle, menu bar, settings window, update integration
- `src/Sources/ServerManager.swift` — bundled backend lifecycle, config generation, auth-related state
- `src/Sources/ThinkingProxy.swift` — local proxy listener and request forwarding
- `src/Sources/SettingsView.swift` — SwiftUI settings and account management UI
- `src/Sources/AuthStatus.swift` — local auth/account state tracking
- `src/Sources/ExternalModelCatalog.swift` — external model catalog fetching, caching, and provider mapping

## Local proxy authentication

CCProxy can enforce a shared secret for local proxy requests.

The local proxy base URL is:

```text
http://localhost:8317
```

To see which model IDs are currently exposed by the local proxy, query:

```bash
curl http://localhost:8317/v1/models
```

Use the returned model IDs when configuring Claude Code.

Example `settings.json`:

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "local-test",
    "ANTHROPIC_BASE_URL": "http://localhost:8317",
    "ANTHROPIC_MODEL": "gpt-5.4",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "MiniMax-M2.7",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5.1",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "gpt-5.4"
  }
}
```

- `ANTHROPIC_AUTH_TOKEN`: local shared secret if you enabled authentication in the app
- `ANTHROPIC_BASE_URL`: local proxy base URL
- `ANTHROPIC_MODEL`: default primary model
- `ANTHROPIC_DEFAULT_HAIKU_MODEL`: model to use for Haiku-like routing
- `ANTHROPIC_DEFAULT_SONNET_MODEL`: model to use for Sonnet-like routing
- `ANTHROPIC_DEFAULT_OPUS_MODEL`: model to use for Opus-like routing

Use the exact model names returned by `http://localhost:8317/v1/models`.
The example values above are only examples and may differ from your local setup.

When a secret key is configured in the app, `ANTHROPIC_AUTH_TOKEN` must match that same secret.
Local proxy requests are expected to provide:

```http
Authorization: Bearer <secret-key>
```

## OpenCode Go provider

CCProxy includes **OpenCode Go** as a hosted provider. It is configured with an API key in the app's settings — not a Go SDK or separate binary.

- Model IDs follow the pattern `opencode-go/<model-id>` in `/v1/models` responses (e.g. `opencode-go/glm-5.1`).
- Internal generated config uses unprefixed model slugs (e.g. `glm-5.1`) with `prefix: opencode-go` and `force-model-prefix: true` to avoid double-prefixing.
- Routing uses `https://opencode.ai/zen/go/v1/messages` through the existing Anthropic-compatible config path only.
- `/chat/completions` and `openai-compatibility` routing are not added in this change.

## External model catalog

CCProxy maintains an external model catalog that drives provider model lists at runtime.

### Catalog sources

- **Primary**: CLIProxyAPI `models.json` and `codex_client_models.json`
- **Secondary**: [models.dev](https://models.dev/api.json)

### Cache behavior

- Runtime cache path: `~/.cli-proxy-api/model-catalog-cache.json`
- Cache TTL: **6 hours** — a fresh cache is reused for up to 6 hours before an on-demand synchronous refresh is attempted
- Failed-refresh retry throttle: **15 minutes** — if a refresh fails, no further external fetch attempts are made for 15 minutes
- On-demand refresh only — catalog data is served from cache/snapshot; when the TTL expires, the next request triggers a synchronous refresh before responding (not a background refresh)

### Fallback order

1. **Fresh runtime cache** (within 6-hour TTL) — served directly
2. **Stale runtime cache** — served if a refresh attempt fails or the retry throttle is active
3. **Bundled snapshot** — a build-time snapshot (`model-catalog-snapshot.json`) baked into the app bundle at `CCProxy.app/Contents/Resources/model-catalog-snapshot.json`
4. **Unavailable** — only if no valid cache or snapshot exists

When no valid runtime cache exists but the bundled snapshot is valid, a failed refresh records failure metadata and repeated `/v1/models` requests inside the 15-minute retry window serve the bundled snapshot without re-fetching external sources.

### Connected provider filtering

The `/v1/models` endpoint is filtered to **connected providers only**.

A provider is considered connected when:
- **Claude / Codex**: enabled with valid, non-disabled, non-expired OAuth auth
- **Z.AI / MiniMax / Kimi / OpenCode Go**: enabled with valid, non-disabled API-key credentials

Providers that are disabled, have no auth, have expired OAuth, or have empty/missing API keys are excluded from `/v1/models` responses and from generated config model lists.

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
