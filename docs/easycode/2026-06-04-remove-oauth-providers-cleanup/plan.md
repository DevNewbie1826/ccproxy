# Remove OAuth Providers And Cleanup Implementation Plan

> **For agentic workers:** Each task is dispatched to the `executor` agent. Follow the EasyCode `execute` stage: per-task TDD cycle, `code-spec-reviewer` and `code-quality-reviewer` review gates, and `completion-verifier` for final evidence. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove Gemini, GitHub Copilot, Antigravity, and Qwen from active CCProxy source, UI, resources, config, and tests while preserving Claude Code, Codex, Z.AI, MiniMax, and Kimi.

**Architecture:** Provider identity is centralized through `ServiceType`, and provider enablement/config generation flows through `ServerManager.oauthProviderKeys`, `ServerManager.getConfigPath()`, auth commands, and `SettingsView` service rows. Runtime request behavior is otherwise provider-agnostic except removed Gemini/Antigravity `gemini-claude-*` handling in `ThinkingProxy`, while resource usage is driven by `SettingsView`, `AppDelegate.preloadIcons()`, and bundled `Resources/config.yaml`.

**Tech Stack:** Swift 5.9 package under `src`, XCTest, SwiftUI/AppKit, Sparkle dependency, bundled `cli-proxy-api` resource, shell verification with `swift test`, `rg`, `git`, and a temporary Python backend startup probe.

## Approved Inputs And Baseline

- Work ID: `2026-06-04-remove-oauth-providers-cleanup`
- Approved spec: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/docs/easycode/2026-06-04-remove-oauth-providers-cleanup/spec.md`
- Approved evidence: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/docs/easycode/2026-06-04-remove-oauth-providers-cleanup/evidence.md`
- Worktree path: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup`
- Branch: `work/2026-06-04-remove-oauth-providers-cleanup`
- Baseline: ready; `swift test` run from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src` passed with 90 tests, 1 skipped, 0 failures.
- Degraded baseline caveat: none.
- Scope anchors from evidence: provider registry and display names in `AuthStatus.swift`; OAuth keys, auth commands, API-key save/scan/config generation in `ServerManager.swift`; service rows, Qwen sheet/state/connect/success, and API-key sheet duplication in `SettingsView.swift`; `gemini-claude-*` handling in `ThinkingProxy.swift`; Gemini preload in `AppDelegate.swift`; removed icons and config comments/key under `Sources/Resources`.

## Plan Approval Gate Before Execute

- Execute is blocked until this revised `plan.md` receives `plan-checker` PASS, `plan-challenger` PASS, and user plan approval.
- In this unattended session, user plan approval is covered by the active unattended target only after both plan reviewers return PASS on the current plan artifact.
- If either reviewer returns FAIL after this revision, stop, revise only the plan artifact again, and rerun both reviewers before any execute-stage work.

## File Structure

### Modify source files

- `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/AuthStatus.swift`
- `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/ServerManager.swift`
- `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/SettingsView.swift`
- `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/ThinkingProxy.swift`
- `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/AppDelegate.swift`
- `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/Resources/config.yaml`

### Delete resource files

- `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/Resources/icon-antigravity.png`
- `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/Resources/icon-copilot.png`
- `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/Resources/icon-gemini.png`
- `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/Resources/icon-qwen.png`

### Modify test files

- `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Tests/CCProxyTests/AuthStatusTests.swift`
- `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Tests/CCProxyTests/ServerManagerConfigTests.swift`
- `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`

### Workflow artifact created by this plan stage

- `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/docs/easycode/2026-06-04-remove-oauth-providers-cleanup/plan.md`

## Parallelization Strategy

- Largest safe parallel executor wave: one implementation worker.
- Reason: removing enum cases from `ServiceType` intentionally breaks compile until `SettingsView`, `ServerManager`, and tests are updated together; provider string cleanup and absence verification also cross-cut the same files.
- Dependency order: Task 1 establishes failing behavior-lock tests; Task 2 updates provider registry and auth/config model; Task 3 removes UI/resources/config/runtime branches; Task 4 performs scoped provider cleanup/refactor; Task 5 runs full verification and review.

## Task 1: Add Provider Removal Behavior-Lock Tests

- [x] RED: Update `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Tests/CCProxyTests/AuthStatusTests.swift`.
  - Test source hygiene requirement for every test added or edited in this task: active test function names, comments, assertion messages, and string literals must not contain contiguous removed-provider tokens or the removed config-key token. When a removed needle is needed, construct it from smaller fragments at runtime so `rg -n -i --glob '*.swift' --glob '*.yaml' 'gemini|github-copilot|copilot|qwen|antigravity|generative-language-api-key' Sources Tests` finds no matches in `Tests` after GREEN.
  - Replace `testServiceTypeIncludesKimi` with tests asserting:
    - `ServiceType.allCases.map(\.rawValue)` equals `[
      "claude", "codex", "zai", "minimax", "kimi"
      ]` in that order.
    - `ServiceType.allCases.map(\.displayName)` equals `[
      "Claude Code", "Codex", "Z.AI GLM", "MiniMax", "Kimi"
      ]`.
    - Removed provider raw values and display-name fragments are absent. Construct removed needles from fragments such as `"ge" + "mi" + "ni"`, `"gi" + "thub-" + "co" + "pilot"`, `"co" + "pilot"`, `"q" + "wen"`, and `"anti" + "gravity"` so the absence test itself does not contain searchable removed literals.
- [x] RED: Update `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Tests/CCProxyTests/ServerManagerConfigTests.swift`.
  - Add `testOAuthProviderKeysOnlyContainClaudeAndCodex` asserting `ServerManager.oauthProviderKeys == ["claude": "claude", "codex": "codex"]`.
  - Update `testOAuthDisabledProvidersGenerateExclusions` to disable only `claude` and `codex`, assert the generated `oauth-excluded-models` section includes only those two providers, and assert absence of removed-provider OAuth keys using fragment-built needles.
  - Add `testBundledConfigOmitsRetiredEntries` using `Sources/Resources/config.yaml` path derived from `#filePath`, asserting the file does not contain the removed config key or removed-provider names using fragment-built needles. Build the removed config-key needle at runtime from components such as `"generative"`, `"language"`, `"api"`, and `"key"` joined with hyphens, and keep assertion messages generic.
  - Add `testActiveSourceAndTestsDoNotContainRemovedProviderNames` that scans active `Sources` and `Tests` `.swift` and `.yaml` files under the package root, excludes only historical docs because they are outside `src`, and searches fragment-built needles for removed names/config key.
- [x] RED: Update `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`.
  - Add `testLegacyPrefixedThinkingModelIsNotSpecialCased` using a model string built from fragments equivalent to the legacy removed alias plus `-opus-4-5-thinking-10000`; no test name, comment, assertion message, or literal may contain any contiguous removed-provider token. Assert the new testable ThinkingProxy seam described in Task 3 returns no transformation for that model body and does not mark thinking as enabled.
  - Add `testClaudeThinkingModelStillTransforms` for a normal `claude-...-thinking-10000` request to protect kept Claude behavior.
  - If the first RED run fails to compile because the seam does not exist yet, implement only the minimal seam extraction in Task 3 preserving current behavior, rerun this RED command immediately, and expect the legacy-prefixed test to fail because current logic still transforms and enables thinking for the runtime-composed legacy alias. Do not proceed to removal until that behavior failure is observed.
- [x] Run RED command from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src`:

  ```bash
  swift test
  ```

  Expected RED result: command fails. Expected failure reasons include exact provider list mismatch because current `ServiceType` still has Gemini, GitHub Copilot, Antigravity, and Qwen; OAuth key/config assertions fail because `oauthProviderKeys` still contains removed providers; active source/resource scan fails because removed provider names and `generative-language-api-key` still exist; the `gemini-claude-*` ThinkingProxy test fails because that model is still special-cased.

## Task 2: Remove Providers From Registry, OAuth Config, Auth Commands, And API-Key Model

- [x] GREEN implementation in `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/AuthStatus.swift`:
  - Remove `case copilot = "github-copilot"`, `case gemini`, `case qwen`, and `case antigravity` from `ServiceType`.
  - Remove their `displayName` switch branches.
  - Keep exactly `claude`, `codex`, `zai`, `minimax`, and `kimi`.
  - Remove the Copilot-specific comment on `AuthAccount.login`; keep the property because credential JSON may still use `login` for any account display fallback.
- [x] GREEN implementation in `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/ServerManager.swift`:
  - Change `ServerManager.oauthProviderKeys` to exactly `["claude": "claude", "codex": "codex"]`.
  - Trim `AuthCommand` to only `case claudeLogin` and `case codexLogin`.
  - Trim `runAuthCommand(_:)` switch to only Claude and Codex arguments.
  - Remove Copilot device-code capture/output branches, Gemini default-project newline branch, Qwen email automation branch, Antigravity login branch, and the `qwenEmail` local variable.
  - Delete `OutputCapture` if no longer referenced after removing Copilot capture logic.
  - Keep Codex newline behavior unchanged.
  - Replace provider literals in API-key provider checks with `ServiceType.zai.rawValue`, `ServiceType.minimax.rawValue`, and `ServiceType.kimi.rawValue` where practical.
  - Introduce a small internal API-key provider metadata structure if it reduces duplicate save/scan/config code without changing behavior; keep it private to `ServerManager.swift` and scoped to Z.AI, MiniMax, and Kimi.
  - Consolidate the three save functions through one private helper while preserving public methods `saveZaiApiKey`, `saveMiniMaxApiKey`, and `saveKimiApiKey` for `SettingsView` call sites.
  - Consolidate API-key scanning into one helper that reads files matching each kept provider raw value prefix and extracts `api_key`.
- [x] Run focused GREEN command from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src`:

  ```bash
  swift test --filter 'AuthStatusTests|ServerManagerConfigTests'
  ```

  Expected GREEN result after Task 2 plus any compile fixes needed in touched files: AuthStatus and ServerManager config tests pass or fail only because Task 3 UI/resource cleanup has not yet removed active removed-provider references. If Swift compilation fails from `SettingsView` references to removed `ServiceType` cases, continue directly to Task 3 before treating this as a blocker.

## Task 3: Remove Removed-Provider UI, Resources, Config Comments, And ThinkingProxy Handling

- [x] GREEN implementation in `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/SettingsView.swift`:
  - Remove `showingQwenEmailPrompt` and `qwenEmail` state.
  - Remove Service rows for `.antigravity`, `.gemini`, `.copilot`, and `.qwen`.
  - Remove Qwen email prompt sheet entirely.
  - Trim `connectService(_:)` to Claude/Codex OAuth only plus early returns for Z.AI, MiniMax, and Kimi API-key prompts; no removed-provider switch cases should remain.
  - Trim `successMessage(for:)` to kept providers only.
  - Delete `startQwenAuth(email:)`.
  - Keep Z.AI, MiniMax, and Kimi rows and API-key flows working.
  - If practical without widening scope, replace the three API-key sheet state groups with a small local enum/metadata-driven sheet for kept API-key providers; otherwise leave separate sheets and only remove removed providers.
- [x] GREEN implementation in `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/ThinkingProxy.swift`:
  - Add or expose a small internal pure seam for tests, for example `internal func processThinkingParameterForTesting(jsonString: String) -> (String, Bool)?`, by moving the existing `processThinkingParameter(jsonString:)` body to an internal helper and having the private proxy method call it. The seam must avoid networking and must not expose unrelated proxy state.
  - After the seam exists but before removing special handling, rerun the Task 1 RED command if it previously failed only because the seam was missing; expected failure is the legacy-prefixed runtime-composed model still being transformed by current removed-provider special handling.
  - Remove `model.starts(with: "gemini-claude-")` from `isClaudeModelRequest(body:)`.
  - In `processThinkingParameter(jsonString:)`, process only models starting with `claude-`.
  - Remove the `gemini-claude-*` clean-model branch and related comments; normal Claude thinking suffix behavior must remain unchanged.
- [x] GREEN implementation in `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/AppDelegate.swift`:
  - Remove `("icon-gemini.png", serviceIconSize)` from `iconsToPreload`.
- [x] GREEN implementation in `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/Resources/config.yaml`:
  - Update OAuth comments to mention only Claude and Codex.
  - Remove `generative-language-api-key: []`.
  - Remove comments implying no API keys are needed globally; keep comments accurate for local OAuth subscriptions only.
- [x] Delete removed icon resources:
  - `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/Resources/icon-antigravity.png`
  - `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/Resources/icon-copilot.png`
  - `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/Resources/icon-gemini.png`
  - `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/Resources/icon-qwen.png`
- [x] Run focused GREEN command from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src`:

  ```bash
  swift test --filter 'AuthStatusTests|ServerManagerConfigTests|ThinkingProxyModelAliasTests'
  ```

  Expected GREEN result: tests pass for exact `ServiceType` list, exact OAuth key list/config, absence of removed provider strings in active source/test/config paths, absence of runtime-composed legacy ThinkingProxy special handling, and retained Claude thinking behavior.

## Task 4: Scoped Provider Cleanup And Literal Centralization

- [x] REFACTOR only after Task 3 focused tests are green.
- [x] In `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/ServerManager.swift`, finish provider-related cleanup without changing behavior:
  - Keep public `saveZaiApiKey`, `saveMiniMaxApiKey`, and `saveKimiApiKey` as thin wrappers over one private helper.
  - Keep one private API-key scanning helper instead of three repeated directory scans.
  - Keep Claude-compatible provider config data in one metadata table using kept provider raw values for prefixes.
  - Keep `oauthProviderKeys` derived from kept OAuth provider raw values where practical, while preserving exact dictionary values required by tests.
- [x] In `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src/Sources/SettingsView.swift`, perform only provider-related cleanup:
  - Centralize kept API-key provider prompts if it clearly reduces duplicate sheet code without affecting UI behavior.
  - Do not rewrite unrelated layout, launch-at-login, security, account deletion, or notification behavior.
- [x] Use the `simplify` skill discipline during this refactor: behavior stays locked by tests, inventory one cleanup target at a time, make one small smell reduction at a time, and verify after each pass.
- [x] Run focused post-refactor command from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src`:

  ```bash
  swift test --filter 'AuthStatusTests|ServerManagerConfigTests|ThinkingProxyModelAliasTests'
  ```

  Expected result: all filtered tests pass with no new compile warnings requiring source changes.

## Task 5: Full Verification, Review, Commit, Push, And PR Prep

- [x] Check worktree state from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup`:

  ```bash
  git status --short --branch
  ```

  Expected result: branch is `work/2026-06-04-remove-oauth-providers-cleanup`; changes are limited to the files listed in this plan.

- [x] Run full Swift test suite from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src`:

  ```bash
  swift test
  ```

  Expected result: all tests pass. Baseline comparison target is at least 90 passing tests, 1 skipped, 0 failures, plus the new tests added by Task 1.

- [x] Run targeted removed-provider active source/test/config search from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src`:

  ```bash
  rg -n -i --glob '*.swift' --glob '*.yaml' 'gemini|github-copilot|copilot|qwen|antigravity|generative-language-api-key' Sources Tests
  ```

  Expected result: no output and exit code `1` from `rg` because no matches were found. If matches occur only because a test intentionally constructs fragments, rewrite the test to avoid literal removed-provider names rather than weakening this search.

- [x] Run targeted removed icon inventory from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src`:

  ```bash
  test ! -e Sources/Resources/icon-antigravity.png && test ! -e Sources/Resources/icon-copilot.png && test ! -e Sources/Resources/icon-gemini.png && test ! -e Sources/Resources/icon-qwen.png
  ```

  Expected result: exit code `0` and no output.

- [x] Run backend temporary startup verification from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup/src` after `Resources/config.yaml` no longer contains `generative-language-api-key`:

  ```bash
  python3 - <<'PY'
  import os, signal, subprocess, tempfile, textwrap, time
  root = tempfile.mkdtemp(prefix='ccproxy-backend-')
  auth = os.path.join(root, 'auth')
  os.makedirs(auth, exist_ok=True)
  config = os.path.join(root, 'config.yaml')
  with open(config, 'w', encoding='utf-8') as f:
      f.write(textwrap.dedent(f'''
      port: 8328
      host: 127.0.0.1
      remote-management:
        allow-remote: false
        secret-key: ""
      auth-dir: "{auth}"
      debug: false
      logging-to-file: false
      force-model-prefix: true
      usage-statistics-enabled: false
      proxy-url: ""
      request-retry: 3
      quota-exceeded:
        switch-project: true
        switch-preview-model: true
      '''))
  proc = subprocess.Popen(['./Sources/Resources/cli-proxy-api', '-config', config], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
  time.sleep(2.5)
  running = proc.poll() is None
  if running:
      proc.terminate()
      try:
          stdout, stderr = proc.communicate(timeout=2)
      except subprocess.TimeoutExpired:
          proc.kill()
          stdout, stderr = proc.communicate(timeout=2)
  else:
      stdout, stderr = proc.communicate(timeout=2)
  print(stdout)
  if stderr:
      print(stderr)
  raise SystemExit(0 if running and 'API server started successfully' in stdout else 1)
  PY
  ```

  Expected result: exit code `0`; stdout includes `API server started successfully`; stderr is empty or contains no startup-fatal error; process is terminated by the probe after confirming it stayed running for 2.5 seconds.

- [ ] Run final active file diff review from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup`:

  ```bash
  git diff -- src/Sources/AuthStatus.swift src/Sources/ServerManager.swift src/Sources/SettingsView.swift src/Sources/ThinkingProxy.swift src/Sources/AppDelegate.swift src/Sources/Resources/config.yaml src/Tests/CCProxyTests/AuthStatusTests.swift src/Tests/CCProxyTests/ServerManagerConfigTests.swift src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift docs/easycode/2026-06-04-remove-oauth-providers-cleanup/plan.md
  ```

  Expected result: diff is limited to the approved provider removal/cleanup scope and the plan artifact.

- [ ] Run deleted resource diff review from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup`:

  ```bash
  git diff -- src/Sources/Resources/icon-antigravity.png src/Sources/Resources/icon-copilot.png src/Sources/Resources/icon-gemini.png src/Sources/Resources/icon-qwen.png
  ```

  Expected result: each listed removed-provider icon appears as deleted and no kept provider icons are deleted.

- [ ] Code review gate before PR creation:
  - Run `code-spec-reviewer` against the approved spec, evidence, and final diff; expected result: PASS.
  - Run `code-quality-reviewer` against the final diff; expected result: PASS.
  - Run `completion-verifier` with `swift test`, targeted search, removed icon inventory, backend temp startup, and git diff evidence; expected result: PASS.
  - If any reviewer fails, return to the smallest relevant task, fix with TDD, and rerun focused plus full verification.

## Commit, Push, PR, Merge, And Cleanup Commands For Later Stages

These commands are for the later `execute`, `final-review`, and `finish` stages only. Do not run them during planning.

- [ ] Stage intended files from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup`:

  ```bash
  git add docs/easycode/2026-06-04-remove-oauth-providers-cleanup/plan.md src/Sources/AuthStatus.swift src/Sources/ServerManager.swift src/Sources/SettingsView.swift src/Sources/ThinkingProxy.swift src/Sources/AppDelegate.swift src/Sources/Resources/config.yaml src/Tests/CCProxyTests/AuthStatusTests.swift src/Tests/CCProxyTests/ServerManagerConfigTests.swift src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift src/Sources/Resources/icon-antigravity.png src/Sources/Resources/icon-copilot.png src/Sources/Resources/icon-gemini.png src/Sources/Resources/icon-qwen.png
  ```

  Expected result: only intended plan/source/test/resource changes are staged.

- [ ] Inspect staged changes from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup`:

  ```bash
  git diff --cached --stat && git diff --cached --name-status
  ```

  Expected result: staged files match the File Structure section exactly.

- [ ] Create implementation commit from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup`:

  ```bash
  git commit -m "Remove retired OAuth providers"
  ```

  Expected result: one commit is created on `work/2026-06-04-remove-oauth-providers-cleanup`.

- [ ] Push branch from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup`:

  ```bash
  git push -u origin work/2026-06-04-remove-oauth-providers-cleanup
  ```

  Expected result: remote branch is created and local branch tracks it.

- [ ] Create PR from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup`:

  ```bash
  gh pr create --base main --head work/2026-06-04-remove-oauth-providers-cleanup --title "Remove retired OAuth providers" --body "Removes Gemini, GitHub Copilot, Antigravity, and Qwen from active provider registry, auth flows, UI, resources, config, and tests. Keeps Claude Code, Codex, Z.AI, MiniMax, and Kimi; removes gemini-claude ThinkingProxy handling; verifies Swift tests, active-source removed-provider search, icon deletion, and backend startup without generative-language-api-key."
  ```

  Expected result: PR URL is printed.

- [ ] After final-review PASS and user-approved finish target, merge PR from repository root `/Volumes/storage/workspace/ccproxy`:

  ```bash
  gh pr merge --squash --delete-branch
  ```

  Expected result: PR is squash-merged into `main` and remote feature branch is deleted.

- [ ] Update local main from repository root `/Volumes/storage/workspace/ccproxy`:

  ```bash
  git checkout main && git pull --ff-only origin main
  ```

  Expected result: local `main` matches `origin/main` after merge.

- [ ] Clean up EasyCode-owned worktree from repository root `/Volumes/storage/workspace/ccproxy`:

  ```bash
  git worktree remove /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup
  ```

  Expected result: EasyCode-owned worktree directory is removed.

- [ ] Delete local feature branch from repository root `/Volumes/storage/workspace/ccproxy` if it still exists:

  ```bash
  git branch -d work/2026-06-04-remove-oauth-providers-cleanup
  ```

  Expected result: local feature branch is deleted, or Git reports it was already removed/not present after worktree cleanup.

## Stop Conditions

- Stop if the current checkout is not `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-remove-oauth-providers-cleanup` for planning or implementation work.
- Stop if `git status --short --branch` does not show branch `work/2026-06-04-remove-oauth-providers-cleanup`.
- Stop if any unplanned files are modified, staged, deleted, or created.
- Stop if the implementation requires changing scope beyond the approved spec, including UserDefaults cleanup for stale removed-provider keys, backend binary changes, unrelated ThinkingProxy refactors, release automation changes, or historical documentation edits.
- Stop if a RED test fails for a reason unrelated to the expected removed-provider behavior-lock failures.
- Stop if focused or full `swift test` fails after GREEN implementation and the failure is not understood.
- Stop if targeted removed-provider search finds active removed-provider literals after implementation; fix source/tests/resources rather than documenting an exception for active paths.
- Stop if backend startup without `generative-language-api-key` fails; investigate config changes before proceeding.
- Stop if code review gates fail; do not commit, push, create a PR, merge, update local main, or clean up the worktree until failures are fixed and verification passes.
- Stop if final diff no longer matches approved spec/evidence or this plan.
- Stop before execute if `plan-checker` PASS, `plan-challenger` PASS, and user plan approval are not all complete for the current plan artifact; in unattended mode, approval is satisfied only after both reviewer PASS results.
