# App Release v0.2.0 Implementation Plan

> **For agentic workers:** Each task is dispatched to the `executor` agent. Follow the EasyCode `execute` stage: per-task TDD cycle, `code-spec-reviewer` and `code-quality-reviewer` review gates, and `completion-verifier` for final evidence. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Release CCProxy app version `0.2.0` with Sparkle build number `12`, including a verified CLIProxyAPI backend update if the repository update script finds and validates one.

**Architecture:** CCProxy is a Swift macOS menu bar app built from `src/` into `CCProxy.app` by `create-app-bundle.sh` and `make sparkle-archive`. Release metadata is split between generated bundle `Info.plist` values and the committed Sparkle feed `appcast.xml`; the bundled backend binary lives at `src/Sources/Resources/cli-proxy-api` and is updated only through the repository script that validates upstream assets.

**Tech Stack:** Swift Package Manager, Makefile targets, Bash release scripts, Sparkle `sign_update`, GitHub CLI `gh`, macOS `ditto`, `/usr/libexec/PlistBuddy`, `python3` XML parsing, Git.

## Approved Inputs And Gates

- Work ID: `2026-06-04-app-release-v0-2-0`
- Approved spec: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0/docs/easycode/2026-06-04-app-release-v0-2-0/spec.md`
- Approved evidence: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0/docs/easycode/2026-06-04-app-release-v0-2-0/evidence.md`
- Worktree path: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0`
- Branch: `work/2026-06-04-app-release-v0-2-0`
- Baseline result: worktree ready; `make backend-version` PASS with `CLIProxyAPI 7.1.43`, `make test` PASS with `98 tests, 1 skipped, 0 failures`, and `make build` PASS.
- User approval mode: active unattended mode through release finish.
- Plan gate: execute may not begin until `plan-checker` returns PASS, `plan-challenger` returns PASS, and unattended plan approval applies.

## File Structure

### Create Or Modify During Plan Stage

- `docs/easycode/2026-06-04-app-release-v0-2-0/plan.md` — this plan artifact only.

### Modify During Execute If Verification Requires It

- `appcast.xml` — update Sparkle feed for `Version 0.2.0`, `sparkle:shortVersionString=0.2.0`, `sparkle:version=12`, release URL, archive length, and Sparkle EdDSA signature.
- `src/Sources/Resources/cli-proxy-api` — update only if `scripts/update-cli-proxy-api.sh` finds a newer upstream release and validates checksum, extraction, executable version, and `make backend-version`.

### Generated Artifacts Never Committed

- `CCProxy.app`
- `CCProxy.app.zip`
- `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip`
- Any temporary release directory under `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/`
- Any Sparkle private key or signing material referenced by `SPARKLE_ED_KEY_FILE`

### Later Workflow Artifact

- `docs/easycode/2026-06-04-app-release-v0-2-0/final-review.md` — created only by final-review later, not during execute planning.

## Stop Conditions

- Stop if the current checkout is not `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0` or the branch is not `work/2026-06-04-app-release-v0-2-0`.
- Stop if `git status --short` shows unexpected tracked modifications before execute begins, except this plan artifact before it is committed by the plan stage.
- Stop if root checkout `/Volumes/storage/workspace/ccproxy/.gitignore` appears in any staged or committed release diff; the known unrelated root `.gitignore` dirty change must remain excluded.
- Stop if remote tag `v0.2.0` or GitHub Release `v0.2.0` already exists.
- Stop if `SPARKLE_ED_KEY_FILE` is unset, relative, cannot be canonicalized, resolves to a non-regular or unreadable file, resolves inside `/Volumes/storage/workspace/ccproxy` or `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0`, or is tracked if its resolved path is inside any Git worktree.
- Stop if the backend update script fails checksum, extraction, executable validation, or `make backend-version`.
- Stop if `make backend-version`, `make test`, or `make build` fails after any release change.
- Stop if `CCProxy.app.zip` is missing, empty, tracked, or has an app bundle whose `CFBundleShortVersionString` is not `0.2.0` or `CFBundleVersion` is not `12`.
- Stop if `appcast.xml` does not match URL `https://github.com/DevNewbie1826/ccproxy/releases/download/v0.2.0/CCProxy.app.zip`, Sparkle short version `0.2.0`, Sparkle build `12`, non-empty `sparkle:edSignature`, and archive byte length.
- Stop if any required plan, code review, final-review, PR, merge, or release gate fails.
- Stop if the staged upload asset differs byte-for-byte from the feature worktree `CCProxy.app.zip`, if SHA-256 values differ, or if byte sizes differ immediately before GitHub Release publication.
- Stop if the published remote tag `v0.2.0` does not resolve to the exact merged release commit SHA used as `gh release create --target`.

## Task 1 — Preflight Release Safety

- [ ] RED check: prove release `v0.2.0` is not already published before any artifact work.
  ```bash
  set +e
  tag_output="$(git ls-remote --exit-code --tags origin refs/tags/v0.2.0 2>&1)"
  tag_rc=$?
  set -e
  case "$tag_rc" in
    0) echo 'remote tag v0.2.0 already exists' >&2; printf '%s\n' "$tag_output" >&2; exit 1 ;;
    2) echo 'remote tag v0.2.0 verified absent' ;;
    *) echo "remote tag v0.2.0 absence unknown; git ls-remote exit $tag_rc" >&2; printf '%s\n' "$tag_output" >&2; exit 1 ;;
  esac
  set +e
  release_output="$(gh release view v0.2.0 --json tagName 2>&1)"
  release_rc=$?
  set -e
  if [ "$release_rc" -eq 0 ]; then
    echo 'GitHub Release v0.2.0 already exists' >&2
    printf '%s\n' "$release_output" >&2
    exit 1
  fi
  case "$release_output" in
    *'release not found'*|*'Release not found'*|*'not found'*|*'Not Found'*) echo 'GitHub Release v0.2.0 verified absent' ;;
    *) echo "GitHub Release v0.2.0 absence unknown; gh exit $release_rc" >&2; printf '%s\n' "$release_output" >&2; exit 1 ;;
  esac
  echo 'release v0.2.0 is not published'
  ```
  Expected output: `remote tag v0.2.0 verified absent`, `GitHub Release v0.2.0 verified absent`, and `release v0.2.0 is not published`. Exit `0` from `git ls-remote --exit-code --tags origin refs/tags/v0.2.0` is a blocker because the tag exists; exit `2` verifies absence; any other exit is an unknown network/auth/remote failure and must stop. `gh release view v0.2.0 --json tagName` may continue only when its combined output is a known not-found condition; auth, network, rate-limit, or unknown failures must stop.

- [ ] GREEN preflight: verify worktree, branch, and clean release state.
  ```bash
  pwd && git rev-parse --show-toplevel && git branch --show-current && git status --short
  ```
  Expected output: both path commands print `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0`, branch prints `work/2026-06-04-app-release-v0-2-0`, and status is empty except for `docs/easycode/2026-06-04-app-release-v0-2-0/plan.md` before the plan commit is finalized.

- [ ] GREEN preflight: verify root `.gitignore` dirty change remains outside this worktree release diff.
  ```bash
  git -C /Volumes/storage/workspace/ccproxy status --short -- .gitignore && git status --short -- .gitignore
  ```
  Expected output: root may show `.gitignore` modified; worktree command must print nothing. Do not stage or commit root `.gitignore`.

- [ ] GREEN preflight: verify Sparkle key environment is safe.
  ```bash
  test -n "${SPARKLE_ED_KEY_FILE:-}" || { echo 'SPARKLE_ED_KEY_FILE is unset' >&2; exit 1; }
  case "$SPARKLE_ED_KEY_FILE" in /*) ;; *) echo 'SPARKLE_ED_KEY_FILE must be an absolute path' >&2; exit 1 ;; esac
  SIGNING_KEY_RESOLVED="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$SPARKLE_ED_KEY_FILE")"
  test -n "$SIGNING_KEY_RESOLVED" || { echo 'resolved Sparkle key path is empty' >&2; exit 1; }
  test -f "$SIGNING_KEY_RESOLVED" || { echo "resolved Sparkle key is not a regular file: $SIGNING_KEY_RESOLVED" >&2; exit 1; }
  test -r "$SIGNING_KEY_RESOLVED" || { echo "resolved Sparkle key is not readable: $SIGNING_KEY_RESOLVED" >&2; exit 1; }
  case "$SIGNING_KEY_RESOLVED" in
    /Volumes/storage/workspace/ccproxy|/Volumes/storage/workspace/ccproxy/*|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0/*)
      echo "resolved Sparkle key is inside forbidden repository/worktree path: $SIGNING_KEY_RESOLVED" >&2
      exit 1
      ;;
  esac
  KEY_GIT_TOP="$(git -C "$(dirname "$SIGNING_KEY_RESOLVED")" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$KEY_GIT_TOP" ]; then
      KEY_REL="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$SIGNING_KEY_RESOLVED" "$KEY_GIT_TOP")"
      if git -C "$KEY_GIT_TOP" ls-files --error-unmatch -- "$KEY_REL" >/dev/null 2>&1; then
          echo "resolved Sparkle key is tracked by git in $KEY_GIT_TOP: $KEY_REL" >&2
          exit 1
      fi
  fi
  echo "Sparkle key resolved to safe readable untracked file: $SIGNING_KEY_RESOLVED"
  ```
  Expected output: `Sparkle key resolved to safe readable untracked file:` followed by the canonicalized absolute key path. The command exits zero only when `SPARKLE_ED_KEY_FILE` is set to an absolute path, resolves through `python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))'` to a regular readable file, the resolved path is outside `/Volumes/storage/workspace/ccproxy` and `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0`, and the resolved path is not tracked if it is inside any Git worktree.

- [ ] Focused verification:
  ```bash
  git status --short
  set +e
  release_output="$(gh release view v0.2.0 --json tagName 2>&1)"
  release_rc=$?
  set -e
  if [ "$release_rc" -eq 0 ]; then echo 'GitHub Release v0.2.0 already exists' >&2; printf '%s\n' "$release_output" >&2; exit 1; fi
  case "$release_output" in
    *'release not found'*|*'Release not found'*|*'not found'*|*'Not Found'*) echo 'GitHub Release v0.2.0 is still absent' ;;
    *) echo "GitHub Release v0.2.0 absence unknown; gh exit $release_rc" >&2; printf '%s\n' "$release_output" >&2; exit 1 ;;
  esac
  ```
  Expected result: git status remains clean except plan artifact, then `GitHub Release v0.2.0 is still absent`; the command exits zero only for a known GitHub not-found response and stops for auth, network, rate-limit, or unknown errors.

## Task 2 — Backend Update Check

- [ ] RED check: capture the current committed backend version before update work.
  ```bash
  make backend-version
  ```
  Expected output includes `CLIProxyAPI backend version:` and `CLIProxyAPI Version 7.1.43`. If this fails, stop because the baseline backend is unreadable.

- [ ] GREEN safe check: run the repository dry-run update workflow.
  ```bash
  scripts/update-cli-proxy-api.sh --dry-run
  ```
  Expected output includes `Resolving latest router-for-me/CLIProxyAPI release...`, `Resolved CLIProxyAPI release:`, `Checksum verified: sha256:`, `Archive contains executable:`, and `Dry run complete; src/Sources/Resources/cli-proxy-api was not modified.` Stop on any non-zero exit.

- [ ] Decide from evidence without guessing:
  ```bash
  git status --short -- src/Sources/Resources/cli-proxy-api && make backend-version
  ```
  Expected output after dry-run: no git status output for `src/Sources/Resources/cli-proxy-api`; backend version still readable.

- [ ] If the dry-run resolved release version is newer than `CLIProxyAPI Version 7.1.43`, run the verified update path.
  ```bash
  scripts/update-cli-proxy-api.sh && make backend-version && git status --short -- src/Sources/Resources/cli-proxy-api
  ```
  Expected output: script ends with `Updated successfully:`, `make backend-version` prints `CLIProxyAPI Version` for the updated binary, and git status shows `M src/Sources/Resources/cli-proxy-api`.

- [ ] If the dry-run resolved release is not newer than `CLIProxyAPI Version 7.1.43`, do not run the mutating update command and record in the executor summary that no binary change was needed.

- [ ] Focused verification after backend decision:
  ```bash
  make backend-version && make test
  ```
  Expected result: backend version prints a `CLIProxyAPI Version` line; tests pass with the repository Swift test summary and `✅ Tests passed`.

## Task 3 — Verification Before Packaging

- [ ] RED check: verify that the release archive for `0.2.0 / 12` is not already valid before packaging.
  ```bash
  test -f CCProxy.app.zip && /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' CCProxy.app/Contents/Info.plist && /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' CCProxy.app/Contents/Info.plist
  ```
  Expected failure mode before packaging: `CCProxy.app.zip` or `CCProxy.app/Contents/Info.plist` is missing, or existing bundle values are not `0.2.0` and `12`.

- [ ] GREEN verification: run supported repository checks before creating release artifacts.
  ```bash
  make backend-version && make test && make build
  ```
  Expected output: `make backend-version` prints `CLIProxyAPI Version`; `make test` completes with 98 tests, 1 skipped, 0 failures or the equivalent current Swift test pass summary plus `✅ Tests passed`; `make build` prints `✅ Build complete: src/.build/debug/CCProxy`.

- [ ] Focused verification:
  ```bash
  git status --short
  ```
  Expected output: only intended tracked changes are visible: `appcast.xml` is not modified yet; `src/Sources/Resources/cli-proxy-api` appears only if Task 2 performed a verified backend update; generated artifacts are absent or untracked and must not be staged.

## Task 4 — Build Release Archive

- [ ] RED check: prove the app bundle does not yet report the requested release metadata.
  ```bash
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' CCProxy.app/Contents/Info.plist && /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' CCProxy.app/Contents/Info.plist
  ```
  Expected failure mode before building: bundle Info.plist is absent, or values are not `0.2.0` and `12`.

- [ ] GREEN implementation: build the Sparkle archive with explicit release metadata.
  ```bash
  APP_VERSION=0.2.0 APP_BUILD_NUMBER=12 make sparkle-archive
  ```
  Expected output includes `🔨 Building release app bundle...`, `✅ Build complete: CCProxy.app`, `🗜️  Creating Sparkle archive...`, and `✅ Created CCProxy.app.zip`.

- [ ] Focused verification: verify bundle metadata and archive state.
  ```bash
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' CCProxy.app/Contents/Info.plist && /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' CCProxy.app/Contents/Info.plist && test -s CCProxy.app.zip && git status --short -- CCProxy.app CCProxy.app.zip
  ```
  Expected output: first line `0.2.0`, second line `12`, `test -s` exits zero, and git status shows `?? CCProxy.app` and `?? CCProxy.app.zip` or no tracked status if ignored. Do not stage these generated artifacts.

## Task 5 — Sign Archive And Update Appcast

- [ ] RED check: prove current `appcast.xml` is not yet the `v0.2.0 / build 12` release entry.
  ```bash
  python3 - <<'PY'
  import sys, xml.etree.ElementTree as ET
  ns={'sparkle':'http://www.andymatuschak.org/xml-namespaces/sparkle'}
  root=ET.parse('appcast.xml').getroot()
  item=root.find('./channel/item')
  short=item.find('sparkle:shortVersionString', ns).text
  build=item.find('sparkle:version', ns).text
  enc=item.find('enclosure')
  ok=(short=='0.2.0' and build=='12' and enc.get('url')=='https://github.com/DevNewbie1826/ccproxy/releases/download/v0.2.0/CCProxy.app.zip')
  sys.exit(0 if ok else 1)
  PY
  ```
  Expected failure mode before appcast update: command exits non-zero because the committed appcast still describes `0.1.10 / 11`.

- [ ] GREEN implementation: sign the archive with `SPARKLE_ED_KEY_FILE` explicitly and write `appcast.xml`.
  ```bash
  test -x src/.build/artifacts/sparkle/Sparkle/bin/sign_update
  test -n "${SPARKLE_ED_KEY_FILE:-}" || { echo 'SPARKLE_ED_KEY_FILE is unset' >&2; exit 1; }
  case "$SPARKLE_ED_KEY_FILE" in /*) ;; *) echo 'SPARKLE_ED_KEY_FILE must be an absolute path' >&2; exit 1 ;; esac
  SIGNING_KEY_RESOLVED="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$SPARKLE_ED_KEY_FILE")"
  test -n "$SIGNING_KEY_RESOLVED" || { echo 'resolved Sparkle key path is empty' >&2; exit 1; }
  test -f "$SIGNING_KEY_RESOLVED" || { echo "resolved Sparkle key is not a regular file: $SIGNING_KEY_RESOLVED" >&2; exit 1; }
  test -r "$SIGNING_KEY_RESOLVED" || { echo "resolved Sparkle key is not readable: $SIGNING_KEY_RESOLVED" >&2; exit 1; }
  case "$SIGNING_KEY_RESOLVED" in
    /Volumes/storage/workspace/ccproxy|/Volumes/storage/workspace/ccproxy/*|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0/*)
      echo "resolved Sparkle key is inside forbidden repository/worktree path: $SIGNING_KEY_RESOLVED" >&2
      exit 1
      ;;
  esac
  KEY_GIT_TOP="$(git -C "$(dirname "$SIGNING_KEY_RESOLVED")" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$KEY_GIT_TOP" ]; then
      KEY_REL="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$SIGNING_KEY_RESOLVED" "$KEY_GIT_TOP")"
      if git -C "$KEY_GIT_TOP" ls-files --error-unmatch -- "$KEY_REL" >/dev/null 2>&1; then
          echo "resolved Sparkle key is tracked by git in $KEY_GIT_TOP: $KEY_REL" >&2
          exit 1
      fi
  fi
  SIGNATURE="$(src/.build/artifacts/sparkle/Sparkle/bin/sign_update --ed-key-file "$SIGNING_KEY_RESOLVED" -p CCProxy.app.zip)"
  SIGNATURE="$SIGNATURE" RELEASE_URL=https://github.com/DevNewbie1826/ccproxy/releases/download/v0.2.0/CCProxy.app.zip python3 - <<'PY'
  import os, re, sys, xml.etree.ElementTree as ET
  signature=os.environ['SIGNATURE']
  if not signature:
      print('sign_update produced an empty signature', file=sys.stderr)
      sys.exit(1)
  if re.search(r'\s', signature):
      print('sign_update signature contains whitespace', file=sys.stderr)
      sys.exit(1)
  if not re.fullmatch(r'[A-Za-z0-9+/=]+', signature):
      print('sign_update signature is not base64-like output', file=sys.stderr)
      sys.exit(1)
  if len(signature) <= 20:
      print('sign_update signature is unexpectedly short', file=sys.stderr)
      sys.exit(1)
  length=str(os.path.getsize('CCProxy.app.zip'))
  release_url=os.environ['RELEASE_URL']
  sparkle_uri='http://www.andymatuschak.org/xml-namespaces/sparkle'
  ET.register_namespace('sparkle', sparkle_uri)
  tree=ET.parse('appcast.xml')
  root=tree.getroot()
  channel=root.find('channel')
  item=channel.find('item')
  def child(name):
      node=item.find(name)
      if node is None:
          node=ET.SubElement(item, name)
      return node
  child('title').text='Version 0.2.0'
  child(f'{{{sparkle_uri}}}shortVersionString').text='0.2.0'
  child(f'{{{sparkle_uri}}}version').text='12'
  enc=item.find('enclosure')
  if enc is None:
      enc=ET.SubElement(item, 'enclosure')
  enc.set('url', release_url)
  enc.set(f'{{{sparkle_uri}}}edSignature', signature)
  enc.set('length', length)
  enc.set('type', 'application/octet-stream')
  tree.write('appcast.xml', encoding='utf-8', xml_declaration=True)
  print('wrote appcast.xml for v0.2.0 build 12 length', length)
  PY
  ```
  Expected output: `wrote appcast.xml for v0.2.0 build 12 length` with the archive byte length. Repository evidence shows `src/.build/artifacts/sparkle/Sparkle/bin/sign_update --ed-key-file "$SIGNING_KEY_RESOLVED" -p CCProxy.app.zip` returns a bare base64 signature, not XML; the plan captures that bare signature only in the in-process `SIGNATURE` shell variable after resolving and safety-checking `SPARKLE_ED_KEY_FILE`, validates that it is non-empty, contains no whitespace, is base64-like, and is longer than 20 characters, then writes it directly as the `sparkle:edSignature` attribute with the release URL and archive byte length. No external signature file may be created. Stop if the repository Sparkle signer is not executable, `SPARKLE_ED_KEY_FILE` is unset, relative, not canonicalizable, resolves to a non-regular or unreadable file, resolves inside `/Volumes/storage/workspace/ccproxy` or `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0`, is tracked if inside any Git worktree, signature validation fails, archive length lookup fails, or XML writing fails.

- [ ] Focused verification: verify appcast fields, signature, URL, and archive length.
  ```bash
  python3 - <<'PY'
  import os, sys, xml.etree.ElementTree as ET
  ns={'sparkle':'http://www.andymatuschak.org/xml-namespaces/sparkle'}
  archive='CCProxy.app.zip'
  root=ET.parse('appcast.xml').getroot()
  item=root.find('./channel/item')
  enc=item.find('enclosure')
  expected_len=str(os.path.getsize(archive))
  checks={
    'title': item.find('title').text == 'Version 0.2.0',
    'short': item.find('sparkle:shortVersionString', ns).text == '0.2.0',
    'build': item.find('sparkle:version', ns).text == '12',
    'url': enc.get('url') == 'https://github.com/DevNewbie1826/ccproxy/releases/download/v0.2.0/CCProxy.app.zip',
    'signature': bool(enc.get('{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature')) and not any(ch.isspace() for ch in enc.get('{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature')),
    'length': enc.get('length') == expected_len,
    'type': enc.get('type') == 'application/octet-stream',
  }
  failed=[name for name, ok in checks.items() if not ok]
  if failed:
      print('failed appcast checks:', ', '.join(failed), file=sys.stderr)
      sys.exit(1)
  print('appcast checks passed for v0.2.0 build 12 length', expected_len)
  PY
  ```
  Expected output: `appcast checks passed for v0.2.0 build 12 length` followed by the archive byte length.

## Task 6 — Stage Archive For Finish Upload

- [ ] RED check: prove the finish upload asset is not already staged.
  ```bash
  test -s /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip
  ```
  Expected failure mode before staging: command exits non-zero because the staged upload asset is absent.

- [ ] GREEN implementation: copy the generated zip to the approved temporary upload path.
  ```bash
  mkdir -p /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release && cp CCProxy.app.zip /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip
  ```
  Expected result: command exits zero and creates only the temp upload copy outside the repository/worktree.

- [ ] Focused verification:
  ```bash
  test -s /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip
  cmp -s CCProxy.app.zip /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip
  test "$(stat -f%z CCProxy.app.zip)" = "$(stat -f%z /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip)"
  shasum -a 256 CCProxy.app.zip /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip
  python3 - <<'PY'
  import os, sys, xml.etree.ElementTree as ET
  enc=ET.parse('appcast.xml').getroot().find('./channel/item/enclosure')
  expected=str(os.path.getsize('/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip'))
  actual=enc.get('length')
  if actual != expected:
      print(f'appcast length {actual} does not match staged asset length {expected}', file=sys.stderr)
      sys.exit(1)
  print('staged asset matches archive and appcast length', expected)
  PY
  ```
  Expected result: existence, byte comparison, and size comparison exit zero; `shasum -a 256` prints identical hashes for both files; Python prints `staged asset matches archive and appcast length` with the byte length.

## Task 7 — Full Verification Before Commit

- [ ] Run complete repository verification.
  ```bash
  make backend-version && make test && make build
  ```
  Expected result: backend version readable; Swift tests pass; Swift debug build passes.

- [ ] Verify app bundle and archive metadata.
  ```bash
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' CCProxy.app/Contents/Info.plist && /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' CCProxy.app/Contents/Info.plist && test -s CCProxy.app.zip && test -s /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip && cmp -s CCProxy.app.zip /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip
  ```
  Expected output: `0.2.0`, `12`, and zero exit for archive existence and byte-for-byte copy comparison.

- [ ] Verify appcast exactly matches generated archive.
  ```bash
  python3 - <<'PY'
  import os, sys, xml.etree.ElementTree as ET
  ns={'sparkle':'http://www.andymatuschak.org/xml-namespaces/sparkle'}
  root=ET.parse('appcast.xml').getroot()
  item=root.find('./channel/item')
  enc=item.find('enclosure')
  sig=enc.get('{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature')
  assert item.find('title').text == 'Version 0.2.0'
  assert item.find('sparkle:shortVersionString', ns).text == '0.2.0'
  assert item.find('sparkle:version', ns).text == '12'
  assert enc.get('url') == 'https://github.com/DevNewbie1826/ccproxy/releases/download/v0.2.0/CCProxy.app.zip'
  assert sig and len(sig) > 20
  assert enc.get('length') == str(os.path.getsize('CCProxy.app.zip'))
  print('verified appcast v0.2.0 build 12')
  PY
  ```
  Expected output: `verified appcast v0.2.0 build 12`.

- [ ] Verify generated artifacts and private key are not staged.
  ```bash
  git status --short && git diff -- appcast.xml src/Sources/Resources/cli-proxy-api && git diff --cached --name-only
  test -n "${SPARKLE_ED_KEY_FILE:-}" || { echo 'SPARKLE_ED_KEY_FILE is unset' >&2; exit 1; }
  case "$SPARKLE_ED_KEY_FILE" in /*) ;; *) echo 'SPARKLE_ED_KEY_FILE must be an absolute path' >&2; exit 1 ;; esac
  SIGNING_KEY_RESOLVED="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$SPARKLE_ED_KEY_FILE")"
  test -f "$SIGNING_KEY_RESOLVED" && test -r "$SIGNING_KEY_RESOLVED"
  case "$SIGNING_KEY_RESOLVED" in
    /Volumes/storage/workspace/ccproxy|/Volumes/storage/workspace/ccproxy/*|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0/*)
      echo "resolved Sparkle key is inside forbidden repository/worktree path: $SIGNING_KEY_RESOLVED" >&2
      exit 1
      ;;
  esac
  KEY_GIT_TOP="$(git -C "$(dirname "$SIGNING_KEY_RESOLVED")" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$KEY_GIT_TOP" ]; then
      KEY_REL="$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$SIGNING_KEY_RESOLVED" "$KEY_GIT_TOP")"
      if git -C "$KEY_GIT_TOP" ls-files --error-unmatch -- "$KEY_REL" >/dev/null 2>&1; then
          echo "resolved Sparkle key is tracked by git in $KEY_GIT_TOP: $KEY_REL" >&2
          exit 1
      fi
  fi
  for path in CCProxy.app CCProxy.app.zip "$SIGNING_KEY_RESOLVED"; do
      if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then echo "tracked forbidden path: $path" >&2; exit 1; fi
  done
  echo 'generated app artifacts and resolved Sparkle key are untracked'
  ```
  Expected result: status shows intended tracked modifications only plus untracked/ignored generated app artifacts; diff covers `appcast.xml` and maybe `src/Sources/Resources/cli-proxy-api`; cached name list is empty before staging; the resolved signing key is a regular readable file outside the repository root and feature worktree, and is not tracked if it is inside any Git worktree; the final message is `generated app artifacts and resolved Sparkle key are untracked`, with a zero exit in the safe state.

## Task 8 — Commit Intended Files Only

- [ ] RED check: verify there is no existing release commit on this branch.
  ```bash
  git log --oneline --decorate -5 && git status --short
  ```
  Expected result: no commit message for `Release v0.2.0`; status shows uncommitted intended release changes.

- [ ] GREEN commit preparation: stage only committed release metadata and verified backend binary if changed.
  ```bash
  git add appcast.xml && if ! git diff --quiet -- src/Sources/Resources/cli-proxy-api; then git add src/Sources/Resources/cli-proxy-api; fi && git status --short
  ```
  Expected output: staged `appcast.xml`; staged `src/Sources/Resources/cli-proxy-api` only if backend update changed it; `CCProxy.app`, `CCProxy.app.zip`, temp upload path, `.gitignore`, and private key are not staged.

- [ ] Commit with intended files only.
  ```bash
  git diff --cached --name-only && git commit -m "Release v0.2.0"
  ```
  Expected output before commit: `appcast.xml` and optionally `src/Sources/Resources/cli-proxy-api` only. Commit succeeds with message `Release v0.2.0`.

- [ ] Focused post-commit verification.
  ```bash
  git status --short && git log --oneline --decorate -3
  ```
  Expected result: branch contains the new `Release v0.2.0` commit; remaining status may show untracked/ignored generated `CCProxy.app` and `CCProxy.app.zip` only, and no staged changes.

## Code Review Gates Before Final-Review

- [ ] Run `code-spec-reviewer` against the approved spec, evidence, committed diff, and verification output.
  Expected result: PASS. If FAIL, route back to execute for minimal fixes and rerun Task 7 plus both code review gates.

- [ ] Run `code-quality-reviewer` against the committed diff and generated artifact safety evidence.
  Expected result: PASS. If FAIL, route back to execute for minimal fixes and rerun Task 7 plus both code review gates.

- [ ] Run `completion-verifier` with the final verification commands, appcast checks, archive staging evidence, git status, and commit hash.
  Expected result: PASS. If FAIL, fix only the verified blocker and rerun required verification and review gates.

- [ ] Proceed to final-review only after all three review gates PASS.
  Expected later artifact: `docs/easycode/2026-06-04-app-release-v0-2-0/final-review.md`.

## Finish Commands After Final-Review PASS

These commands are for the finish stage only after final-review PASS. Do not run them during planning or execute review.

- [ ] Push the release branch from the worktree.
  ```bash
  git push -u origin work/2026-06-04-app-release-v0-2-0
  ```
  Expected result: remote branch is created or updated without force-push.

- [ ] Create the PR from the worktree.
  ```bash
  gh pr create --base main --head work/2026-06-04-app-release-v0-2-0 --title "Release v0.2.0" --body "Release CCProxy v0.2.0 build 12 with updated Sparkle appcast and verified release archive staged for publication."
  ```
  Expected result: command prints the PR URL.

- [ ] Merge the PR from the repository root without branch deletion.
  ```bash
  gh pr merge work/2026-06-04-app-release-v0-2-0 --merge
  ```
  Run from `/Volumes/storage/workspace/ccproxy`. Expected result: PR merges successfully; do not pass `--delete-branch` while the feature worktree still exists.

- [ ] Update local main from the repository root.
  ```bash
  git checkout main && git pull --ff-only origin main
  ```
  Run from `/Volumes/storage/workspace/ccproxy`. Expected result: local `main` fast-forwards to merged `origin/main`; the unrelated root `.gitignore` dirty change remains unstaged and uncommitted.

- [ ] Verify the merged release commit SHA from updated local main before publication.
  ```bash
  MERGED_RELEASE_SHA="$(git rev-parse main)"
  ORIGIN_MAIN_SHA="$(git rev-parse origin/main)"
  PR_MERGE_SHA="$(gh pr view work/2026-06-04-app-release-v0-2-0 --json mergeCommit --jq '.mergeCommit.oid')"
  test -n "$MERGED_RELEASE_SHA" && test -n "$ORIGIN_MAIN_SHA" && test -n "$PR_MERGE_SHA"
  test "$MERGED_RELEASE_SHA" = "$ORIGIN_MAIN_SHA"
  test "$MERGED_RELEASE_SHA" = "$PR_MERGE_SHA"
  git log -1 --oneline "$MERGED_RELEASE_SHA"
  ```
  Run from `/Volumes/storage/workspace/ccproxy` after `git pull --ff-only origin main`. Expected output: the merged `main` commit line for the PR merge/release commit. Stop if local `main`, `origin/main`, and the PR merge commit do not resolve to the same SHA. This step is verification only; recompute and reverify the SHA immediately before GitHub Release creation.

- [ ] Verify the staged zip is still preserved before publication.
  ```bash
  test -s /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0/CCProxy.app.zip
  test -s /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip
  cmp -s /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0/CCProxy.app.zip /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip
  WORKTREE_ASSET_SIZE="$(stat -f%z /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0/CCProxy.app.zip)"
  STAGED_ASSET_SIZE="$(stat -f%z /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip)"
  test "$WORKTREE_ASSET_SIZE" = "$STAGED_ASSET_SIZE"
  WORKTREE_ASSET_SHA="$(shasum -a 256 /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0/CCProxy.app.zip | cut -d ' ' -f 1)"
  STAGED_ASSET_SHA="$(shasum -a 256 /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip | cut -d ' ' -f 1)"
  test -n "$WORKTREE_ASSET_SHA" && test -n "$STAGED_ASSET_SHA" && test "$WORKTREE_ASSET_SHA" = "$STAGED_ASSET_SHA"
  shasum -a 256 /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip
  python3 - <<'PY'
  import os, sys, xml.etree.ElementTree as ET
  appcast='/Volumes/storage/workspace/ccproxy/appcast.xml'
  asset='/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip'
  enc=ET.parse(appcast).getroot().find('./channel/item/enclosure')
  expected=str(os.path.getsize(asset))
  actual=enc.get('length')
  if actual != expected:
      print(f'appcast length {actual} does not match staged asset length {expected}', file=sys.stderr)
      sys.exit(1)
  print('staged release asset preserved with appcast length', expected)
  PY
  ```
  Run from `/Volumes/storage/workspace/ccproxy` before worktree cleanup. Expected result: feature worktree archive and staged asset both exist, `cmp -s` exits zero, `stat -f%z` sizes are equal, SHA-256 values are equal, checksum prints, and Python prints `staged release asset preserved with appcast length` with the byte length. Stop if this fails.

- [ ] Verify tag and release still do not exist immediately before publication.
  ```bash
  set +e
  tag_output="$(git ls-remote --exit-code --tags origin refs/tags/v0.2.0 2>&1)"
  tag_rc=$?
  set -e
  case "$tag_rc" in
    0) echo 'remote tag v0.2.0 already exists' >&2; printf '%s\n' "$tag_output" >&2; exit 1 ;;
    2) echo 'remote tag v0.2.0 verified absent immediately before publication' ;;
    *) echo "remote tag v0.2.0 absence unknown; git ls-remote exit $tag_rc" >&2; printf '%s\n' "$tag_output" >&2; exit 1 ;;
  esac
  set +e
  release_output="$(gh release view v0.2.0 --json tagName 2>&1)"
  release_rc=$?
  set -e
  if [ "$release_rc" -eq 0 ]; then
    echo 'GitHub Release v0.2.0 already exists' >&2
    printf '%s\n' "$release_output" >&2
    exit 1
  fi
  case "$release_output" in
    *'release not found'*|*'Release not found'*|*'not found'*|*'Not Found'*) echo 'GitHub Release v0.2.0 verified absent immediately before publication' ;;
    *) echo "GitHub Release v0.2.0 absence unknown; gh exit $release_rc" >&2; printf '%s\n' "$release_output" >&2; exit 1 ;;
  esac
  echo 'release v0.2.0 is still unpublished immediately before publication'
  ```
  Expected output: `remote tag v0.2.0 verified absent immediately before publication`, `GitHub Release v0.2.0 verified absent immediately before publication`, and `release v0.2.0 is still unpublished immediately before publication`. Exit `0` from `git ls-remote --exit-code --tags origin refs/tags/v0.2.0` is a blocker because the tag exists; exit `2` verifies absence; any other exit is an unknown network/auth/remote failure and must stop. `gh release view v0.2.0 --json tagName` may continue only for a known not-found response; auth, network, rate-limit, or unknown failures must stop.

- [ ] Create the GitHub Release with the staged zip asset.
  ```bash
  MERGED_RELEASE_SHA="$(git rev-parse main)"
  ORIGIN_MAIN_SHA="$(git rev-parse origin/main)"
  PR_MERGE_SHA="$(gh pr view work/2026-06-04-app-release-v0-2-0 --json mergeCommit --jq '.mergeCommit.oid')"
  test -n "$MERGED_RELEASE_SHA" && test -n "$ORIGIN_MAIN_SHA" && test -n "$PR_MERGE_SHA"
  test "$MERGED_RELEASE_SHA" = "$ORIGIN_MAIN_SHA"
  test "$MERGED_RELEASE_SHA" = "$PR_MERGE_SHA"
  git log -1 --oneline "$MERGED_RELEASE_SHA"
  test -s /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0/CCProxy.app.zip
  test -s /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip
  cmp -s /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0/CCProxy.app.zip /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip
  WORKTREE_ASSET_SIZE="$(stat -f%z /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0/CCProxy.app.zip)"
  STAGED_ASSET_SIZE="$(stat -f%z /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip)"
  test "$WORKTREE_ASSET_SIZE" = "$STAGED_ASSET_SIZE"
  WORKTREE_ASSET_SHA="$(shasum -a 256 /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0/CCProxy.app.zip | cut -d ' ' -f 1)"
  STAGED_ASSET_SHA="$(shasum -a 256 /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip | cut -d ' ' -f 1)"
  test -n "$WORKTREE_ASSET_SHA" && test -n "$STAGED_ASSET_SHA" && test "$WORKTREE_ASSET_SHA" = "$STAGED_ASSET_SHA"
  gh release create v0.2.0 /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.2.0-release/CCProxy.app.zip --target "$MERGED_RELEASE_SHA" --title "CCProxy v0.2.0" --notes "Release CCProxy v0.2.0 build 12. This release includes provider-removal changes from main and the verified Sparkle appcast update for CCProxy.app.zip."
  ```
  Expected result: local `main`, `origin/main`, and the PR merge commit resolve to the same non-empty SHA; immediately before `gh release create`, the staged upload asset is byte-for-byte identical to the feature worktree `CCProxy.app.zip`, has the same byte size, and has the same SHA-256; GitHub Release `v0.2.0` is created with `CCProxy.app.zip` attached; and the release is requested against the freshly verified merged release commit SHA through `--target "$MERGED_RELEASE_SHA"`, not a moving branch name.

- [ ] Verify published release.
  ```bash
  MERGED_RELEASE_SHA="$(git rev-parse main)"
  ORIGIN_MAIN_SHA="$(git rev-parse origin/main)"
  PR_MERGE_SHA="$(gh pr view work/2026-06-04-app-release-v0-2-0 --json mergeCommit --jq '.mergeCommit.oid')"
  test -n "$MERGED_RELEASE_SHA" && test -n "$ORIGIN_MAIN_SHA" && test -n "$PR_MERGE_SHA"
  test "$MERGED_RELEASE_SHA" = "$ORIGIN_MAIN_SHA"
  test "$MERGED_RELEASE_SHA" = "$PR_MERGE_SHA"
  gh release view v0.2.0 --json tagName,name,assets,url
  git fetch --force origin refs/tags/v0.2.0:refs/tags/v0.2.0
  PUBLISHED_TAG_SHA="$(git rev-list -n 1 v0.2.0)"
  test -n "$PUBLISHED_TAG_SHA"
  test "$PUBLISHED_TAG_SHA" = "$MERGED_RELEASE_SHA"
  echo "remote tag v0.2.0 resolves to merged release commit $MERGED_RELEASE_SHA"
  ```
  Expected result: JSON reports `tagName` `v0.2.0`, release name `CCProxy v0.2.0`, and an asset named `CCProxy.app.zip`; fetched remote tag `v0.2.0` resolves through `git rev-list -n 1 v0.2.0` to the same merged release commit SHA used as `--target`, which works for lightweight and annotated tags.

- [ ] Remove the EasyCode worktree from the repository root only after successful publication.
  ```bash
  git worktree remove /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-04-app-release-v0-2-0
  ```
  Expected result: EasyCode feature worktree is removed after PR merge, local main update, staged zip verification, GitHub Release creation, and published release verification.

- [ ] Delete the local and remote feature branches after worktree cleanup.
  ```bash
  git branch -d work/2026-06-04-app-release-v0-2-0 && git push origin --delete work/2026-06-04-app-release-v0-2-0
  ```
  Run from `/Volumes/storage/workspace/ccproxy`. Expected result: local and remote feature branches are deleted after merge and after the EasyCode worktree no longer exists.
