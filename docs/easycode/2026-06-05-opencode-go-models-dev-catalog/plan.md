# OpenCode Go Provider And External Model Catalog Implementation Plan

> **For agentic workers:** Each task is dispatched to the `executor` agent. Follow the EasyCode `execute` stage: per-task TDD cycle, `code-spec-reviewer` and `code-quality-reviewer` review gates, and `completion-verifier` for final evidence. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add OpenCode Go as a hosted Anthropic-compatible provider and replace Swift runtime hardcoded model-list catalog behavior with a cached external catalog plus bundled generated snapshot.

**Architecture:** CCProxy remains a Swift Package macOS app with `ServerManager` generating hosted-provider config and `ThinkingProxy` handling local `/v1/models` responses. A new Swift catalog component parses CLIProxyAPI registry JSON first and models.dev second, stores validated snapshots under the app data path with a six-hour TTL, and renders OpenAI-style model-list responses for connected providers only. OpenCode Go uses only the existing `claude-api-key` compatible config path to `https://opencode.ai/zen/go/v1/messages`; `/chat/completions` routing and `openai-compatibility` config are outside this plan.

**Tech Stack:** Swift 5.9, Swift Package Manager, XCTest, Foundation `URLSession`/`JSONSerialization`/`Codable`, SwiftUI, Makefile targets `make backend-version`, `make test`, `make build`, `create-app-bundle.sh`, and a Swift snapshot-generation script.

## Approved Inputs And Baseline

- Work ID: `2026-06-05-opencode-go-models-dev-catalog`
- Approved spec: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-opencode-go-models-dev-catalog/docs/easycode/2026-06-05-opencode-go-models-dev-catalog/spec.md`
- Approved evidence: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-opencode-go-models-dev-catalog/docs/easycode/2026-06-05-opencode-go-models-dev-catalog/evidence.md`
- Worktree path: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-opencode-go-models-dev-catalog`
- Branch: `work/2026-06-05-opencode-go-models-dev-catalog`
- Spec reviewer: PASS after correction
- Spec user approval: unattended approval is active based on the user's explicit target to proceed through PR creation, PR merge, local base-branch update, EasyCode worktree cleanup, and feature-branch cleanup; app release publication is excluded after the latest clarification.
- Worktree baseline: ready
- Baseline results:
  - `make backend-version` PASS: `CLIProxyAPI Version: 7.1.44, Commit: fd309448, BuiltAt: 2026-06-03T17:06:35Z`
  - `make test` PASS: `98 tests, 1 skipped, 0 failures`
  - `make build` PASS: built `src/.build/debug/CCProxy`
- Degraded-baseline caveat: none.
- Active finish target: create PR, merge PR, update local base branch, remove EasyCode worktree, delete feature branch. Do not publish an app release.

## Current Execute State Reconciliation

- Task 1 implemented and passed `code-spec-reviewer` PASS and `code-quality-reviewer` PASS after gating fixes.
- Task 2 implemented and passed `code-spec-reviewer` PASS and `code-quality-reviewer` PASS after cache/determinism fixes.
- Task 3 partially implemented but failed spec/quality review due `ServerManager.shared` singleton divergence and live-network/default path concerns.
- Latest `plan-checker` result before this revision: PASS.
- Latest `plan-challenger` result before this revision: FAIL due ambiguous resume path and `ServerManager.shared` guard omission.
- Active continuation path: Tasks 1 and 2 are complete and review-passed. Do not rerun their RED/GREEN implementation cycles; rerun only their focused/full verification commands as regression checks when Task 3, Task 4, Task 5, or final completion verification requires them.
- Execution must resume at Task 3 remediation, not Task 1 or Task 2. Complete Task 3 RED/GREEN remediation and its source guards first, then proceed in order to Task 4 snapshot work and Task 5 final config/docs work.
- Before any further catalog wiring, snapshot work, docs work, or Task 4/5 work, delete `ServerManager.shared` unless a non-production test-only justification is explicitly reviewed and accepted by both `code-spec-reviewer` and `code-quality-reviewer`. The default expectation is deletion. Also remove or replace any separately constructed production `ServerManager()` path used for `/v1/models` catalog filtering, and make the AppDelegate-owned manager the only production state source.
- Keep approved scope unchanged: do not add app release publication, `/chat/completions` routing, `openai-compatibility` config, Go SDK integration, or direct-client bypass of CCProxy.

## Execute Gate Before Implementation

- [ ] Stop before any implementation edit until `docs/easycode/2026-06-05-opencode-go-models-dev-catalog/plan.md` is current and reviewed.
- [ ] `plan-checker` must return PASS for this exact plan artifact.
- [ ] `plan-challenger` must return PASS for this exact plan artifact.
- [ ] Because unattended completion is active, implementation may begin only after the plan approval gate is satisfied by the user/unattended workflow after both plan reviewers PASS.
- [ ] If either reviewer changes scope or rejects a task sequence, revise only this plan artifact and rerun both plan reviewers before execute begins.

## Repository Evidence Used For Planning

- `Makefile:9-12,46-49,81-89` defines the supported verification commands: `make build`, `make test`, and `make backend-version`.
- `src/Package.swift:1-36` confirms a Swift Package executable target, copied resources under `src/Sources/Resources`, and XCTest target layout.
- `src/Sources/AuthStatus.swift:3-19` defines provider identity through `ServiceType`.
- `src/Sources/ServerManager.swift:465-656` contains API-key credential storage, hosted provider config generation, and the existing `claude-api-key` compatible provider path.
- `src/Sources/SettingsView.swift:112-261` and related provider rows contain the UI flow for connected accounts and API-key entry.
- `src/Sources/AppDelegate.swift:11-12` shows AppDelegate owns both production `serverManager` and `thinkingProxy` properties; `src/Sources/AppDelegate.swift:31-34` initializes `serverManager = ServerManager()` and `thinkingProxy = ThinkingProxy()`, making AppDelegate the production owner/wiring seam for injecting the app-owned `ServerManager` into `ThinkingProxy` and `ProductionModelListCatalogProvider`.
- `src/Sources/ThinkingProxy.swift:1061-1147,1286-1383` contains current `/v1/models` detection, hardcoded alias/catalog filtering, and response-body replacement mechanics.
- `src/Tests/CCProxyTests/AuthStatusTests.swift:4-50`, `src/Tests/CCProxyTests/ServerManagerConfigTests.swift:47-77`, and `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift:1-260` show existing test style and current hardcoded model-list assertions to replace.
- CodeGraph was queried with `AuthStatus ServerManager SettingsView ThinkingProxy model list /v1/models package tests Makefile external catalog`; it warned that the index was from the root worktree, so exact planning evidence above is taken from direct reads in the isolated worktree.

## External Catalog Input Shapes To Implement

- Primary CLIProxyAPI registry input `https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/main/internal/registry/models/models.json` is a top-level JSON object whose keys are upstream provider/tier names and whose values are arrays of model descriptor objects. Known keys include `claude`, `codex-free`, `codex-team`, `codex-plus`, `codex-pro`, and `kimi`; descriptors include at least `id`, commonly `object`, `created`, `owned_by`, `type`, `display_name`, and may include many unknown fields such as token limits or `thinking`.
- Primary CLIProxyAPI provider-key normalization is exact and must happen before merge/filtering into CCProxy provider IDs:
  - `claude` maps to CCProxy provider `claude`.
  - `codex-free`, `codex-team`, `codex-plus`, and `codex-pro` all map to CCProxy provider `codex`; preserve the source tier (`free`, `team`, `plus`, `pro`) in model metadata when it can be derived from the key, but do not create separate CCProxy providers for those tiers.
  - `kimi` maps to CCProxy provider `kimi`.
  - Other primary keys are parsed and retained in source diagnostics/provenance, but model-list output emits them only when a future explicit mapping connects them to an enabled CCProxy provider; do not emit unmapped primary sections by default.
- Primary Codex client input `https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/main/internal/registry/models/codex_client_models.json` is a top-level JSON object with `models` as an array. Its model descriptors use `slug` as the model ID and commonly include `display_name`, `description`, visibility/support fields, context metadata, and many nested unknown fields. The parser must tolerate unknown fields and map `slug` to supplemental Codex client metadata keyed by `slug` under CCProxy provider `codex`; this file is not a separate provider and must not replace the tier-normalized Codex coverage from `models.json`.
- Secondary models.dev input `https://models.dev/api.json` is a top-level JSON object keyed by provider ID. Each provider object may contain metadata plus a nested `models` object keyed by model ID. The parser must tolerate unknown provider/model fields and derive model IDs from the nested model key or from model `id`/`slug` when present.
- Approved CCProxy-to-models.dev mappings are exact: `claude -> anthropic`, `codex -> openai`, `zai -> zai-coding-plan`, `minimax -> minimax-coding-plan`, `kimi -> moonshotai`, `opencode-go -> opencode-go`.
- Primary source precedence is exact: CLIProxyAPI registry entries are inserted first after the primary-key normalization above; `codex_client_models.json` supplements Codex models by `slug`; models.dev fills only missing mapped connected-provider coverage and must not replace already-covered primary sections or treat models.dev as the sole catalog source. Duplicate provider/model IDs keep the primary descriptor.
- Parser acceptance is tolerant but not vague: require a non-empty model ID string, derive `owned_by` from descriptor `owned_by`, provider key, or mapped CCProxy provider, default `object` to `model`, default missing/invalid `created` to `0`, and ignore unsupported fields rather than failing the whole source. Malformed JSON or an input with zero valid model entries is an invalid source.
- Model ID domains are separate:
  - External catalog/rendered `/v1/models` IDs are provider-qualified OpenAI-style IDs and may be `opencode-go/<model-slug>` for OpenCode Go; the rendered output must include the provider prefix exactly once.
  - Generated `claude-api-key` config model names for OpenCode Go must be unprefixed model slugs when the generated provider block has `prefix: "opencode-go"` and `force-model-prefix: true`, because the backend config layer adds the prefix.
  - Tests must prove OpenCode Go config does not double-prefix model names while `/v1/models` output emits provider-qualified IDs exactly once.
- Runtime cache metadata must include the last refresh attempt timestamp and last refresh failure metadata. If the runtime cache is stale and the previous failed refresh attempt is within a deterministic 15-minute retry interval, serve the stale cache without external fetch. A fresh app process may attempt one refresh when it first observes a stale cache; subsequent `/v1/models` requests obey the same failure throttle until the retry interval elapses.
- When no valid runtime cache exists but a bundled snapshot is valid, a failed refresh must record last-attempt and failure metadata in memory and, where feasible, persistent cache metadata; repeated `/v1/models` requests inside the same deterministic 15-minute retry window must serve the bundled snapshot without re-fetching external sources.

## Bundled Snapshot Production Lookup Strategy

- Use the production-compatible lookup strategy that first attempts to load `model-catalog-snapshot.json` from the manually created app bundle resources path exposed by `Bundle.main.resourceURL`, specifically `CCProxy.app/Contents/Resources/model-catalog-snapshot.json` in release/app-bundle execution.
- Fall back to `Bundle.module.url(forResource: "model-catalog-snapshot", withExtension: "json")` only when the main-bundle resource lookup is unavailable, such as SwiftPM XCTest execution.
- Do not require copying SwiftPM's generated resource bundle into `CCProxy.app`; repository evidence shows `create-app-bundle.sh` manually copies files from `src/Sources/Resources/` into `CCProxy.app/Contents/Resources/`, so the app runtime must read the flat resource file layout directly.
- Unit tests must cover both lookup paths with injected bundle/resource URLs: flat app-bundle resources first, SwiftPM `Bundle.module` fallback second. Release verification must prove the generated app bundle contains `CCProxy.app/Contents/Resources/model-catalog-snapshot.json` and that the file is parseable JSON.

## Connected-Provider Calculation Required For Catalog Filtering

- The connected-provider set used by `/v1/models` and catalog-backed config generation is the intersection of enabled provider state and valid credential/auth state. A provider present in the catalog is never enough by itself.
- OAuth providers are exactly `claude` and `codex`. Include an OAuth provider only when it is enabled and the configured auth directory contains at least one provider-matching auth file/account that is non-disabled and non-expired. Exclude the provider when no auth file/account exists, every account is disabled, or every account is expired.
- API-key hosted providers are exactly `zai`, `minimax`, `kimi`, and `opencode-go`. Include an API-key provider only when it is enabled and the configured auth directory contains at least one provider-matching API-key credential file/account with a non-empty key that is non-disabled. Exclude the provider when no credential exists, every credential is disabled, or every key is empty/invalid.
- Disabled providers are excluded even if valid OAuth auth files or API-key credential files exist.
- No-auth/no-key providers are excluded even if they appear in defaults, settings, external catalog sources, bundled snapshots, or models.dev. The catalog renderer must not expose models for a provider unless that provider is in the connected-provider set above.
- Expired OAuth credentials are excluded whenever token/account metadata exposes expiration, such as `expires_at`, `expiresAt`, `expiration`, or equivalent date fields in the existing auth JSON. If current `AuthManager`/auth-file parsing has no expiration handling, implement an internal testable seam while preserving existing valid-auth behavior: parse optional expiration metadata from auth JSON, compare it with an injected clock, treat absent expiration metadata as non-expiring for backward compatibility, and exclude credentials whose expiration is at or before the injected current time.
- Deterministic tests must prove the exact connected-provider outcomes for no-auth, disabled-provider, valid-auth/key, and expired-OAuth cases before catalog filtering is considered implemented.

## File Structure

### Create

- `src/Sources/ExternalModelCatalog.swift` — catalog types, parser/merge/filter logic, cache coordinator, bundled snapshot loader that reads `Bundle.main.resourceURL` app-bundle resources before `Bundle.module`, provider mappings, OpenAI-style renderer, and injectable test doubles.
- `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift` — parser, merge, mapping, filtering, TTL/cache, snapshot, failure, and response-shape tests.
- `src/Tests/CCProxyTests/OpenCodeGoProviderTests.swift` — OpenCode Go provider/save/config/connected-provider tests.
- `src/Sources/Resources/model-catalog-snapshot.json` — generated external-source snapshot bundled as a SwiftPM resource.
- `scripts/generate-model-catalog-snapshot.swift` — deterministic Swift generator for the bundled snapshot.

### Modify

- `src/Sources/AuthStatus.swift` — add `ServiceType.opencodeGo` raw value `opencode-go` and display name `OpenCode Go`.
- `src/Sources/ServerManager.swift` — add OpenCode Go API-key storage/scanning, connected-provider helper, and `claude-api-key` provider config entry using `https://opencode.ai/zen/go/v1/messages` only.
- `src/Sources/SettingsView.swift` — add OpenCode Go provider row, API-key prompt/save flow, and help text.
- `src/Sources/ThinkingProxy.swift` — consume catalog-backed model-list renderer and remove hardcoded Swift model catalog/alias tables from the runtime `/v1/models` source path.
- `src/Tests/CCProxyTests/AuthStatusTests.swift` — update provider identity expectations.
- `src/Tests/CCProxyTests/ServerManagerConfigTests.swift` — update hosted-provider config tests and remove assertions that require static model lists.
- `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift` — replace hardcoded runtime model-list expectations with catalog-backed response-shape tests; retain request-normalization tests only if implementation still justifies them outside model-list fallback.
- `Makefile` — add a snapshot target and run it before build/release only when needed.
- `create-app-bundle.sh` — ensure direct release-script use refreshes or validates the bundled snapshot before release build and copies `src/Sources/Resources/model-catalog-snapshot.json` into `CCProxy.app/Contents/Resources/model-catalog-snapshot.json`.
- `README.md` and `README.ko.md` — document OpenCode Go setup, catalog sources, TTL, cache path, fallback order, and messages-only routing.

### Do Not Modify Unless A Focused Failing Test Proves It Is Required

- `src/Package.swift` — keep dependencies unchanged if Foundation-only code is sufficient.
- `src/Sources/Resources/config.yaml` — prefer generated config in `ServerManager` over static config changes.
- Binary/image resources — do not add provider artwork unless build/UI tests prove a resource is required.

## Task 0 — Preflight And Execute Readiness

- [ ] Verify the isolated worktree and branch:
  ```bash
  pwd && git rev-parse --show-toplevel && git branch --show-current && git status --short
  ```
  Expected output: both paths equal `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-opencode-go-models-dev-catalog`, branch is `work/2026-06-05-opencode-go-models-dev-catalog`, and changes are limited to approved EasyCode artifacts before implementation begins.
- [ ] Re-run baseline verification:
  ```bash
  make backend-version
  make test
  make build
  ```
  Expected output: backend version prints `CLIProxyAPI Version`; `make test` passes all existing tests; `make build` exits zero and prints `Build complete: src/.build/debug/CCProxy`.
- [ ] Confirm SwiftPM test filters:
  ```bash
  (cd src && swift test --filter AuthStatusTests)
  ```
  Expected output: only `AuthStatusTests` run and pass. If the filter syntax differs, use `make test` for focused verification and record the supported command in executor notes.
- [ ] Confirm no release publication is in scope. Expected result: executor notes state PR/merge/local update/worktree cleanup only.

## Task 1 — COMPLETED/REVIEW-PASSED: OpenCode Go Provider Identity And Messages-Only Config

- [x] Task 1 implementation is complete in the current partial implementation state and passed both task-level EasyCode review gates after gating fixes. Do not rerun Task 1 as active implementation work; use the commands in this section only as regression verification after Task 3 remediation or during full completion verification.

### Task 1 Historical RED Steps

- [ ] Update `src/Tests/CCProxyTests/AuthStatusTests.swift` first:
  - `ServiceType.allCases.map(\.rawValue)` must equal `claude`, `codex`, `zai`, `minimax`, `kimi`, `opencode-go`.
  - `ServiceType.allCases.map(\.displayName)` must equal `Claude Code`, `Codex`, `Z.AI GLM`, `MiniMax`, `Kimi`, `OpenCode Go`.
- [ ] Create `src/Tests/CCProxyTests/OpenCodeGoProviderTests.swift` first:
  - Saving an OpenCode Go key writes one `0o600` JSON credential under the isolated auth directory with `type: "opencode-go"`, `api_key: "opencode-test-key"`, no key in the filename, and no source-controlled secret.
  - Connected-provider calculation includes `opencode-go` only when the provider is enabled and the isolated auth directory contains at least one non-disabled credential file/account with `type: "opencode-go"` and a non-empty `api_key`.
  - Connected-provider calculation excludes `opencode-go` when the provider is enabled but no credential file exists, when the only credential has an empty API key, and when the only credential/account is marked disabled.
  - Connected-provider calculation excludes `opencode-go` when the provider is disabled even if a valid credential file exists.
- [ ] Add connected-provider tests for all provider types in `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`, because `ServerManager` owns credential scanning and generated-provider config state:
  - With enabled `claude` and an isolated auth directory containing a non-disabled, non-expired Claude OAuth account file, the connected-provider set contains `claude`.
  - With enabled `codex` and an isolated auth directory containing a non-disabled, non-expired Codex OAuth account file, the connected-provider set contains `codex`.
  - With enabled `claude` or `codex` but no provider-matching OAuth auth file/account, the connected-provider set excludes that provider.
  - With enabled `claude` or `codex` but only disabled OAuth account files, the connected-provider set excludes that provider.
  - With enabled `claude` or `codex` but only expired OAuth account files whose metadata expiration is before or equal to an injected fixed current date, the connected-provider set excludes that provider.
  - With enabled `zai`, `minimax`, `kimi`, or `opencode-go` and at least one matching non-disabled API-key credential file/account with a non-empty key, the connected-provider set contains that provider.
  - With enabled `zai`, `minimax`, `kimi`, or `opencode-go` but no matching API-key credential, only disabled credentials, or only empty-key credentials, the connected-provider set excludes that provider.
  - With any disabled provider, including `claude`, `codex`, `zai`, `minimax`, `kimi`, or `opencode-go`, the connected-provider set excludes that provider even when valid auth or API-key credentials exist.
  - A provider configured as no-auth/no-key in defaults or test settings is excluded from the connected-provider set even when enabled, because it has no valid credential/auth account.
- [ ] Update `src/Tests/CCProxyTests/ServerManagerConfigTests.swift` first:
  - With an isolated `opencode-go` credential, generated config contains one `claude-api-key` provider entry with `prefix: "opencode-go"`, `base-url: "https://opencode.ai/zen/go/v1/messages"`, and `api-key: "opencode-test-key"`.
  - With injected OpenCode Go catalog models `opencode-go/kimi-k2.6` and `opencode-go/claude-sonnet-4`, generated `claude-api-key` config model names are unprefixed slugs `kimi-k2.6` and `claude-sonnet-4`; the config must not contain `opencode-go/opencode-go/` and must not store already-prefixed `opencode-go/...` model names in a block where `prefix: "opencode-go"` and `force-model-prefix: true` are present.
  - Generated config does not contain `https://opencode.ai/zen/go/v1/chat/completions`, `openai-compatibility`, `go.mod`, or Go SDK package names.
  - Existing Z.AI, MiniMax, and Kimi hosted provider config tests continue to assert their base URLs and credentials but no longer require hardcoded model catalog entries.
- [ ] Run RED verification:
  ```bash
  (cd src && swift test --filter AuthStatusTests)
  (cd src && swift test --filter OpenCodeGoProviderTests)
  (cd src && swift test --filter ServerManagerConfigTests)
  ```
  Expected failure: `opencode-go` enum/config/save/connected-provider behavior does not exist yet, or the new tests fail to compile because the helper names do not exist. Existing unrelated tests should not newly fail during RED.

### Task 1 Historical GREEN Steps

- [ ] Modify `src/Sources/AuthStatus.swift` to add `case opencodeGo = "opencode-go"` and display name `OpenCode Go`.
- [ ] Modify `src/Sources/ServerManager.swift`:
  - Add `saveOpenCodeGoApiKey(_ apiKey:completion:)` by delegating to the existing `saveApiKey` pattern.
  - Include `opencode-go` in API-key credential scanning.
  - Add OpenCode Go to the existing Claude-compatible provider list with prefix `opencode-go` and base URL `https://opencode.ai/zen/go/v1/messages` only.
  - When model names for the OpenCode Go `claude-api-key` block come from provider-qualified catalog IDs, strip exactly one leading `opencode-go/` before writing config because `force-model-prefix: true` plus `prefix: "opencode-go"` will add the provider prefix at runtime. Do not strip prefixes for `/v1/models` rendering.
  - Add an internal connected-provider helper that calculates the set exactly as defined in `Connected-Provider Calculation Required For Catalog Filtering`: OAuth providers `claude`/`codex` require enabled state plus a non-disabled, non-expired auth file/account; API-key hosted providers `zai`/`minimax`/`kimi`/`opencode-go` require enabled state plus a non-disabled credential file/account with a non-empty key; disabled providers and no-auth/no-key providers are excluded.
  - Add a narrow expiration parsing seam for OAuth auth-file/account metadata if current auth parsing does not already expose expiration. The seam must accept an injected clock in tests, treat absent expiration metadata as non-expiring for backward compatibility, and mark metadata expired when its expiration time is at or before the injected current time.
  - Do not add `/chat/completions` or `openai-compatibility` config.
- [ ] Modify `src/Sources/SettingsView.swift` to add an OpenCode Go provider row, API-key prompt, save action, and help text using the existing hosted API-key provider UI pattern.
- [ ] Run focused GREEN verification:
  ```bash
  (cd src && swift test --filter AuthStatusTests)
  (cd src && swift test --filter OpenCodeGoProviderTests)
  (cd src && swift test --filter ServerManagerConfigTests)
  ```
  Expected result: all three focused suites pass.
- [ ] Run provider regression verification:
  ```bash
  make test
  ```
  Expected result: all tests pass.
- [ ] Refactor only after GREEN. If `SettingsView.swift` duplicates API-key prompt code, extract a small private helper without changing behavior, then rerun:
  ```bash
  make test
  ```
  Expected result: all tests remain passing.

## Task 2 — COMPLETED/REVIEW-PASSED: External Catalog Parser, Merge, Filter, Cache, And Renderer

- [x] Task 2 implementation is complete in the current partial implementation state and passed both task-level EasyCode review gates after cache/determinism fixes. Do not rerun Task 2 as active implementation work; use the commands in this section only as regression verification after Task 3 remediation or during full completion verification.

### Task 2 Historical RED Steps

- [ ] Create `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift` first with in-memory fixtures and no network access.
- [ ] Add deterministic parser tests:
  - CLIProxyAPI `models.json` fixture is a top-level provider-key object with array values and descriptors containing `id`; unknown fields are ignored.
  - CLIProxyAPI `codex_client_models.json` fixture is an object with `models` array and descriptors containing `slug`; `slug` becomes model ID.
  - models.dev fixture is a top-level provider-key object whose provider contains a nested `models` object keyed by model IDs; nested keys become model IDs.
  - Malformed JSON makes that source invalid; a valid other source can still produce a valid combined snapshot.
- [ ] Add merge/filter tests:
  - CLIProxyAPI primary wins when the same CCProxy provider/model appears in primary and secondary.
  - CLIProxyAPI primary-key normalization maps `claude` to CCProxy `claude`; maps `codex-free`, `codex-team`, `codex-plus`, and `codex-pro` to CCProxy `codex` while preserving tier metadata; maps `kimi` to CCProxy `kimi`; parses but does not emit unmapped primary keys for connected providers unless an explicit mapping exists.
  - `codex_client_models.json.models` supplements CCProxy `codex` metadata keyed by `slug` and is never emitted as a separate provider.
  - models.dev fills missing mapped providers/models for `claude`, `codex`, `zai`, `minimax`, `kimi`, and `opencode-go`, but does not replace CLIProxyAPI-covered primary provider sections or primary Codex model descriptors.
  - Output is filtered to connected CCProxy providers only and excludes unrelated models.dev providers.
  - With an empty connected-provider set, rendered output is `object: "list"` with an empty `data` array, even when the merged catalog contains Claude, Codex, Z.AI, MiniMax, Kimi, OpenCode Go, models.dev-only, and no-auth/no-key provider entries.
  - With only disabled-provider outcomes supplied by the connected-provider helper, rendered output is empty and does not expose catalog entries for providers that have credentials but are disabled.
  - With connected providers limited to valid-auth/key providers `claude`, `codex`, `zai`, `minimax`, `kimi`, and `opencode-go`, rendered output contains only those providers' catalog entries and excludes unrelated catalog sections.
  - With OAuth providers represented by expired-auth outcomes from the connected-provider helper, rendered output excludes Claude and Codex entries while still allowing valid API-key hosted providers in the same fixture.
  - With enabled no-auth/no-key providers present in settings/defaults but absent from the connected-provider set, rendered output excludes their catalog entries.
  - OpenCode Go rendered `/v1/models` IDs keep exactly one `opencode-go/` prefix when present in models.dev or normalized catalog data and do not synthesize unrelated IDs.
- [ ] Add cache/fallback tests with fixed dates and temporary directories:
  - Runtime cache younger than six hours is fresh and does not invoke the fetcher.
  - Runtime cache age at or over six hours is stale and attempts refresh.
  - Refresh success atomically replaces the runtime cache only after valid parse/merge.
  - Refresh failure uses stale runtime cache when one exists and records `lastRefreshAttemptAt` plus structured failure metadata such as failed source URL and error summary in runtime cache metadata.
  - If a stale cache had a failed refresh attempt less than 15 minutes ago, a new `/v1/models` request serves the stale cache and performs zero external fetch calls.
  - If a stale cache had a failed refresh attempt at least 15 minutes ago, the next request attempts one refresh and updates the attempt/failure metadata when it fails.
  - A fresh app start with stale cache and no in-memory attempt state may attempt one refresh; subsequent requests in the same process obey persisted or in-memory failure-throttle metadata and do not fetch per request after failure.
  - No runtime cache attempts one refresh; if refresh fails and the bundled snapshot is valid, the coordinator serves the bundled snapshot and records `lastRefreshAttemptAt` plus structured failure metadata in memory and, where feasible, persistent cache metadata without writing an invalid runtime snapshot.
  - No valid runtime cache plus valid bundled snapshot plus failed refresh throttles repeated `/v1/models` requests for 15 minutes: a second request inside the retry window serves the bundled snapshot and performs zero additional external fetch calls.
  - No valid runtime cache plus valid bundled snapshot retries after the 15-minute window elapses: the next request performs exactly one external fetch attempt and updates failure metadata if it fails again.
  - Invalid runtime cache is ignored in favor of bundled snapshot.
  - No valid runtime cache and no valid bundled snapshot returns an explicit unavailable result.
- [ ] Add renderer tests:
  - Response JSON has top-level `object: "list"` and `data` entries with `id`, `object: "model"`, `created`, and `owned_by`.
  - OpenCode Go `/v1/models` response emits provider-qualified IDs such as `opencode-go/kimi-k2.6` exactly once, while the separate generated config model-name test in `ServerManagerConfigTests` asserts unprefixed slugs for `claude-api-key` config.
  - Runtime generation does not call `modelAliasToCanonical`, `filterModelListResponseBody`, or any static Swift model catalog table.
- [ ] Run RED verification:
  ```bash
  (cd src && swift test --filter ExternalModelCatalogTests)
  ```
  Expected failure: `ExternalModelCatalog` types and helpers do not exist.

### Task 2 Historical GREEN Steps

- [ ] Create `src/Sources/ExternalModelCatalog.swift` with minimal internal/public APIs needed by tests:
  - Codable snapshot model with `schemaVersion`, `generatedAt`, `sources`, and provider-to-model map.
  - Model type with `id`, `object`, `created`, `ownedBy`, `displayName`, source provenance, optional `tier`, and supplemental metadata keyed by source model ID or slug.
  - Parser functions for the exact three source shapes listed in this plan.
  - Approved provider mapping table only; do not encode model catalogs in Swift. The primary mapping table must include `claude -> claude`, `codex-free -> codex`, `codex-team -> codex`, `codex-plus -> codex`, `codex-pro -> codex`, and `kimi -> kimi`; the secondary models.dev mapping table must include only `claude -> anthropic`, `codex -> openai`, `zai -> zai-coding-plan`, `minimax -> minimax-coding-plan`, `kimi -> moonshotai`, and `opencode-go -> opencode-go`.
  - Merge function that inserts primary models first after provider-key normalization, attaches `codex_client_models.json` supplemental Codex metadata by `slug`, and fills gaps from secondary only for missing mapped connected-provider coverage.
  - Connected-provider filter from CCProxy provider IDs to external provider IDs that consumes only the already-calculated connected-provider set; it must never infer connectivity from catalog presence, default-enabled state, no-auth/no-key provider declarations, or external source availability.
  - Cache coordinator with six-hour TTL, 15-minute failed-refresh retry interval, injected clock/fetcher/file paths, atomic write of valid snapshots, persisted runtime metadata for last refresh attempt and last failure, stale-cache fallback, bundled snapshot fallback, explicit unavailable result, and no per-request external fetch loop after a stale-cache refresh failure.
  - When no valid runtime cache exists and refresh fails, serve a valid bundled snapshot when available, record the failed attempt in process memory and in persistent cache metadata where feasible, and suppress additional external fetches for repeated `/v1/models` requests until the deterministic 15-minute retry interval expires.
  - Renderer for OpenAI-compatible `/v1/models` data.
- [ ] Store runtime cache at `~/.cli-proxy-api/model-catalog-cache.json`; inject temporary paths in tests.
- [ ] Ensure fresh cache path performs zero network fetches; prove via fake fetcher call counts.
- [ ] Run focused GREEN verification:
  ```bash
  (cd src && swift test --filter ExternalModelCatalogTests)
  ```
  Expected result: all catalog tests pass.
- [ ] Run adjacent verification:
  ```bash
  (cd src && swift test --filter ServerManagerConfigTests)
  (cd src && swift test --filter OpenCodeGoProviderTests)
  ```
  Expected result: both suites pass.
- [ ] Refactor only after GREEN. Keep cleanup one target at a time under the `simplify` discipline and rerun:
  ```bash
  (cd src && swift test --filter ExternalModelCatalogTests)
  ```
  Expected result: tests remain passing.

## Task 3 — RED: Reproduce Current Production Wiring Divergence And Default-Path Network Risk

- [ ] Task 3 is a remediation task against the current partial implementation state. Do not write tests that expect missing `ExternalModelCatalog`, `ModelListCatalogProvider`, `catalogModelsOverride`, or `ProductionModelListCatalogProvider.createDefault()` symbols, because those already exist from Tasks 1 and 2.
- [ ] Task 3 modify file list is limited to `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`, `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift` if a catalog-provider construction regression belongs there, `src/Sources/ThinkingProxy.swift`, `src/Sources/AppDelegate.swift`, `src/Sources/ExternalModelCatalog.swift`, and `src/Sources/ServerManager.swift` only when a narrow connected-provider seam is required. Do not start Task 4/5 files before Task 3 passes.
- [ ] Treat `src/Sources/AppDelegate.swift:11-12` and `src/Sources/AppDelegate.swift:31-34` as the production ownership evidence: AppDelegate owns the production `serverManager` and `thinkingProxy`, so Task 3 must make that AppDelegate-owned `serverManager` the only production state source for `/v1/models` catalog filtering.
- [ ] Update `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift` before remediation changes:
  - Add or adjust a regression test that fails when `/v1/models` catalog filtering reads provider enable/disable or credential state from `ServerManager.shared`, an internally constructed `ServerManager()`, or any manager other than the AppDelegate-owned manager injected into `ThinkingProxy`.
  - In that regression test, create two managers with conflicting state, inject the AppDelegate-owned manager into the production-style `ThinkingProxy`/catalog provider path, and assert only the injected manager controls whether credential-valid provider catalog entries appear.
  - Add or adjust a test proving provider enable/disable changes made through the same injected AppDelegate-owned manager affect `/v1/models` filtering without constructing a separate production manager or singleton.
  - Add or adjust a production-default wiring test without live network access: instantiate the default production catalog-provider path through an injectable factory using the AppDelegate-owned `ServerManager`, an injected fake fetcher, a temporary runtime-cache path, and a temporary bundled-snapshot path; assert the test performs zero live `URLSession` calls.
  - Add or adjust a test that the production default path does not fetch external sources during initialization or on repeated `/v1/models` calls when a stale-cache refresh failure is inside the deterministic 15-minute retry interval.
  - Keep existing catalog-backed response-shape expectations that a valid backend `/v1/models` response is replaced with connected-provider catalog output, no connected providers produce an empty OpenAI-style list, disabled providers are excluded, expired Claude/Codex OAuth credentials are excluded, no-auth/no-key providers are excluded, unavailable catalog state preserves HTTP response safety, response rebuild recalculates `Content-Length` and removes stale transfer headers, and request alias normalization is not used as a `/v1/models` catalog fallback.
- [ ] If the default-provider construction behavior is tested more cleanly in `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift`, add only focused construction/fetcher-injection assertions there; keep `/v1/models` state-divergence tests in `ThinkingProxyModelAliasTests`.
- [ ] Run RED verification from the current partial implementation state:
  ```bash
  (cd src && swift test --filter ThinkingProxyModelAliasTests)
  (cd src && swift test --filter ExternalModelCatalogTests)
  ```
  Expected failure: at least one focused test fails because the current production path still uses `ServerManager.shared`, constructs a separate `ServerManager()`, ignores the AppDelegate-owned injected manager, or can use a live-network/default fetch path in tests instead of the injected fake fetcher. RED must not be a missing-type compile failure for Task 1/2 catalog symbols.

## Task 3 — GREEN: Remediate AppDelegate-Owned Manager Injection Before Further Catalog Wiring

- [ ] Before any other Task 3 implementation, delete `ServerManager.shared` from production source unless a non-production test-only justification is explicitly documented in executor notes and accepted by both task reviewers. Default expected implementation is deletion. Also remove or replace every hidden production-only `ServerManager()` construction used by `/v1/models` catalog filtering. Tests may still construct isolated managers as explicit fixtures.
- [ ] Modify `src/Sources/ThinkingProxy.swift`:
  - Require `ThinkingProxy` production catalog behavior to receive the AppDelegate-owned `ServerManager` or a connected-provider closure derived from that exact manager.
  - In `GET /v1/models` response handling, render the catalog-backed model list using only the connected-provider set calculated from the injected manager; no-auth/no-key providers, disabled providers, missing-credential providers, and expired OAuth providers must not appear even if the catalog contains entries for them.
  - Keep `catalogModelsOverride` as a test seam only when it cannot diverge from the injected manager's connected-provider state.
  - Call the catalog coordinator in a way that respects six-hour TTL and 15-minute failed-refresh throttling; `/v1/models` must not start a network fetch on every request after a stale-cache refresh failure.
  - Remove `modelAliasToCanonical`, `filterModelListResponseBody`, and model-list `normalizeOwnedBy` from the runtime `/v1/models` source path if the partial implementation has not already removed them.
  - If `canonicalizeTopLevelModelAlias` remains, rename or scope it as request-normalization-only and keep it out of model-list generation.
  - Preserve model-list request classification and HTTP response rebuild behavior unless the new tests require a narrow change.
- [ ] Modify `src/Sources/AppDelegate.swift` in Task 3 only:
  - Wire the AppDelegate-owned `serverManager` from `src/Sources/AppDelegate.swift:31-32` into `ThinkingProxy` and the production `ProductionModelListCatalogProvider`/catalog coordinator used by `ThinkingProxy`, replacing independent default construction with dependency injection or an equivalent explicit setup.
  - Ensure provider enable/disable and credential changes made through the AppDelegate-owned manager are the exact and only state source used for production `/v1/models` filtering.
  - Do not leave any `ServerManager.shared`, newly constructed production-only `ServerManager()`, or divergent Settings/AppDelegate versus `ThinkingProxy` state path in production catalog filtering. If any `ServerManager.shared` text remains anywhere in production sources, stop unless task reviewers have explicitly accepted it as non-production test-only code; the default expected state is no production `ServerManager.shared` path.
- [ ] Modify `src/Sources/ExternalModelCatalog.swift` only as needed to make `ProductionModelListCatalogProvider.createDefault()` accept injected production dependencies for manager-derived connected-provider state, fetcher, runtime-cache path, bundled-snapshot path, and clock. Its production defaults may use real app paths and real `URLSession`, but tests must be able to provide fake fetchers and temporary paths.
- [ ] Modify `src/Sources/ServerManager.swift` only as needed to expose connected-provider state to the catalog without SwiftUI coupling and without reintroducing a singleton.
- [ ] Run focused GREEN verification:
  ```bash
  (cd src && swift test --filter ThinkingProxyModelAliasTests)
  (cd src && swift test --filter ExternalModelCatalogTests)
  ```
  Expected result: both focused suites pass, the singleton-divergence regression test proves the injected AppDelegate-owned manager controls filtering, and the production-default tests prove zero live-network calls with injected fake fetchers.
- [ ] Run explicit source-path guard before proceeding to Task 4:
  ```bash
  ! rg 'ServerManager\.shared' src/Sources/ThinkingProxy.swift src/Sources/AppDelegate.swift src/Sources/ExternalModelCatalog.swift src/Sources/ServerManager.swift
  rg 'ProductionModelListCatalogProvider\.createDefault\(|ServerManager\(\)' src/Sources/ThinkingProxy.swift src/Sources/AppDelegate.swift src/Sources/ExternalModelCatalog.swift src/Sources/ServerManager.swift
  ```
  Expected result: the first command exits zero because no production `ServerManager.shared` text remains in `ThinkingProxy.swift`, `AppDelegate.swift`, `ExternalModelCatalog.swift`, or `ServerManager.swift`. The second command may print only reviewed safe occurrences: any `ProductionModelListCatalogProvider.createDefault(...)` call explicitly receives the AppDelegate-owned manager or manager-derived connected-provider provider, and any `ServerManager()` occurrence is only AppDelegate's owned production manager initialization or an explicit non-production fixture outside production `/v1/models` filtering. If `ServerManager.swift` still defines or exposes `ServerManager.shared`, stop before Task 4 unless both task reviewers explicitly accepted a non-production test-only justification.
- [ ] Run full regression verification:
  ```bash
  make test
  ```
  Expected result: all tests pass.
- [ ] Refactor only after GREEN using the `simplify` skill: inventory one cleanup target, remove obsolete singleton/default-manager or model-list alias/catalog code one smell at a time, and rerun `make test` after each cleanup. Expected result: all tests remain passing.

## Task 4 — RED: Deterministic Build-Time Snapshot Generation And Existing Snapshot Behavior

- [ ] Add failing tests in `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift` before script/resource changes:
  - `testBundledSnapshotLoaderReadsMainBundleResourceURLFirst` expects an injected main-bundle resource URL shaped like `CCProxy.app/Contents/Resources` to load `model-catalog-snapshot.json` and parse the snapshot schema used by `ExternalModelCatalog` without relying on SwiftPM generated resource bundles.
  - `testBundledSnapshotLoaderFallsBackToBundleModuleForSwiftPMTests` expects `Bundle.module` loading to work only when the injected main-bundle resource URL is absent or does not contain `model-catalog-snapshot.json`.
  - `testBundledSnapshotLoaderPrefersMainBundleResourceOverBundleModule` creates two valid snapshots with different `generatedAt` values and expects the main-bundle resource file to win, proving production app-bundle layout takes precedence over test resources.
  - `testBundledSnapshotRequiresExternalSourceMetadata` rejects a snapshot missing both primary CLIProxyAPI URLs and the secondary models.dev URL in `sources` metadata.
  - `testExistingValidBundledSnapshotCanBeReusedWhenGenerationSourcesUnavailable` uses an injected generator file system/fetcher and expects an already valid `src/Sources/Resources/model-catalog-snapshot.json` to remain unchanged and be accepted when all external fetches fail.
  - `testMalformedExistingSnapshotFailsWhenGenerationSourcesUnavailable` expects generation to exit/report failure when fetches fail and the existing snapshot is missing required schema/source metadata.
  - `testSnapshotJSONIsDeterministic` expects sorted provider keys, sorted model IDs, fixed pretty-print formatting, and stable output for identical inputs.
- [ ] Add a command-level RED check after tests are written but before creating the script/resource:
  ```bash
  (cd src && swift test --filter ExternalModelCatalogTests)
  make build
  ```
  Expected failure: snapshot loader/generator abstractions or resource do not exist; if `make build` still passes before Makefile integration, that is acceptable at RED only if the focused XCTest failures prove missing behavior.

## Task 4 — GREEN: Add Snapshot Script, Resource, And Build Hooks

- [ ] Create `scripts/generate-model-catalog-snapshot.swift` with deterministic behavior:
  - Fetch `models.json`, `codex_client_models.json`, and `https://models.dev/api.json`.
  - Parse using the same source-shape rules as `ExternalModelCatalog.swift`; tolerate unknown fields and reject sources with zero valid models.
  - Merge primary entries first using exact CLIProxyAPI primary-key normalization (`claude -> claude`, `codex-free -> codex`, `codex-team -> codex`, `codex-plus -> codex`, `codex-pro -> codex`, `kimi -> kimi`, preserving Codex tier metadata), attach `codex_client_models.json.models` as supplemental Codex metadata keyed by `slug`, parse but do not emit unmapped primary keys, then fill only missing mapped connected-provider coverage from models.dev.
  - Write sorted, pretty JSON with schema/source metadata to `src/Sources/Resources/model-catalog-snapshot.json` using atomic replacement.
  - If one external source fails but the other valid source produces a non-empty snapshot, write the snapshot and record failed source metadata.
  - If all external sources fail and an existing bundled snapshot is valid, leave it unchanged and exit zero with an explicit reuse message.
  - If all external sources fail and no existing valid bundled snapshot exists, exit nonzero with an explicit unavailable message.
- [ ] Generate or validate the bundled snapshot:
  ```bash
  swift scripts/generate-model-catalog-snapshot.swift
  ```
  Expected result: `src/Sources/Resources/model-catalog-snapshot.json` exists, is valid deterministic JSON, includes source metadata for both primary URLs and models.dev when fetched successfully, and includes `opencode-go` when the external catalog source provides it.
- [ ] Modify `Makefile`:
  - Add a `model-catalog-snapshot` target that runs `swift scripts/generate-model-catalog-snapshot.swift`.
  - Make `build` and `release` depend on `model-catalog-snapshot`.
  - Keep `test` running an executable subshell command equivalent to `(cd src && swift test)`; do not make unit tests depend on live network.
- [ ] Modify `create-app-bundle.sh` to run `swift scripts/generate-model-catalog-snapshot.swift` before `swift build -c release`, so direct script invocation follows the same snapshot rules.
- [ ] In `src/Sources/ExternalModelCatalog.swift`, implement bundled snapshot loading in this order:
  - Read `Bundle.main.resourceURL?.appendingPathComponent("model-catalog-snapshot.json")` first for production and manually created `CCProxy.app/Contents/Resources` layouts.
  - If the main-bundle resource file is missing, try `Bundle.module.url(forResource: "model-catalog-snapshot", withExtension: "json")` for SwiftPM/XCTest execution.
  - Treat an invalid main-bundle file as a structured bundled-snapshot load failure; use `Bundle.module` fallback for tests only when the main-bundle file is absent, not when production contains a corrupt file.
- [ ] Keep `create-app-bundle.sh` copying `src/Sources/Resources/*` contents directly into `CCProxy.app/Contents/Resources/`; do not add a requirement to copy SwiftPM generated resource bundles into the app bundle.
- [ ] Run focused GREEN verification:
  ```bash
  (cd src && swift test --filter ExternalModelCatalogTests)
  make build
  ```
  Expected result: catalog tests pass; build succeeds and prints `Build complete: src/.build/debug/CCProxy`. If the network is unavailable, `make build` succeeds only when the existing bundled snapshot is valid and reused.
- [ ] Run production app-bundle resource-layout verification:
  ```bash
  APP_VERSION=0.0.0 APP_BUILD_NUMBER=0 make release
  test -f CCProxy.app/Contents/Resources/model-catalog-snapshot.json
  python3 -m json.tool CCProxy.app/Contents/Resources/model-catalog-snapshot.json >/dev/null
  ```
  Expected result: `make release` exits zero and prints `Build complete: CCProxy.app`; the `test -f` command exits zero proving the manually created app bundle contains the flat resource file at `CCProxy.app/Contents/Resources/model-catalog-snapshot.json`; `python3 -m json.tool` exits zero proving the bundled snapshot is parseable JSON. If Python 3 is unavailable on the executor host, run `swift -e 'import Foundation; let url = URL(fileURLWithPath: "CCProxy.app/Contents/Resources/model-catalog-snapshot.json"); _ = try JSONSerialization.jsonObject(with: Data(contentsOf: url)); print("parseable")'` and expect `parseable`.
- [ ] Run full verification for this task:
  ```bash
  make test
  make build
  APP_VERSION=0.0.0 APP_BUILD_NUMBER=0 make release
  test -f CCProxy.app/Contents/Resources/model-catalog-snapshot.json
  python3 -m json.tool CCProxy.app/Contents/Resources/model-catalog-snapshot.json >/dev/null
  ```
  Expected result: tests pass without live network dependency; build either refreshes the snapshot or explicitly reuses a valid existing snapshot; release creates `CCProxy.app`; the app bundle contains `Contents/Resources/model-catalog-snapshot.json`; the bundled snapshot is parseable JSON.
- [ ] Refactor only after GREEN. If parser duplication between the script and runtime file becomes risky, extract shared pure logic inside `ExternalModelCatalog.swift` only if Swift script execution can import or reuse it without package restructuring; otherwise keep duplication small and covered by identical fixtures. Rerun `make test` and `make build`.

## Task 5 — RED: Config Uses Catalog Models And Documentation Locks Final Behavior

- [ ] Add failing tests before production/docs changes:
  - In `ServerManagerConfigTests`, hosted provider config model names for Z.AI, MiniMax, Kimi, and OpenCode Go come from injected catalog data, not static Swift arrays.
  - In `ServerManagerConfigTests`, OpenCode Go config model names are unprefixed slugs when the provider block has `prefix: "opencode-go"` and `force-model-prefix: true`; no generated config line may contain `opencode-go/opencode-go/` or an already-prefixed model name for OpenCode Go.
  - In `ServerManagerConfigTests`, OpenCode Go config remains messages-only and never emits `/chat/completions` or `openai-compatibility`.
  - In `ExternalModelCatalogTests`, CLIProxyAPI primary provider mappings exactly equal `claude -> claude`, `codex-free -> codex`, `codex-team -> codex`, `codex-plus -> codex`, `codex-pro -> codex`, and `kimi -> kimi`; models.dev mappings exactly equal the approved secondary table; unsupported primary keys and unsupported models.dev mappings are not emitted.
  - In `ExternalModelCatalogTests`, stale-cache refresh failure metadata throttles retries for 15 minutes so two `/v1/models` calls after one failed refresh perform one external fetch attempt total.
  - In `ExternalModelCatalogTests`, no-valid-runtime-cache plus valid bundled-snapshot fallback after a failed refresh records failure metadata and throttles retries for 15 minutes so two `/v1/models` calls perform one external fetch attempt total and both serve the bundled snapshot.
  - In `ExternalModelCatalogTests`, connected-provider filtering excludes no-auth/no-key providers, disabled providers with credentials, OAuth providers with missing/disabled/expired auth, and hosted API-key providers with missing/disabled/empty-key credentials; it includes only enabled OAuth providers with valid non-expired auth and enabled hosted providers with valid API-key credentials.
  - In `ThinkingProxyModelAliasTests`, `/v1/models` response shape compatibility is preserved for catalog-backed results and OpenCode Go response IDs include `opencode-go/` exactly once.
  - In `ThinkingProxyModelAliasTests`, `/v1/models` does not expose unrelated catalog entries for no-auth, disabled, missing-auth, or expired-auth providers.
- [ ] Run RED verification:
  ```bash
  (cd src && swift test --filter ServerManagerConfigTests)
  (cd src && swift test --filter ExternalModelCatalogTests)
  (cd src && swift test --filter ThinkingProxyModelAliasTests)
  ```
  Expected failure: config still has static hosted-provider model arrays or docs-driven assertions are not yet satisfied.

## Task 5 — GREEN: Complete Catalog-Backed Config And Docs

- [ ] Modify `src/Sources/ServerManager.swift` so hosted provider model lists in generated `claude-api-key` config are derived from the external catalog for connected providers. Keep only URL/prefix/auth configuration as Swift constants.
- [ ] Ensure the connected-provider helper remains the single source for catalog-backed config and `/v1/models` filtering. Do not let config generation or `ThinkingProxy` infer connectivity from provider defaults, catalog entries, bundled snapshot contents, or provider display rows.
- [ ] For OpenCode Go config only, convert provider-qualified catalog IDs to unprefixed slugs before writing `claude-api-key` model names because the generated block uses `prefix: "opencode-go"` and `force-model-prefix: true`. Keep provider-qualified IDs in `/v1/models` responses and catalog snapshots.
- [ ] Remove remaining Swift static model catalog/alias fallback data from runtime `/v1/models` and hosted-provider model-list generation. Keep only provider mapping constants and independently justified request compatibility normalization.
- [ ] Modify `README.md` and `README.ko.md`:
  - Document OpenCode Go as a hosted provider configured with an API key, not a Go SDK.
  - Document `opencode-go/<model-id>` model IDs and CCProxy local proxy usage.
  - Document that `/v1/models` emits provider-qualified OpenCode Go IDs such as `opencode-go/<model-id>`, while generated internal `claude-api-key` config uses unprefixed model slugs with `prefix: opencode-go` and `force-model-prefix: true` to avoid double-prefixing.
  - State that routing uses `https://opencode.ai/zen/go/v1/messages` through the existing Anthropic-compatible config path only.
  - State that `/chat/completions` and `openai-compatibility` routing are not added in this change.
  - Document catalog sources: CLIProxyAPI `models.json` and `codex_client_models.json` as primary, `https://models.dev/api.json` as secondary.
  - Document runtime cache path `~/.cli-proxy-api/model-catalog-cache.json`, six-hour TTL, 15-minute failed-refresh retry throttle, no per-request fetch, and fallback order: fresh runtime cache, stale runtime cache if refresh fails or retry throttle is active, bundled snapshot, unavailable only if no valid cache/snapshot.
  - Document that when no valid runtime cache exists but the bundled snapshot is valid, a failed refresh records failure metadata and repeated `/v1/models` requests inside the 15-minute retry window serve the bundled snapshot without re-fetching external sources.
  - State `/v1/models` is filtered to connected providers.
  - Define connected providers in the docs as enabled providers with valid credentials/auth: Claude/Codex require non-disabled, non-expired OAuth auth; Z.AI, MiniMax, Kimi, and OpenCode Go require non-disabled API-key credentials; disabled and no-auth/no-key providers are excluded.
- [ ] Run focused GREEN verification:
  ```bash
  (cd src && swift test --filter ServerManagerConfigTests)
  (cd src && swift test --filter ExternalModelCatalogTests)
  (cd src && swift test --filter ThinkingProxyModelAliasTests)
  ```
  Expected result: all focused suites pass.
- [ ] Run complete implementation verification:
  ```bash
  make backend-version
  make test
  make build
  APP_VERSION=0.0.0 APP_BUILD_NUMBER=0 make release
  test -f CCProxy.app/Contents/Resources/model-catalog-snapshot.json
  python3 -m json.tool CCProxy.app/Contents/Resources/model-catalog-snapshot.json >/dev/null
  ```
  Expected result: backend version prints `CLIProxyAPI Version`; all tests pass; debug build succeeds; release creates `CCProxy.app`; `CCProxy.app/Contents/Resources/model-catalog-snapshot.json` exists in the manually created app-bundle layout and is parseable JSON. If Python 3 is unavailable, use the Swift one-liner from Task 4 and expect `parseable`.
- [ ] Refactor only after GREEN using the `simplify` discipline. Remove dead model-list code one smell at a time and rerun `make test` after each removal.

## Full Completion Verification

- [ ] Verify changed files are limited to this plan and approved implementation paths:
  ```bash
  git status --short
  git diff -- docs/easycode/2026-06-05-opencode-go-models-dev-catalog/plan.md src/Sources/AuthStatus.swift src/Sources/ServerManager.swift src/Sources/SettingsView.swift src/Sources/ThinkingProxy.swift src/Sources/AppDelegate.swift src/Sources/ExternalModelCatalog.swift src/Tests/CCProxyTests/AuthStatusTests.swift src/Tests/CCProxyTests/ServerManagerConfigTests.swift src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift src/Tests/CCProxyTests/ExternalModelCatalogTests.swift src/Tests/CCProxyTests/OpenCodeGoProviderTests.swift src/Sources/Resources/model-catalog-snapshot.json scripts/generate-model-catalog-snapshot.swift Makefile create-app-bundle.sh README.md README.ko.md
  ```
  Expected result: only intended files are modified/added. If additional files are changed, stop and revert or justify them before review.
- [ ] Run complete verification:
  ```bash
  make backend-version
  make test
  make build
  APP_VERSION=0.0.0 APP_BUILD_NUMBER=0 make release
  test -f CCProxy.app/Contents/Resources/model-catalog-snapshot.json
  python3 -m json.tool CCProxy.app/Contents/Resources/model-catalog-snapshot.json >/dev/null
  ```
  Expected result: `make backend-version` exits zero and prints `CLIProxyAPI Version`; `make test` exits zero with all XCTest suites passing; `make build` exits zero and prints `Build complete: src/.build/debug/CCProxy`; `make release` exits zero and prints `Build complete: CCProxy.app`; `CCProxy.app/Contents/Resources/model-catalog-snapshot.json` exists and is parseable JSON. If Python 3 is unavailable, use `swift -e 'import Foundation; let url = URL(fileURLWithPath: "CCProxy.app/Contents/Resources/model-catalog-snapshot.json"); _ = try JSONSerialization.jsonObject(with: Data(contentsOf: url)); print("parseable")'` and expect `parseable`.
- [ ] Do not add live-network production-default tests or optional live OpenCode Go discovery checks. Expected result: any production-default provider verification uses injected fake fetcher, temporary runtime-cache path, and temporary bundled-snapshot path; live network access is not required for local verification.
- [ ] Re-run the singleton-divergence source guard before execute reviews:
  ```bash
  ! rg 'ServerManager\.shared' src/Sources/ThinkingProxy.swift src/Sources/AppDelegate.swift src/Sources/ExternalModelCatalog.swift src/Sources/ServerManager.swift
  ```
  Expected result: command exits zero, proving no production `ServerManager.shared` path remains in the `/v1/models` catalog filtering source set, including `src/Sources/ServerManager.swift`.

## Code Review Gates Before PR Work

- [ ] Run EasyCode execute-stage reviews after implementation and local verification:
  - `code-spec-reviewer` must PASS for spec alignment, messages-only OpenCode Go routing, external catalog source precedence, cache semantics, bundled snapshot behavior, and no hardcoded runtime model catalog fallback.
  - `code-quality-reviewer` must PASS for maintainability, minimal scope, deterministic snapshot behavior, failure handling, no per-request network fetch, and no secrets.
  - `completion-verifier` must PASS using fresh local `git status`, `git diff`, `make backend-version`, `make test`, `make build`, `APP_VERSION=0.0.0 APP_BUILD_NUMBER=0 make release`, `test -f CCProxy.app/Contents/Resources/model-catalog-snapshot.json`, and JSON parse evidence for `CCProxy.app/Contents/Resources/model-catalog-snapshot.json`.
- [ ] If any execute review fails, return to executor with reviewer findings and repeat the TDD cycle. Do not create a PR until all execute reviews and final-review PASS.

## Commit Plan

- [ ] Before committing, inspect status, diff, and recent history:
  ```bash
  git status --short
  git diff
  git log --oneline -10
  ```
  Expected result: only intended files are present; no secrets, app bundles, build products, or local cache files are staged.
- [ ] Commit after full verification passes:
  ```bash
  git add docs/easycode/2026-06-05-opencode-go-models-dev-catalog/plan.md src/Sources/AuthStatus.swift src/Sources/ServerManager.swift src/Sources/SettingsView.swift src/Sources/ThinkingProxy.swift src/Sources/AppDelegate.swift src/Sources/ExternalModelCatalog.swift src/Tests/CCProxyTests/AuthStatusTests.swift src/Tests/CCProxyTests/ServerManagerConfigTests.swift src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift src/Tests/CCProxyTests/ExternalModelCatalogTests.swift src/Tests/CCProxyTests/OpenCodeGoProviderTests.swift src/Sources/Resources/model-catalog-snapshot.json scripts/generate-model-catalog-snapshot.swift Makefile create-app-bundle.sh README.md README.ko.md
  git commit -m "Add OpenCode Go catalog-backed models"
  ```
  Expected result: one implementation commit is created on `work/2026-06-05-opencode-go-models-dev-catalog`.
- [ ] If review feedback requires separate commits, use these boundaries only after each boundary passes focused tests:
  - `Add OpenCode Go hosted provider`
  - `Use cached external model catalog`
  - `Bundle generated model catalog snapshot`

## Finish-Stage Push, PR, Merge, And Cleanup Commands

- [ ] After execute completion, final-review PASS, and active unattended finish approval, push the branch:
  ```bash
  git push -u origin work/2026-06-05-opencode-go-models-dev-catalog
  ```
  Expected result: feature branch is pushed to origin.
- [ ] Create the PR from the worktree:
  ```bash
  gh pr create --base main --head work/2026-06-05-opencode-go-models-dev-catalog --title "Add OpenCode Go catalog-backed models" --body "Adds OpenCode Go as a hosted Anthropic-compatible provider and replaces runtime hardcoded model-list catalog behavior with a cached external catalog and bundled generated snapshot.\n\nVerification:\n- make backend-version\n- make test\n- make build\n- APP_VERSION=0.0.0 APP_BUILD_NUMBER=0 make release\n- test -f CCProxy.app/Contents/Resources/model-catalog-snapshot.json\n- python3 -m json.tool CCProxy.app/Contents/Resources/model-catalog-snapshot.json >/dev/null"
  ```
  Expected result: GitHub CLI returns a PR URL.
- [ ] Merge the PR only after required checks pass:
  ```bash
  gh pr merge --merge --delete-branch
  ```
  Expected result: PR is merged and remote feature branch is deleted.
- [ ] Update local base branch from the main repository root `/Volumes/storage/workspace/ccproxy`, not from inside the feature worktree:
  ```bash
  git checkout main
  git pull --ff-only origin main
  ```
  Expected result: local `main` fast-forwards to the merged PR.
- [ ] Clean up the EasyCode worktree and local feature branch from the main repository root:
  ```bash
  git worktree remove /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-opencode-go-models-dev-catalog
  git branch -d work/2026-06-05-opencode-go-models-dev-catalog
  ```
  Expected result: worktree is removed and local feature branch is deleted.
- [ ] Do not run release publication, Sparkle archive, appcast, version bump, or app release commands in this finish target.

## Stop Conditions

- Stop if current checkout is not `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-opencode-go-models-dev-catalog` or branch is not `work/2026-06-05-opencode-go-models-dev-catalog`.
- Stop if `spec.md` or `evidence.md` is missing or no longer matches the approved corrected requirements.
- Stop before implementation if `plan-checker` PASS, `plan-challenger` PASS, or unattended/user plan approval is missing.
- Stop if any RED test unexpectedly passes before production code changes; inspect whether the test asserts the intended missing behavior.
- Stop if any GREEN or full verification command fails for an unclear reason; use systematic debugging before changing code further.
- Stop if implementation would add OpenCode Go `/chat/completions` routing, `openai-compatibility` config, Go SDK integration, or direct-client bypass of CCProxy.
- Stop if runtime `/v1/models` would fall back to hardcoded Swift model catalogs or alias tables.
- Stop if `ServerManager.shared` remains in `src/Sources/ThinkingProxy.swift`, `src/Sources/AppDelegate.swift`, `src/Sources/ExternalModelCatalog.swift`, or `src/Sources/ServerManager.swift`, unless both task reviewers explicitly accepted a non-production test-only justification. The default expected result is deletion.
- Stop if snapshot generation would require third-party dependencies or package architecture changes beyond this approved scope.
- Stop if unit tests depend on live network access; use injected fixtures and fake fetchers for tests.
- Stop if `git status --short` shows unrelated modifications, untracked secrets, local cache files, generated app bundles, or build products.
- Stop before PR creation unless execute reviews and final-review PASS.
