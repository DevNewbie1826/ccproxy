# CCProxy v0.1.10 App Release Implementation Plan

> **For agentic workers:** Each task is dispatched to the `executor` agent. Follow the EasyCode `execute` stage: per-task TDD cycle, `code-spec-reviewer` and `code-quality-reviewer` review gates, and `completion-verifier` for final evidence. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Release CCProxy `v0.1.10` build `11` with the bundled CLIProxyAPI updated to the latest public release, a signed Sparkle appcast, and a GitHub release asset prepared for finish.

**Architecture:** CCProxy is a Swift macOS menu bar app that bundles the CLIProxyAPI executable at `src/Sources/Resources/cli-proxy-api`. Release packaging is driven by Make targets that build `CCProxy.app`, zip it as `CCProxy.app.zip`, and use Sparkle metadata in `appcast.xml` to point clients at the GitHub release asset. The existing appcast generator uses Sparkle `sign_update`, but this release must use the key-file signing path at execution time without recording, copying, committing, or printing private key contents.

**Tech Stack:** Swift Package Manager, Make, Bash, Git, GitHub CLI `gh`, Sparkle `sign_update`, macOS `/usr/bin/stat`, `ditto`, `curl`, `python3`, `shasum`, `tar`.

## Approved Inputs And Gates

- Work ID: `2026-06-03-app-release-v0-1-10`.
- Approved spec: `docs/easycode/2026-06-03-app-release-v0-1-10/spec.md`.
- Approved evidence: `docs/easycode/2026-06-03-app-release-v0-1-10/evidence.md`.
- Spec reviewer result: `PASS`.
- Worktree path: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-03-app-release-v0-1-10`.
- Branch: `work/2026-06-03-app-release-v0-1-10`.
- Worktree checkpoint commit: `0e479f6`.
- Worktree baseline status: `ready`.
- Baseline command: `make backend-version && make test && make build`.
- Baseline result: passed.
- Baseline backend version: `CLIProxyAPI Version: 7.1.40, Commit: 02d0d92a, BuiltAt: 2026-06-02T11:31:42Z`.
- Degraded baseline caveat: none.
- Root checkout caveat: an unrelated dirty `.gitignore` exists in `/Volumes/storage/workspace/ccproxy`; do not touch, overwrite, reset, stash, or clean it.
- External release evidence: latest public CLIProxyAPI was `v7.1.43` when evidence was collected.
- Finish target already user-approved in the spec: after execute and final-review PASS, create PR, merge PR, update local `main`, clean worktree and branches, and create GitHub release `v0.1.10` with `CCProxy.app.zip`.

## Pre-Execute Gate

- [ ] Confirm current shell is in the feature worktree:

  ```bash
  pwd
  git rev-parse --show-toplevel
  git status --short --branch
  ```

  Expected output: both path commands print `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-03-app-release-v0-1-10`; status shows branch `work/2026-06-03-app-release-v0-1-10` and no unexpected dirty files except this plan artifact before execution begins.

- [ ] Confirm the plan gate has completed before any execute-stage work:

  - `plan-checker`: `PASS`.
  - `plan-challenger`: `PASS`.
  - User approval of this plan: granted.

- [ ] Stop if any pre-execute gate is missing or failed.

## File Structure

### Files To Modify During Execute

- `src/Sources/Resources/cli-proxy-api` — replace with the latest CLIProxyAPI macOS arm64 binary via `scripts/update-cli-proxy-api.sh`.
- `appcast.xml` — update release item to `0.1.10` build `11` with the GitHub release URL, computed zip length, and Sparkle EdDSA signature.
- `docs/easycode/2026-06-03-app-release-v0-1-10/plan.md` — include this approved plan artifact in the release commit.

### Files To Read Or Execute During Execute

- `docs/easycode/2026-06-03-app-release-v0-1-10/spec.md`.
- `docs/easycode/2026-06-03-app-release-v0-1-10/evidence.md`.
- `scripts/update-cli-proxy-api.sh`.
- `Makefile`.
- `src/.build/artifacts/sparkle/Sparkle/bin/sign_update`.

### Generated Artifacts Not To Commit

- `CCProxy.app`.
- `CCProxy.app.zip`.
- `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.1.10-release/CCProxy.app.zip`.

## Execute-Stage Tasks

Execute-stage work may update the backend, build the archive, generate the appcast, commit intended files, and copy the release zip to the pre-approved temp location. Execute must not push, create a PR, merge, update local `main`, clean up the worktree or branches, or publish the GitHub release.

### Task 1: RED Checks For Release Starting State

- [ ] Run the appcast RED check:

  ```bash
  python3 - <<'PY'
  from pathlib import Path
  text = Path('appcast.xml').read_text()
  checks = {
      'shortVersionString 0.1.10': '<sparkle:shortVersionString>0.1.10</sparkle:shortVersionString>' in text,
      'build 11': '<sparkle:version>11</sparkle:version>' in text,
      'v0.1.10 asset URL': 'https://github.com/DevNewbie1826/ccproxy/releases/download/v0.1.10/CCProxy.app.zip' in text,
  }
  present = [name for name, ok in checks.items() if ok]
  if present:
      raise SystemExit('Unexpected v0.1.10 appcast fields already present: ' + ', '.join(present))
  print('RED OK: appcast does not yet contain v0.1.10/build 11 release fields')
  PY
  ```

  Expected output: `RED OK: appcast does not yet contain v0.1.10/build 11 release fields`. Stop if the script reports v0.1.10 fields already present because the plan would need conflict handling.

- [ ] Run release/tag absence RED checks:

  ```bash
  git ls-remote --tags origin refs/tags/v0.1.10
  gh release view v0.1.10 --repo DevNewbie1826/ccproxy >/tmp/ccproxy-v0.1.10-release-view.txt 2>&1; rc=$?; if [ "$rc" -eq 0 ]; then cat /tmp/ccproxy-v0.1.10-release-view.txt; exit 1; fi; if [ "$rc" -ne 1 ]; then cat /tmp/ccproxy-v0.1.10-release-view.txt; exit "$rc"; fi; cat /tmp/ccproxy-v0.1.10-release-view.txt
  ```

  Expected output: first command prints nothing; second command exits successfully after printing a GitHub CLI not-found message such as `release not found`. Stop if tag or release `v0.1.10` exists, or if the GitHub CLI command fails for authentication, network, or API reasons other than not found.

- [ ] Run baseline backend RED check:

  ```bash
  make backend-version
  ```

  Expected output includes `CLIProxyAPI Version: 7.1.40`. This establishes that the updater must change the backend version from the baseline. Stop if the command fails or already reports a version newer than baseline before the update.

- [ ] Handle stale generated artifacts safely:

  ```bash
  git status --short -- CCProxy.app CCProxy.app.zip
  test ! -e CCProxy.app.zip || git ls-files --error-unmatch CCProxy.app.zip >/dev/null 2>&1 || rm -f CCProxy.app.zip
  test ! -e CCProxy.app.zip && echo 'RED OK: release archive absent before generation'
  ```

  Expected output: no tracked generated artifact status; final line prints `RED OK: release archive absent before generation`. If `CCProxy.app.zip` is tracked, modified, or cannot be safely removed as an untracked stale artifact, stop. Do not run `make clean` because it removes the bundled backend binary.

### Task 2: GREEN Update Bundled CLIProxyAPI

- [ ] Run the existing updater script:

  ```bash
  scripts/update-cli-proxy-api.sh
  ```

  Expected output includes `Resolving latest router-for-me/CLIProxyAPI release...`, `Resolved CLIProxyAPI release: v7.1.43` or a newer latest release, `Checksum verified: sha256:`, `Updating`, `Validating updated binary...`, and `Updated successfully:`. Stop if the script fails due to network/API, asset selection, checksum validation, missing tools, missing target binary, or backend validation.

- [ ] Verify backend changed from baseline:

  ```bash
  make backend-version
  ```

  Expected output includes `CLIProxyAPI Version:` and must not include `CLIProxyAPI Version: 7.1.40`. It should report `7.1.43` if the latest release remains the same as current evidence. Record the exact output in execute evidence. Stop if the version remains `7.1.40` or cannot be read.

- [ ] Confirm only the backend binary and plan artifact are dirty at this point:

  ```bash
  git status --short
  ```

  Expected output includes ` M src/Sources/Resources/cli-proxy-api` and `?? docs/easycode/2026-06-03-app-release-v0-1-10/plan.md`, with no generated archive or app bundle tracked. Stop on any unexpected dirty path.

### Task 3: GREEN Test And Build The App

- [ ] Run the repository test suite:

  ```bash
  make test
  ```

  Expected output includes `🧪 Running tests...` and `✅ Tests passed`. Stop if tests fail.

- [ ] Run the repository build:

  ```bash
  make build
  ```

  Expected output includes `🔨 Building Swift executable...` and `✅ Build complete: src/.build/debug/CCProxy`. Stop if build fails.

- [ ] Focused status check:

  ```bash
  git status --short
  ```

  Expected output still includes only intended tracked changes plus the plan artifact, while Swift build outputs remain ignored/untracked according to repository rules. Stop on unexpected dirty paths.

### Task 4: GREEN Build Release Archive

- [ ] Build the release archive with the approved app version and build number:

  ```bash
  APP_VERSION=0.1.10 APP_BUILD_NUMBER=11 make sparkle-archive
  ```

  Expected output includes `🔨 Building release app bundle...`, `✅ Build complete: CCProxy.app`, `🗜️  Creating Sparkle archive...`, and `✅ Created CCProxy.app.zip`. Stop if archive generation fails.

- [ ] Verify generated archive exists and has positive size:

  ```bash
  /usr/bin/stat -f%z CCProxy.app.zip
  test -d CCProxy.app
  test -f CCProxy.app.zip
  ```

  Expected output: the `stat` command prints a positive integer byte length; both `test` commands exit 0. Stop if the archive or app bundle is missing.

- [ ] Confirm generated artifacts are not tracked for commit:

  ```bash
  git status --short -- CCProxy.app CCProxy.app.zip
  git ls-files --error-unmatch CCProxy.app >/dev/null 2>&1; echo "CCProxy.app tracked rc=$?"
  git ls-files --error-unmatch CCProxy.app.zip >/dev/null 2>&1; echo "CCProxy.app.zip tracked rc=$?"
  ```

  Expected output: `git status --short` may show untracked generated artifacts only; both `git ls-files` status echoes must report nonzero return codes. Stop if either generated artifact is tracked.

### Task 5: GREEN Generate Signed Appcast With Key-File Signing

- [ ] Verify Sparkle signing preconditions without printing the key path or key contents:

  ```bash
  test -n "${SPARKLE_ED_KEY_FILE:-}"
  test -r "$SPARKLE_ED_KEY_FILE"
  case "$SPARKLE_ED_KEY_FILE" in "$PWD"/*) echo 'Signing key must not be inside active worktree' >&2; exit 1;; esac
  if case "$SPARKLE_ED_KEY_FILE" in /Volumes/storage/workspace/ccproxy/*) true;; *) false;; esac; then
    KEY_REL="${SPARKLE_ED_KEY_FILE#/Volumes/storage/workspace/ccproxy/}"
    if git -C /Volumes/storage/workspace/ccproxy ls-files --error-unmatch -- "$KEY_REL" >/dev/null 2>&1; then unset KEY_REL; exit 1; fi
    if ! git -C /Volumes/storage/workspace/ccproxy check-ignore -q -- "$KEY_REL"; then unset KEY_REL; exit 1; fi
    unset KEY_REL
  fi
  test -x src/.build/artifacts/sparkle/Sparkle/bin/sign_update
  ```

  Expected output: no private key path or contents are printed; every command exits 0. Stop if `SPARKLE_ED_KEY_FILE` is unset, unreadable, inside the active worktree, tracked under the root repository, not ignored if under the root repository, or if `sign_update` is missing/not executable.

- [ ] Verify the Sparkle EdDSA signature command using the key-file mechanism and compute archive length without printing the signature:

  ```bash
  SIGNATURE="$(src/.build/artifacts/sparkle/Sparkle/bin/sign_update --ed-key-file "$SPARKLE_ED_KEY_FILE" -p CCProxy.app.zip)"
  test -n "$SIGNATURE"
  case "$SIGNATURE" in *sparkle:edSignature*|*length=*|*$'\n'*|*' '*) echo 'sign_update output was not a bare signature' >&2; exit 1;; esac
  ARCHIVE_LENGTH="$(/usr/bin/stat -f%z CCProxy.app.zip)"
  test "$ARCHIVE_LENGTH" -gt 0
  unset SIGNATURE ARCHIVE_LENGTH
  ```

  Expected output: none. Stop if signing fails, the signature is empty, the key path or contents are printed, or archive length is not a positive integer.

- [ ] Overwrite `appcast.xml` manually while preserving the existing appcast structure:

  ```bash
  SIGNATURE="$(src/.build/artifacts/sparkle/Sparkle/bin/sign_update --ed-key-file "$SPARKLE_ED_KEY_FILE" -p CCProxy.app.zip)"
  test -n "$SIGNATURE"
  case "$SIGNATURE" in *sparkle:edSignature*|*length=*|*$'\n'*|*' '*) echo 'sign_update output was not a bare signature' >&2; exit 1;; esac
  ARCHIVE_LENGTH="$(/usr/bin/stat -f%z CCProxy.app.zip)"
  test "$ARCHIVE_LENGTH" -gt 0
  export SIGNATURE ARCHIVE_LENGTH
  python3 - <<'PY'
  import os
  from pathlib import Path
  sig = os.environ['SIGNATURE']
  length = os.environ['ARCHIVE_LENGTH']
  Path('appcast.xml').write_text(f'''<?xml version="1.0" encoding="utf-8"?>\n<rss version="2.0"\n     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"\n     xmlns:dc="http://purl.org/dc/elements/1.1/">\n  <channel>\n    <title>CCProxy Changelog</title>\n    <item>\n      <title>Version 0.1.10</title>\n      <sparkle:shortVersionString>0.1.10</sparkle:shortVersionString>\n      <sparkle:version>11</sparkle:version>\n      <enclosure\n        url="https://github.com/DevNewbie1826/ccproxy/releases/download/v0.1.10/CCProxy.app.zip"\n        sparkle:edSignature="{sig}"\n        length="{length}"\n        type="application/octet-stream" />\n    </item>\n  </channel>\n</rss>\n''')
  PY
  unset SIGNATURE ARCHIVE_LENGTH
  ```

  Expected output: none; `appcast.xml` is updated only with the approved version, build, URL, signature, and archive length. Stop if the command fails.

- [ ] Verify appcast fields without printing sensitive key information:

  ```bash
  python3 - <<'PY'
  from pathlib import Path
  import re
  text = Path('appcast.xml').read_text()
  required = [
      '<title>Version 0.1.10</title>',
      '<sparkle:shortVersionString>0.1.10</sparkle:shortVersionString>',
      '<sparkle:version>11</sparkle:version>',
      'url="https://github.com/DevNewbie1826/ccproxy/releases/download/v0.1.10/CCProxy.app.zip"',
      'type="application/octet-stream"',
  ]
  missing = [item for item in required if item not in text]
  if missing:
      raise SystemExit('Missing appcast fields: ' + ', '.join(missing))
  sig = re.search(r'sparkle:edSignature="([^"]+)"', text)
  length = re.search(r'length="([0-9]+)"', text)
  if not sig or not sig.group(1):
      raise SystemExit('Missing non-empty sparkle:edSignature')
  if not length or int(length.group(1)) <= 0:
      raise SystemExit('Missing positive length')
  print('GREEN OK: appcast v0.1.10 build 11 fields verified')
  PY
  ```

  Expected output: `GREEN OK: appcast v0.1.10 build 11 fields verified`. Stop if any appcast field is missing or invalid.

### Task 6: GREEN Preserve Release Zip Outside Worktree

- [ ] Verify temp parent and copy the release archive to the approved temp location:

  ```bash
  test -d /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode
  mkdir -p /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.1.10-release
  cp -f CCProxy.app.zip /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.1.10-release/CCProxy.app.zip
  /usr/bin/stat -f%z /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.1.10-release/CCProxy.app.zip
  cmp -s CCProxy.app.zip /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.1.10-release/CCProxy.app.zip
  ```

  Expected output: `stat` prints the same positive byte length used in `appcast.xml`; `cmp` exits 0. Stop if the temp parent is unavailable, copy fails, or the copied archive differs.

### Task 7: Full Execute Verification And Commit

- [ ] Run full verification before staging:

  ```bash
  make backend-version && make test && make build
  python3 - <<'PY'
  from pathlib import Path
  import re
  text = Path('appcast.xml').read_text()
  for expected in ['0.1.10', '<sparkle:version>11</sparkle:version>', 'https://github.com/DevNewbie1826/ccproxy/releases/download/v0.1.10/CCProxy.app.zip']:
      if expected not in text:
          raise SystemExit(f'Missing expected appcast value: {expected}')
  length = re.search(r'length="([0-9]+)"', text)
  if not length or int(length.group(1)) <= 0:
      raise SystemExit('Invalid appcast length')
  signature = re.search(r'sparkle:edSignature="([^"]+)"', text)
  if not signature or not signature.group(1):
      raise SystemExit('Invalid appcast signature')
  print('Full verification appcast checks passed')
  PY
  test -f /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.1.10-release/CCProxy.app.zip
  cmp -s CCProxy.app.zip /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.1.10-release/CCProxy.app.zip
  ```

  Expected output: backend version reports a version newer than `7.1.40`; tests and build pass; appcast check prints `Full verification appcast checks passed`; temp zip exists and matches. Stop on any failure.

- [ ] Inspect final unstaged state:

  ```bash
  git status --short
  git diff -- appcast.xml docs/easycode/2026-06-03-app-release-v0-1-10/plan.md
  git diff --stat -- src/Sources/Resources/cli-proxy-api appcast.xml docs/easycode/2026-06-03-app-release-v0-1-10/plan.md
  ```

  Expected output: dirty paths are limited to `appcast.xml`, `src/Sources/Resources/cli-proxy-api`, the plan artifact, and untracked generated artifacts `CCProxy.app` or `CCProxy.app.zip`. Stop on any unexpected source, config, script, key, or root `.gitignore` change.

- [ ] Stage exactly the intended commit files:

  ```bash
  git add appcast.xml src/Sources/Resources/cli-proxy-api docs/easycode/2026-06-03-app-release-v0-1-10/plan.md
  git diff --cached --name-only
  ```

  Expected output exactly:

  ```text
  appcast.xml
  docs/easycode/2026-06-03-app-release-v0-1-10/plan.md
  src/Sources/Resources/cli-proxy-api
  ```

  Stop if staged files differ or include `CCProxy.app`, `CCProxy.app.zip`, signing keys, root `.gitignore`, or unrelated changes.

- [ ] Commit release changes:

  ```bash
  git commit -m "Release CCProxy v0.1.10"
  ```

  Expected output: one commit created on `work/2026-06-03-app-release-v0-1-10`. Stop if commit hooks or verification fail; fix only issues within approved scope and rerun verification before committing.

- [ ] Post-commit execute verification:

  ```bash
  git status --short --branch
  test -f /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.1.10-release/CCProxy.app.zip
  /usr/bin/stat -f%z /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.1.10-release/CCProxy.app.zip
  ```

  Expected output: branch is `work/2026-06-03-app-release-v0-1-10`; only untracked/ignored generated artifacts may remain in the worktree; temp zip exists with positive size. Do not push during execute.

## Execute Review Gates

- [ ] Run `code-spec-reviewer` with the approved spec, evidence, plan, commit diff, and verification output. Expected result: `PASS`.
- [ ] Run `code-quality-reviewer` with the approved spec, evidence, plan, commit diff, and verification output. Expected result: `PASS`.
- [ ] If either reviewer fails, return to execute-stage tasks, change only approved-scope files, rerun focused and full verification, recommit as needed, and rerun both reviewers.
- [ ] Run `completion-verifier` after execute reviewers pass. Expected result: completion evidence confirms backend update, appcast update, archive preservation, intended commit files, and no execute-stage push/PR/release actions.

## Final-Review Gate Before Finish

- [ ] Run EasyCode `final-review` after execute completion. Expected result: `PASS`.
- [ ] Stop if final-review is not `PASS`. Do not push, create PR, merge, update local `main`, clean worktree, delete branches, or create the GitHub release until final-review passes.

## Finish-Stage Plan After Final-Review PASS

Run finish commands only after final-review PASS. Push/PR/merge/local-main-update/worktree cleanup/branch deletion/release publish are finish-stage actions and must not occur during execute.

### Finish Task 1: Fresh Verification Before Push

- [ ] From the feature worktree, verify the release commit and preserved zip:

  ```bash
  cd /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-03-app-release-v0-1-10
  git status --short --branch
  make backend-version && make test && make build
  test -f /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.1.10-release/CCProxy.app.zip
  /usr/bin/stat -f%z /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.1.10-release/CCProxy.app.zip
  ```

  Expected output: branch is `work/2026-06-03-app-release-v0-1-10`; backend version is newer than `7.1.40`; tests and build pass; temp zip exists with positive size. Stop on unexpected dirty state other than known generated worktree artifacts.

### Finish Task 2: Push Branch And Create PR

- [ ] Push the feature branch:

  ```bash
  git push -u origin work/2026-06-03-app-release-v0-1-10
  ```

  Expected output: branch pushed and upstream set. Stop on authentication, network, or remote rejection failures.

- [ ] Create the pull request:

  ```bash
  gh pr create --repo DevNewbie1826/ccproxy --base main --head work/2026-06-03-app-release-v0-1-10 --title "Release CCProxy v0.1.10" --body "## Summary
  - update bundled CLIProxyAPI for CCProxy v0.1.10 build 11
  - update Sparkle appcast for the v0.1.10 GitHub release asset
  - preserve CCProxy.app.zip for release publishing

  ## Verification
  - make backend-version
  - make test
  - make build
  - APP_VERSION=0.1.10 APP_BUILD_NUMBER=11 make sparkle-archive
  - Sparkle appcast signed with key-file sign_update flow
  "
  ```

  Expected output: PR URL. Stop if PR creation fails.

- [ ] Check PR mergeability:

  ```bash
  gh pr view --repo DevNewbie1826/ccproxy --json number,mergeStateStatus,isDraft,headRefName,baseRefName,url
  ```

  Expected output: JSON shows `headRefName` as `work/2026-06-03-app-release-v0-1-10`, `baseRefName` as `main`, `isDraft` false, and merge state suitable for merging. Stop if PR is not mergeable, checks are failing, or merge state is ambiguous.

### Finish Task 3: Merge PR From Main Repository Root

- [ ] Switch command context to main repository root and verify the root caveat:

  ```bash
  cd /Volumes/storage/workspace/ccproxy
  git rev-parse --show-toplevel
  git status --short --branch
  ```

  Expected output: top-level path is `/Volumes/storage/workspace/ccproxy`; status may show the unrelated dirty `.gitignore`. Stop if there are any additional unexpected root changes or if `.gitignore` state would block a safe update.

- [ ] Merge the PR without deleting the branch:

  ```bash
  PR_NUMBER="$(gh pr view --repo DevNewbie1826/ccproxy work/2026-06-03-app-release-v0-1-10 --json number --jq .number)"
  test -n "$PR_NUMBER"
  gh pr merge "$PR_NUMBER" --repo DevNewbie1826/ccproxy --merge --subject "Release CCProxy v0.1.10" --body "Release CCProxy v0.1.10 build 11."
  ```

  Expected output: PR merged. The command intentionally does not use `--delete-branch` while the feature worktree still checks out the branch. Stop if merge fails or PR is no longer mergeable.

### Finish Task 4: Safely Update Local Main

- [ ] From the main repository root, update local `main` without touching the unrelated root `.gitignore`:

  ```bash
  cd /Volumes/storage/workspace/ccproxy
  git branch --show-current
  git status --short -- .gitignore
  git fetch origin main
  git pull --ff-only origin main
  git status --short -- .gitignore
  ```

  Expected output: current branch is `main`; `.gitignore` remains dirty exactly as it was before update; fetch and fast-forward pull succeed. Stop if the current branch is not `main`, pull is not fast-forward, `.gitignore` would be overwritten, or additional unexpected root changes appear.

### Finish Task 5: Remove Generated Worktree Artifacts And Cleanup Branches

- [ ] Verify temp zip before cleanup:

  ```bash
  test -f /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.1.10-release/CCProxy.app.zip
  /usr/bin/stat -f%z /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.1.10-release/CCProxy.app.zip
  ```

  Expected output: positive byte length. Stop if the release asset is missing.

- [ ] Remove only known generated artifacts from the feature worktree:

  ```bash
  rm -rf /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-03-app-release-v0-1-10/CCProxy.app
  rm -f /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-03-app-release-v0-1-10/CCProxy.app.zip
  git -C /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-03-app-release-v0-1-10 status --short --branch
  ```

  Expected output: no generated artifact remains dirty; stop on unexpected dirty tracked files.

- [ ] Remove the feature worktree non-forced from main repository root:

  ```bash
  cd /Volumes/storage/workspace/ccproxy
  git worktree remove /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-03-app-release-v0-1-10
  ```

  Expected output: worktree removed successfully. Stop if Git refuses removal; do not use forced removal without explicit user approval.

- [ ] Delete local and remote feature branches after worktree removal:

  ```bash
  git branch -d work/2026-06-03-app-release-v0-1-10
  git push origin --delete work/2026-06-03-app-release-v0-1-10
  ```

  Expected output: local branch deleted; remote branch deleted. Stop if local branch is not fully merged or remote deletion fails.

### Finish Task 6: Publish GitHub Release With Asset

- [ ] Recheck release/tag uniqueness immediately before publishing:

  ```bash
  git ls-remote --tags origin refs/tags/v0.1.10
  gh release view v0.1.10 --repo DevNewbie1826/ccproxy >/tmp/ccproxy-v0.1.10-release-view.txt 2>&1; rc=$?; if [ "$rc" -eq 0 ]; then cat /tmp/ccproxy-v0.1.10-release-view.txt; exit 1; fi; if [ "$rc" -ne 1 ]; then cat /tmp/ccproxy-v0.1.10-release-view.txt; exit "$rc"; fi; cat /tmp/ccproxy-v0.1.10-release-view.txt
  ```

  Expected output: tag command prints nothing; release view reports not found. Stop if tag or release exists, or if GitHub CLI cannot confirm absence.

- [ ] Create GitHub release `v0.1.10` with the preserved asset:

  ```bash
  gh release create v0.1.10 /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.1.10-release/CCProxy.app.zip --repo DevNewbie1826/ccproxy --target main --title "CCProxy v0.1.10" --notes "CCProxy v0.1.10 build 11.

  Includes updated bundled CLIProxyAPI and Sparkle appcast metadata for https://github.com/DevNewbie1826/ccproxy/releases/download/v0.1.10/CCProxy.app.zip."
  ```

  Expected output: GitHub release URL. Stop if release creation or asset upload fails.

- [ ] Verify release and asset:

  ```bash
  gh release view v0.1.10 --repo DevNewbie1826/ccproxy --json tagName,name,url,assets
  ```

  Expected output: JSON shows `tagName` `v0.1.10`, release name `CCProxy v0.1.10`, and an asset named `CCProxy.app.zip`. Stop if verification fails.

## Stop Conditions

- Missing plan approval, `plan-checker` PASS, or `plan-challenger` PASS before execute.
- Current checkout is not `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-03-app-release-v0-1-10` during execute.
- Approved spec/evidence paths are missing or conflict with this plan.
- Network/API failure blocks latest CLIProxyAPI lookup, downloads, checksum retrieval, GitHub release/tag checks, push, PR creation, merge, or release publish.
- `scripts/update-cli-proxy-api.sh` fails or the backend remains at `CLIProxyAPI Version: 7.1.40` after update.
- `make backend-version`, `make test`, `make build`, or `APP_VERSION=0.1.10 APP_BUILD_NUMBER=11 make sparkle-archive` fails.
- `SPARKLE_ED_KEY_FILE` is unset, unreadable, inside the active worktree, tracked if under the root repository, not ignored if under the root repository, or signing fails.
- Private key path or contents would be printed, copied, committed, or included in an artifact.
- `appcast.xml` cannot be generated with version `0.1.10`, build `11`, the approved URL, a non-empty EdDSA signature, and a positive archive length.
- `CCProxy.app.zip` cannot be copied to `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.1.10-release/CCProxy.app.zip` or the copied file differs from the generated archive.
- Final staged files are not exactly `appcast.xml`, `docs/easycode/2026-06-03-app-release-v0-1-10/plan.md`, and `src/Sources/Resources/cli-proxy-api`.
- Generated artifacts `CCProxy.app` or `CCProxy.app.zip` are tracked or staged for commit.
- Unexpected dirty state appears in the worktree or root checkout, including any attempted change to the unrelated dirty root `.gitignore`.
- Release/tag `v0.1.10` already exists before publish.
- PR is not mergeable, required checks fail, or merge state is ambiguous.
- Local `main` cannot be fast-forwarded safely or root `.gitignore` blocks safe update.
- Non-forced worktree removal or branch deletion fails.

## Scope Boundaries

- Do not use `make clean` because it removes the backend binary.
- Do not modify Swift application behavior, release scripts, updater script logic, build configuration, opencode configuration, EasyCode skills, prompt/runtime hooks, or unrelated files.
- Do not commit, copy, print, or otherwise expose Sparkle private key contents.
- Do not commit `CCProxy.app`, `CCProxy.app.zip`, or the temp release copy.
- Do not push, create PR, merge, update local `main`, clean worktree/branches, or publish GitHub release during execute.
