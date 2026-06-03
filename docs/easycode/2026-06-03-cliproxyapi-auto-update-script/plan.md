# CLIProxyAPI Auto Update Script Implementation Plan

> **For agentic workers:** Each task is dispatched to the `executor` agent. Follow the EasyCode `execute` stage: per-task TDD cycle, `code-spec-reviewer` and `code-quality-reviewer` review gates, and `completion-verifier` for final evidence. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable Bash script that resolves the latest public CLIProxyAPI release, verifies the macOS arm64 archive checksum, safely updates the bundled backend binary on request, and supports a non-mutating dry run.

**Architecture:** The implementation is a standalone repository script under `scripts/` that follows existing Bash conventions: strict error handling, script-relative repository root detection, dependency checks, and clear status output. It uses the public GitHub releases API to discover the latest `router-for-me/CLIProxyAPI` release, downloads assets into a temporary directory, verifies SHA-256 before extraction, inspects the archive for exactly one executable, and only then replaces `src/Sources/Resources/cli-proxy-api` in update mode. Dry-run mode performs discovery, download, checksum verification, extraction, and executable inspection without modifying the tracked backend binary.

**Tech Stack:** Bash 3+ compatible shell script, `curl`, `python3` for JSON parsing, `shasum`, `tar`, `mktemp`, `chmod`, optional `xattr`, `make backend-version`, Git.

## Approved Inputs and Gates

- Work ID: `2026-06-03-cliproxyapi-auto-update-script`
- Approved spec: `docs/easycode/2026-06-03-cliproxyapi-auto-update-script/spec.md`
- Approved evidence: `docs/easycode/2026-06-03-cliproxyapi-auto-update-script/evidence.md`
- Spec reviewer result: PASS
- Worktree path: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-03-cliproxyapi-auto-update-script`
- Branch: `work/2026-06-03-cliproxyapi-auto-update-script`
- Worktree checkpoint commit: `afed457`
- Baseline status: ready
- Baseline command: `make backend-version && make test && make build`
- Baseline result: passed
- Baseline backend version output: `CLIProxyAPI Version: 7.1.40, Commit: 02d0d92a, BuiltAt: 2026-06-02T11:31:42Z`
- Degraded baseline caveat: none
- Root checkout caveat: the root checkout has an unrelated dirty `.gitignore`; do not touch it and do not run implementation from the root checkout.

## File Structure

Create:

- `scripts/update-cli-proxy-api.sh`

Modify:

- `docs/easycode/2026-06-03-cliproxyapi-auto-update-script/plan.md` is created by the plan stage only and should be committed with the local implementation commit if EasyCode finish policy wants workflow artifacts included.

Do not modify:

- `src/Sources/Resources/cli-proxy-api` in the final committed diff. Update-mode verification may replace it transiently only when the task explicitly restores it before commit.
- `.gitignore`, especially the unrelated dirty root checkout `.gitignore`.
- `Makefile`, Swift source, Sparkle files, appcast files, release scripts, generated archives, app bundles, or EasyCode state/ledger artifacts.

Test and verification targets:

- `scripts/update-cli-proxy-api.sh --help`
- `scripts/update-cli-proxy-api.sh --dry-run`
- `make backend-version`
- `make test`
- `make build`
- `git status --short`

## Execution Rules

- Run all commands from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-03-cliproxyapi-auto-update-script` unless a command states otherwise.
- Pre-execute gate: no implementation, execute-stage work, source edits, test edits, script creation, commit, push, PR, or finish action may begin until the current `docs/easycode/2026-06-03-cliproxyapi-auto-update-script/plan.md` has `plan-checker` PASS, `plan-challenger` PASS, and explicit user approval. If this plan is revised after review, rerun both plan reviewers and obtain user approval of the revised plan before execute-stage work begins.
- Do not run `make clean`.
- Do not run download/update commands from the root checkout.
- Do not require GitHub authentication or Sparkle signing keys.
- Do not commit downloaded archives, extracted files, temporary directories, app bundles, or unrelated files.
- Treat network-dependent failures separately from script logic failures; if GitHub is unreachable or rate-limited, stop and report the exact failing command and output.

## Task 1: Add Script Skeleton, Help, and Worktree Safety

- [ ] RED: prove the script behavior does not exist yet.
  - Command: `test -x scripts/update-cli-proxy-api.sh && scripts/update-cli-proxy-api.sh --help`
  - Expected failure: command exits non-zero because `scripts/update-cli-proxy-api.sh` does not exist or is not executable.
- [ ] GREEN: create `scripts/update-cli-proxy-api.sh` with the minimal non-network skeleton.
  - File to edit: `scripts/update-cli-proxy-api.sh`
  - Required contents and behavior:
    - Shebang `#!/bin/bash`.
    - `set -euo pipefail`.
    - Script-relative root detection equivalent to `ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`.
    - Constants for `OWNER_REPO="router-for-me/CLIProxyAPI"`, `TARGET_BINARY="$ROOT_DIR/src/Sources/Resources/cli-proxy-api"`, and latest release API URL.
    - Argument parsing for `--dry-run`, `--help`, and no argument. No argument means update mode.
    - Reject unknown options with a clear error and exit code 2.
    - Dependency checks for `curl`, `python3`, `shasum`, `tar`, `mktemp`, `chmod`, and `make` only when the command path needs them.
    - Clear usage text explaining that `--dry-run` downloads and verifies without replacing `src/Sources/Resources/cli-proxy-api`.
    - No network calls in `--help`.
  - Set executable bit with: `chmod +x scripts/update-cli-proxy-api.sh`
- [ ] GREEN verification.
  - Command: `scripts/update-cli-proxy-api.sh --help`
  - Expected pass: exits 0 and output contains `Usage: scripts/update-cli-proxy-api.sh [--dry-run]` and `Updates src/Sources/Resources/cli-proxy-api`.
  - Command: `scripts/update-cli-proxy-api.sh --unknown-option`
  - Expected failure: exits 2 and output contains `Unknown option: --unknown-option`.
  - Command: `bash -n scripts/update-cli-proxy-api.sh`
  - Expected pass: exits 0 with no syntax errors.
- [ ] Refactor only while checks stay green.
  - Keep the skeleton small; do not add release lookup or download logic before Task 2.

## Task 2: Implement Latest Release and Asset Resolution

- [ ] RED: define the expected dry-run discovery behavior before implementing it.
  - Command: `scripts/update-cli-proxy-api.sh --dry-run`
  - Expected failure: exits non-zero because latest release lookup and asset resolution are not implemented yet. Output should not report a successful dry run.
- [ ] GREEN: add latest release lookup and asset selection.
  - File to edit: `scripts/update-cli-proxy-api.sh`
  - Required behavior:
    - Request `https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest` with `curl --fail --location --silent --show-error`.
    - Parse the JSON with `python3`, not brittle shell-only JSON parsing.
    - Read `tag_name` and assets with `name`, `browser_download_url`, and `digest`.
    - Select exactly one macOS arm64 archive asset whose name matches `^CLIProxyAPI_[^/]+_darwin_aarch64\.tar\.gz$`.
    - Select exactly one `checksums.txt` asset from the same release.
    - Fail clearly if `tag_name` is missing, the archive asset is missing, multiple matching archive assets exist, or `checksums.txt` is missing.
    - Print the resolved release tag and selected asset name.
    - Do not replace `src/Sources/Resources/cli-proxy-api` in this task.
- [ ] GREEN verification.
  - Command: `scripts/update-cli-proxy-api.sh --dry-run`
  - Expected partial pass for this task: output contains `Resolved CLIProxyAPI release: v` and `Selected asset: CLIProxyAPI_`; if the command continues to fail later because checksum/download/extraction is not implemented, that is acceptable for this task only and the failure must occur after release and asset selection are printed.
  - Command: `bash -n scripts/update-cli-proxy-api.sh`
  - Expected pass: exits 0 with no syntax errors.
- [ ] Refactor only while checks stay green.
  - Keep GitHub API parsing in a small function such as `resolve_latest_release`.
  - Do not add version arguments or platform support outside macOS arm64.

## Task 3: Implement Dry-Run Download, SHA-256 Verification, and Archive Inspection

- [ ] RED: require full dry-run verification before implementation.
  - Command: `before_sha="$(shasum -a 256 src/Sources/Resources/cli-proxy-api | awk '{print $1}')" && scripts/update-cli-proxy-api.sh --dry-run && after_sha="$(shasum -a 256 src/Sources/Resources/cli-proxy-api | awk '{print $1}')" && test "$before_sha" = "$after_sha"`
  - Expected failure: exits non-zero because full dry-run download, checksum verification, and archive inspection are not implemented yet, or dry-run does not yet prove the binary is unchanged.
- [ ] GREEN: add non-mutating dry-run verification.
  - File to edit: `scripts/update-cli-proxy-api.sh`
  - Required behavior:
    - Create a temporary working directory with `mktemp -d` and remove it with a trap on exit.
    - Download the selected tarball and `checksums.txt` into the temporary directory with `curl --fail --location --silent --show-error`.
    - Determine the expected SHA-256 by matching the selected archive name in `checksums.txt`.
    - If the GitHub API asset `digest` is present and starts with `sha256:`, verify it agrees with `checksums.txt`; fail clearly if it disagrees.
    - Compute the actual archive SHA-256 with `shasum -a 256` and compare it to the checksum value.
    - Extract the tarball into a temporary extraction directory only after checksum verification.
    - Inspect the extracted archive and identify exactly one executable file suitable for CLIProxyAPI. The executable candidate must be a regular file with executable permissions, must not be a directory, and must be validated by running its `--version` output and requiring `CLIProxyAPI Version`.
    - Fail clearly if zero or multiple executable candidates are found.
    - In `--dry-run`, print `Dry run complete; src/Sources/Resources/cli-proxy-api was not modified.` and exit 0 without replacing the tracked binary.
- [ ] GREEN verification.
  - Command: `before_sha="$(shasum -a 256 src/Sources/Resources/cli-proxy-api | awk '{print $1}')" && scripts/update-cli-proxy-api.sh --dry-run && after_sha="$(shasum -a 256 src/Sources/Resources/cli-proxy-api | awk '{print $1}')" && test "$before_sha" = "$after_sha"`
  - Expected pass: exits 0; output includes `Resolved CLIProxyAPI release: v`, `Selected asset: CLIProxyAPI_`, `Checksum verified: sha256`, `Archive contains executable:`, and `Dry run complete; src/Sources/Resources/cli-proxy-api was not modified.`
  - Command: `git status --short src/Sources/Resources/cli-proxy-api scripts/update-cli-proxy-api.sh`
  - Expected pass: output shows `?? scripts/update-cli-proxy-api.sh` or `A  scripts/update-cli-proxy-api.sh`; it must not show any change for `src/Sources/Resources/cli-proxy-api`.
  - Command: `bash -n scripts/update-cli-proxy-api.sh`
  - Expected pass: exits 0 with no syntax errors.
- [ ] Refactor only while checks stay green.
  - Keep download, checksum, and archive inspection functions separate enough to make failures readable.
  - Do not persist temporary downloads or extracted contents under the repository.

## Task 4: Implement Update Mode with Safe Replacement and Validation

- [ ] RED: prove update mode is not complete before adding replacement logic.
  - Command: `scripts/update-cli-proxy-api.sh`
  - Expected failure before implementation: exits non-zero because replacement and validation are not implemented yet, or stops before replacing the tracked binary.
  - Immediate cleanup if the RED command unexpectedly changes the binary: `git checkout -- src/Sources/Resources/cli-proxy-api`
- [ ] GREEN: add update-mode replacement and validation.
  - File to edit: `scripts/update-cli-proxy-api.sh`
  - Required behavior:
    - Reuse the same latest release, download, checksum, extraction, and executable validation path as dry-run.
    - Before replacing, confirm `src/Sources/Resources/cli-proxy-api` exists or fail clearly.
    - Replace only `src/Sources/Resources/cli-proxy-api`; do not touch `config.yaml`, `static`, app bundles, Sparkle files, Swift files, or ignored generated artifacts.
    - Copy the validated executable into place atomically enough for a script: copy to a temporary sibling path in `src/Sources/Resources/`, set mode `755`, remove quarantine metadata with `xattr -d com.apple.quarantine` if `xattr` exists and the attribute is present, then move it over `src/Sources/Resources/cli-proxy-api`.
    - Validate the replacement by running `make backend-version` from the repository root and requiring output containing `CLIProxyAPI Version`.
    - Print the updated backend version output.
    - Do not run `make clean`.
- [ ] GREEN verification with mandatory restore before commit.
  - Command: `bash -c 'set -e; original_sha="$(shasum -a 256 src/Sources/Resources/cli-proxy-api | awk "{print \$1}")"; restore_binary() { status=$?; git checkout -- src/Sources/Resources/cli-proxy-api; restored_sha="$(shasum -a 256 src/Sources/Resources/cli-proxy-api | awk "{print \$1}")"; if [ "$restored_sha" != "$original_sha" ]; then printf "%s\n" "ERROR: src/Sources/Resources/cli-proxy-api restore failed" >&2; exit 1; fi; exit "$status"; }; trap restore_binary EXIT; scripts/update-cli-proxy-api.sh; make backend-version; updated_sha="$(shasum -a 256 src/Sources/Resources/cli-proxy-api | awk "{print \$1}")"; if [ "$updated_sha" = "$original_sha" ]; then printf "%s\n" "Update mode completed but latest binary matches original hash"; else printf "%s\n" "Update mode changed binary hash as expected"; fi'`
  - Expected pass: the command always runs `git checkout -- src/Sources/Resources/cli-proxy-api` through the `EXIT` trap before returning to the shell; update mode exits 0, output includes `CLIProxyAPI Version`, and restore validation confirms the final hash equals the original hash. If the latest release is the same as the existing binary, the command may print `Update mode completed but latest binary matches original hash`, which is acceptable only because checksum verification, replacement flow, backend validation, and restore validation still completed.
  - Restore verification command after the trapped command returns: `expected_sha="$(git show HEAD:src/Sources/Resources/cli-proxy-api | shasum -a 256 | awk '{print $1}')" && make backend-version && test "$(shasum -a 256 src/Sources/Resources/cli-proxy-api | awk '{print $1}')" = "$expected_sha" && git status --short src/Sources/Resources/cli-proxy-api`
  - Expected pass after restore: `make backend-version` outputs `CLIProxyAPI Version: 7.1.40, Commit: 02d0d92a, BuiltAt: 2026-06-02T11:31:42Z` or another checkpoint baseline-equivalent version if the checkpoint binary changed; `git status --short src/Sources/Resources/cli-proxy-api` outputs nothing.
  - Command: `scripts/update-cli-proxy-api.sh --dry-run`
  - Expected pass: dry-run still completes and does not modify `src/Sources/Resources/cli-proxy-api`.
  - Command: `bash -n scripts/update-cli-proxy-api.sh`
  - Expected pass: exits 0 with no syntax errors.
- [ ] Refactor only while checks stay green.
  - Apply the `simplify` skill discipline during cleanup: behavior is locked by dry-run and update-mode verification, cleanup one smell at a time, and rerun `bash -n`, `--help`, and `--dry-run` after each cleanup.

## Task 5: Final Local Verification and Commit Preparation

- [ ] RED: check for unsafe or unexpected repository state before final verification.
  - Command: `git status --short`
  - Expected result before staging: only `?? scripts/update-cli-proxy-api.sh` and `?? docs/easycode/2026-06-03-cliproxyapi-auto-update-script/plan.md` should be untracked, or the same files should be staged if an earlier step staged them. There must be no `src/Sources/Resources/cli-proxy-api` change and no `.gitignore` change.
  - Stop if any unrelated file appears.
- [ ] GREEN: run focused script checks.
  - Command: `bash -n scripts/update-cli-proxy-api.sh`
  - Expected pass: exits 0 with no syntax errors.
  - Command: `scripts/update-cli-proxy-api.sh --help`
  - Expected pass: exits 0 and prints usage text.
  - Command: `before_sha="$(shasum -a 256 src/Sources/Resources/cli-proxy-api | awk '{print $1}')" && scripts/update-cli-proxy-api.sh --dry-run && after_sha="$(shasum -a 256 src/Sources/Resources/cli-proxy-api | awk '{print $1}')" && test "$before_sha" = "$after_sha"`
  - Expected pass: dry-run resolves latest release, verifies checksum, validates one executable candidate, and leaves the tracked backend binary unchanged.
- [ ] GREEN: run project baseline verification.
  - Command: `make backend-version && make test && make build`
  - Expected pass: `make backend-version` outputs a line containing `CLIProxyAPI Version`, Swift tests pass, and Swift build completes.
- [ ] GREEN: verify final diff scope.
  - Command: `git status --short`
  - Expected pass before staging: only `scripts/update-cli-proxy-api.sh` and `docs/easycode/2026-06-03-cliproxyapi-auto-update-script/plan.md` are changed or untracked; there must be no `src/Sources/Resources/cli-proxy-api` entry.
  - Command: `git add --intent-to-add scripts/update-cli-proxy-api.sh docs/easycode/2026-06-03-cliproxyapi-auto-update-script/plan.md`
  - Expected pass: exits 0 and makes diffs for any new files visible without staging their content.
  - Command: `git diff --stat -- scripts/update-cli-proxy-api.sh docs/easycode/2026-06-03-cliproxyapi-auto-update-script/plan.md && git diff -- scripts/update-cli-proxy-api.sh docs/easycode/2026-06-03-cliproxyapi-auto-update-script/plan.md`
  - Expected pass: diff contains only the new script and this plan artifact; it contains no binary diff and no changes to `src/Sources/Resources/cli-proxy-api`.
  - Command: `git add scripts/update-cli-proxy-api.sh docs/easycode/2026-06-03-cliproxyapi-auto-update-script/plan.md`
  - Expected pass: exits 0 and stages only the intended files.
  - Command: `git diff --cached --name-only`
  - Expected pass: output lists exactly these two lines and no other paths: `docs/easycode/2026-06-03-cliproxyapi-auto-update-script/plan.md` and `scripts/update-cli-proxy-api.sh`.
  - Command: `git diff --cached --stat && git diff --cached`
  - Expected pass: staged diff contains only `docs/easycode/2026-06-03-cliproxyapi-auto-update-script/plan.md` and `scripts/update-cli-proxy-api.sh`; no updated `src/Sources/Resources/cli-proxy-api` binary is staged.
- [ ] Create the local implementation commit only after all verification passes.
  - Command: `git commit -m "Add CLIProxyAPI update script"`
  - Expected pass: creates one local commit on `work/2026-06-03-cliproxyapi-auto-update-script` containing the script and plan artifact.
  - Command: `git status --short`
  - Expected pass after commit: no output.

## Full Verification Before Completion

Run these commands from `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-03-cliproxyapi-auto-update-script` after the final local commit:

- [ ] `git branch --show-current`
  - Expected output: `work/2026-06-03-cliproxyapi-auto-update-script`
- [ ] `bash -n scripts/update-cli-proxy-api.sh`
  - Expected result: exits 0.
- [ ] `scripts/update-cli-proxy-api.sh --help`
  - Expected result: exits 0 and prints usage text.
- [ ] `before_sha="$(shasum -a 256 src/Sources/Resources/cli-proxy-api | awk '{print $1}')" && scripts/update-cli-proxy-api.sh --dry-run && after_sha="$(shasum -a 256 src/Sources/Resources/cli-proxy-api | awk '{print $1}')" && test "$before_sha" = "$after_sha"`
  - Expected result: exits 0, verifies latest public release asset/checksum/archive executable, and leaves the tracked binary unchanged.
- [ ] `make backend-version && make test && make build`
  - Expected result: exits 0; backend version output contains `CLIProxyAPI Version`; tests and build pass.
- [ ] `git status --short`
  - Expected result: no output.

## Code Review Gates Before PR Creation

- [ ] Run EasyCode execute-stage review gates after implementation and local verification:
  - `code-spec-reviewer` must confirm the implementation matches `docs/easycode/2026-06-03-cliproxyapi-auto-update-script/spec.md` and does not perform the non-goal one-off CLIProxyAPI update in the committed diff.
  - `code-quality-reviewer` must confirm the script is maintainable, has clear failures, safely handles temporary files, avoids broad cleanup, and does not require Sparkle keys.
  - `completion-verifier` must confirm local verification evidence, final diff scope, and clean worktree status.
- [ ] If any review gate fails, return to the executor task that owns the failure, revise only within approved scope, rerun focused verification, rerun full verification, and rerun the failed review gate plus any dependent review gate.

## Finish-Stage Commands Not Included in Execute Work

Normal mode applies. Do not push, create a PR, merge, release, or update the local main branch during execute. After final-review PASS, ask the user which finish action they want.

If the user later approves pushing and PR creation during finish, use these commands from the worktree after rechecking status and recent commits:

- [ ] `git status --short`
  - Expected result: no output.
- [ ] `git log --oneline -5`
  - Expected result: shows the local implementation commit `Add CLIProxyAPI update script` at the top.
- [ ] `git push -u origin work/2026-06-03-cliproxyapi-auto-update-script`
  - Expected result: branch is pushed and upstream is set.
- [ ] `gh pr create --base main --head work/2026-06-03-cliproxyapi-auto-update-script --title "Add CLIProxyAPI update script" --body "Adds a Bash updater for the bundled CLIProxyAPI backend with latest-release resolution, checksum verification, dry-run preview, safe replacement, and backend-version validation."`
  - Expected result: prints the created PR URL.

## Stop Conditions

- Stop if the current directory is not `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-03-cliproxyapi-auto-update-script` or `git branch --show-current` is not `work/2026-06-03-cliproxyapi-auto-update-script`.
- Stop before execute-stage work if the current plan has not received `plan-checker` PASS, `plan-challenger` PASS, and explicit user approval.
- Stop if `docs/easycode/2026-06-03-cliproxyapi-auto-update-script/spec.md` or `docs/easycode/2026-06-03-cliproxyapi-auto-update-script/evidence.md` is missing.
- Do not stop or return control immediately after update-mode verification if `src/Sources/Resources/cli-proxy-api` is modified; first run `git checkout -- src/Sources/Resources/cli-proxy-api`, verify its SHA-256 hash matches the saved original hash, and verify `git status --short src/Sources/Resources/cli-proxy-api` outputs nothing. If restore fails, keep the task blocked and report the restore failure; do not proceed to other work, staging, commit, review, or handoff with the binary modified.
- Stop if `git status --short` shows unrelated changes, especially `.gitignore` or `src/Sources/Resources/cli-proxy-api` after the mandatory restore verification.
- Stop if any command requires GitHub authentication, Sparkle signing keys, `make clean`, or root-checkout changes.
- Stop if GitHub API lookup, asset selection, checksum verification, archive extraction, executable validation, backend validation, tests, or build fail; capture the exact command and output.
- Stop if the latest release assets are missing, ambiguous, have mismatched API digest/checksums.txt values, or do not contain exactly one executable that reports `CLIProxyAPI Version`.
- Stop if implementing a requested change would require modifying Swift application code, Makefile targets, Sparkle release workflow, Linux/Windows support, Intel macOS support, appcast files, generated artifacts, or the tracked backend binary in the final commit.
- Stop if the plan and approved spec diverge; return to the spec stage for approval before expanding scope.
