# Catalog Source Policy And v0.3.1 Release Evidence

## Internal Evidence

- `src/Sources/AuthStatus.swift` defines the current CCProxy provider identifiers: `claude`, `codex`, `zai`, `minimax`, `kimi`, and `opencode-go`.
- `src/Sources/ServerManager.swift` defines `oauthProviderKeys = ["claude": "claude", "codex": "codex"]`, establishing that the current OAuth providers are `claude` and `codex`.
- `src/Sources/ServerManager.swift` distinguishes connected OAuth providers from API-key providers: OAuth providers require valid OAuth credential files, while API-key providers require non-disabled credentials with non-empty `api_key`.
- `src/Sources/ExternalModelCatalog.swift` currently has a CLIProxyAPI primary mapping for `claude`, `codex-free`, `codex-team`, `codex-plus`, `codex-pro`, and `kimi`.
- `src/Sources/ExternalModelCatalog.swift` currently has a models.dev secondary mapping for all six current providers: `claude -> anthropic`, `codex -> openai`, `zai -> zai-coding-plan`, `minimax -> minimax-coding-plan`, `kimi -> moonshotai`, and `opencode-go -> opencode-go`.
- `scripts/generate-model-catalog-snapshot.swift` duplicates the primary and secondary mapping tables and therefore must be kept in sync with `ExternalModelCatalog.swift`.
- `scripts/generate-model-catalog-snapshot.swift` defines the catalog source URLs: CLIProxyAPI `models.json`, CLIProxyAPI `codex_client_models.json`, and models.dev `api.json`.
- `scripts/generate-model-catalog-snapshot.swift` merges primary data first, supplements Codex metadata from `codex_client_models.json`, and then uses models.dev for missing provider/model entries. Because secondary data is additive, models.dev-only OAuth models can still appear unless OAuth mappings are removed.
- `src/Sources/ExternalModelCatalog.swift` filters catalog snapshots by connected provider keys and renders an OpenAI-style `{ object: "list", data: [...] }` response.
- `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift` pins exact primary and secondary mappings and must be updated when policy changes.
- `src/Tests/CCProxyTests/ServerManagerConfigTests.swift` contains a test locking OAuth provider keys to `claude` and `codex`.
- `create-app-bundle.sh` runs the model catalog snapshot generator before building the app bundle and injects release metadata from `APP_VERSION` and `APP_BUILD_NUMBER` into `CCProxy.app/Contents/Info.plist`.
- `Makefile` provides release-relevant targets including `model-catalog-snapshot`, `build`, `release`, `sparkle-archive`, `test`, and `test-snapshot-generator`.
- Current `appcast.xml` is for `0.3.0` build `13`, so `v0.3.1` build `14` requires a new appcast update and signature.

## External Evidence

- The user-provided CLIProxyAPI registry URL is `https://github.com/router-for-me/CLIProxyAPI/blob/5753d1a0896fd5bb9ace47adb17b0174ceb79e4d/internal/registry/models/models.json`.
- The commit-pinned raw registry URL is `https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/5753d1a0896fd5bb9ace47adb17b0174ceb79e4d/internal/registry/models/models.json`.
- At commit `5753d1a0896fd5bb9ace47adb17b0174ceb79e4d`, `models.json` is a single JSON registry file in the CLIProxyAPI source tree with top-level provider/category keys including `claude`, `gemini`, `vertex`, `gemini-cli`, `aistudio`, `codex-free`, `codex-team`, `codex-plus`, `codex-pro`, `kimi`, `antigravity`, and `xai`.
- The external evidence supports treating commit-pinned CLIProxyAPI `models.json` as the reproducible official registry source for OAuth provider support. The work must not infer support from unpinned branches or third-party sources.

## Checked Scope

- Internal repository evidence checked by explorer: provider identifiers, OAuth/API-key classification, primary/secondary catalog mappings, snapshot generator source URLs and merge order, model list filtering/rendering, tests pinning mappings and OAuth keys, release script version/build injection, Makefile release targets, and current appcast version/build.
- External evidence checked by librarian: the user-provided commit-pinned CLIProxyAPI `models.json` file and its raw permalink.
- User decisions checked in chat: `v0.3.1` / build `14`, unattended release target, Sparkle key path, and container reflection out of scope.

## Unchecked Scope

- The full current contents of `src/Sources/Resources/model-catalog-snapshot.json` were not inspected during the spec stage.
- The exact final implementation files and test names are not fixed by this spec; those belong to the plan stage.
- GitHub tag/release absence for `v0.3.1` has not yet been checked in the spec stage and must be checked before publication.
- Sparkle key readability/public-key matching has not yet been revalidated for this new release and must be verified before signing.

## Unresolved Uncertainty

- Whether a future CCProxy provider for `xai`/Grok should be added is out of scope; current work only defines the policy if such a provider is added later.
- If CLIProxyAPI updates after commit `5753d1a0896fd5bb9ace47adb17b0174ceb79e4d`, the plan must decide whether to pin this exact registry evidence or validate a newer backend registry as part of release execution.
