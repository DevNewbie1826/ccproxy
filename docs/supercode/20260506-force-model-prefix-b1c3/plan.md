# Work ID

20260506-force-model-prefix-b1c3

# Goal

Hotfix CCProxy-generated CLIProxyAPI configuration so Z.AI/Kimi/MiniMax Claude-compatible provider models are exposed only with their provider-prefixed IDs by enabling CLIProxyAPI's global `force-model-prefix: true` setting.

# Source Spec

- `/Volumes/storage/workspace/ccproxy/.worktrees/20260506-force-model-prefix-b1c3/docs/supercode/20260506-force-model-prefix-b1c3/spec.md`
- Approved objective: add a minimal config-level fix for duplicated raw and prefixed provider model IDs, with tests and live backend verification.

# Architecture / Design Strategy

- Use the smallest supported backend configuration change: add `force-model-prefix: true` to the bundled CLIProxyAPI config file.
- Preserve existing CCProxy provider generation in `ServerManager.swift`; do not rewrite providers, prefixes, model names, auth flow, or the bundled backend binary.
- Extend existing config-generation tests with a narrow string assertion consistent with current test conventions and the absence of a YAML parser dependency. Because these tests use `src/Tests/CCProxyTests/Fixtures/config.yaml` as the bundled-config fixture, update that fixture with the same top-level setting so tests cover ServerManager merge behavior.
- Verify behavior in two layers:
  1. Static real bundled config and fixture-based generated config each contain exactly one top-level `force-model-prefix: true` key.
  2. Live backend `/v1/models` on `http://127.0.0.1:8328/v1/models` is queried only against the worktree bundled CLIProxyAPI binary started explicitly with an isolated temporary config assembled from the bundled config plus a fake Z.AI `claude-api-key` provider entry matching `ServerManager`'s generated provider shape and a temp empty `auth-dir`.
- Do not use `$HOME/.cli-proxy-api/merged-config.yaml` for live backend verification because it can contain stale config, real unrelated credentials, or state from a different CCProxy run. ServerManager-generated config coverage remains in `ServerManagerConfigTests.swift`; live backend verification isolates CLIProxyAPI behavior for the same provider shape.
- Z.AI live verification is sufficient for the reported reproduction because the observed duplicates were `glm-*`/`zai/glm-*`. Kimi and MiniMax are covered by the static/global-setting generated-config verification because `force-model-prefix` is a CLIProxyAPI global setting and those providers use the same generated prefixed `claude-api-key` shape.
- This split satisfies the spec by proving both required links: (a) CCProxy/ServerManager-generated config includes the global setting via fixture-based merge tests and static real bundled config checks, and (b) CLIProxyAPI 6.10.8 with that setting suppresses raw duplicates for a synthetic but representative prefixed `claude-api-key` provider shape.
- If live backend verification still exposes raw duplicates despite `force-model-prefix: true`, stop execution and route back to planning for the spec-defined `excluded-models` fallback; do not implement that fallback under this plan.

# Scope

## In Scope

- Modify bundled config at `src/Sources/Resources/config.yaml` to include `force-model-prefix: true`.
- Modify config fixture at `src/Tests/CCProxyTests/Fixtures/config.yaml` to include the same top-level `force-model-prefix: true` setting used by `ServerManagerConfigTests`.
- Update `src/Tests/CCProxyTests/ServerManagerConfigTests.swift` so fixture-based generated merged config tests assert the setting is present exactly once as a top-level key.
- Run Swift tests from `src` and targeted config-generation tests.
- Perform command-level live backend verification on default backend port `8328` without printing or committing secrets.
- Produce implementation evidence suitable for a later hotfix PR/release decision; PR creation and release execution are handled by the finish stage or explicit user selection, not by this implementation plan.

## Out of Scope

- Changing provider architecture or moving Z.AI/Kimi/MiniMax to `openai-compatibility` providers.
- Adding `excluded-models` unless this plan is explicitly revised after failed live verification.
- Provider UI changes.
- Changing model names, prefixes, ports, auth flow, local ThinkingProxy behavior, OAuth provider listings, or bundled backend binary.
- Release automation, backend auto-update automation, or broad VibeProxy sync.
- Creating a PR, merging a PR, or cutting the patch release during implementation execution.

# Assumptions

- CLIProxyAPI 6.10.8 honors global `force-model-prefix: true` by suppressing raw IDs for prefixed credentials while preserving prefixed IDs.
- `ServerManager.swift` merges bundled `config.yaml` unchanged before appending generated `claude-api-key` provider entries, so adding the global setting to the bundled config is sufficient unless tests prove otherwise.
- Existing tests in `ServerManagerConfigTests.swift` can be extended using narrow string assertions rather than introducing a YAML parser.
- Live verification must use an isolated temporary runtime config, not `$HOME/.cli-proxy-api/merged-config.yaml`, to avoid stale user state and real credentials. ServerManager-generated config coverage remains in isolated unit tests in `ServerManagerConfigTests.swift`.

# Source Spec Alignment

- Success criterion “`src/Sources/Resources/config.yaml` contains `force-model-prefix: true`” maps to Task 1.
- Success criterion “Config generation tests pass and assert the setting is present” maps to Task 1 QA.
- Success criterion “`swift test` passes” maps to Task 2 QA.
- Success criterion “Live `/v1/models` verification ... prefixed Z.AI model IDs remain and raw `glm-*` duplicates are absent” maps to Task 2.
- Kimi/MiniMax success is covered by the exact top-level global setting checks in bundled/generated config because they use the same generated prefixed-provider configuration path; the isolated live check targets a fake Z.AI entry because Z.AI is the reproduced duplicate model family.
- Constraint “route back to planning for `excluded-models` fallback if insufficient” is enforced in Task 2 expected result and dependency notes.
- Constraint “redact secrets and avoid printing API keys” is enforced in Task 2 verification steps.

# Execution Policy

- Implementation must follow test-driven development: add or update the config-generation test assertion first, observe the targeted test fail if possible, then change bundled config.
- Modify only files named in the task file targets unless a test failure proves a direct need; any additional production file change must be justified against the source spec before editing.
- Do not add dependencies.
- Do not print API keys, tokens, generated auth secrets, or full credential-bearing config contents in logs or final evidence.
- Do not implement `excluded-models` fallback in this execution. If live verification fails the raw-duplicate check, stop and route back to planning.
- Do not commit, push, create PRs, or perform release steps unless separately requested by the user after implementation verification. Implementation completion means producing test/runtime evidence only; finish-stage routing or explicit user instruction decides PR/release actions.

# File Structure

```text
/Volumes/storage/workspace/ccproxy/.worktrees/20260506-force-model-prefix-b1c3/
  src/
    Sources/
      Resources/
        config.yaml
        cli-proxy-api
      ServerManager.swift                 # expected read-only unless tests prove merge behavior changed
    Tests/
      CCProxyTests/
        Fixtures/
          config.yaml
        ServerManagerConfigTests.swift
  docs/
    supercode/
      20260506-force-model-prefix-b1c3/
        spec.md
        plan.md
```

# File Responsibilities

- `src/Sources/Resources/config.yaml`: Bundled CLIProxyAPI base configuration. Must contain the global `force-model-prefix: true` setting.
- `src/Sources/Resources/cli-proxy-api`: Bundled CLIProxyAPI backend binary. Must remain unchanged; may be invoked for local verification only if the normal CCProxy startup path is not used.
- `src/Tests/CCProxyTests/Fixtures/config.yaml`: Test fixture used by `ServerManagerConfigTests` as the bundled config input. Must contain the same top-level `force-model-prefix: true` setting so generated-config tests validate merge behavior with the new global key.
- `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`: Existing isolated config-generation test coverage. Must assert generated merged YAML includes `force-model-prefix: true` using existing string-check style.
- `src/Sources/ServerManager.swift`: Existing config path and merge/generation implementation. Expected to remain unchanged because evidence indicates bundled config is merged unchanged before generated provider entries are appended.
- Temporary runtime config under `$(mktemp -d)`: Live backend verification input assembled from bundled config plus a temp empty `auth-dir` and fake Z.AI `claude-api-key` provider entry with `api-key: "test-live-key"`, `prefix: "zai"`, and known model aliases `glm-5` / `glm-5-turbo`. Must be deleted after verification and must not be committed.
- `$HOME/.cli-proxy-api/merged-config.yaml`: Not used for live backend verification. Existing user runtime config may be stale or contain unrelated real credentials.
- `docs/supercode/20260506-force-model-prefix-b1c3/plan.md`: This execution plan artifact only.

# Task Sections

## Task 1 — Add generated-config coverage and bundled setting

- **Task id:** T1
- **Task name:** Add `force-model-prefix` config coverage and setting
- **Purpose:** Ensure the generated CLIProxyAPI config includes the global setting needed to suppress raw duplicate model IDs for prefixed provider credentials.
- **Files to create / modify / test:**
  - Modify: `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`
  - Modify: `src/Sources/Resources/config.yaml`
  - Modify: `src/Tests/CCProxyTests/Fixtures/config.yaml`
  - Test: `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`
- **Concrete steps:**
  1. In `ServerManagerConfigTests.swift`, identify the existing generated merged config test that asserts bundled config content and generated provider entries.
  2. Add a narrow assertion that the generated YAML contains exactly one top-level `force-model-prefix: true` line. Treat top-level as a line beginning at column 1 with no leading whitespace and matching `force-model-prefix: true` after trimming trailing whitespace.
  3. Run the targeted config-generation test before changing configs if the test runner supports selecting that test; confirm it fails because the setting is absent from the fixture-generated config. If selective execution is unavailable, run the smallest available `swift test` invocation for `CCProxyTests` and record that the new assertion fails before the config changes.
  4. Add `force-model-prefix: true` to `src/Sources/Resources/config.yaml` at the top-level with existing YAML style and no indentation.
  5. Add the same top-level `force-model-prefix: true` line to `src/Tests/CCProxyTests/Fixtures/config.yaml` so fixture-based generated config tests exercise ServerManager merge behavior with the new global key.
  6. Re-run the targeted config-generation test.
- **Explicit QA / verification:**
  - From `/Volumes/storage/workspace/ccproxy/.worktrees/20260506-force-model-prefix-b1c3/src`, run a targeted XCTest invocation for the updated config test, for example:
    - `swift test --filter ServerManagerConfigTests`
  - From `/Volumes/storage/workspace/ccproxy/.worktrees/20260506-force-model-prefix-b1c3`, verify both the real bundled config and the fixture config have exactly one top-level key without printing full config:
    ```sh
    python3 - <<'PY'
    from pathlib import Path
    checks = {
        'bundled': Path('src/Sources/Resources/config.yaml'),
        'fixture': Path('src/Tests/CCProxyTests/Fixtures/config.yaml'),
    }
    ok = True
    for label, p in checks.items():
        lines = p.read_text().splitlines()
        top = [line for line in lines if line.strip() == 'force-model-prefix: true' and not line.startswith((' ', '\t'))]
        any_matches = [line for line in lines if line.strip().startswith('force-model-prefix:')]
        print(f'{label}_force_model_prefix_top_level_true_count={len(top)}')
        print(f'{label}_force_model_prefix_any_key_count={len(any_matches)}')
        ok = ok and len(top) == 1 and len(any_matches) == 1
    raise SystemExit(0 if ok else 1)
    PY
    ```
  - Confirm the test output passes after the config change.
  - Inspect the diff to confirm only `src/Sources/Resources/config.yaml`, `src/Tests/CCProxyTests/Fixtures/config.yaml`, and `src/Tests/CCProxyTests/ServerManagerConfigTests.swift` changed for this task.
- **Expected result:**
  - Fixture-based generated merged config tests assert and pass with exactly one top-level `force-model-prefix: true` line present.
  - The bundled config includes exactly one top-level `force-model-prefix: true` entry.
  - The test fixture config includes exactly one top-level `force-model-prefix: true` entry.
- **Dependency notes:**
  - No dependency on Task 2.
  - If the fixture-based generated config does not include the fixture setting after editing `src/Tests/CCProxyTests/Fixtures/config.yaml`, inspect `ServerManager.swift` merge behavior and route back to planning before broadening implementation.
- **Parallel eligibility:**
  - Not parallelizable with Task 2 because Task 2 verifies behavior produced by this config/test change.

## Task 2 — Full regression and live backend verification

- **Task id:** T2
- **Task name:** Verify tests and `/v1/models` model exposure
- **Purpose:** Prove the minimal config-level fix passes the local test suite, prove CCProxy-generated config includes the setting via existing tests, and prove the worktree bundled CLIProxyAPI binary suppresses raw duplicates for the generated Z.AI provider shape using an isolated temporary config.
- **Files to create / modify / test:**
  - Test: `src/Sources/Resources/config.yaml`
  - Test: `src/Tests/CCProxyTests/Fixtures/config.yaml`
  - Test: `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`
  - Runtime verification target: isolated temporary config under `$(mktemp -d)` assembled during verification
  - Runtime verification endpoint: `http://127.0.0.1:8328/v1/models`
  - Runtime backend binary path: `/Volumes/storage/workspace/ccproxy/.worktrees/20260506-force-model-prefix-b1c3/src/Sources/Resources/cli-proxy-api`
  - Expected no modifications: production source other than `src/Sources/Resources/config.yaml`
- **Concrete steps:**
  1. From `/Volumes/storage/workspace/ccproxy/.worktrees/20260506-force-model-prefix-b1c3/src`, run the full Swift test suite.
  2. Treat the passing `ServerManagerConfigTests` assertion from Task 1 as the generated-config proof: CCProxy/ServerManager-generated YAML produced from the fixture config includes exactly one top-level `force-model-prefix: true` line. Do not use `$HOME/.cli-proxy-api/merged-config.yaml` for live verification.
  3. Verify port `8328` is available before starting the live backend. If port `8328` is occupied by any unknown process, mark live verification blocked rather than querying it or killing it.
  4. Create an isolated temporary config by copying the worktree bundled config, overriding `auth-dir` to a temp empty auth directory, and appending a fake Z.AI `claude-api-key` provider entry with the same generated provider shape used by `ServerManager`: `api-key: "test-live-key"`, `prefix: "zai"`, `base-url: "https://api.z.ai/api/anthropic"`, and models `glm-5` / `glm-5-turbo`.
  5. Confirm the temporary config has exactly one top-level `force-model-prefix: true` key. Print counts only, not the full config.
  6. Start the worktree bundled `cli-proxy-api` explicitly with the temporary config on default port `8328`, redirect logs to a temporary file, capture the PID, and verify the PID is still running before querying.
  7. Query `http://127.0.0.1:8328/v1/models` against that captured process only.
  8. Compare only the known fake Z.AI aliases/canonicals configured in the temporary config:
     - expected prefixed IDs: `zai/glm-5`, `zai/glm-5-turbo`
     - raw duplicate IDs that must be absent: `glm-5`, `glm-5-turbo`
  9. Stop the captured backend PID and delete the temporary directory.
  10. If raw duplicates persist for the known fake aliases, stop and report that the plan must be revised for an `excluded-models` fallback; do not implement fallback filtering.
- **Explicit QA / verification:**
  - Run from `src`:
    - `swift test`
  - Confirm generated-config coverage from Task 1 remains in `ServerManagerConfigTests.swift` and passes under `swift test`; this is the proof that CCProxy-generated config includes the global setting when merging from the fixture config used by those tests.
  - Run the following live backend command templates in the same shell session so `CCPROXY_LIVE_TMPDIR` and `CCPROXY_LIVE_PID` remain available. If any live query step fails after the backend starts, still run the cleanup template before reporting failure.
  - From `/Volumes/storage/workspace/ccproxy/.worktrees/20260506-force-model-prefix-b1c3`, verify port `8328` is available before starting the backend:
    ```sh
    python3 - <<'PY'
    import socket, sys
    s = socket.socket()
    try:
        s.bind(('127.0.0.1', 8328))
        print('port_8328_available=yes')
        sys.exit(0)
    except OSError:
        print('port_8328_available=no')
        print('live_verification_blocked=port_8328_occupied_by_unknown_process')
        sys.exit(2)
    finally:
        s.close()
    PY
    ```
  - Assemble an isolated temporary config and verify it contains exactly one top-level `force-model-prefix: true` key. This command prints only creation status and key counts; `test-live-key` is a fake non-secret literal and the config must not be committed:
    ```sh
    TMPDIR="$(mktemp -d)"
    export CCPROXY_LIVE_TMPDIR="$TMPDIR"
    python3 - <<'PY'
    from pathlib import Path
    import os, sys
    root = Path('/Volumes/storage/workspace/ccproxy/.worktrees/20260506-force-model-prefix-b1c3')
    bundled = root / 'src/Sources/Resources/config.yaml'
    out = Path(os.environ['CCPROXY_LIVE_TMPDIR']) / 'live-force-model-prefix.yaml'
    auth_dir = Path(os.environ['CCPROXY_LIVE_TMPDIR']) / 'empty-auth'
    auth_dir.mkdir()
    auth_dir_empty = not any(auth_dir.iterdir())
    content = bundled.read_text()
    lines = content.splitlines()
    replaced = False
    for i, line in enumerate(lines):
        if line.startswith('auth-dir:'):
            lines[i] = f'auth-dir: "{auth_dir}"'
            replaced = True
            break
    if not replaced:
        lines.append(f'auth-dir: "{auth_dir}"')
    content = '\n'.join(lines) + '\n'
    provider = '''

claude-api-key:
  # Z.AI Claude-compatible upstream (isolated live verification fake key)
  - api-key: "test-live-key"
    prefix: "zai"
    base-url: "https://api.z.ai/api/anthropic"
    models:
      - name: "glm-5"
      - name: "glm-5-turbo"
'''
    out.write_text(content.rstrip() + provider)
    lines = out.read_text().splitlines()
    top = [line for line in lines if line.strip() == 'force-model-prefix: true' and not line.startswith((' ', '\t'))]
    any_keys = [line for line in lines if line.strip().startswith('force-model-prefix:')]
    auth_dir_lines = [line for line in lines if line.startswith('auth-dir:') and str(auth_dir) in line]
    print('temp_live_config_created=yes')
    print(f'temp_auth_dir_empty={"yes" if auth_dir_empty else "no"}')
    print(f'temp_auth_dir_override_count={len(auth_dir_lines)}')
    print(f'temp_force_model_prefix_top_level_true_count={len(top)}')
    print(f'temp_force_model_prefix_any_key_count={len(any_keys)}')
    sys.exit(0 if len(top) == 1 and len(any_keys) == 1 and len(auth_dir_lines) == 1 and auth_dir_empty else 1)
    PY
    ```
  - Start the worktree bundled backend explicitly with the temporary config, capture the PID, and print only PID/provenance status:
    ```sh
    BACKEND="/Volumes/storage/workspace/ccproxy/.worktrees/20260506-force-model-prefix-b1c3/src/Sources/Resources/cli-proxy-api"
    CONFIG="$CCPROXY_LIVE_TMPDIR/live-force-model-prefix.yaml"
    LOG="$CCPROXY_LIVE_TMPDIR/cli-proxy-api.log"
    "$BACKEND" -config "$CONFIG" >"$LOG" 2>&1 &
    CCPROXY_LIVE_PID=$!
    export CCPROXY_LIVE_PID
    sleep 2
    if kill -0 "$CCPROXY_LIVE_PID" 2>/dev/null; then
      printf 'live_backend_started=yes\n'
      printf 'live_backend_pid=%s\n' "$CCPROXY_LIVE_PID"
      printf 'live_backend_binary=%s\n' "$BACKEND"
      printf 'live_backend_port=8328\n'
    else
      printf 'live_backend_started=no\n'
      exit 1
    fi
    ```
  - Query the captured backend on `http://127.0.0.1:8328/v1/models` and compare only the fake configured Z.AI aliases/canonicals. Because port `8328` was verified free immediately before starting the captured PID, and the PID is checked again before querying, the response is attributed to the worktree bundled backend process:
    ```sh
    python3 - <<'PY'
    import json, os, sys, urllib.request, urllib.error, subprocess
    pid = os.environ.get('CCPROXY_LIVE_PID')
    if not pid:
        print('live_backend_pid_present=no')
        sys.exit(1)
    if subprocess.run(['kill', '-0', pid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
        print('live_backend_pid_running=no')
        sys.exit(1)
    print('live_backend_pid_running=yes')
    url = 'http://127.0.0.1:8328/v1/models'
    req = urllib.request.Request(url)
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            print(f'models_http_status={resp.status}')
            payload = json.loads(resp.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        print(f'models_http_status={e.code}')
        sys.exit(1)
    if isinstance(payload, dict):
        models = payload.get('data', [])
    elif isinstance(payload, list):
        models = payload
    else:
        models = []
    ids = []
    for item in models:
        if isinstance(item, dict):
            mid = item.get('id') or item.get('name')
            if isinstance(mid, str):
                ids.append(mid)
        elif isinstance(item, str):
            ids.append(item)
    expected_prefixed = {'zai/glm-5', 'zai/glm-5-turbo'}
    forbidden_raw = {'glm-5', 'glm-5-turbo'}
    present_prefixed = sorted(expected_prefixed.intersection(ids))
    present_raw = sorted(forbidden_raw.intersection(ids))
    print(f'expected_fake_zai_prefixed_present_count={len(present_prefixed)}')
    print(f'expected_fake_zai_prefixed_all_present={"yes" if len(present_prefixed) == len(expected_prefixed) else "no"}')
    print(f'forbidden_fake_zai_raw_present_count={len(present_raw)}')
    print(f'forbidden_fake_zai_raw_present={"yes" if present_raw else "no"}')
    sys.exit(0 if len(present_prefixed) == len(expected_prefixed) and not present_raw else 1)
    PY
    ```
  - Stop the captured backend PID and remove the temporary directory:
    ```sh
    if [ -n "${CCPROXY_LIVE_PID:-}" ]; then
      kill "$CCPROXY_LIVE_PID" 2>/dev/null || true
      wait "$CCPROXY_LIVE_PID" 2>/dev/null || true
      printf 'live_backend_stopped=yes\n'
    fi
    if [ -n "${CCPROXY_LIVE_TMPDIR:-}" ]; then
      rm -rf "$CCPROXY_LIVE_TMPDIR"
      printf 'temp_live_config_removed=yes\n'
    fi
    ```
  - Verify the expected successful result is: fake configured prefixed Z.AI model IDs `zai/glm-5` and `zai/glm-5-turbo` present, and fake configured raw duplicate IDs `glm-5` and `glm-5-turbo` absent.
- **Expected result:**
  - `swift test` passes.
  - `ServerManagerConfigTests` prove fixture-based CCProxy-generated config includes exactly one top-level `force-model-prefix: true` key.
  - Real bundled config and fixture config each include exactly one top-level `force-model-prefix: true` key.
  - Temporary live config includes exactly one top-level `force-model-prefix: true` key, overrides `auth-dir` to a temp empty auth directory, and includes a fake Z.AI provider entry using the generated provider shape.
  - Worktree bundled backend binary is the process queried on port `8328`, identified by captured PID and stopped after verification.
  - Isolated `/v1/models` no longer exposes raw fake Z.AI `glm-5` / `glm-5-turbo` duplicates while still exposing prefixed fake Z.AI `zai/glm-5` / `zai/glm-5-turbo` model IDs. This synthetic live config is representative for CLIProxyAPI behavior because it uses the same prefixed `claude-api-key` provider shape generated by ServerManager, while tests/static checks prove generated config carries the global setting.
  - Kimi/MiniMax are not separately live-tested in this task because the bug reproduction was Z.AI-specific and the static/generated config checks prove the global backend setting applies before all generated prefixed provider entries. If future evidence shows provider-specific behavior, route back to planning.
  - If this expected result is not achieved, execution stops and routes back to planning for the spec-approved fallback path.
- **Dependency notes:**
  - Depends on Task 1 completion.
  - Does not require local user credentials; the live config uses fake non-secret literal `test-live-key`.
  - Requires default backend port `8328` to be available before starting the worktree bundled binary. If port `8328` is occupied by any unknown process, do not query it and do not kill it; report live verification as blocked.
- **Parallel eligibility:**
  - Not parallelizable with Task 1.

# QA Standard

- Required automated checks:
  - `swift test --filter ServerManagerConfigTests` from `src` after Task 1.
  - `swift test` from `src` after all code/config changes.
- Required manual/runtime checks:
  - Bundled config check prints only:
    - `bundled_force_model_prefix_top_level_true_count=1`
    - `bundled_force_model_prefix_any_key_count=1`
  - Fixture config check prints only:
    - `fixture_force_model_prefix_top_level_true_count=1`
    - `fixture_force_model_prefix_any_key_count=1`
  - Generated-config coverage must come from `ServerManagerConfigTests`, not `$HOME/.cli-proxy-api/merged-config.yaml`, and must prove fixture-based generated YAML includes exactly one top-level `force-model-prefix: true` line.
  - Live backend check must not use `$HOME/.cli-proxy-api/merged-config.yaml` or real user auth files. It must assemble an isolated temporary config from the bundled config plus a temp empty `auth-dir` override and fake Z.AI provider entry, then print only:
    - `port_8328_available=yes`
    - `temp_live_config_created=yes`
    - `temp_auth_dir_empty=yes`
    - `temp_auth_dir_override_count=1`
    - `temp_force_model_prefix_top_level_true_count=1`
    - `temp_force_model_prefix_any_key_count=1`
    - `live_backend_started=yes`
    - `live_backend_pid=<pid>`
    - `live_backend_binary=/Volumes/storage/workspace/ccproxy/.worktrees/20260506-force-model-prefix-b1c3/src/Sources/Resources/cli-proxy-api`
    - `live_backend_port=8328`
    - `live_backend_pid_running=yes`
    - `models_http_status=200`
    - `expected_fake_zai_prefixed_present_count=2`
    - `expected_fake_zai_prefixed_all_present=yes`
    - `forbidden_fake_zai_raw_present_count=0`
    - `forbidden_fake_zai_raw_present=no`
    - `live_backend_stopped=yes`
    - `temp_live_config_removed=yes`
  - Redaction boundaries:
    - Allowed to print: pass/fail status, counts above, backend PID, backend binary path, port, HTTP status, and sanitized yes/no model-ID presence for the four known fake IDs only.
    - Not allowed to print: real API keys, bearer tokens, management secret, full bundled config, full temporary config, full `$HOME/.cli-proxy-api/merged-config.yaml`, full model response payload, auth JSON files, or backend logs.
- Required review checks:
  - Diff does not change provider architecture, provider prefixes, model names, auth flow, OAuth listings, ThinkingProxy behavior, or bundled backend binary.
  - Diff does not add dependencies or YAML parser usage.
  - Diff does not contain secrets or local credential artifacts.
  - Diff is limited to `src/Sources/Resources/config.yaml`, `src/Tests/CCProxyTests/Fixtures/config.yaml`, and `src/Tests/CCProxyTests/ServerManagerConfigTests.swift` unless a scoped test failure proves another direct spec-aligned edit is needed.
  - Implementation final evidence is limited to tests, config key counts, and sanitized live model presence/absence. PR creation, PR merge, and patch release are not part of execution completion and require finish-stage routing or explicit user instruction.
- Failure policy:
  - If automated tests fail, fix only within scoped files unless evidence shows the spec requires a different file.
  - If live `/v1/models` still shows raw duplicates, stop and route back to planning for `excluded-models` fallback.
  - If port `8328` is occupied by an unknown process, do not query it and do not kill it; mark live verification blocked with `live_verification_blocked=port_8328_occupied_by_unknown_process`.
  - If live backend verification cannot run because the worktree bundled binary cannot start or the environment cannot bind port `8328`, do not mark the live success criterion complete; report it as blocked with the missing prerequisite.

# Revisions

- 2026-05-07: Initial execution plan created from approved spec and planning evidence packet. Plan keeps scope to bundled config plus config-generation tests, with full Swift test and redacted live `/v1/models` verification.
- 2026-05-07: Revised plan to specify exact live verification commands, default port `8328`, `$HOME/.cli-proxy-api/merged-config.yaml` regeneration expectations, top-level/exactly-once config checks, Z.AI versus Kimi/MiniMax coverage rationale, redaction boundaries, and PR/release handoff boundary.
- 2026-05-07: Revised live verification to avoid stale `$HOME` config, real credentials, and stale port state by using an isolated temporary config with fake Z.AI provider entry, explicit port availability check, captured worktree backend PID, sanitized fake-ID comparisons, and required backend cleanup.
- 2026-05-07: Revised plan to include the fixture config used by `ServerManagerConfigTests`, require exact top-level checks for both real bundled and fixture-generated config paths, override live `auth-dir` to a temp empty directory, fix model parser branching for dict/list responses, and clarify synthetic live config representativeness.
