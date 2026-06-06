# OpenCode Go Logo And v0.3.2 Release Evidence

## Internal Evidence

- `src/Sources/SettingsView.swift:437-451` — the `ServiceRow` for `.opencodeGo` currently passes `iconName: ""`, explaining the missing logo.
- `src/Sources/SettingsView.swift:355-452` — other provider rows use concrete icon filenames such as `icon-claude.png`, `icon-zai.png`, `icon-minimax.png`, and `icon-kimi.png`.
- `src/Sources/IconCatalog.swift:12-44` — current icon loading uses `image(named:resizedTo:template:)`, builds a file path under `Bundle.main.resourcePath`, and loads with `NSImage(contentsOfFile:)`; no data URI path was found. This supports converting the supplied SVG to a PNG resource rather than adding runtime SVG data URI support.
- `src/Sources/AuthStatus.swift:3-21` — `ServiceType` includes `case opencodeGo = "opencode-go"` and display names, but no logo/icon field.
- `src/Sources/AppDelegate.swift:76-87` — preload list only includes active/inactive/codex/claude icons; per-provider preload is not required for all providers.
- `src/Sources/Resources/` — explorer found icon PNG resources for existing providers but no `icon-opencode-go.*` resource and no SVG resources.
- `src/Tests/CCProxyTests/OpenCodeGoProviderTests.swift:31-325` — opencode-go tests cover credentials/config behavior and do not cover icons.
- Grep across `src/Tests/CCProxyTests/` for `iconName|ServiceRow|IconCatalog|provider.*icon` returned zero matches, so icon coverage needs to be added if behavior changes.
- `appcast.xml:1-18` — current released appcast item is `Version 0.3.1`, `sparkle:shortVersionString` `0.3.1`, `sparkle:version` `14`, URL under `/v0.3.1/`, and length `16083579`.
- `src/Info.plist:17-22` — committed baseline version/build remains `0.1.0` / `1` and is expected to be overwritten by the build script.
- `create-app-bundle.sh:104-123` — app version and build are injected from `APP_VERSION` and `APP_BUILD_NUMBER`, and the Sparkle feed URL is set during bundle creation.
- Prior EasyCode release workflow evidence confirms `v0.3.1` build `14` was published and cleaned up; this supports `v0.3.2` build `15` as the next patch release target for this logo-only change.
- Root checkout has a known pre-existing dirty `.gitignore`; it must not be touched or staged for this work.

## External Evidence

- No external evidence was gathered during the spec stage. The supplied SVG data URI is user-provided input, and repository evidence is sufficient to define the revised PNG-resource scope.
- External or platform documentation may be needed during planning/execution only if repository tooling for converting the supplied SVG into a PNG is unclear.

## Checked Scope

- Provider UI row definitions in `SettingsView.swift`.
- Icon loading implementation in `IconCatalog.swift`.
- Provider enum/display names in `AuthStatus.swift`.
- Menu/icon preload behavior in `AppDelegate.swift`.
- Existing provider icon resources under `src/Sources/Resources/`.
- Existing opencode-go tests and icon-related test coverage under `src/Tests/CCProxyTests/`.
- Release metadata and version/build conventions in `appcast.xml`, `src/Info.plist`, `create-app-bundle.sh`, and prior EasyCode release artifacts.

## Unchecked Scope

- `src/Package.swift` and `src/Package.resolved` were not inspected during spec evidence collection; planning should confirm resource processing/test dependency implications if any.
- `Makefile` target bodies were not re-read during this spec stage; planning should verify the release/build commands from repository targets.
- Any possible `appcast-x86_64.xml` file was not confirmed; planning should check before deciding release metadata scope.
- Specific local SVG-to-PNG conversion tooling was not researched during spec. Planning/execution should choose a repository-safe/local conversion method and verify the resulting PNG loads.

## Unresolved Uncertainty

- Whether local conversion tooling can convert the supplied URL-encoded SVG data URI into a PNG without altering the intended logo. If conversion is not straightforward, the workflow must stop for a revised user-approved spec rather than silently substituting a different image.
- Whether the focused regression test should inspect `SettingsView` source text, expose a small provider-icon mapping helper, or load the resource directly. Planning should choose the smallest tested design that proves `opencode-go` no longer has an empty icon.
