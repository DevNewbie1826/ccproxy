# OpenCode Go Provider And External Model Catalog Evidence

## Internal Evidence

- `src/Package.swift:1-36` — The project is a Swift Package targeting macOS 13+ and currently has no Go module/dependency surface relevant to a Go-language SDK integration.
- `README.md:9-15,25-34` — The project is a macOS menu-bar app that runs a local proxy on `localhost:8317` and is focused on opening the provider layer/routing across providers.
- `src/Sources/AuthStatus.swift:3-19` — Provider/service types are statically represented today, including providers such as `claude`, `codex`, `zai`, `minimax`, and `kimi`.
- `src/Sources/ServerManager.swift:465-506` — Existing API-key hosted providers store credentials as `0o600` JSON files in `~/.cli-proxy-api/`, providing a safe pattern for OpenCode Go API-key storage.
- `src/Sources/ServerManager.swift:509-656` — `getConfigPath()` is the central config-merging seam that adds hosted provider upstreams into the generated merged config.
- `src/Sources/ServerManager.swift:582-620` — Existing `claudeCompatibleProviders` tuple array is the minimal-change seam for adding another hosted upstream when compatible with the current backend config model.
- `src/Sources/ThinkingProxy.swift:1135-1147` — The proxy recognizes `GET /v1/models` model-list requests.
- `src/Sources/ThinkingProxy.swift:1061-1117` — Existing model-list transformation deduplicates aliases and normalizes `owned_by` using hardcoded alias/canonical behavior; this is the runtime catalog behavior the user wants removed/replaced, not preserved as a fallback catalog.
- `src/Sources/ThinkingProxy.swift:1286-1383` — Existing HTTP response rewriting for model-list responses already handles headers and body replacement mechanics.
- `src/Sources/ServerManager.swift:130-135` — Existing provider enable/disable state exists and is relevant to defining connected providers.
- `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift` — Existing tests cover model alias and model-list transformation behavior, providing a non-regression test area.
- Repository search found no existing `models.dev`, `modelsDev`, `catalog`, `fetchModels`, `loadModels`, or `providerList` implementation in Swift sources.
- Repository search found no `*.go` files or `go.mod`, supporting that OpenCode Go should be treated as a hosted provider, not a Go-language library dependency.

## External Evidence

- `https://opencode.ai/ko/go` — Korean landing page for OpenCode Go; describes it as a low-cost coding model subscription and not a Go-language SDK.
- `https://opencode.ai/docs/go/` — Official OpenCode Go docs describe setup through OpenCode provider connection, model IDs in the form `opencode-go/<model-id>`, direct compatible endpoints, and model-list endpoint information.
- `https://opencode.ai/docs/go/` — Documents OpenAI-compatible `https://opencode.ai/zen/go/v1/chat/completions`, Anthropic-compatible `https://opencode.ai/zen/go/v1/messages`, and model-list endpoint `https://opencode.ai/zen/go/v1/models`.
- `https://github.com/anomalyco/opencode/commit/3beadee` — Official OpenCode source adds the OpenCode Go `/zen/go/v1/models` route and allows the `Authorization` CORS header.
- `https://github.com/anomalyco/opencode/commit/5cf195e` — Official OpenCode source shows model handler parsing `headers.get("authorization")?.split(" ")[1]`, supporting `Authorization: Bearer <token>` usage.
- `https://opencode.ai/` — Describes OpenCode provider/model support through Models.dev.
- `https://models.dev/api.json` — Official models.dev catalog endpoint for provider/model metadata.
- `https://models.dev/model-schema.json` — Official models.dev schema endpoint for valid provider/model identifiers.
- `https://github.com/anomalyco/models.dev/blob/dev/README.md` — Official models.dev documentation describes provider/model catalog structure.
- `https://models.dev/api.json` provider-key research confirmed the following current mappings: CCProxy `claude` -> `anthropic`, `codex` -> `openai`, `kimi` -> `moonshotai`.
- User selected CCProxy Z.AI -> `zai-coding-plan`, MiniMax -> `minimax-coding-plan`, OpenCode Go -> `opencode-go`, and Kimi -> `moonshotai`.
- Follow-up models.dev research confirmed `zai-coding-plan` as an official top-level provider key with provider metadata: name `Z.AI Coding Plan`, env `ZHIPU_API_KEY`, npm `@ai-sdk/openai-compatible`, API `https://api.z.ai/api/coding/paas/v4`.
- Follow-up models.dev research confirmed MiniMax coding-plan providers exist, including `minimax-coding-plan`.
- Follow-up OpenCode Go provider-key research confirmed `opencode-go` as a first-class models.dev provider key for OpenCode Go, distinct from `opencode` / OpenCode Zen.
- `https://opencode.ai/docs/go/` — Official OpenCode docs describe model IDs in the form `opencode-go/<model-id>`, with examples such as `opencode-go/kimi-k2.6`.
- Official OpenCode source treats `opencode-go` as a provider id in provider selection UI with the description "Low cost subscription for everyone".
- `https://github.com/router-for-me/CLIProxyAPI/tree/main/internal/registry/models` — User selected the CLIProxyAPI registry models path as the primary external catalog source because it is closest to the backend/proxy catalog lineage CCProxy already depends on.
- `https://github.com/automazeio/vibeproxy` / bundled `cli-proxy-api-plus` research — VibeProxy delegates `/v1/models` to a bundled backend registry using an embedded/network-refreshed model catalog rather than per-request provider live fetches or models.dev-only behavior. This supports an external-catalog-plus-cache strategy.
- User selected a build-time latest external catalog snapshot bundled into the app so no-cache first launch does not immediately fail.

## Release Process Evidence

- `Makefile` — Defines release, Sparkle archive, test, build, and backend-version targets used by existing app releases.
- `create-app-bundle.sh` — Builds `CCProxy.app`, injects `APP_VERSION` and `APP_BUILD_NUMBER`, configures Sparkle feed URL, and signs the bundle.
- `scripts/generate-sparkle-appcast.sh` — Generates `appcast.xml` with Sparkle EdDSA signature from a release archive.
- `scripts/update-cli-proxy-api.sh` — Updates the bundled CLIProxyAPI backend release and verifies it with `make backend-version`.
- `appcast.xml` — Current Sparkle feed advertises the current release metadata.
- `src/Info.plist` — Contains Sparkle update configuration including `SUFeedURL` and `SUPublicEDKey`.
- `docs/easycode/2026-06-03-app-release-v0-1-10/plan.md` — Prior EasyCode release plan documenting the canonical release workflow.
- `docs/easycode/2026-06-04-app-release-v0-2-0/spec.md` and `evidence.md` — Prior release artifacts documenting the release process and evidence.
- `docs/easycode/2026-06-04-app-release-v0-2-0/final-review.md` — Records a prior release final-review PASS and verification evidence.

## Checked Scope

- Internal repository evidence checked by read-only explorer research:
  - Build/package surface.
  - Provider enum/auth status surface.
  - ThinkingProxy model-list request and response transformation logic.
  - ServerManager provider enablement surface.
  - Existing model alias tests.
  - API-key credential storage and config-merge seams for hosted providers.
  - Repo-wide search for Go files and existing catalog/models.dev code.
- External evidence checked by read-only librarian research:
  - Official OpenCode Go Korean landing page.
  - Official OpenCode Go docs.
  - Official OpenCode root page statement about Models.dev.
  - Official models.dev API/schema documentation/endpoints.
  - Official OpenCode source commits related to OpenCode Go model listing and authorization parsing.
  - Official models.dev API/provider sources for current provider-key mapping.
  - VibeProxy / CLIProxyAPIPlus model-list architecture for comparison with registry-based cached catalog behavior.
- Release process evidence checked by read-only explorer research:
  - Makefile release/test/build/backend-version targets.
  - App bundle creation script.
  - Sparkle appcast generation script.
  - CLIProxyAPI backend updater script.
  - Current appcast and Info.plist update metadata.
  - Prior EasyCode release specs/plans/evidence/final-review artifacts.

## Unchecked Scope

- Exact implementation details of any bundled upstream backend/proxy binary beyond repository-visible Swift code.
- Live authentication behavior against OpenCode Go endpoints using a real subscription key.
- Full models.dev schema evolution and all provider-specific identifier mismatches.
- Exact raw file/API shape under `router-for-me/CLIProxyAPI/tree/main/internal/registry/models`; planning should inspect this source before implementation.
- Exact build-time snapshot generation mechanism and whether it belongs in an existing build/release script or a new helper script; planning should decide based on repository conventions.
- Whether CCProxy should also expose the non-coding-plan `zai` or `minimax` models.dev providers in addition to the user-selected coding-plan mappings; current spec maps CCProxy's existing Z.AI and MiniMax surfaces to the coding-plan providers only.
- Verbatim `opencode-go` JSON block from `https://models.dev/api.json`; follow-up research established the key's existence from official docs/source and dependent catalog consumers, but did not capture the raw JSON block because the API payload is large and single-line.
- Whether the current backend config model can represent both OpenCode Go OpenAI-compatible and Anthropic-compatible endpoints without additional proxy-specific handling.
- Live remote tag/GitHub Release state for the future release version, which must be checked at finish time.

## Unresolved Uncertainty

- Public docs and official source support `Authorization: Bearer <OPENCODE_API_KEY>`, but live verification with a configured subscription key is still needed before claiming end-to-end success.
- Confirmed/user-selected provider-key mappings exist for `claude`, `codex`, `zai`, `minimax`, `kimi`, and OpenCode Go.
- External catalog sources have no guaranteed availability in the checked evidence, so implementation should cache external-source-derived data defensively with the user-selected six-hour refresh policy and include a build-time external-source-derived snapshot. The user clarified that hardcoded catalog fallback should not remain supported.
- The current backend/config path may need careful handling for OpenCode Go models split across OpenAI-compatible and Anthropic-compatible endpoint families.
- The release version/build number must be derived safely from existing release conventions during planning; it should not be guessed in the spec.
