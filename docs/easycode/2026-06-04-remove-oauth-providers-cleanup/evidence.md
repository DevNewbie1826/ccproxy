# Remove OAuth Providers And Cleanup Evidence

## Internal Evidence

- `src/Sources/AuthStatus.swift:3-13` defines 9 `ServiceType` providers: Claude, Codex, Copilot, Gemini, Qwen, Antigravity, Z.AI, MiniMax, and Kimi.
- `src/Sources/AuthStatus.swift:14-26` maps display names for the same provider set.
- `src/Sources/ServerManager.swift:117-125` defines `oauthProviderKeys` for 6 OAuth providers: Claude, Codex, Gemini, GitHub Copilot, Antigravity, and Qwen.
- `src/Sources/ServerManager.swift:338-374` dispatches OAuth auth commands for Claude, Codex, Copilot, Gemini, Qwen, and Antigravity.
- `src/Sources/ServerManager.swift:887-894` defines `AuthCommand` cases for those 6 OAuth flows and no API-key flows.
- `src/Sources/ServerManager.swift:549-694` contains three dedicated API-key save functions for Z.AI, MiniMax, and Kimi.
- `src/Sources/ServerManager.swift:710-743` scans credential files for `zai-*.json`, `minimax-*.json`, and `kimi-*.json`.
- `src/Sources/ServerManager.swift:801-839` generates Claude-compatible API-key provider config for Z.AI, MiniMax, and Kimi.
- `src/Sources/SettingsView.swift:354-500` renders provider service rows. The rows for Z.AI, MiniMax, and Kimi open API-key prompts, while the other rows use OAuth connect flows.
- `src/Sources/SettingsView.swift:516-541` contains the Qwen email prompt sheet.
- `src/Sources/SettingsView.swift:542-619` contains three similar API-key input sheets for Z.AI, MiniMax, and Kimi.
- `src/Sources/SettingsView.swift:677-746` contains provider-specific connect and success-message switches.
- `src/Sources/SettingsView.swift:748-769` contains Qwen-specific auth startup logic.
- `src/Sources/ThinkingProxy.swift:284,355-358,368-377,446` contains `gemini-claude-*` model handling tied to removed Gemini/Antigravity behavior.
- `src/Sources/AppDelegate.swift:71-77` preloads `icon-gemini.png`.
- `src/Sources/Resources/` contains removed-provider icons: `icon-antigravity.png`, `icon-copilot.png`, `icon-gemini.png`, and `icon-qwen.png`.
- `src/Sources/Resources/config.yaml:36-41` contains OAuth provider comments mentioning Gemini tokens and `generative-language-api-key: []`.
- Runtime verification in a temporary directory showed bundled `cli-proxy-api` version `7.1.43` starts successfully both with and without `generative-language-api-key: []` present. The no-key case stayed running after 2.5 seconds and logged `API server started successfully` with no stderr.
- `src/Tests/CCProxyTests/AuthStatusTests.swift:5-7` only asserts Kimi is present, so it is too weak for the new exact provider set.
- `src/Tests/CCProxyTests/ServerManagerConfigTests.swift:119-138` exercises disabled OAuth provider config for Claude and Codex, but does not cover the full removed-provider cleanup.
- `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift` has no active assertions for Gemini/Copilot/Qwen/Antigravity per explorer grep evidence.
- `README.md:27` mentions kept providers Kimi and MiniMax and does not require removed-provider edits based on checked scope.
- `docs/supercode/20260506-cliproxy-refresh-a1b2/stability-backport-decisions.md:452-454` contains historical references to removed-provider CLI flags; these are historical docs, not active product code.

## External Evidence

No external library or API evidence was needed for the spec. The requested work is based on repository-owned provider lists, UI, config generation, and tests.

## Checked Scope

- Repository provider inventory and auth-mode split were checked by an EasyCode `explorer` agent.
- Provider removal impact was checked by an EasyCode `explorer` agent across Swift sources, resources, tests, docs, package metadata, appcast, and relevant config files.
- Provider maintainability/slop opportunities were checked by an EasyCode `explorer` agent across provider-related Swift files, resources, tests, and README.
- CodeGraph indexing was approved by the user and completed successfully after confirming `.codegraph/` was already present in `.gitignore`.
- The `generative-language-api-key: []` uncertainty was checked by an EasyCode `explorer` agent through source/config analysis, then resolved with a local temporary runtime test outside the repository.
- Runtime test command policy: generated temporary configs under `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/`, pointed `auth-dir` to a temporary empty directory, launched the bundled binary with `-config`, waited 2.5 seconds, then terminated it. No repository files were edited by the runtime test.
- Checked key files include:
  - `src/Sources/AuthStatus.swift`
  - `src/Sources/ServerManager.swift`
  - `src/Sources/SettingsView.swift`
  - `src/Sources/ThinkingProxy.swift` provider-related sections
  - `src/Sources/AppDelegate.swift`
  - `src/Sources/IconCatalog.swift`
  - `src/Sources/Resources/config.yaml`
  - `src/Sources/Resources/` icon inventory
  - `src/Tests/CCProxyTests/AuthStatusTests.swift`
  - `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`
  - `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`
  - `src/Tests/CCProxyTests/ServerManagerProcessTests.swift`
  - `src/Tests/CCProxyTests/Fixtures/config.yaml`
  - `README.md`
  - `appcast.xml`
  - `src/Package.swift`, `src/Info.plist`, and other provider-agnostic project files for absence of provider references.

## Unchecked Scope

- The bundled `src/Sources/Resources/cli-proxy-api` binary is opaque and was not inspected internally.
- Full unrelated `ThinkingProxy.swift` behavior outside removed-provider-specific branches was not audited for unrelated refactors.
- Historical docs under `docs/supercode` were not treated as active product requirements.
- Build/release artifacts outside tracked active source/resource/test paths were not audited for unrelated cleanup.

## Unresolved Uncertainty

- None blocking the spec.
- Existing stale UserDefaults entries for removed providers may exist, but the user explicitly chose not to migrate or clean them in this work.
- Historical documentation may retain removed-provider names by design; active source/test/resource cleanup should not be blocked by historical references unless they are current user-facing documentation.
