# Catalog Source Policy And v0.3.1 Release Implementation Plan

> **For agentic workers:** Each task is dispatched to the `executor` agent. Follow the EasyCode `execute` stage: per-task TDD cycle, `code-spec-reviewer` and `code-quality-reviewer` review gates, and `completion-verifier` for final evidence. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce CCProxy catalog source policy for OAuth versus compatible/API-key providers, regenerate the bundled catalog snapshot, and prepare the signed `v0.3.1` build `14` release assets without committing generated app archives or secrets.

**Architecture:** CCProxy builds `/v1/models` from `ExternalModelCatalog` by parsing CLIProxyAPI `models.json`, supplementing Codex metadata from `codex_client_models.json`, and merging models.dev data before filtering by connected providers. The standalone snapshot generator duplicates the production mapping tables to produce `src/Sources/Resources/model-catalog-snapshot.json`, so production and generator mappings must change together and be guarded by tests. Release packaging is driven by `create-app-bundle.sh`, `make sparkle-archive`, Sparkle `sign_update`, `appcast.xml`, and GitHub Release assets.

**Tech Stack:** Swift 5.9 package, XCTest via SwiftPM, shell scripts, Makefile targets, Sparkle 2.x signing tools from `src/.build/artifacts/sparkle/Sparkle/bin`, Git, GitHub CLI, macOS app bundle tooling, Python 3 for JSON/XML verification snippets, and Python `cryptography` for Sparkle Ed25519 public-key derivation from 32-byte seed key files.

## Approved Inputs And Baseline

- Approved spec: `docs/easycode/2026-06-06-catalog-source-policy-v0-3-1-release/spec.md`
- Approved evidence: `docs/easycode/2026-06-06-catalog-source-policy-v0-3-1-release/evidence.md`
- Worktree path: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-catalog-source-policy-v0-3-1-release`
- Branch: `work/2026-06-06-catalog-source-policy-v0-3-1-release`
- Baseline status: ready
- Baseline command: `make backend-version && scripts/test-snapshot-generator.sh && make test && make build`
- Baseline result: passed; output artifact `/Users/mirage/.local/share/opencode/tool-output/tool_e98a43ab8001J1Dn7mGNkvXmv0`; tests 243 executed, 1 skipped, 0 failures; build passed
- Degraded-baseline caveat: none
- CodeGraph note: CodeGraph exploration for `ExternalModelCatalog model catalog mappings snapshot generator tests Makefile sparkle archive appcast` warned that the available index was from the root worktree, so exact file evidence was verified through direct reads in the isolated worktree.

## Execute Resume Context

- This plan revision resumes mid-execute after a Task 2A review failure; it is not a pristine pre-execute plan.
- Tasks 0, 1, and 2 are completed checkpoints and already received task-level `code-spec-reviewer` PASS and `code-quality-reviewer` PASS. Their RED/GREEN commands below are retained as historical execution evidence and review context, not as commands to rerun against the current dirty worktree.
- The previous Task 2A attempt observed RED for stale schema `"1"` snapshot acceptance, then failed review because schema validation, generator schema/mapping updates, bundled snapshot regeneration, and affected fixture updates were not completed as one atomic consistent unit.
- The current worktree may already contain approved completed diffs from Tasks 0-2 plus in-progress Task 2A remediation diffs, including URL pins, source-policy tests/mappings, production schema `"2"` validation, and partial schema `"2"` fixture changes.
- The executor must not try to rerun Tasks 0-2 from a pristine baseline, must not restore or revert their approved changes, and must not treat their historical RED expectations as current expected failures.
- Remaining execution resumes at Task 2A remediation and atomic completion. Task 2A must complete fixture migration, generator mapping/schema updates, bundled snapshot regeneration, and validation as one review unit before requesting task-level review.
- Task 2A has a documented historical TDD evidence gap: pre-edit RED evidence was not captured for `testProviderSourcePolicy_snapshotGeneratorMappingsMatchProductionPolicy` before generator mapping/schema edits. This plan revision does not pretend that evidence exists. Reviewers must judge that guard against the recovery evidence path in Task 2A: a reversible negative-control mutation of only `scripts/generate-model-catalog-snapshot.swift` back to the old/wrong generator mapping/schema, focused RED showing the guard fails, byte-for-byte restoration of the current generator file, and focused/broad GREEN verification.
- Executor-provided recovery evidence paths for the Task 2A generator guard are: RED `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/task2a-red-green-evidence/red-generator-guard.txt`; focused GREEN `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/task2a-red-green-evidence/green-generator-guard-focused.txt`; broad GREEN `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/task2a-red-green-evidence/green-broad-tests.txt`; snapshot-generator GREEN `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/task2a-red-green-evidence/green-snapshot-generator-script.txt`.
- No separate state, ledger, or progress artifact records this context; this section is the sole workflow progress context for the resume.

## Scope Lock

- Enforce provider source policy only for current CCProxy providers: `claude`, `codex`, `zai`, `minimax`, `kimi`, and `opencode-go`.
- Do not add `grok` or `xai` as a provider.
- Do not implement container reflection, Docker changes, live `/v1/models` network fetching, OAuth credential redesign, or Sparkle key storage changes.
- Do not touch root checkout `.gitignore`; it has a pre-existing dirty change outside this work.
- Do not commit `CCProxy.app`, `CCProxy.app.zip`, staged release copies, Sparkle private key files, decoded key bytes, or temporary build products.

## File Structure

Modify source:
- `src/Sources/ExternalModelCatalog.swift`
  - Remove `"kimi": "kimi"` from `ExternalModelCatalog.primaryProviderMapping`.
  - Remove `"claude": "anthropic"` and `"codex": "openai"` from `ExternalModelCatalog.secondaryProviderMapping`.
  - Keep compatible/API-key provider secondary mappings: `zai`, `minimax`, `kimi`, `opencode-go`.
  - Pin production `URLSessionCatalogFetcher` CLIProxyAPI URLs for both `models.json` and `codex_client_models.json` to approved commit `5753d1a0896fd5bb9ace47adb17b0174ceb79e4d`.
  - Add cache policy version validation so old runtime cache snapshots generated under the previous source policy are rejected and cannot expose models.dev-only OAuth models.

Modify generator:
- `scripts/generate-model-catalog-snapshot.swift`
  - Apply the same primary and secondary mapping changes as production.
  - Pin both CLIProxyAPI source URLs to approved commit `5753d1a0896fd5bb9ace47adb17b0174ceb79e4d`: `models.json` and `codex_client_models.json` must no longer default to `CLIProxyAPI/main`.
  - Emit the new catalog policy schema version expected by production validation.

Modify tests:
- `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift`
  - Update existing mapping/merge tests for the new policy.
  - Add guard tests proving OAuth providers are absent from secondary mapping and absent from merged output via models.dev-only fixtures, while compatible/API-key providers remain present from models.dev.
  - Add guard tests proving source and generator text mappings remain in sync enough to catch future drift.
  - Add cache validation tests proving stale old-policy runtime snapshots are rejected and fresh policy-version snapshots remain valid.
- `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`
  - Update any current-valid bundled/runtime snapshot fixture, helper, or assertion affected by the schema bump from `"1"` to `"2"`.
- `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`
  - Update any current-valid bundled/runtime snapshot fixture, helper, or assertion affected by the schema bump from `"1"` to `"2"`.
- Any other current repository test fixture/helper discovered during execution that intentionally models a valid runtime or bundled catalog snapshot
  - Update current-valid schema values to `"2"`; keep schema `"1"` only for explicit stale old-policy invalidation/fallback fixtures.

Modify test scripts:
- `scripts/test-snapshot-generator.sh`
  - Update snapshot generator expectations, fixture assertions, or deterministic-output checks affected by the schema bump to `"2"` and by required `sources` entries.

Regenerate tracked data:
- `src/Sources/Resources/model-catalog-snapshot.json`
  - Regenerate through `make model-catalog-snapshot` after tests and mapping changes.

Modify release metadata:
- `appcast.xml`
  - Replace the current `0.3.0` build `13` entry with `0.3.1` build `14`, release URL `https://github.com/DevNewbie1826/ccproxy/releases/download/v0.3.1/CCProxy.app.zip`, archive byte length, and Sparkle EdDSA signature for the exact final archive.

Generated but not committed:
- `CCProxy.app`
- `CCProxy.app.zip`
- `/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip`

## Safety Preflight Before Any Implementation Edit

- [ ] Enter the isolated worktree:
  ```bash
  pwd && git rev-parse --show-toplevel && git branch --show-current
  ```
  Expected output includes `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-catalog-source-policy-v0-3-1-release` for both `pwd` and top-level, and `work/2026-06-06-catalog-source-policy-v0-3-1-release` for the branch. Stop if the top-level is `/Volumes/storage/workspace/ccproxy`.

- [ ] Inspect worktree state without touching root `.gitignore`:
  ```bash
  git status --short
  ```
  Expected output may include approved completed Tasks 0-2 diffs and in-progress Task 2A remediation diffs only. Stop if `.gitignore`, Sparkle key files, `CCProxy.app`, or `CCProxy.app.zip` are staged.

- [ ] Validate that current implementation diffs are explained by completed Tasks 0-2 or in-progress Task 2A remediation before editing anything else:
  ```bash
  git diff --name-only
  ```
  Expected output is limited to `docs/easycode/2026-06-06-catalog-source-policy-v0-3-1-release/plan.md`, `src/Sources/ExternalModelCatalog.swift`, `scripts/generate-model-catalog-snapshot.swift`, `scripts/test-snapshot-generator.sh`, `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift`, `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`, `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`, `src/Sources/Resources/model-catalog-snapshot.json`, and any other current-valid snapshot fixture/helper explicitly needed for Task 2A schema `"2"` remediation. Stop if any other implementation file is modified unless executor evidence can tie it directly to completed Tasks 0-2 or Task 2A remediation under the approved spec.

- [ ] Verify release/tag absence before release work proceeds:
  ```bash
  git fetch origin --tags --prune && local_tag="$(git tag -l 'v0.3.1')" && test -z "$local_tag" && remote_tag="$(git ls-remote --tags origin 'refs/tags/v0.3.1')" && test -z "$remote_tag" && if gh release view v0.3.1 >/dev/null 2>&1; then echo "release v0.3.1 already exists" >&2; exit 1; else echo "release v0.3.1 absent"; fi
  ```
  Expected output: `release v0.3.1 absent` and exit code 0. Local tag lookup and remote tag lookup must both be empty. Stop if a local tag, remote tag, or GitHub Release already exists.

- [ ] Verify Sparkle key file presence without printing contents:
  ```bash
  test -f "/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key" && test -s "/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key" && test -x "src/.build/artifacts/sparkle/Sparkle/bin/sign_update"
  ```
  Expected output: no output and exit code 0. Stop if any test fails. Do not run `cat`, `base64 -d`, or any command that prints private key material.

- [ ] Confirm the approved external release staging path is outside the repository before using it:
  ```bash
  python3 - <<'PY'
  from pathlib import Path
  repo = Path('/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-catalog-source-policy-v0-3-1-release').resolve()
  stage = Path('/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip').resolve()
  assert repo not in (stage, *stage.parents), f'staging path is inside repo: {stage}'
  print('external staging path verified')
  PY
  ```
  Expected output: `external staging path verified`. Stop if the assertion fails; use no in-repository release staging path.

## Pre-Execute Gate

- [ ] Do not resume Task 2A remediation or any implementation work until the EasyCode plan stage is complete: `plan-checker` returned PASS, `plan-challenger` returned PASS, and user approval or unattended-mode plan approval accepted this exact plan revision.
- [ ] Before that plan-stage gate is complete, do not edit implementation files, run implementation TDD cycles, create implementation commits, push branches, create PRs, perform release build/signing work, publish releases, merge PRs, update local `main`, or run finish cleanup commands.
- [ ] If this plan changes after reviewer PASS, return to the plan reviewer gates and obtain approval for the revised artifact before resuming Task 2A.

## Task 0: Completed Checkpoint - Pin CLIProxyAPI Catalog Source URLs RED And GREEN

Status: completed and reviewed PASS before this resume revision. The steps in this section are historical evidence for completed Task 0; do not rerun the RED command expecting failure in the current dirty worktree, and do not revert approved Task 0 URL pin changes.

- [ ] Edit only `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift`.
- [ ] Add failing source URL policy tests with these exact behaviors:
  - Add a small test helper that derives paths from `#filePath` by walking parent directories until it finds `Package.swift`; that directory is the SwiftPM package root (`src`), and its parent is the repository root. The helper must build `packageRoot.appendingPathComponent("Sources/ExternalModelCatalog.swift")` and `repoRoot.appendingPathComponent("scripts/generate-model-catalog-snapshot.swift")`. Do not use hard-coded parent traversal strings for repository files.
  - `testProviderSourcePolicy_snapshotGeneratorPinsCLIProxyAPISourcesToApprovedCommit` reads the generator file using the helper-derived repository-root path and asserts the generator contains the approved commit URLs for `models.json` and `codex_client_models.json`, and does not contain the corresponding `CLIProxyAPI/main` URLs.
  - `testProviderSourcePolicy_productionFetcherPinsCLIProxyAPISourcesToApprovedCommit` reads `ExternalModelCatalog.swift` using the helper-derived package-root path and asserts production `URLSessionCatalogFetcher` source contains the approved commit URLs for `models.json` and `codex_client_models.json`, and does not contain the corresponding `CLIProxyAPI/main` URLs.
- [ ] Run RED before editing production or generator source URLs:
  ```bash
  cd src && swift test --filter 'ExternalModelCatalogTests.testProviderSourcePolicy_snapshotGeneratorPinsCLIProxyAPISourcesToApprovedCommit|ExternalModelCatalogTests.testProviderSourcePolicy_productionFetcherPinsCLIProxyAPISourcesToApprovedCommit'
  ```
  Expected failure mode: production and generator still default both CLIProxyAPI URLs to `main`, so the tests fail on the approved commit assertions.

- [ ] Edit only `src/Sources/ExternalModelCatalog.swift` and `scripts/generate-model-catalog-snapshot.swift`.
- [ ] In both production `URLSessionCatalogFetcher` and snapshot generator defaults, change the `models.json` URL to `https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/5753d1a0896fd5bb9ace47adb17b0174ceb79e4d/internal/registry/models/models.json`.
- [ ] In both production `URLSessionCatalogFetcher` and snapshot generator defaults, change the `codex_client_models.json` URL to `https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/5753d1a0896fd5bb9ace47adb17b0174ceb79e4d/internal/registry/models/codex_client_models.json`.
- [ ] Keep the snapshot generator's existing environment override behavior for `MODEL_CATALOG_MODELS_JSON_URL` and `MODEL_CATALOG_CODEX_CLIENT_URL` so generator script tests can use local fixtures. Do not add production environment override behavior; production tests must use source-text assertions, injected `CatalogFetcher` fakes, or existing test fixture mechanisms.
- [ ] Run GREEN:
  ```bash
  cd src && swift test --filter 'ExternalModelCatalogTests.testProviderSourcePolicy_snapshotGeneratorPinsCLIProxyAPISourcesToApprovedCommit|ExternalModelCatalogTests.testProviderSourcePolicy_productionFetcherPinsCLIProxyAPISourcesToApprovedCommit'
  ```
  Expected output: both pinning tests pass with zero failures.

- [ ] Verify production and generator no longer default to `main` for CLIProxyAPI sources:
  ```bash
  python3 - <<'PY'
  from pathlib import Path
  for path in ['src/Sources/ExternalModelCatalog.swift', 'scripts/generate-model-catalog-snapshot.swift']:
      s = Path(path).read_text()
      assert 'CLIProxyAPI/main/internal/registry/models/models.json' not in s, path
      assert 'CLIProxyAPI/main/internal/registry/models/codex_client_models.json' not in s, path
      assert 'CLIProxyAPI/5753d1a0896fd5bb9ace47adb17b0174ceb79e4d/internal/registry/models/models.json' in s, path
      assert 'CLIProxyAPI/5753d1a0896fd5bb9ace47adb17b0174ceb79e4d/internal/registry/models/codex_client_models.json' in s, path
  print('CLIProxyAPI source pins verified')
  PY
  ```
  Expected output: `CLIProxyAPI source pins verified`.

## Task 1: Completed Checkpoint - Catalog Source Policy Tests RED

Status: completed and reviewed PASS before this resume revision. The steps in this section are historical evidence for completed Task 1; do not rerun the RED command expecting failure in the current dirty worktree, and do not revert approved Task 1 policy tests.

- [ ] Edit only `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift`.
- [ ] Add failing policy guard tests with these exact behaviors:
  - `testProviderSourcePolicy_secondaryMappingExcludesOAuthProviders` verifies `ExternalModelCatalog.secondaryProviderMapping` has no `claude` or `codex` entries and still maps `zai`, `minimax`, `kimi`, and `opencode-go` to models.dev provider keys.
  - `testProviderSourcePolicy_modelsDevOnlyFixtureDoesNotExposeOAuthProviders` uses a fixture containing only models.dev `anthropic` and `openai` providers, merges with no primary and no Codex client source, filters connected providers `claude` and `codex`, and expects no `claude/` or `codex/` models in the rendered/filtered output.
  - `testProviderSourcePolicy_primaryRegistryDoesNotExposeCompatibleApiKeyKimiWithoutModelsDev` merges `modelsJSONFixture` with no secondary source, filters connected provider `kimi`, and expects no `kimi/` models. Do not require `parseModelsJSON` itself to omit the raw `kimi` key; parser semantics may continue to parse raw keys.
  - `testProviderSourcePolicy_mergeDoesNotAddModelsDevOnlyOAuthModels` merges all fixtures, expects `claude` IDs to be exactly `claude-opus-4` and `claude-sonnet-4`, and expects `codex` IDs not to include `gpt-4o-mini`.
  - `testProviderSourcePolicy_compatibleProvidersStillUseModelsDev` merges all fixtures and expects `zai/glm-5.1`, `zai/glm-5`, `minimax/MiniMax-M2.7`, `kimi/kimi-k2`, and `opencode-go/kimi-k2.6` to be present after filtering all current providers.
  - `testProviderSourcePolicy_noGrokOrXaiProviderAdded` verifies merged `providerModels` does not contain `grok` or `xai`.
- [ ] Update existing tests in the same file only when necessary to express the new expected policy; do not edit production code yet.
- [ ] Run RED:
  ```bash
  cd src && swift test --filter ExternalModelCatalogTests
  ```
  Expected failure mode: the newly added tests fail because current production still maps `claude` and `codex` through models.dev secondary mapping, still exposes `kimi` through CLIProxyAPI primary mapping when models.dev is absent, and still adds models.dev-only `codex/gpt-4o-mini`. Existing tests that pin the old mapping may also fail until expectations are updated.

- [ ] Verify RED is meaningful:
  ```bash
  git diff -- src/Tests/CCProxyTests/ExternalModelCatalogTests.swift
  ```
  Expected output: only test changes are present; no production/source mapping changes are in the diff.

## Task 2: Completed Checkpoint - Production Mapping GREEN

Status: completed and reviewed PASS before this resume revision. The steps in this section are historical evidence for completed Task 2; do not restore old production mappings or rerun this section as if production mapping changes were absent.

- [ ] Edit only `src/Sources/ExternalModelCatalog.swift` and any still-failing assertions in `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift` that encode the old policy.
- [ ] In `ExternalModelCatalog.primaryProviderMapping`, keep only:
  ```swift
  "claude": "claude",
  "codex-free": "codex",
  "codex-team": "codex",
  "codex-plus": "codex",
  "codex-pro": "codex"
  ```
- [ ] In `ExternalModelCatalog.secondaryProviderMapping`, keep only:
  ```swift
  "zai": "zai-coding-plan",
  "minimax": "minimax-coding-plan",
  "kimi": "moonshotai",
  "opencode-go": "opencode-go"
  ```
- [ ] Do not change parsing, merging, filtering, network fetching, provider credential logic, or renderer behavior unless a focused failing test proves it is necessary. Cache validation changes are reserved for Task 2A.
- [ ] Run GREEN for focused production tests:
  ```bash
  cd src && swift test --filter ExternalModelCatalogTests
  ```
  Expected output: `ExternalModelCatalogTests` passes. The expected test count may increase from baseline because new tests were added; failures must be zero.

- [ ] Verify `/v1/models` catalog behavior at the model-filter layer:
  ```bash
  cd src && swift test --filter ThinkingProxyModelAliasTests.testProductionProvider_ReturnsAvailableModelsWhenCatalogAndProvidersExist
  ```
  Expected output: selected test passes, proving production provider wiring can still return catalog data for connected providers.

- [ ] Inspect diff:
  ```bash
  git diff -- src/Sources/ExternalModelCatalog.swift src/Tests/CCProxyTests/ExternalModelCatalogTests.swift
  ```
  Expected output: mapping changes and policy tests only; no `grok` or `xai` additions; no credential or request-path changes.

## Task 2A: Atomic Schema, Generator, Snapshot, And Cache Policy RED/GREEN

This is one atomic executor assignment and one review unit. It prevents existing runtime cache snapshots, including user caches such as `~/.cli-proxy-api/model-catalog-cache.json`, from surviving the source-policy update when they were generated under the old policy. Do not request `code-spec-reviewer` or `code-quality-reviewer` PASS for this task until production schema validation, generator schema/mapping updates, regenerated bundled snapshot, and all affected current-valid fixtures are consistent.

- [ ] Allowed files for this atomic task are exactly `src/Sources/ExternalModelCatalog.swift`, `scripts/generate-model-catalog-snapshot.swift`, `src/Sources/Resources/model-catalog-snapshot.json`, `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift`, `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`, `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`, `scripts/test-snapshot-generator.sh`, and any other current-valid snapshot fixture/helper discovered during execution. Do not include unrelated source changes.

- [ ] Inspect current resume diff before further Task 2A edits:
  ```bash
  git status --short && git diff --name-only && git diff -- src/Sources/ExternalModelCatalog.swift scripts/generate-model-catalog-snapshot.swift scripts/test-snapshot-generator.sh src/Tests/CCProxyTests/ExternalModelCatalogTests.swift src/Tests/CCProxyTests/ServerManagerConfigTests.swift src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift src/Sources/Resources/model-catalog-snapshot.json
  ```
  Expected output: diffs are limited to approved completed Tasks 0-2 and in-progress Task 2A remediation. Stop if unrelated implementation files appear or if app/release artifacts are staged. If generator mapping/schema has already been changed without pre-edit RED evidence, do not revert approved completed work to recreate a pristine baseline; use the Task 2A generator-guard recovery evidence path below and document the historical TDD evidence gap honestly in executor and reviewer summaries.

- [ ] Treat the previous Task 2A cache-schema RED as already observed if executor evidence records the focused stale-schema command failing before production schema validation changed. Do not revert production schema validation or fixtures to recreate that RED.
- [ ] If the previous cache-schema RED evidence is not available and production schema validation has not yet been changed, add or verify the cache invalidation tests below and run the focused RED command. If production schema validation has already changed and no RED evidence exists, stop and report the evidence gap rather than reverting code.
- [ ] Cache invalidation tests must have these exact behaviors:
  - `testRuntimeCache_oldPolicySchemaRejected_fallsBackToBundled` writes a fresh runtime `model-catalog-cache.json` with `schemaVersion: "1"`, sources including `models.dev`, and old-policy OAuth models including `codex/gpt-4o-mini`; writes a valid bundled snapshot using the new policy schema and no models.dev-only OAuth models; configures fetcher errors; expects `CacheCoordinator.getCatalog()` to serve the bundled snapshot, not the runtime cache.
  - `testRuntimeCache_oldPolicySchemaRejected_refreshesWhenPossible` writes the same stale runtime cache, configures fetcher fixture data, calls `getCatalog()`, and expects a refreshed snapshot with no `codex/gpt-4o-mini` plus compatible providers from models.dev.
  - `testSnapshotValidation_acceptsCurrentPolicySchema` builds a snapshot with the new policy schema version, valid sources, and provider models, and expects `ExternalModelCatalog.isValidSnapshot` to return true.
  - `testSnapshotValidation_rejectsOldPolicySchema` builds a snapshot with `schemaVersion: "1"` and otherwise valid-looking old-policy provider models, and expects `ExternalModelCatalog.isValidSnapshot` to return false.
- [ ] Update test fixture helpers and current-valid test snapshots from `schemaVersion: "1"` to `schemaVersion: "2"` wherever they represent valid current-policy bundled/runtime/refreshed snapshots. This explicitly includes `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift`, `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`, `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`, `scripts/test-snapshot-generator.sh`, and any other current repository test fixture/helper discovered during execution that intentionally models a valid runtime or bundled catalog snapshot. Fixture rule: every fixture intended to exercise non-schema validation must use schema `"2"`; schema `"1"` is allowed only for tests explicitly asserting old-policy schema invalidation/fallback.
- [ ] Run cache-schema RED only if the previous RED evidence is missing and production schema validation has not yet been changed:
  ```bash
  cd src && swift test --filter 'ExternalModelCatalogTests.testRuntimeCache_oldPolicySchemaRejected_fallsBackToBundled|ExternalModelCatalogTests.testRuntimeCache_oldPolicySchemaRejected_refreshesWhenPossible|ExternalModelCatalogTests.testSnapshotValidation_rejectsOldPolicySchema'
  ```
  Expected failure mode: stale `schemaVersion: "1"` snapshots are still accepted by current validation, so old-policy runtime cache content can be served.

- [ ] Complete or verify `src/Sources/ExternalModelCatalog.swift` and all affected current-valid fixtures/helpers/assertions in `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift`, `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`, `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`, `scripts/test-snapshot-generator.sh`, and any other discovered current-valid snapshot fixture/helper.
- [ ] Add a single production policy schema constant `static let currentSchemaVersion = "2"` inside `ExternalModelCatalog`.
- [ ] Update `ExternalModelCatalog.isValidSnapshot(_:)` to require `snapshot.schemaVersion == currentSchemaVersion`. Keep existing non-empty source/provider/model-ID validation.
- [ ] Update `ExternalModelCatalog.mergeCatalogs(...)` snapshot creation to emit `schemaVersion: ExternalModelCatalog.currentSchemaVersion` so refreshed runtime caches and in-memory snapshots are valid after the policy change.
- [ ] Ensure all current-valid cache/bundled snapshot tests and script fixtures now use schema `"2"`; stale old-policy cache invalidation/fallback tests must be the only tests that keep schema `"1"`. Structural invalid fixtures that test non-schema validation must also use schema `"2"` so they continue exercising their intended structural failure instead of failing early on schema.
- [ ] Do not add per-user cache deletion, migration files, persistent workflow state, or runtime hooks. Validation-based invalidation is sufficient: stale caches are ignored and refresh/bundled fallback paths already exist.
- [ ] Continue within this same atomic task to update generator mappings/schema and regenerate the bundled snapshot before any review is requested. The atomic task cannot be marked complete until all following substeps pass.

### Task 2A Substep: Generator Policy And Schema RED/GREEN

- [ ] Review and preserve the historical evidence boundary for the generator guard:
  ```bash
  git diff -- scripts/generate-model-catalog-snapshot.swift
  ```
  Expected output may include Task 0 approved URL pin changes plus in-progress Task 2A generator mapping/schema changes. If mapping or schema changes are already present, do not claim pre-edit RED evidence and do not revert the worktree to manufacture history. Continue only if the generator guard exists and the reversible negative-control recovery evidence below is or will be captured.
- [ ] Add or update the generator mapping/schema guard test that reuses the Task 0 helper-derived repository-root path for `scripts/generate-model-catalog-snapshot.swift` and verifies the generator mapping source does not contain `"claude": "anthropic"`, `"codex": "openai"`, or `"kimi": "kimi"`, does contain `"kimi": "moonshotai"`, `"zai": "zai-coding-plan"`, `"minimax": "minimax-coding-plan"`, and `"opencode-go": "opencode-go"`, and emits current policy schema `schemaVersion: "2"` instead of old schema `schemaVersion: "1"`.
- [ ] Use this acceptance rule for `testProviderSourcePolicy_snapshotGeneratorMappingsMatchProductionPolicy`: because pre-edit RED was not captured before the generator mapping/schema edits, reviewers must not require impossible historical RED evidence. Required recovery evidence is a reversible negative-control mutation test: temporarily mutate only `scripts/generate-model-catalog-snapshot.swift` to the old/wrong generator policy/schema (`"claude": "anthropic"`, `"codex": "openai"`, primary `"kimi": "kimi"`, or old schema `"1"` as needed to exercise the guard), run the focused guard test and observe failure, restore the generator file byte-for-byte to the current intended implementation, then rerun focused and broad GREEN commands.
- [ ] If the recovery evidence has not already been captured, capture it with these exact constraints before requesting Task 2A review: no production source, test, snapshot, fixture, appcast, or release artifact may be changed during the negative-control mutation; only `scripts/generate-model-catalog-snapshot.swift` may be temporarily changed and it must be restored byte-for-byte afterward.
- [ ] Run the focused negative-control RED during the temporary mutation, or cite the existing raw evidence path if already captured:
  ```bash
  cd src && swift test --filter ExternalModelCatalogTests.testProviderSourcePolicy_snapshotGeneratorMappingsMatchProductionPolicy
  ```
  Expected failure mode for recovery RED: the guard fails when the generator is temporarily mutated to the old/wrong mapping/schema, proving it detects generator drift. Existing captured RED evidence is `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/task2a-red-green-evidence/red-generator-guard.txt`, which records 5 failures under the negative-control mutation. Stop if the negative-control test passes, if any file other than the generator changed during mutation, or if byte-for-byte restoration cannot be proven.
- [ ] Restore `scripts/generate-model-catalog-snapshot.swift` byte-for-byte after the negative-control RED and verify restoration before GREEN:
  ```bash
  git diff -- scripts/generate-model-catalog-snapshot.swift
  ```
  Expected output: the generator diff is exactly the intended Task 0 and Task 2A implementation diff, with no temporary old/wrong negative-control mutation remaining. If available, compare to the executor's pre-mutation checksum or saved diff in command output; do not create a new artifact file for this plan revision.
- [ ] Edit or verify `scripts/generate-model-catalog-snapshot.swift` within this same atomic task only after either normal pre-edit RED was captured before generator edits or the revised negative-control recovery RED has been captured and restored.
- [ ] Apply the same mapping change as production: remove primary `kimi`; remove secondary `claude` and `codex`; keep secondary `zai`, `minimax`, `kimi`, and `opencode-go`.
- [ ] Update generator snapshot creation to emit the same current policy schema version required by `ExternalModelCatalog.isValidSnapshot`: `schemaVersion: "2"`.
- [ ] Update `scripts/test-snapshot-generator.sh` expectations and fixtures so current-valid generated snapshots use schema `"2"`, required `sources` includes `models.json`, `codex_client_models.json`, and `models.dev`, and stale schema `"1"` appears only in explicit invalidation/fallback test contexts.
- [ ] Run focused generator-guard GREEN after restoration:
  ```bash
  cd src && swift test --filter ExternalModelCatalogTests.testProviderSourcePolicy_snapshotGeneratorMappingsMatchProductionPolicy
  ```
  Expected output: the generator mapping/schema guard passes with zero failures. Existing captured focused GREEN evidence is `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/task2a-red-green-evidence/green-generator-guard-focused.txt`.

### Task 2A Substep: Regenerate Bundled Snapshot And Verify Data

- [ ] Verify both approved pinned CLIProxyAPI raw source URLs fetch and parse before snapshot generation:
  ```bash
  python3 - <<'PY'
  import json
  import urllib.request
  urls = {
      'models.json': 'https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/5753d1a0896fd5bb9ace47adb17b0174ceb79e4d/internal/registry/models/models.json',
      'codex_client_models.json': 'https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/5753d1a0896fd5bb9ace47adb17b0174ceb79e4d/internal/registry/models/codex_client_models.json',
  }
  parsed = {}
  for name, url in urls.items():
      with urllib.request.urlopen(url, timeout=30) as response:
          assert 200 <= response.status < 300, f'{name} HTTP {response.status}'
          parsed[name] = json.loads(response.read().decode('utf-8'))
  assert isinstance(parsed['models.json'], dict) and parsed['models.json'], 'models.json did not parse as non-empty object'
  codex_models = parsed['codex_client_models.json'].get('models')
  assert isinstance(codex_models, list) and codex_models, 'codex_client_models.json missing non-empty models array'
  assert any(isinstance(model, dict) and model.get('slug') for model in codex_models), 'codex_client_models.json has no slug entries'
  print('pinned CLIProxyAPI sources verified, including codex client models')
  PY
  ```
  Expected output: `pinned CLIProxyAPI sources verified, including codex client models`. Stop if either pinned raw URL fails, returns malformed JSON, or `codex_client_models.json` does not contain a non-empty `models` array with slug entries.

- [ ] Regenerate tracked snapshot through the project convention:
  ```bash
  make model-catalog-snapshot
  ```
  Expected output includes `Generating model catalog snapshot` and the Swift generator exits 0.

- [ ] Verify snapshot provider policy using Python 3:
  ```bash
  python3 - <<'PY'
  import json
  from pathlib import Path
  p = Path('src/Sources/Resources/model-catalog-snapshot.json')
  data = json.loads(p.read_text())
  assert data['schemaVersion'] == '2', f"unexpected schemaVersion: {data['schemaVersion']}"
  sources = set(data['sources'])
  for required_source in ['models.json', 'codex_client_models.json', 'models.dev']:
      assert required_source in sources, f'missing snapshot source: {required_source}'
  providers = set(data['providerModels'])
  required = {'claude', 'codex', 'zai', 'minimax', 'kimi', 'opencode-go'}
  missing = required - providers
  forbidden = {'grok', 'xai'} & providers
  assert not missing, f'missing providers: {sorted(missing)}'
  assert not forbidden, f'forbidden providers: {sorted(forbidden)}'
  codex_ids = {m['id'] for m in data['providerModels']['codex']}
  assert 'gpt-4o-mini' not in codex_ids, 'codex contains models.dev-only gpt-4o-mini'
  assert data['providerModels']['kimi'], 'kimi must be populated from models.dev'
  assert data['providerModels']['zai'], 'zai must be populated from models.dev'
  assert data['providerModels']['codex'], 'codex must be populated from pinned CLIProxyAPI and codex client sources'
  print('snapshot policy verified')
  PY
  ```
  Expected output: `snapshot policy verified`. Stop if snapshot `sources` omits `models.json`, `codex_client_models.json`, or `models.dev`; the release must not pass if the Codex supplemental source silently drops.

- [ ] Verify tests cover that the actual tracked bundled snapshot is accepted by `ExternalModelCatalog.isValidSnapshot`:
  ```bash
  cd src && swift test --filter 'ExternalModelCatalogTests|ServerManagerConfigTests|ThinkingProxyModelAliasTests'
  ```
  Expected output: all focused Swift tests pass. The focused tests must include acceptance coverage for the actual bundled `src/Sources/Resources/model-catalog-snapshot.json` through `ExternalModelCatalog.isValidSnapshot`, plus affected ServerManager and ThinkingProxy fixtures.

- [ ] Run atomic GREEN verification:
  ```bash
  cd src && swift test --filter 'ExternalModelCatalogTests|ServerManagerConfigTests|ThinkingProxyModelAliasTests' && cd .. && scripts/test-snapshot-generator.sh
  ```
  Expected output: all `ExternalModelCatalogTests`, `ServerManagerConfigTests`, and affected `ThinkingProxyModelAliasTests` pass with zero failures, including the new stale-runtime-cache tests and actual bundled snapshot acceptance coverage; `scripts/test-snapshot-generator.sh` passes after schema and source-policy updates.

- [ ] Inspect cache validation diff:
  ```bash
  git diff -- src/Sources/ExternalModelCatalog.swift scripts/generate-model-catalog-snapshot.swift src/Sources/Resources/model-catalog-snapshot.json src/Tests/CCProxyTests/ExternalModelCatalogTests.swift src/Tests/CCProxyTests/ServerManagerConfigTests.swift src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift scripts/test-snapshot-generator.sh
  ```
  Expected output: production `currentSchemaVersion = "2"` validation, generator schema/mapping updates, tracked bundled snapshot regeneration to schema `"2"`, affected fixtures, and test script updates are all present together. The actual bundled snapshot must be accepted by `ExternalModelCatalog.isValidSnapshot` via tests. Only explicit stale old-policy invalidation/fallback fixtures remain at schema `"1"`; no user cache files are created, deleted, or committed.

- [ ] Atomic review gate: request `code-spec-reviewer` and `code-quality-reviewer` only after every Task 2A substep above is complete and the full atomic GREEN verification passes. Reviewers must evaluate schema validation, generator mappings/schema, regenerated bundled snapshot, and affected fixtures as one consistent unit.
- [ ] Task 2A review acceptance for the generator mapping/schema guard: `code-spec-reviewer` must accept the documented historical TDD evidence gap and evaluate the guard using the revised recovery path, not by requiring non-existent pre-edit RED. The minimum acceptable evidence is the negative-control RED file, byte-for-byte restoration proof in executor command output, focused GREEN file, broad GREEN file, and snapshot-generator script GREEN file listed in Execute Resume Context. If any of those recovery evidence pieces is missing, stale, or inconsistent with the current diff, return to executor for recovery verification rather than failing solely because pre-edit RED was not captured.

## Task 3: Full Pre-Release Verification Before Build Artifacts

- [ ] Run repository verification from the baseline command:
  ```bash
  make backend-version && scripts/test-snapshot-generator.sh && make test && make build
  ```
  Expected output: backend version is readable, snapshot generator tests pass after schema `"2"` fixture updates, all focused relevant Swift tests are covered by the full suite, Swift tests pass with zero failures, and build completes. The test count should be at least the baseline 243 executed tests plus the newly added policy tests, with 1 skipped expected unless test inventory changed intentionally.

- [ ] Verify no unintended files are staged or modified:
  ```bash
  git status --short
  ```
  Expected output: modified files are limited to `appcast.xml` only after release metadata task, `src/Sources/ExternalModelCatalog.swift`, `scripts/generate-model-catalog-snapshot.swift`, `scripts/test-snapshot-generator.sh`, `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift`, `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`, `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`, any other discovered current-valid snapshot test fixture/helper that required schema `"2"`, and `src/Sources/Resources/model-catalog-snapshot.json`; `docs/easycode/.../plan.md` may also appear as the planning artifact. Stop if `.gitignore`, Sparkle key files, `CCProxy.app`, or `CCProxy.app.zip` are staged.

## Task 4: Commit Catalog Policy Changes

- [ ] Confirm release files have not yet been changed for this commit:
  ```bash
  git diff --name-only
  ```
  Expected output for this commit boundary includes only catalog source, generator, test scripts, tests, snapshot, and the plan artifact if the workflow keeps the plan in branch history. If `appcast.xml` is already modified, either postpone staging it to the release commit or stop and re-check task order.

- [ ] Stage intended files only:
  ```bash
  git add docs/easycode/2026-06-06-catalog-source-policy-v0-3-1-release/plan.md src/Sources/ExternalModelCatalog.swift scripts/generate-model-catalog-snapshot.swift scripts/test-snapshot-generator.sh src/Tests/CCProxyTests/ExternalModelCatalogTests.swift src/Tests/CCProxyTests/ServerManagerConfigTests.swift src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift src/Sources/Resources/model-catalog-snapshot.json
  ```
  Expected output: no output and exit code 0. If execution discovered another current-valid snapshot fixture/helper that required schema `"2"`, stage that specific test fixture/helper too and document it in executor evidence.

- [ ] Review staged diff:
  ```bash
  git diff --cached --stat && git diff --cached --name-only
  ```
  Expected output lists only the staged files above.

- [ ] Commit catalog policy:
  ```bash
  git commit -m "Enforce catalog source policy"
  ```
  Expected output: one commit created on `work/2026-06-06-catalog-source-policy-v0-3-1-release`.

## Task 5: Build v0.3.1 Build 14 Archive And Sign Appcast

- [ ] Re-run release preflight:
  ```bash
  git fetch origin --tags --prune && local_tag="$(git tag -l 'v0.3.1')" && test -z "$local_tag" && remote_tag="$(git ls-remote --tags origin 'refs/tags/v0.3.1')" && test -z "$remote_tag" && if gh release view v0.3.1 >/dev/null 2>&1; then echo "release v0.3.1 already exists" >&2; exit 1; else echo "release v0.3.1 absent"; fi
  ```
  Expected output: `release v0.3.1 absent` and exit code 0. Local tag lookup and remote tag lookup must both be empty. Stop if a local tag, remote tag, or GitHub Release already exists.

- [ ] Verify local release tooling before any signing or release packaging:
  ```bash
  python3 -c 'from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey; from cryptography.hazmat.primitives import serialization; print("python cryptography available")'
  ```
  Expected output: `python cryptography available`. Stop before signing/release work if Python `cryptography` is unavailable; route to needs-more-evidence/tooling setup rather than continuing to late execution. Do not inspect or print Sparkle private key material in this tooling preflight.

- [ ] Verify Sparkle key and signing tool without printing key material:
  ```bash
  test -f "/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key" && test -s "/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key" && test -x "src/.build/artifacts/sparkle/Sparkle/bin/sign_update"
  ```
  Expected output: no output and exit code 0.

- [ ] Re-verify both approved pinned CLIProxyAPI raw source URLs before release build:
  ```bash
  python3 - <<'PY'
  import json
  import urllib.request
  urls = {
      'models.json': 'https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/5753d1a0896fd5bb9ace47adb17b0174ceb79e4d/internal/registry/models/models.json',
      'codex_client_models.json': 'https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/5753d1a0896fd5bb9ace47adb17b0174ceb79e4d/internal/registry/models/codex_client_models.json',
  }
  parsed = {}
  for name, url in urls.items():
      with urllib.request.urlopen(url, timeout=30) as response:
          assert 200 <= response.status < 300, f'{name} HTTP {response.status}'
          parsed[name] = json.loads(response.read().decode('utf-8'))
  codex_models = parsed['codex_client_models.json'].get('models')
  assert isinstance(parsed['models.json'], dict) and parsed['models.json']
  assert isinstance(codex_models, list) and any(isinstance(model, dict) and model.get('slug') for model in codex_models)
  print('pinned CLIProxyAPI release sources verified')
  PY
  ```
  Expected output: `pinned CLIProxyAPI release sources verified`. Stop if either pinned raw URL fails, returns malformed JSON, or the Codex client supplemental file cannot be parsed with slug entries.

- [ ] Build the arm64 archive with release metadata:
  ```bash
  APP_VERSION=0.3.1 APP_BUILD_NUMBER=14 TARGET_ARCH=arm64 make sparkle-archive
  ```
  Expected output includes release app bundle creation, `Setting version to: 0.3.1 (build 14)`, `Building for architecture: arm64`, and `Created CCProxy.app.zip`.

- [ ] Verify app bundle metadata and architecture:
  ```bash
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' 'CCProxy.app/Contents/Info.plist' && /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' 'CCProxy.app/Contents/Info.plist' && file 'CCProxy.app/Contents/MacOS/CCProxy' && codesign --verify --deep --strict --verbose=2 'CCProxy.app'
  ```
  Expected output: `0.3.1`, then `14`, `arm64` in the `file` output, and codesign verification success.

- [ ] Derive the Sparkle public key from the approved private key file and compare it to `SUPublicEDKey` in both source and built app plists before appcast signing:
  ```bash
  KEY_CHECK_OUTPUT="$(python3 - <<'PY'
  import base64
  from pathlib import Path
  from cryptography.hazmat.primitives.asymmetric import ed25519
  from cryptography.hazmat.primitives import serialization
  key_text = Path('/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key').read_text(encoding='utf-8').strip()
  decoded = base64.b64decode(key_text, validate=True)
  if len(decoded) == 32:
      public_key = ed25519.Ed25519PrivateKey.from_private_bytes(decoded).public_key().public_bytes(encoding=serialization.Encoding.Raw, format=serialization.PublicFormat.Raw)
      length_class = '32-byte-seed'
  elif len(decoded) == 96:
      public_key = decoded[-32:]
      length_class = '96-byte-sparkle-legacy-secret'
  else:
      raise SystemExit(f'unsupported decoded Sparkle key length: {len(decoded)}')
  print(f'decoded_length_class={length_class}')
  print(f'public_key={base64.b64encode(public_key).decode("ascii")}')
  PY
  )" && printf '%s\n' "$KEY_CHECK_OUTPUT" && DERIVED_PUBLIC_KEY="$(printf '%s\n' "$KEY_CHECK_OUTPUT" | awk -F= '/^public_key=/{print $2}')" && SOURCE_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' 'src/Info.plist')" && BUILT_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' 'CCProxy.app/Contents/Info.plist')" && test "$DERIVED_PUBLIC_KEY" = "$SOURCE_PUBLIC_KEY" && test "$DERIVED_PUBLIC_KEY" = "$BUILT_PUBLIC_KEY" && echo "Sparkle public key matches approved private key"
  ```
  Expected output includes `decoded_length_class=32-byte-seed` or `decoded_length_class=96-byte-sparkle-legacy-secret`, a `public_key=...` public key line, and `Sparkle public key matches approved private key`. The command validates UTF-8/base64 text, derives the public key from a 32-byte Ed25519 seed with Python `cryptography`, extracts the final 32 public-key bytes for Sparkle's 96-byte legacy secret format, and rejects any other decoded length. It must not print private key contents or decoded private key bytes. Stop before signing if the derived public key differs from `SUPublicEDKey` in `src/Info.plist` or `CCProxy.app/Contents/Info.plist`.

- [ ] Compute release asset length and SHA-256:
  ```bash
  wc -c < 'CCProxy.app.zip' && shasum -a 256 'CCProxy.app.zip'
  ```
  Expected output: first line is a positive byte count; second line is a SHA-256 hash followed by `CCProxy.app.zip`. Record both in execute evidence; do not put the SHA in code unless release notes require it.

- [ ] Sign the exact archive with Sparkle without printing private key contents:
  ```bash
  src/.build/artifacts/sparkle/Sparkle/bin/sign_update --ed-key-file "/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key" "CCProxy.app.zip"
  ```
  Expected output includes an `sparkle:edSignature="..."` value and `length="..."` for `CCProxy.app.zip`. The `length` must match `wc -c`; stop if it differs.

- [ ] Update `appcast.xml` manually with:
  - `Version 0.3.1`
  - `<sparkle:shortVersionString>0.3.1</sparkle:shortVersionString>`
  - `<sparkle:version>14</sparkle:version>`
  - enclosure URL `https://github.com/DevNewbie1826/ccproxy/releases/download/v0.3.1/CCProxy.app.zip`
  - the exact Sparkle signature and byte length from `sign_update --ed-key-file`

- [ ] Verify `appcast.xml` content against the exact archive length and a fresh `sign_update --ed-key-file` output, then run Sparkle verification with the same explicit approved key file and no Keychain fallback:
  ```bash
  python3 - <<'PY'
  import re
  import subprocess
  import xml.etree.ElementTree as ET
  from pathlib import Path
  archive = Path('CCProxy.app.zip')
  actual_length = archive.stat().st_size
  sign_output = subprocess.check_output([
      'src/.build/artifacts/sparkle/Sparkle/bin/sign_update',
      '--ed-key-file',
      '/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key',
      str(archive),
  ], text=True)
  sig_match = re.search(r'sparkle:edSignature="([^"]+)"', sign_output)
  len_match = re.search(r'length="([0-9]+)"', sign_output)
  assert sig_match, 'sign_update output missing sparkle:edSignature'
  assert len_match, 'sign_update output missing length'
  expected_signature = sig_match.group(1)
  expected_length = int(len_match.group(1))
  assert expected_length == actual_length, f'sign_update length {expected_length} != archive length {actual_length}'
  root = ET.parse('appcast.xml').getroot()
  ns = {'sparkle': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
  item = root.find('./channel/item')
  assert item.findtext('title') == 'Version 0.3.1'
  assert item.findtext('sparkle:shortVersionString', namespaces=ns) == '0.3.1'
  assert item.findtext('sparkle:version', namespaces=ns) == '14'
  enc = item.find('enclosure')
  assert enc.attrib['url'] == 'https://github.com/DevNewbie1826/ccproxy/releases/download/v0.3.1/CCProxy.app.zip'
  assert int(enc.attrib['length']) == actual_length == expected_length
  appcast_signature = enc.attrib['{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature']
  assert appcast_signature == expected_signature, 'appcast signature differs from fresh sign_update output'
  subprocess.check_call([
      'src/.build/artifacts/sparkle/Sparkle/bin/sign_update',
      '--verify',
      '--ed-key-file',
      '/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key',
      str(archive),
      appcast_signature,
  ])
  print('appcast v0.3.1 verified against exact archive and Sparkle --verify with explicit key file')
  PY
  ```
  Expected output includes Sparkle verification success and `appcast v0.3.1 verified against exact archive and Sparkle --verify with explicit key file`. The signing recomputation and verification both pass `--ed-key-file /Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key`; do not rely on Keychain fallback. The command may print the public signature/length generated by `sign_update`; it must not print private key contents or decoded private key bytes.

- [ ] Stage release upload asset outside the repository:
  ```bash
  python3 - <<'PY'
  from pathlib import Path
  repo = Path('/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-catalog-source-policy-v0-3-1-release').resolve()
  stage = Path('/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip').resolve()
  assert repo not in (stage, *stage.parents), f'staging path is inside repo: {stage}'
  print('external staging path verified')
  PY
  mkdir -p "/Volumes/storage/artifact/ccproxy/releases/v0.3.1" && cp "CCProxy.app.zip" "/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip" && test -s "/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip" && cmp -s "CCProxy.app.zip" "/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip" && stat -f '%z %N' "CCProxy.app.zip" "/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip" && shasum -a 256 "CCProxy.app.zip" "/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip"
  ```
  Expected output: external staging path is verified, copy succeeds, staged asset is non-empty, `cmp -s` exits 0, both `stat` byte counts match, and both SHA-256 lines have the same hash.

- [ ] Confirm generated app artifacts are untracked or ignored and not staged:
  ```bash
  git status --short --ignored -- CCProxy.app CCProxy.app.zip
  test -s "/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip" && cmp -s "CCProxy.app.zip" "/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip"
  ```
  Expected output: `CCProxy.app` and `CCProxy.app.zip` are not staged for commit; external staged asset verification uses filesystem checks only and `cmp -s` exits 0. Do not pass `/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip` to `git status`, `git diff`, `git check-ignore`, or any git pathspec command.

## Task 6: Full Verification And Release Commit

- [ ] Run final full verification after appcast update:
  ```bash
  make backend-version && scripts/test-snapshot-generator.sh && make test && make build
  ```
  Expected output: backend version readable, snapshot generator tests pass, all Swift tests pass with zero failures, and build completes.

- [ ] Re-verify release archive and appcast after `make build`:
  ```bash
  test -s "/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip" && cmp -s "CCProxy.app.zip" "/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip" && python3 - <<'PY'
  import xml.etree.ElementTree as ET
  from pathlib import Path
  staged = Path('/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip')
  item = ET.parse('appcast.xml').getroot().find('./channel/item')
  enc = item.find('enclosure')
  assert item.findtext('title') == 'Version 0.3.1'
  assert enc.attrib['url'].endswith('/v0.3.1/CCProxy.app.zip')
  assert int(enc.attrib['length']) == staged.stat().st_size
  assert enc.attrib['{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature']
  print('release asset and appcast length still match')
  PY
  ```
  Expected output: `cmp -s` exits 0 and `release asset and appcast length still match`.

- [ ] Stage intended release metadata only:
  ```bash
  git add appcast.xml
  ```
  Expected output: no output and exit code 0.

- [ ] Review staged release diff:
  ```bash
  git diff --cached --stat && git diff --cached -- appcast.xml
  ```
  Expected output: only `appcast.xml` is staged, with version `0.3.1`, build `14`, v0.3.1 release URL, and non-empty Sparkle signature/length.

- [ ] Commit release metadata:
  ```bash
  git commit -m "Prepare v0.3.1 appcast"
  ```
  Expected output: one commit created on the work branch.

- [ ] Record the archive build source commit SHA in executor and final-review summaries without creating extra artifact files:
  ```bash
  git rev-parse HEAD && git diff --quiet HEAD -- appcast.xml Makefile create-app-bundle.sh scripts/generate-model-catalog-snapshot.swift scripts/test-snapshot-generator.sh src/Package.swift src/Package.resolved src/Sources/ExternalModelCatalog.swift src/Sources/Resources/model-catalog-snapshot.json src/Sources/Resources/cli-proxy-api src/Tests/CCProxyTests/ExternalModelCatalogTests.swift src/Tests/CCProxyTests/ServerManagerConfigTests.swift src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift docs/easycode/2026-06-06-catalog-source-policy-v0-3-1-release/spec.md docs/easycode/2026-06-06-catalog-source-policy-v0-3-1-release/evidence.md docs/easycode/2026-06-06-catalog-source-policy-v0-3-1-release/plan.md
  ```
  Expected output: first line is `ARCHIVE_BUILD_SOURCE_COMMIT`, the commit whose source produced the signed `CCProxy.app.zip` and `appcast.xml`, and `git diff --quiet` exits 0 for release-relevant files at that commit. The executor must copy that SHA into its completion evidence and final-review must preserve it in the final-review PASS summary as `ARCHIVE_BUILD_SOURCE_COMMIT`. Do not confuse this with `FINAL_REVIEWED_HEAD_SHA`, which is the branch head after final-review and any final-review artifact commit. Do not create release source manifest files, hash-list files, or other extra workflow artifacts; the only external file allowed by this plan is the staged release upload asset `/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip`.

## Task 7: Execute-Stage Code Review Gate Before Final Review

- [ ] Inspect final branch status and commits:
  ```bash
  git status --short && git log --oneline -5
  ```
  Expected output: working tree has no staged source changes; generated `CCProxy.app` and `CCProxy.app.zip` may exist but must be untracked/ignored and not staged. Recent commits include `Prepare v0.3.1 appcast` and `Enforce catalog source policy`.

- [ ] Inspect cumulative diff against base:
  ```bash
  git diff --stat main...HEAD && git diff --name-only main...HEAD
  ```
  Expected output: only approved files are changed: `appcast.xml`, `scripts/generate-model-catalog-snapshot.swift`, `scripts/test-snapshot-generator.sh`, `src/Sources/ExternalModelCatalog.swift`, `src/Sources/Resources/model-catalog-snapshot.json`, `src/Tests/CCProxyTests/ExternalModelCatalogTests.swift`, `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`, `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`, any other discovered current-valid snapshot test fixture/helper that required schema `"2"`, and the plan artifact if committed.

- [ ] Required EasyCode execute review gates before final-review handoff:
  - `code-spec-reviewer` must PASS against the approved spec and evidence.
  - `code-quality-reviewer` must PASS with no required changes.
  - If either reviewer fails, return to the executor TDD loop; do not create a PR.

- [ ] Completion verifier expected evidence:
  - Baseline command rerun output for `make backend-version && scripts/test-snapshot-generator.sh && make test && make build`.
  - Focused `ExternalModelCatalogTests`, `ServerManagerConfigTests`, and affected `ThinkingProxyModelAliasTests` output after schema fixture updates.
  - `scripts/test-snapshot-generator.sh` output after schema fixture updates.
  - CLIProxyAPI source pin verification output for production and generator URLs.
  - Runtime cache stale-policy invalidation test output.
  - Task 2A generator mapping/schema guard recovery evidence: explicit statement that pre-edit RED was not captured; negative-control RED output for `testProviderSourcePolicy_snapshotGeneratorMappingsMatchProductionPolicy`; proof that only `scripts/generate-model-catalog-snapshot.swift` was temporarily mutated; proof of byte-for-byte restoration; focused GREEN output; broad GREEN output; and `scripts/test-snapshot-generator.sh` GREEN output. Accepted raw evidence paths are `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/task2a-red-green-evidence/red-generator-guard.txt`, `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/task2a-red-green-evidence/green-generator-guard-focused.txt`, `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/task2a-red-green-evidence/green-broad-tests.txt`, and `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/task2a-red-green-evidence/green-snapshot-generator-script.txt`.
  - Snapshot policy Python verification output.
  - Pinned raw CLIProxyAPI source verification output for both `models.json` and `codex_client_models.json`, including successful Codex client JSON parse with slug entries.
  - Bundled snapshot source verification output showing `sources` includes `models.json`, `codex_client_models.json`, and `models.dev`.
  - Sparkle signing command output with signature and length, exact appcast comparison output, and Sparkle `--verify --ed-key-file /Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key` output, excluding private key material.
  - Sparkle public-key derivation check output proving `/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key` matches `SUPublicEDKey` in `src/Info.plist` and `CCProxy.app/Contents/Info.plist`, excluding private key material.
  - App metadata and architecture verification output.
  - External staged asset path `/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip` and matching SHA-256.
  - `ARCHIVE_BUILD_SOURCE_COMMIT` from `git rev-parse HEAD`, recorded in command output and summaries only, plus confirmation that release-relevant files were clean at that SHA.
  - Git status/diff evidence proving no `.app`, `.zip`, Sparkle key, or root `.gitignore` changes are committed.
- [ ] Execute stage stops after local commits, local verification, execute review gates, and completion-verifier evidence. Do not push the feature branch, create a PR, merge a PR, publish a release, update local `main`, or clean up worktrees/branches during execute or before final-review PASS.

## Task 8: Final-Review Artifact Expectations

- [ ] Final-review must run after execute completion and before merge/release publication.
- [ ] Final-review must independently verify:
  - Approved spec/evidence alignment.
  - Production and generator CLIProxyAPI source URLs are pinned to commit `5753d1a0896fd5bb9ace47adb17b0174ceb79e4d` for both `models.json` and `codex_client_models.json`.
  - `claude` and `codex` are not in models.dev secondary mappings in production or generator.
  - `kimi` is not in CLIProxyAPI primary mapping and remains in models.dev secondary mapping.
  - Pinned raw `models.json` and `codex_client_models.json` URLs fetch and parse successfully, and the bundled snapshot `sources` includes `models.json`, `codex_client_models.json`, and `models.dev`.
  - Stale runtime cache snapshots with old schema/policy are rejected and cannot expose models.dev-only OAuth models.
  - `grok` and `xai` were not added.
  - Bundled snapshot satisfies the provider policy.
  - Sparkle public-key derivation from `/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key` matches `SUPublicEDKey` in both `src/Info.plist` and `CCProxy.app/Contents/Info.plist`; no private key contents or decoded private key bytes appear in evidence.
  - `appcast.xml` points to v0.3.1 build 14, its length equals the exact staged archive length, its signature equals fresh `sign_update --ed-key-file /Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key` output for the exact archive, and Sparkle `--verify --ed-key-file /Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key` passes without Keychain fallback.
  - Final-review PASS summary records `ARCHIVE_BUILD_SOURCE_COMMIT`, the commit whose source produced the signed archive/appcast, and `FINAL_REVIEWED_HEAD_SHA`, the branch head after final-review and any final-review artifact commit used for PR merge. These must be recorded in summaries only, without creating extra manifest artifacts.
  - Generated `.app`/`.zip` and Sparkle key material are not committed.
  - Full verification passed after release metadata updates.
- [ ] Stop if final-review is not PASS.

## Task 9: Finish Commands After Final-Review PASS

Run finish commands only after final-review PASS and from the correct checkout as noted.

- [ ] Confirm finish SHA inputs from final-review PASS before push or PR work:
  ```bash
  ARCHIVE_BUILD_SOURCE_COMMIT="${ARCHIVE_BUILD_SOURCE_COMMIT:?set to the archive build source commit SHA recorded in execute and final-review PASS summaries}" && FINAL_REVIEWED_HEAD_SHA="${FINAL_REVIEWED_HEAD_SHA:?set to the final-reviewed branch head SHA recorded in final-review PASS summary}" && git cat-file -e "$ARCHIVE_BUILD_SOURCE_COMMIT^{commit}" && git cat-file -e "$FINAL_REVIEWED_HEAD_SHA^{commit}" && test "$(git rev-parse HEAD)" = "$FINAL_REVIEWED_HEAD_SHA" && printf 'ARCHIVE_BUILD_SOURCE_COMMIT=%s\nFINAL_REVIEWED_HEAD_SHA=%s\n' "$ARCHIVE_BUILD_SOURCE_COMMIT" "$FINAL_REVIEWED_HEAD_SHA"
  ```
  Expected output prints both SHA variables, both commit objects exist, and current feature-branch `HEAD` equals `FINAL_REVIEWED_HEAD_SHA`. Stop if either SHA is missing, ambiguous, unavailable, or if feature branch `HEAD` differs from `FINAL_REVIEWED_HEAD_SHA`; do not use `ARCHIVE_BUILD_SOURCE_COMMIT` for PR head matching when final-review added a later artifact commit.

- [ ] Push the feature branch after final-review PASS:
  ```bash
  git push -u origin work/2026-06-06-catalog-source-policy-v0-3-1-release
  ```
  Expected output: branch pushed and upstream tracking set. Stop if final-review PASS is not available.

- [ ] Create the PR after final-review PASS:
  ```bash
  PR_BODY="$(printf '%s\n' '## Summary' '- enforce OAuth provider catalog sourcing from CLIProxyAPI official registry only' '- pin CLIProxyAPI catalog URLs to approved commit 5753d1a0896fd5bb9ace47adb17b0174ceb79e4d and invalidate stale old-policy runtime caches' '- keep compatible/API-key providers on models.dev and regenerate the bundled model catalog snapshot' '- prepare Sparkle appcast metadata for CCProxy v0.3.1 build 14' '' '## Verification' '- make backend-version && scripts/test-snapshot-generator.sh && make test && make build' "- cd src && swift test --filter 'ExternalModelCatalogTests|ServerManagerConfigTests|ThinkingProxyModelAliasTests'" '- scripts/test-snapshot-generator.sh after schema fixture updates' '- CLIProxyAPI source pin verification and runtime cache invalidation tests' '- pinned raw models.json and codex_client_models.json fetch/parse verification' '- snapshot policy Python verification' '- APP_VERSION=0.3.1 APP_BUILD_NUMBER=14 TARGET_ARCH=arm64 make sparkle-archive' '- Sparkle sign_update with --ed-key-file /Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key' '- appcast v0.3.1 exact length/signature comparison and Sparkle --verify with explicit --ed-key-file')" && PR_URL="$(gh pr create --base main --head work/2026-06-06-catalog-source-policy-v0-3-1-release --title 'Enforce catalog source policy and prepare v0.3.1' --body "$PR_BODY")" && PR_NUMBER="$(gh pr view "$PR_URL" --json number --jq '.number')" && printf 'PR_URL=%s\nPR_NUMBER=%s\n' "$PR_URL" "$PR_NUMBER"
  ```
  Expected output: `PR_URL=...` and `PR_NUMBER=...`. Stop if final-review PASS is not available, or if `PR_NUMBER` is empty. Preserve `PR_NUMBER` or `PR_URL` in finish evidence for the root-only merge command.

- [ ] Verify the PR head still equals the final-reviewed branch head before mutating `main`, then merge from the repository root only without deleting the branch while the feature worktree exists:
  ```bash
  cd "/Volumes/storage/workspace/ccproxy" && pwd && test "$(git rev-parse --show-toplevel)" = "/Volumes/storage/workspace/ccproxy" && PR_NUMBER="${PR_NUMBER:?set to the PR number captured when creating the PR}" && FINAL_REVIEWED_HEAD_SHA="${FINAL_REVIEWED_HEAD_SHA:?set to the final-reviewed branch head SHA recorded in final-review PASS summary}" && PR_HEAD_SHA="$(gh pr view "$PR_NUMBER" --json headRefOid --jq '.headRefOid')" && printf 'PR_HEAD_SHA=%s\nFINAL_REVIEWED_HEAD_SHA=%s\n' "$PR_HEAD_SHA" "$FINAL_REVIEWED_HEAD_SHA" && test "$PR_HEAD_SHA" = "$FINAL_REVIEWED_HEAD_SHA" && gh pr merge "$PR_NUMBER" --merge --match-head-commit "$FINAL_REVIEWED_HEAD_SHA"
  ```
  Expected output: top-level is `/Volumes/storage/workspace/ccproxy`, `PR_HEAD_SHA` exactly equals `FINAL_REVIEWED_HEAD_SHA`, and the selected PR is merged with `--match-head-commit "$FINAL_REVIEWED_HEAD_SHA"`. This pre-merge gate must detect PR head drift before local `main` is mutated; the later source-identity gate remains as a second defense, not the first drift check. Do not run this command from the feature worktree. Do not use `--delete-branch` while `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-catalog-source-policy-v0-3-1-release` exists. If the PR head changed, `--match-head-commit` fails, branch protection requires a different merge method, or `PR_HEAD_SHA` differs from `FINAL_REVIEWED_HEAD_SHA`, stop and return to execute/final-review to rebuild, restage, re-sign, update appcast if needed, and re-review from the actual PR head.

- [ ] Update local `main` from the repository root, not from inside the feature worktree:
  ```bash
  cd "/Volumes/storage/workspace/ccproxy" && pwd && git rev-parse --show-toplevel && git switch main && git pull --ff-only origin main
  ```
  Expected output: top-level is `/Volumes/storage/workspace/ccproxy`, branch switches to `main`, and fast-forward pull succeeds.

- [ ] Verify merged commit contains release metadata:
  ```bash
  git log --oneline -5 && python3 - <<'PY'
  import xml.etree.ElementTree as ET
  item = ET.parse('appcast.xml').getroot().find('./channel/item')
  assert item.findtext('title') == 'Version 0.3.1'
  print('main appcast v0.3.1 verified')
  PY
  ```
  Expected output: recent log includes the merged PR commit and `main appcast v0.3.1 verified`.

- [ ] Gate release publication on full-tree source identity between merged `main` and `ARCHIVE_BUILD_SOURCE_COMMIT`, allowing only the final-review artifact difference:
  ```bash
  pwd && test "$(git rev-parse --show-toplevel)" = "/Volumes/storage/workspace/ccproxy" && ARCHIVE_BUILD_SOURCE_COMMIT="${ARCHIVE_BUILD_SOURCE_COMMIT:?set to the archive build source commit SHA recorded in execute and final-review PASS summaries}" && FINAL_REVIEWED_HEAD_SHA="${FINAL_REVIEWED_HEAD_SHA:?set to the final-reviewed branch head SHA recorded in final-review PASS summary}" && MERGED_RELEASE_SHA="$(git rev-parse HEAD)" && test -s "/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip" && git cat-file -e "$ARCHIVE_BUILD_SOURCE_COMMIT^{commit}" && git cat-file -e "$FINAL_REVIEWED_HEAD_SHA^{commit}" && if git merge-base --is-ancestor "$FINAL_REVIEWED_HEAD_SHA" "$MERGED_RELEASE_SHA" || test "$MERGED_RELEASE_SHA" = "$FINAL_REVIEWED_HEAD_SHA"; then echo "final-reviewed head is represented in merged main history"; else echo "final-reviewed head not represented in merged history" >&2; exit 1; fi && if git merge-base --is-ancestor "$ARCHIVE_BUILD_SOURCE_COMMIT" "$MERGED_RELEASE_SHA"; then echo "archive build source commit is included in merged main history"; else echo "archive build source commit not in merged history; requiring full-tree source identity"; fi && git diff --quiet "$ARCHIVE_BUILD_SOURCE_COMMIT" "$MERGED_RELEASE_SHA" -- . ':(exclude)docs/easycode/2026-06-06-catalog-source-policy-v0-3-1-release/final-review.md' && printf 'ARCHIVE_BUILD_SOURCE_COMMIT=%s\nFINAL_REVIEWED_HEAD_SHA=%s\nMERGED_RELEASE_SHA=%s\nrelease source identity verified\n' "$ARCHIVE_BUILD_SOURCE_COMMIT" "$FINAL_REVIEWED_HEAD_SHA" "$MERGED_RELEASE_SHA"
  ```
  Expected output: first line is `/Volumes/storage/workspace/ccproxy`, `final-reviewed head is represented in merged main history`, then either `archive build source commit is included in merged main history` or `archive build source commit not in merged history; requiring full-tree source identity`, followed by the three SHA lines and `release source identity verified`. Stop if this is not running from the root checkout, if `ARCHIVE_BUILD_SOURCE_COMMIT` or `FINAL_REVIEWED_HEAD_SHA` is not set to the SHA recorded in execute/final-review summaries, if either commit object is unavailable, if `FINAL_REVIEWED_HEAD_SHA` is not represented in merged `main`, if the staged archive is missing or empty, or if the full-tree `git diff --quiet` finds any drift other than `docs/easycode/2026-06-06-catalog-source-policy-v0-3-1-release/final-review.md`. If this diff is not clean, do not publish a stale archive; return to execute/plan as appropriate to rebuild, restage, re-sign, update appcast if needed, and re-review from the actual merged source.

- [ ] Re-run the Sparkle public-key derivation check before release publication, comparing the approved private key to merged source `src/Info.plist` and the built app plist in the feature worktree:
  ```bash
  KEY_CHECK_OUTPUT="$(python3 - <<'PY'
  import base64
  from pathlib import Path
  from cryptography.hazmat.primitives.asymmetric import ed25519
  from cryptography.hazmat.primitives import serialization
  key_text = Path('/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key').read_text(encoding='utf-8').strip()
  decoded = base64.b64decode(key_text, validate=True)
  if len(decoded) == 32:
      public_key = ed25519.Ed25519PrivateKey.from_private_bytes(decoded).public_key().public_bytes(encoding=serialization.Encoding.Raw, format=serialization.PublicFormat.Raw)
      length_class = '32-byte-seed'
  elif len(decoded) == 96:
      public_key = decoded[-32:]
      length_class = '96-byte-sparkle-legacy-secret'
  else:
      raise SystemExit(f'unsupported decoded Sparkle key length: {len(decoded)}')
  print(f'decoded_length_class={length_class}')
  print(f'public_key={base64.b64encode(public_key).decode("ascii")}')
  PY
  )" && printf '%s\n' "$KEY_CHECK_OUTPUT" && DERIVED_PUBLIC_KEY="$(printf '%s\n' "$KEY_CHECK_OUTPUT" | awk -F= '/^public_key=/{print $2}')" && SOURCE_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' 'src/Info.plist')" && BUILT_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' '/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-catalog-source-policy-v0-3-1-release/CCProxy.app/Contents/Info.plist')" && test "$DERIVED_PUBLIC_KEY" = "$SOURCE_PUBLIC_KEY" && test "$DERIVED_PUBLIC_KEY" = "$BUILT_PUBLIC_KEY" && echo "Sparkle public key still matches approved private key before publication"
  ```
  Expected output includes `decoded_length_class=32-byte-seed` or `decoded_length_class=96-byte-sparkle-legacy-secret`, a `public_key=...` public key line, and `Sparkle public key still matches approved private key before publication`. Stop before publishing if the derived public key differs from `SUPublicEDKey` in merged `src/Info.plist` or the built app plist. Do not print private key contents or decoded private key bytes.

- [ ] Publish GitHub Release from local `main` using the staged asset outside the repo:
  ```bash
  MERGED_RELEASE_SHA="${MERGED_RELEASE_SHA:-$(git rev-parse HEAD)}" && test "$MERGED_RELEASE_SHA" = "$(git rev-parse HEAD)" && gh release create "v0.3.1" "/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip#CCProxy.app.zip" --target "$MERGED_RELEASE_SHA" --title "CCProxy v0.3.1" --notes "CCProxy v0.3.1 build 14 updates model catalog source policy so OAuth providers use the official CLIProxyAPI registry and compatible/API-key providers use models.dev."
  ```
  Expected output: release URL for `v0.3.1`. Stop if `gh` reports a tag/release collision.

- [ ] Assert the published tag target is the merged release SHA before asset verification:
  ```bash
  MERGED_RELEASE_SHA="${MERGED_RELEASE_SHA:-$(git rev-parse HEAD)}" && git fetch --force origin "refs/tags/v0.3.1:refs/tags/v0.3.1" && PUBLISHED_TAG_SHA="$(git rev-list -n 1 v0.3.1)" && CURRENT_MAIN_SHA="$(git rev-parse HEAD)" && printf 'PUBLISHED_TAG_SHA=%s\nMERGED_RELEASE_SHA=%s\nCURRENT_MAIN_SHA=%s\n' "$PUBLISHED_TAG_SHA" "$MERGED_RELEASE_SHA" "$CURRENT_MAIN_SHA" && test "$PUBLISHED_TAG_SHA" = "$MERGED_RELEASE_SHA" && test "$PUBLISHED_TAG_SHA" = "$CURRENT_MAIN_SHA"
  ```
  Expected output prints matching `PUBLISHED_TAG_SHA`, `MERGED_RELEASE_SHA`, and `CURRENT_MAIN_SHA`. Stop if the tag points anywhere other than updated local `main` at `MERGED_RELEASE_SHA`.

- [ ] Verify release, tag target, and asset metadata without downloading or creating extra artifacts:
  ```bash
  STAGED_ASSET="/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip" && STAGED_SIZE="$(stat -f '%z' "$STAGED_ASSET")" && STAGED_SHA="$(shasum -a 256 "$STAGED_ASSET" | cut -d ' ' -f 1)" && RELEASE_JSON="$(gh release view "v0.3.1" --json assets,tagName,name,url)" && RELEASE_JSON="$RELEASE_JSON" STAGED_SIZE="$STAGED_SIZE" STAGED_SHA="$STAGED_SHA" python3 - <<'PY'
  import json
  import os
  data = json.loads(os.environ['RELEASE_JSON'])
  assert data['tagName'] == 'v0.3.1', data['tagName']
  assets = data.get('assets', [])
  matches = [asset for asset in assets if asset.get('name') == 'CCProxy.app.zip']
  assert len(matches) == 1, f'expected one CCProxy.app.zip asset, found {len(matches)}'
  asset = matches[0]
  expected_size = int(os.environ['STAGED_SIZE'])
  staged_sha = os.environ['STAGED_SHA']
  assert int(asset.get('size', -1)) == expected_size, f"asset size {asset.get('size')} != staged size {expected_size}"
  expected_asset_url = 'https://github.com/DevNewbie1826/ccproxy/releases/download/v0.3.1/CCProxy.app.zip'
  assert asset.get('url') == expected_asset_url, f"asset URL {asset.get('url')} != {expected_asset_url}"
  digest = asset.get('digest')
  if digest:
      normalized = digest.removeprefix('sha256:')
      assert normalized == staged_sha, f'asset digest {digest} != staged sha256 {staged_sha}'
      print(f"release asset metadata verified with digest: name={asset['name']} size={asset['size']} digest={digest} url={asset['url']}")
  else:
      print(f"release asset metadata verified without GitHub digest: name={asset['name']} size={asset['size']} url={asset['url']} staged_sha256={staged_sha}")
  PY
  ```
  Expected output: release JSON validates `tagName` `v0.3.1`, one asset named `CCProxy.app.zip`, asset size matching `/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip`, asset URL exactly `https://github.com/DevNewbie1826/ccproxy/releases/download/v0.3.1/CCProxy.app.zip`, and asset digest matching the staged SHA-256 if GitHub exposes `digest`; otherwise record the staged SHA-256 with the asset name/size/url evidence. Do not download the release asset or create any extra release verification artifact.

- [ ] Confirm release verification used only the approved external staged asset and repository/worktree files:
  ```bash
  test -s "/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip" && shasum -a 256 "/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip"
  ```
  Expected output: staged asset exists and the staged asset SHA-256 is printed for evidence. No downloaded release asset, manifest, hash-list, or other extra artifact is created.

- [ ] Remove only generated local app artifacts from the feature worktree and prove the feature worktree is clean before removing it:
  ```bash
  test -s "/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip" && if git -C "/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-catalog-source-policy-v0-3-1-release" ls-files --error-unmatch CCProxy.app >/dev/null 2>&1; then echo "refusing to remove tracked CCProxy.app" >&2; exit 1; fi && if git -C "/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-catalog-source-policy-v0-3-1-release" ls-files --error-unmatch CCProxy.app.zip >/dev/null 2>&1; then echo "refusing to remove tracked CCProxy.app.zip" >&2; exit 1; fi && rm -rf "/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-catalog-source-policy-v0-3-1-release/CCProxy.app" "/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-catalog-source-policy-v0-3-1-release/CCProxy.app.zip" && git -C "/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-catalog-source-policy-v0-3-1-release" status --short
  ```
  Expected output: staged external asset exists, no `refusing to remove tracked CCProxy.app` or `refusing to remove tracked CCProxy.app.zip` message appears, and final `git status --short` output is empty. This step must check `CCProxy.app` and `CCProxy.app.zip` independently before removal, must not remove tracked files, must not remove `/Volumes/storage/artifact/ccproxy/releases/v0.3.1/CCProxy.app.zip`, and must run only after final-review PASS plus successful release and external asset metadata verification.

- [ ] Cleanup EasyCode-owned worktree and local feature branch from the root checkout:
  ```bash
  cd "/Volumes/storage/workspace/ccproxy" && git worktree remove "/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-catalog-source-policy-v0-3-1-release" && git branch -D "work/2026-06-06-catalog-source-policy-v0-3-1-release" && git push origin --delete "work/2026-06-06-catalog-source-policy-v0-3-1-release"
  ```
  Expected output: worktree removed, local feature branch deleted, and remote feature branch deleted only after the worktree has been removed. Stop if worktree removal reports uncommitted changes.

## Stop Conditions

- Stop if the current checkout top-level is `/Volumes/storage/workspace/ccproxy` during plan/execute implementation tasks; implementation must happen in the isolated worktree.
- Stop if `docs/easycode/2026-06-06-catalog-source-policy-v0-3-1-release/spec.md` or `docs/easycode/2026-06-06-catalog-source-policy-v0-3-1-release/evidence.md` is missing.
- Stop if any requested change conflicts with the approved spec or evidence.
- Stop if tests do not fail during RED after adding policy tests; reassess whether tests actually exercise the old bug. The Task 2A generator mapping/schema guard is the documented exception: its historical pre-edit RED was missed and is replaced by the negative-control recovery RED path described above.
- Stop if a reviewer requires pre-edit RED for `testProviderSourcePolicy_snapshotGeneratorMappingsMatchProductionPolicy`; this revised plan explicitly replaces that impossible historical requirement with the documented negative-control recovery evidence path for Task 2A.
- Stop if the Task 2A generator-guard negative-control recovery test passes under the old/wrong generator mapping/schema, if the temporary mutation touches any file other than `scripts/generate-model-catalog-snapshot.swift`, if byte-for-byte restoration cannot be proven, or if focused/broad GREEN verification is missing after restoration.
- Stop if focused tests, snapshot generator tests, full verification, build, Sparkle signing, appcast validation, or release asset verification fails.
- Stop before signing or release packaging if Python `cryptography` is unavailable for Sparkle Ed25519 public-key derivation; route to needs-more-evidence/tooling setup instead of continuing.
- Stop if production or generator CLIProxyAPI source URLs still default to `CLIProxyAPI/main` instead of approved commit `5753d1a0896fd5bb9ace47adb17b0174ceb79e4d`.
- Stop if pinned raw CLIProxyAPI `models.json` or `codex_client_models.json` cannot be fetched and parsed, or if generated snapshot `sources` omits `models.json`, `codex_client_models.json`, or `models.dev`.
- Stop if stale old-policy runtime cache validation tests fail or if the implementation deletes user cache files instead of rejecting old-policy snapshots through validation.
- Stop if `.gitignore`, Sparkle key material, decoded key bytes, `CCProxy.app`, `CCProxy.app.zip`, or external staged assets are staged for commit.
- Stop if GitHub tag `v0.3.1` or release `v0.3.1` already exists before publication.
- Stop if `ARCHIVE_BUILD_SOURCE_COMMIT`, `FINAL_REVIEWED_HEAD_SHA`, or `MERGED_RELEASE_SHA` is missing, unavailable, or used for the wrong gate. PR merge must match `FINAL_REVIEWED_HEAD_SHA`; release source identity must compare `ARCHIVE_BUILD_SOURCE_COMMIT` to `MERGED_RELEASE_SHA` with only `docs/easycode/2026-06-06-catalog-source-policy-v0-3-1-release/final-review.md` allowed to differ.
- Stop if merged `main` full-tree source identity differs from `ARCHIVE_BUILD_SOURCE_COMMIT` by anything other than `docs/easycode/2026-06-06-catalog-source-policy-v0-3-1-release/final-review.md`; do not publish until the archive is rebuilt, restaged, re-signed, appcast is updated if needed, and final-review passes again.
- Stop if published tag `v0.3.1` does not resolve to `MERGED_RELEASE_SHA` and current updated local `main` HEAD.
- Stop if `sign_update` output length does not match `wc -c < CCProxy.app.zip`, if `appcast.xml` signature differs from fresh `sign_update --ed-key-file /Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key` output, or if Sparkle `--verify --ed-key-file /Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key` fails or would fall back to Keychain.
- Stop before signing or publishing if the public key derived from `/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key` does not match `SUPublicEDKey` in `src/Info.plist` or the built `CCProxy.app/Contents/Info.plist`.
- Stop if any push, PR creation, PR merge, release publication, local `main` update, or cleanup command is attempted before final-review PASS.
- Stop if final-review does not return PASS before merge/release publication.
- Stop if finish commands are about to run from the feature worktree when they must run from the root checkout.
- Stop if PR merge is attempted outside `/Volumes/storage/workspace/ccproxy`, if the merge command omits the explicit captured `PR_NUMBER` or `PR_URL`, or if `--delete-branch` is used before the feature worktree is removed.
