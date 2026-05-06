# Work ID

20260506-cliproxy-refresh-a1b2

# Goal

Prepare CCProxy for a manually supplied official-style CLIProxyAPI backend at `src/Sources/Resources/cli-proxy-api`, remove stale config/runtime references tied to the old baseline, preserve CCProxy's Claude-compatible Z.AI/Kimi/MiniMax provider behavior, strengthen generated YAML safety, and selectively apply or document the three approved VibeProxy stability candidates.

# Source Spec

`/Volumes/storage/workspace/ccproxy/.worktrees/20260506-cliproxy-refresh-a1b2/docs/supercode/20260506-cliproxy-refresh-a1b2/spec.md`

# Architecture / Design Strategy

- Keep this as a bounded maintenance refresh; do not import VibeProxy's broader provider architecture.
- Treat `cli-proxy-api` as the only final backend resource/runtime name and final replacement resource in source control; remove the tracked old `cli-proxy-api-plus` resource and stage/commit the user-supplied `cli-proxy-api` binary per explicit user approval.
- Do not add automatic binary download, update, release, or GitHub Actions workflows.
- Preserve the existing inline provider generation model in `ServerManager.swift` unless a small constant/helper extraction directly supports tests or safer YAML serialization.
- Use an explicit YAML scalar strategy for generated API keys: prefer a small double-quoted YAML scalar encoder that escapes `\\`, `"`, newline, and other required control characters. Do not add a production YAML dependency unless execution finds the existing project already has one suitable for this narrow use.
- Make YAML safety local and test-driven: add failing config-generation/helper round-trip tests before changing production config rendering. Prefer a full generated-config validation path using an existing parser or backend-compatible non-startup validation if available. If no such parser/validation exists without out-of-scope dependencies or starting the server, use an independently implemented scalar decode check and record residual risk in final notes.
- Evaluate VibeProxy stability candidates against exact approved upstream permalinks/snippets and exact local symbols/functions before applying or rejecting code changes; only backport local equivalents that match CCProxy's existing code paths.
- Record each stability candidate decision as `ported`, `already equivalent`, or `not applicable` with upstream permalink/snippet evidence and exact local symbol/function evidence. No `ported` decision may be based only on upstream similarity.

# Scope

In scope:

- Replace final runtime/script references from `cli-proxy-api-plus` to `cli-proxy-api`.
- Remove `request-timeout` from bundled config and any tests/fixtures unless a direct runtime consumer is found; current evidence says none.
- Add focused tests for YAML-sensitive provider API keys and existing provider enable/disable semantics.
- Keep Z.AI, Kimi, and MiniMax as generated Claude-compatible `claude-api-key` entries with their existing prefixes, base URLs, and models.
- Preserve OAuth provider disable behavior through `oauth-excluded-models` entries with `"*"`.
- Add or update one lightweight manual backend-version check that runs `src/Sources/Resources/cli-proxy-api` non-mutatingly.
- Remove the old tracked `src/Sources/Resources/cli-proxy-api-plus` resource from final source state.
- Include and stage/commit the user-supplied `src/Sources/Resources/cli-proxy-api` as the replacement backend resource in final source-control state per explicit user approval. Execution may use the supplied file already present in the worktree, but must never download, generate, synthesize, or modify it.
- If execution discovers `src/Sources/Resources/cli-proxy-api` is absent, not a usable executable file, or clearly not user-supplied, stop for user direction before removing/committing backend resources.

Out of scope:

- CLIProxyAPI auto-download, auto-update, or release automation.
- Compatibility fallback to `cli-proxy-api-plus` as a final runtime path.
- VibeProxy `ConfigComposer`, custom-provider UI/storage, `openai-compatibility`, Amp, Copilot, Factory, Vercel, Intel build, branding, or UI redesign work.
- Changing local ports `8317` and `8328` or localhost-only exposure.

# Assumptions

- Baseline `swift test` currently passes: 6 tests, 1 skipped, 0 failures.
- The user-supplied backend binary already exists at `src/Sources/Resources/cli-proxy-api` in the worktree; final repository state should stage/commit it as the replacement resource, but execution must not create, download, or modify it.
- No direct runtime consumer for `request-timeout` has been found in provided evidence; execution may remove it without external schema research unless a targeted verification search finds a consumer.
- The old tracked backend file `src/Sources/Resources/cli-proxy-api-plus` is obsolete and should be removed from final source-control state.
- Existing tests are Swift Package tests run by `swift test`.

# Source Spec Alignment

- Binary integration: tasks T02 and T06 switch code/scripts/checks to `cli-proxy-api` and explicitly forbid automation.
- Config cleanup: tasks T01 and T02 remove and verify absence of `request-timeout` unless a runtime consumer is found.
- Provider config safety: tasks T01 and T03 add failing tests first, then implement YAML-safe serialization.
- Provider behavior preservation: tasks T01 and T03 keep Claude-compatible `claude-api-key` generation and OAuth exclusions tested.
- Stability candidates: tasks T04 and T05 cover only `ThinkingProxy.stop()`, server pipe/process cleanup, and auth retry/stale cleanup.
- Final success criteria: T06 runs targeted repo searches, version-check command verification, and `swift test`.

# Execution Policy

- Tests first for behavior-changing work:
  - T01 must be completed and its request-timeout failing-test evidence recorded before any production/resource changes in T02. YAML special-character tests may pass initially; if they pass, T03 must avoid YAML production changes unless later tests reveal a defect.
  - Any unit-testable stability behavior in T04/T05 must add/update tests before production changes.
- Do not modify files outside the listed task targets unless a targeted verification search finds old-name references in tracked docs/scripts; if that happens, update only those references or pause if ownership is unclear.
- Do not download, generate, synthesize, or modify a backend binary. Final repository state must remove tracked `cli-proxy-api-plus` and stage/commit the already user-supplied `cli-proxy-api`; if that file is absent/unusable, stop for user direction.
- Keep each stability candidate decision evidence-based and recorded in `docs/supercode/20260506-cliproxy-refresh-a1b2/stability-backport-decisions.md` before applying or rejecting related code changes.
- If a proposed VibeProxy backport requires out-of-scope architecture, mark it `not applicable` with evidence instead of importing the architecture.
- For auth cleanup, forbid generic global process killing by binary name. Cleanup may terminate only tracked active child auth processes, must exclude the backend PID/process, and may use auth-specific `cli-proxy-api` argument patterns only when evidence shows CCProxy owns that auth process; otherwise record `not applicable`.

# File Structure

- `src/Sources/ServerManager.swift`
- `src/Sources/ThinkingProxy.swift`
- `src/Sources/Resources/config.yaml`
- `src/Sources/Resources/cli-proxy-api` *(user-supplied binary; do not generate/download)*
- `src/Sources/Resources/cli-proxy-api-plus` *(old tracked resource to remove from final source-control state)*
- `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`
- `src/Tests/CCProxyTests/ThinkingProxyLifecycleTests.swift` *(create only if T04 identifies a safe, focused test seam for `ThinkingProxy.stop()` lifecycle behavior)*
- `src/Tests/CCProxyTests/ServerManagerProcessTests.swift` *(create only if T05 identifies a safe, focused test seam for backend process/auth lifecycle behavior)*
- `create-app-bundle.sh`
- `Makefile`
- `docs/supercode/20260506-cliproxy-refresh-a1b2/stability-backport-decisions.md`

# File Responsibilities

- `ServerManager.swift`: backend binary path, backend process lifecycle, auth process lifecycle, provider credential scanning/config generation, YAML scalar escaping.
- `ThinkingProxy.swift`: local proxy listener lifecycle, state synchronization, and stop cleanup.
- `config.yaml`: bundled CLIProxyAPI config defaults; remove unsupported `request-timeout`.
- `cli-proxy-api`: final backend resource supplied manually by user and staged/committed as the replacement resource in final source-control state.
- `cli-proxy-api-plus`: obsolete backend resource name; final source-control state should remove this tracked file and final source must not use it as primary runtime path.
- `ServerManagerConfigTests.swift`: focused config-generation tests for provider inclusion/exclusion and YAML-sensitive API keys.
- `ThinkingProxyLifecycleTests.swift`: focused `ThinkingProxy.stop()` lifecycle/idempotency/race tests when a safe listener lifecycle test seam exists; otherwise not created and non-testability evidence is recorded before code changes.
- `ServerManagerProcessTests.swift`: focused ServerManager backend process/auth lifecycle tests when safe seams exist; otherwise not created and non-testability evidence is recorded before code changes.
- `create-app-bundle.sh`: app bundle resource copy/version-check references for the backend binary.
- `Makefile`: manual non-mutating backend-version check target if no suitable target exists; preserve existing clean behavior.
- `stability-backport-decisions.md`: evidence log for the three approved VibeProxy stability candidates.

# Task Sections

## T01 — Harden and add config-generation tests

- Task id: T01
- Task name: Harden and add config-generation tests
- Purpose: Lock expected config cleanup, provider behavior, YAML-sensitive API-key coverage, and safe test isolation before production changes.
- Files to create / modify / test:
  - Modify/test: `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`
  - Modify only if no safe auth-dir override/test seam exists: `src/Sources/ServerManager.swift`
  - Test command: `swift test --filter ServerManagerConfigTests`
- Concrete steps:
  1. Refactor the config-generation tests so they never read from or write to real `~/.cli-proxy-api`. Use per-test temporary directories and unique filenames; do not use fixed credential filenames that can collide with real or concurrent test data.
  2. Snapshot and restore every `UserDefaults` key touched by these tests in setup/teardown or `defer`, including provider enable/disable keys and any auth-dir/test-seam key.
  3. If current production code lacks a safe auth-dir override for config-generation tests, first add a focused failing test in `ServerManagerConfigTests.swift` proving test credentials must be loaded from an isolated temp auth directory, then add the smallest production test seam in `ServerManager.swift` needed to pass it. The seam must not change runtime default behavior.
  4. Ensure assertion failure messages do not print full generated config, full extracted API keys, temp credential contents, or other credential-bearing strings. Use redacted values, counts, key labels, or sanitized snippets only.
  5. Add or update tests asserting generated config does not contain `request-timeout`; this is the required RED for the config cleanup path and should fail until T02 removes the bundled config key.
  6. Preserve existing assertions that Z.AI/Kimi/MiniMax credentials generate Claude-compatible `claude-api-key` entries with provider-specific `prefix`, `base-url`, and `models`.
  7. Preserve or add tests that disabled OAuth providers generate `oauth-excluded-models` with `"*"`.
  8. Add table-driven coverage for API key values containing: colon (`:`), hash (`#`), single quote, double quote, backslash, leading spaces, trailing spaces, and newline.
  9. Target the accepted serialization strategy: generated API keys should be emitted as double-quoted YAML scalars with required escaping, unless execution documents an equally explicit narrow scalar strategy.
  10. Add helper-level or generated-config tests proving each special-character value round-trips to the exact original key. First use a full generated-config validation path if available through an existing YAML parser, existing project dependency, or backend-compatible non-startup validation command. Do not add a new production dependency or start the backend solely for this test. If no full validation path is available, test the scalar encoder with an independently implemented scalar decode check and document that this is a narrow scalar encoder for generated values only, not a general YAML parser.
  11. Run `swift test --filter ServerManagerConfigTests` and confirm the required RED is `testGeneratedConfigDoesNotContainRequestTimeout` or equivalent request-timeout cleanup coverage. YAML special-character tests may pass against current production code; if they pass, record that T03 should treat YAML serialization as already equivalent for the required cases unless later tests reveal a defect.
- Explicit QA / verification:
  - `swift test --filter ServerManagerConfigTests` must fail on the request-timeout cleanup test before T02 changes production/resources.
  - YAML special-character tests are allowed to pass before T03; passing YAML tests are evidence that current serialization is already equivalent for the required cases.
  - Confirm no test touches real `~/.cli-proxy-api`, no assertion message can leak full credentials/generated config, and all touched `UserDefaults` keys are restored after each test.
  - Record in test comments or final notes which validation path was used: existing parser/backend-compatible validation, or independently implemented scalar decode fallback with residual risk.
- Expected result:
  - Test suite contains executable coverage for the spec-required provider behavior and YAML-sensitive keys.
  - The request-timeout test fails until T02 is implemented.
  - YAML special-character coverage either passes initially and constrains T03 to no production serialization change, or fails and provides T03's RED.
- Dependency notes:
  - Must run before T02 and T03.
  - Provides the required request-timeout failing-test evidence for T02.
  - Provides YAML evidence for T03; if YAML tests pass, T03 should not modify serialization.
- Parallel eligibility:
  - Not parallel. T01 must complete first so failing-test evidence is unambiguous.

## T02 — Switch backend resource path and bundled config/script references

- Task id: T02
- Task name: Switch backend resource path and bundled config/script references
- Purpose: Make `src/Sources/Resources/cli-proxy-api` the final backend resource path and remove stale config/script references.
- Files to create / modify / test:
  - Modify: `src/Sources/ServerManager.swift`
  - Modify: `src/Sources/Resources/config.yaml`
  - Modify: `create-app-bundle.sh`
  - Modify if needed: `Makefile`
  - Remove: `src/Sources/Resources/cli-proxy-api-plus`
  - Include existing user-supplied file: `src/Sources/Resources/cli-proxy-api`
- Concrete steps:
  1. Replace old backend path/name references in `ServerManager.swift` around the known launch/path locations with `cli-proxy-api`.
  2. Update `create-app-bundle.sh` references around the known copy/version-check areas to use `cli-proxy-api`.
  3. Remove `request-timeout: "10m"` from `src/Sources/Resources/config.yaml`.
  4. Inspect `Makefile`'s existing clean target reference and add/update a lightweight manual backend-version check target only after discovering a known-safe non-mutating invocation for `src/Sources/Resources/cli-proxy-api`: `--version`, `version`, `--help`, or equivalent behavior observed not to start the server or mutate user/repo state. If no safe invocation is known, stop for user direction rather than adding a target that starts normal server mode.
  5. Verify the user-supplied `src/Sources/Resources/cli-proxy-api` exists and is a usable executable file before backend resource replacement. Do not download, generate, or alter it.
  6. Remove the tracked old `src/Sources/Resources/cli-proxy-api-plus` resource from final source-control state.
  7. Stage/commit the existing user-supplied `src/Sources/Resources/cli-proxy-api` as the replacement resource in final source-control state. If it is absent/unusable, stop for user direction before removing/committing backend resources.
- Explicit QA / verification:
  - `git grep -n "cli-proxy-api-plus" -- .` returns no final code/script/doc primary runtime references. If only historical spec/plan references remain under `docs/supercode/20260506-cliproxy-refresh-a1b2/`, they are acceptable as historical context.
  - `git grep -n "request-timeout" -- src` returns no runtime/test/fixture occurrences unless a direct runtime consumer is found and cited.
  - Run the manual backend-version target or command only after confirming the invocation is known-safe and non-mutating. If only normal server startup is available or the user-supplied binary is absent/not executable, stop for user direction and do not synthesize a binary.
- Expected result:
  - Final runtime/script path is `cli-proxy-api`.
  - Bundled config no longer contains `request-timeout`.
  - Old tracked resource is removed, and the existing user-supplied `cli-proxy-api` is staged/committed as the replacement backend resource in final source-control state.
- Dependency notes:
  - Depends on T01 request-timeout failing-test evidence being recorded.
  - T06 depends on this for final old-name verification.
- Parallel eligibility:
  - Not parallel with T01; starts after T01.

## T03 — Verify or implement YAML-safe provider config rendering

- Task id: T03
- Task name: Verify or implement YAML-safe provider config rendering
- Purpose: Use T01 evidence to either mark current YAML serialization already equivalent for required API-key cases or make the smallest tested serialization fix while preserving CCProxy's Claude-compatible provider semantics.
- Files to create / modify / test:
  - Modify only if T01 reveals a YAML defect or missing safe test seam remains: `src/Sources/ServerManager.swift`
  - Test: `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`
- Concrete steps:
  1. Review T01 results for YAML special-character tests after test isolation is fixed.
  2. If all required YAML special-character round-trip tests pass against current production code, make no YAML serialization production change. Record in final notes or implementation notes that serialization is already equivalent for the required cases covered by T01.
  3. If any required YAML special-character test fails, review the existing escaping code around the known provider rendering locations and identify the smallest safe helper or serialization change needed.
  4. For a failing YAML case only, implement the accepted strategy as a small double-quoted YAML scalar encoder for generated API keys: wrap values in double quotes; escape backslash as `\\`, double quote as `\"`, newline as `\n`, and any other required control characters using explicit YAML-compatible escapes. If execution chooses another strategy, it must be equally explicit, tested for exact round-trip, and justified in the changed test comments or decision notes.
  5. Apply any helper consistently to generated `claude-api-key` credential values and only adjacent generated string fields that share the same proven escaping risk.
  6. Preserve provider prefixes, base URLs, model lists, credential enablement checks, and OAuth exclusion semantics.
  7. Preserve T01 test isolation: no real `~/.cli-proxy-api` access, unique temp credential filenames, UserDefaults snapshot/restore, and no assertion messages containing full generated config or credential values.
  8. Avoid introducing a production YAML dependency unless the repository already has one suitable for this narrow scalar rendering need; do not add a new dependency solely for this maintenance refresh.
  9. Avoid introducing VibeProxy `ConfigComposer`, custom provider storage, or OpenAI-compatible provider rewrites.
- Explicit QA / verification:
  - `swift test --filter ServerManagerConfigTests` passes.
  - Confirm tests added in T01 now pass without weakening assertions.
  - Inspect generated test output or assertions to confirm keys round-trip exactly, including newline and leading/trailing space cases.
  - Confirm tests remain isolated from real `~/.cli-proxy-api`, restore touched `UserDefaults`, and do not print full credentials/generated config in assertion messages.
  - Prefer full generated config validation using an existing parser or backend-compatible non-startup validation if available.
  - If no parser/backend validation is available without out-of-scope dependencies or server startup, confirm tests explicitly validate the double-quoted scalar encoder's escape output with an independently implemented scalar decode check, and record residual risk in final notes.
- Expected result:
  - Generated YAML safely represents special-character API keys either because current production behavior is already equivalent for required cases or because a minimal tested fix was applied.
  - Existing Claude-compatible provider behavior remains unchanged except for safer serialization.
- Dependency notes:
  - Depends on T01 request-timeout RED plus YAML pass/fail evidence.
  - Should run after T02 to avoid overlapping `ServerManager.swift` path edits unless execution explicitly serializes patches.
  - Independent of T04/T05 stability work except for shared `ServerManager.swift` edit coordination.
- Parallel eligibility:
  - Not parallel with T01, T02, T04, or T05 due to TDD sequencing and shared `ServerManager.swift` edits.

## T04 — Evaluate and backport ThinkingProxy stop cleanup if applicable

- Task id: T04
- Task name: Evaluate and backport ThinkingProxy stop cleanup if applicable
- Purpose: Address the approved VibeProxy `ThinkingProxy.stop()` stability candidate without importing unrelated architecture.
- Files to create / modify / test:
  - Modify if applicable: `src/Sources/ThinkingProxy.swift`
  - Create if safe seam exists: `src/Tests/CCProxyTests/ThinkingProxyLifecycleTests.swift`
  - Create/modify: `docs/supercode/20260506-cliproxy-refresh-a1b2/stability-backport-decisions.md`
  - Test commands: `swift test --filter ThinkingProxyLifecycleTests` if the lifecycle test file is created; always `swift test`
- Concrete steps:
  1. Capture the exact upstream permalink and relevant snippet from VibeProxy commit `14c9bd36c20b94c31ea890c3d6578a1015dff305`, `ThinkingProxy.swift` lines 25-31 and 98-107, in `stability-backport-decisions.md` before changing code.
  2. Capture the exact local CCProxy symbol/function references for `ThinkingProxy.stop()` plus listener/state properties before changing code.
  3. Decide applicability using the spec rules: applicable only for equivalent local stop/listener/state cleanup paths that can be fixed narrowly.
  4. If applicable and a safe test seam exists for `ThinkingProxy.stop()` lifecycle behavior, create `src/Tests/CCProxyTests/ThinkingProxyLifecycleTests.swift` with a focused failing test before production changes. Target only stop idempotency, listener teardown, state synchronization, or start/stop race behavior that can be exercised without broad refactor or flaky port assumptions.
  5. If no safe test seam exists, record non-testability evidence in `stability-backport-decisions.md` before production changes, including the attempted seam, why it would require broad refactor/flaky networking/server startup, and the planned fallback of code review plus `swift test`.
  6. Backport only narrow stop/listener teardown, connection cleanup, or state synchronization changes that map to CCProxy's local code.
  7. Finalize the decision entry as `ported`, `already equivalent`, or `not applicable` with upstream permalink/snippet and exact local symbol/function evidence. A `ported` decision must cite the local symbol/function that actually received the mapped change; upstream similarity alone is insufficient.
- Explicit QA / verification:
  - `swift test` passes.
  - If `ThinkingProxyLifecycleTests.swift` is created, `swift test --filter ThinkingProxyLifecycleTests` fails before the production change and passes after.
  - If no test is created, decision log contains pre-change non-testability evidence and fallback rationale.
  - Decision log contains a ThinkingProxy entry with status, exact upstream permalink/snippet, and exact local symbol/function reference.
  - If code changed, verify `stop()` remains idempotent by review and any added test; no port or listener constants change.
- Expected result:
  - ThinkingProxy candidate is either narrowly ported or explicitly documented as already equivalent/not applicable.
- Dependency notes:
  - Independent of T02 and T03 except for final full test run.
- Parallel eligibility:
  - Can run after T01 and may run independently of T02/T03 if no shared files are edited; if T03/T05 are active, sequence to keep evidence and patches clear.

## T05 — Evaluate and backport ServerManager process/auth cleanup if applicable

- Task id: T05
- Task name: Evaluate and backport ServerManager process/auth cleanup if applicable
- Purpose: Address the approved VibeProxy server pipe/process cleanup and auth retry/stale cleanup candidates within CCProxy's existing `ServerManager` structure.
- Files to create / modify / test:
  - Modify if applicable: `src/Sources/ServerManager.swift`
  - Create if safe seam exists: `src/Tests/CCProxyTests/ServerManagerProcessTests.swift`
  - Create/modify: `docs/supercode/20260506-cliproxy-refresh-a1b2/stability-backport-decisions.md`
  - Test commands: `swift test --filter ServerManagerProcessTests` if the process/auth lifecycle test file is created; always `swift test`
- Concrete steps:
  1. Capture the exact upstream permalink and relevant snippet from VibeProxy commit `14c9bd36c20b94c31ea890c3d6578a1015dff305`, `ServerManager.swift` lines 206-352 and pipe handler cleanup lines 270-278, in `stability-backport-decisions.md` before changing process cleanup code.
  2. Capture exact local CCProxy symbol/function references for backend launch/stop, stdout/stderr pipe handlers, termination handlers, process queue use, process niling, wait, and kill behavior before changing process cleanup code.
  3. If CCProxy has equivalent stdout/stderr pipe handlers, termination handlers, process queues, process niling, or wait/kill paths needing the upstream cleanup, apply the narrow local fix.
  4. Capture the exact upstream permalink/snippet for VibeProxy PR #344 and VibeProxy commit lines 555-621, plus exact local CCProxy auth flow symbol/function references, before changing auth cleanup code.
  5. If applicable, add or adapt active auth process tracking/termination/stale cleanup only within CCProxy-owned auth processes.
  6. For stale auth cleanup, forbid generic global binary-name killing. Any process termination must be scoped to one or more of: tracked active child auth process PID, backend PID/process exclusion, auth-specific command arguments, and final `cli-proxy-api` auth patterns only when local evidence supports CCProxy ownership. If that ownership cannot be proven, mark the auth cleanup candidate `not applicable` rather than killing by binary name.
  7. Before any unit-testable process/auth lifecycle behavior change, create `src/Tests/CCProxyTests/ServerManagerProcessTests.swift` with a focused failing test using safe existing seams. Target only backend pipe handler cleanup, termination handler cleanup, tracked active auth process termination, backend PID exclusion, or auth-specific stale cleanup behavior that can be exercised without launching the real backend or adding broad dependency injection.
  8. If no safe test seam exists for a candidate, record non-testability evidence in `stability-backport-decisions.md` before production changes for that candidate, including the attempted seam, why testing would require broad refactor/real process orchestration/flaky OS process matching/server startup, and the planned fallback of exact code review plus `swift test`.
  9. Avoid Amp, TunnelManager, Copilot, Factory, Vercel, or broad VibeProxy architecture imports.
  10. Record separate decision entries for pipe/process cleanup and auth retry/stale cleanup as `ported`, `already equivalent`, or `not applicable` with exact upstream permalink/snippet and exact local symbol/function evidence. A `ported` decision must cite the local symbol/function that actually received the mapped change; upstream similarity alone is insufficient.
- Explicit QA / verification:
  - `swift test` passes.
  - If `ServerManagerProcessTests.swift` is created, `swift test --filter ServerManagerProcessTests` fails before the production change and passes after.
  - If no process/auth lifecycle test is created for a candidate, decision log contains pre-change non-testability evidence and fallback rationale for that candidate.
  - Decision log contains separate entries for server pipe/process cleanup and auth retry/stale cleanup, each with exact upstream permalink/snippet and exact local symbol/function references captured before code changes.
  - If stale auth cleanup is ported, verify there is no generic global kill by binary name, backend PID/process is excluded, old `cli-proxy-api-plus` process patterns are not retained, and any final `cli-proxy-api` pattern is auth-specific and ownership-supported.
  - Review `ServerManager.swift` to confirm provider generation behavior from T03 remains intact.
- Expected result:
  - Both ServerManager stability candidates are either narrowly ported or explicitly documented as already equivalent/not applicable.
- Dependency notes:
  - Shares `ServerManager.swift` with T02/T03; sequence after T03 unless execution coordinates patches carefully.
  - T06 depends on the decision log.
- Parallel eligibility:
  - Not parallel with T03 due to shared file edits. Can run after T04 only after decision log edits are serialized; safer sequence is T04 then T05.

## T06 — Final verification and scope guard checks

- Task id: T06
- Task name: Final verification and scope guard checks
- Purpose: Prove the maintenance refresh satisfies the spec and did not introduce out-of-scope automation or provider rewrites.
- Files to create / modify / test:
  - Test entire worktree; no production modifications unless verification finds a missed in-scope reference.
  - Review: all files changed by T01-T05.
- Concrete steps:
  1. Run `swift test`.
  2. Run targeted old-name search: `git grep -n "cli-proxy-api-plus" -- .` and verify no final code/script/doc primary runtime references remain. Historical references in this spec/plan/decision log are acceptable only as historical evidence.
  3. Run targeted timeout search: `git grep -n "request-timeout" -- src` and verify no source/resource/test occurrence remains unless directly justified by a runtime consumer.
  4. Run targeted automation guard searches for newly introduced download/update workflow indicators, including `CLIProxyAPI` download URLs, `curl`, `wget`, GitHub Actions update workflow names, or generated binary scripts in changed files.
  5. Run the manual backend-version check target/command from T02 against the user-supplied `src/Sources/Resources/cli-proxy-api` only after the invocation is known-safe (`--version`, `version`, `--help`, or observed equivalent non-mutating behavior). If no safe invocation exists, or if the binary is absent/unusable, stop for user direction rather than starting normal server mode, synthesizing a binary, or falling back to `cli-proxy-api-plus`.
  6. Review changed provider output tests to confirm Z.AI/Kimi/MiniMax still use `claude-api-key`, not OpenAI-compatible/custom-provider architecture.
  7. Confirm `stability-backport-decisions.md` has exactly three candidate decisions: ThinkingProxy stop cleanup, ServerManager pipe/process cleanup, and auth retry/stale cleanup.
  8. Confirm final git status/diff show `src/Sources/Resources/cli-proxy-api-plus` removed and the existing user-supplied `src/Sources/Resources/cli-proxy-api` staged/committed as the replacement resource, without evidence of assistant download/generation.
- Explicit QA / verification:
  - `swift test` passes.
  - Old-name and timeout searches satisfy steps 2 and 3.
  - No auto-download, auto-update, GitHub Actions automation, or assistant-generated binary changes are present; the only binary replacement is the user-supplied `cli-proxy-api` approved for inclusion.
  - Manual version command succeeds non-mutatingly against the user-supplied binary using a known-safe invocation; if no safe invocation exists or the supplied binary is absent/unusable, execution has stopped for user direction.
  - Final resource diff removes `cli-proxy-api-plus` and stages/commits `cli-proxy-api` as the replacement resource without generated/downloaded provenance.
- Expected result:
  - Worktree is ready for final review with all in-scope behavior covered and out-of-scope changes excluded.
- Dependency notes:
  - Depends on T01-T05.
- Parallel eligibility:
  - Must run last; not parallel.

# QA Standard

- Required test commands:
  - `swift test --filter ServerManagerConfigTests` after T01/T03.
  - `swift test --filter ThinkingProxyLifecycleTests` if T04 creates `src/Tests/CCProxyTests/ThinkingProxyLifecycleTests.swift`; otherwise `stability-backport-decisions.md` must contain pre-change non-testability evidence for T04.
  - `swift test --filter ServerManagerProcessTests` if T05 creates `src/Tests/CCProxyTests/ServerManagerProcessTests.swift`; otherwise `stability-backport-decisions.md` must contain pre-change non-testability evidence for each untested T05 candidate.
  - `swift test` after stability changes and at final verification.
- Required search checks:
  - `git grep -n "cli-proxy-api-plus" -- .`
  - `git grep -n "request-timeout" -- src`
  - Targeted changed-file checks for auto-download/update workflow additions.
- Required manual binary check:
  - Discover and document a known-safe invocation before adding/running a command or Make target: `--version`, `version`, `--help`, or equivalent observed non-mutating behavior.
  - The command/target must invoke `src/Sources/Resources/cli-proxy-api` to display backend version/help output without starting normal server mode or mutating user/repo state.
  - If no safe invocation exists, stop for direction rather than adding/running a normal server-start command.
- Required binary source-control contract:
  - Final repository state removes tracked `src/Sources/Resources/cli-proxy-api-plus` and stages/commits the already user-supplied `src/Sources/Resources/cli-proxy-api` as its replacement, per explicit user approval.
  - If the supplied replacement binary is absent or unusable, stop for user direction; do not synthesize, download, or fall back to the old binary.
- Required evidence artifact:
  - `docs/supercode/20260506-cliproxy-refresh-a1b2/stability-backport-decisions.md` must record the three approved stability candidate outcomes with exact upstream permalink/snippet and exact local symbol/function references captured before related code changes.
  - No `ported` decision is valid unless it cites the exact local symbol/function that received the mapped change; upstream similarity alone is insufficient.
- Required YAML safety standard:
  - Generated API keys use a double-quoted YAML scalar encoder or another explicit, narrowly justified strategy.
  - Tests verify exact round-trip/helper behavior for colon, hash, quotes, backslash, leading/trailing spaces, and newline.
  - YAML special-character tests may pass against current production code; if they do, treat serialization as already equivalent for required cases and do not change production serialization.
  - Prefer full generated config validation using an existing parser or backend-compatible non-startup validation if available.
  - Do not add a new production YAML dependency unless strictly justified by existing project dependency context; if no parser/backend validation is available without out-of-scope dependencies or server startup, use an independently implemented scalar decode check and record residual risk in final notes.
- Required test isolation standard:
  - Config-generation tests must never read from or write to real `~/.cli-proxy-api`; use isolated temporary auth directories and unique filenames.
  - Snapshot and restore every `UserDefaults` key touched by tests.
  - Assertion messages must not print full generated config, full extracted API keys, or credential-bearing file contents; use redacted/sanitized diagnostics only.
  - If a safe auth-dir override does not exist, add the smallest tested seam before using config-generation tests; preserve runtime default behavior.
- Failure handling:
  - If tests fail for unrelated baseline/toolchain reasons, stop and report the failure evidence.
  - If a direct runtime consumer for `request-timeout` is found, stop and route back for planning/spec clarification before preserving it.
  - If removing `cli-proxy-api-plus` conflicts with absent/unusable `cli-proxy-api`, pause for user direction; do not synthesize a binary.
  - If auth stale cleanup cannot prove CCProxy process ownership, mark that candidate `not applicable`; do not kill by generic binary name.

# Revisions

- 2026-05-06: Initial execution-ready plan created from approved spec and supplied internal/upstream evidence.
- 2026-05-06: Revised to tighten binary source-control contract, strict TDD sequencing, YAML scalar strategy/testing, stability evidence requirements, and safe auth cleanup scope.
- 2026-05-06: Revised to incorporate explicit user approval to stage/commit the user-supplied `cli-proxy-api`, require safe backend version invocation discovery, prefer full generated-config YAML validation with residual-risk fallback, and require exact local symbol/function evidence for stability port decisions.
- 2026-05-06: Revised to name explicit lifecycle test targets for T04/T05 and require pre-change non-testability evidence when no safe seam exists.
- 2026-05-06: Revised after T01 review findings to make request-timeout the required RED, allow YAML tests to pass as already-equivalent evidence, and require safe config-test isolation, UserDefaults restoration, and credential-redacted assertions.
