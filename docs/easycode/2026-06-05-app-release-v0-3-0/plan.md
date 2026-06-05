# App Release v0.3.0 Implementation Plan

> **For agentic workers:** Each task is dispatched to the `executor` agent. Follow the EasyCode `execute` stage: per-task TDD cycle, `code-spec-reviewer` and `code-quality-reviewer` review gates, and `completion-verifier` for final evidence. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish CCProxy app release `v0.3.0` with Sparkle build number `13`, using an arm64-only archive and a verified Sparkle appcast.

**Architecture:** CCProxy is a Swift macOS menu bar app built from `src/` into `CCProxy.app` by `create-app-bundle.sh` and `make sparkle-archive`. Release state is split between the generated bundle metadata, the committed Sparkle feed `appcast.xml`, and the bundled backend binary at `src/Sources/Resources/cli-proxy-api`, which may change only through the repository-owned backend update script after validation.

**Tech Stack:** Swift Package Manager, Makefile targets, Bash scripts, Sparkle `sign_update`, GitHub CLI `gh`, macOS `ditto`, `/usr/libexec/PlistBuddy`, `python3`, `shasum`, `stat`, `cmp`, Git.

## Approved Inputs And Gates

- Work ID: `2026-06-05-app-release-v0-3-0`
- Approved spec: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/docs/easycode/2026-06-05-app-release-v0-3-0/spec.md`
- Approved evidence: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/docs/easycode/2026-06-05-app-release-v0-3-0/evidence.md`
- Worktree path: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0`
- Branch: `work/2026-06-05-app-release-v0-3-0`
- Baseline result: worktree ready; `make backend-version && make test && make build` PASS; output `/Users/mirage/.local/share/opencode/tool-output/tool_e97cd1630001hRTOiNHNOZ4VRV`; `make test` reported `243 tests, 1 skipped, 0 failures`; `make build` PASS.
- Degraded baseline caveat: none.
- User mode: unattended to app release completion with release `v0.3.0`, build `13`, CLIProxyAPI latest check/update if validation succeeds, arm64-only; destructive, unsafe, or key-missing blockers must stop.
- Plan gate: execute is explicitly blocked until all three current-plan gates are complete: `plan-checker` PASS, `plan-challenger` PASS, and user approval of this revised plan.

## File Structure

### Create Or Modify During Plan Stage

- `docs/easycode/2026-06-05-app-release-v0-3-0/plan.md` — this plan artifact only.

### Modify During Execute

- `appcast.xml` — update the Sparkle feed to exactly one release item for `Version 0.3.0`, `sparkle:shortVersionString=0.3.0`, `sparkle:version=13`, URL `https://github.com/DevNewbie1826/ccproxy/releases/download/v0.3.0/CCProxy.app.zip`, archive byte length, and EdDSA signature that matches recomputation for the exact generated archive.
- `src/Sources/Resources/cli-proxy-api` — update only if `scripts/update-cli-proxy-api.sh --dry-run` resolves a newer CLIProxyAPI release and the mutating update validates successfully.
- `docs/easycode/2026-06-05-app-release-v0-3-0/plan.md` — commit with the release work if it is still uncommitted when execute begins.

### Generated Artifacts Never Committed

- `CCProxy.app`
- `CCProxy.app.zip`
- `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip`
- No other external temporary log, state, decision, coordination, or process artifact is approved; only the staged upload asset path above may be created outside the repository.
- Any Sparkle private key or signing material referenced by `SPARKLE_ED_KEY_FILE`
- The pre-existing unrelated root checkout `.gitignore` dirty change at `/Volumes/storage/workspace/ccproxy/.gitignore`

## Execution Model And Serialization

- Release tasks must be serialized because later steps depend on byte-for-byte identity among `CCProxy.app.zip`, `appcast.xml` length/signature fields, the staged upload asset, the merged commit SHA, and the final GitHub Release target.
- TDD applies to implementation tasks as RED/GREEN/verify loops. Where the task is release packaging or publication rather than code behavior, RED means proving the target state is absent or invalid before the change; GREEN means running the minimal repository release command; verification then proves the expected release state.
- Do not use CodeGraph for this release unless implementation unexpectedly touches app architecture or call flow. If cleanup/refactor becomes necessary, stop and route through the `simplify` discipline; release tooling refactors are outside the approved spec unless required to unblock safe publication.
- External Sparkle evidence added during plan challenge: Sparkle `sign_update --verify` verifies against the public key derived from the supplied private key and does not accept `SUPublicEDKey`; Sparkle `generate_keys -p` prints a keychain public key only. Therefore this plan requires a separate no-keychain-side-effect public-key derivation check from the UTF-8/base64 `SPARKLE_ED_KEY_FILE`, rejecting raw binary key data and invalid decoded lengths before any backend update/build mutation, comparing the derived base64 public key to `src/Info.plist` immediately, comparing the same deterministic derived public key to the built app Info.plist after bundle build, and only then using `sign_update --ed-key-file "$SIGNING_KEY_RESOLVED"` on the exact appcast/archive.

## Stop Conditions

- Stop if the current checkout is not `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0` or the branch is not `work/2026-06-05-app-release-v0-3-0` during execute.
- Stop if root checkout `/Volumes/storage/workspace/ccproxy/.gitignore` appears in any staged, committed, or release diff; preserve it untouched and unstaged.
- Stop if remote tag `v0.3.0` or GitHub Release `v0.3.0` already exists at preflight or immediately before publication.
- Stop if `SPARKLE_ED_KEY_FILE` is unset, relative, cannot be canonicalized, resolves to a non-regular or unreadable file, resolves inside `/Volumes/storage/workspace/ccproxy` or the release worktree, is tracked by any Git repository, is not UTF-8/base64 text, is raw binary key data, decodes to anything other than exactly 32 bytes (seed) or 96 bytes (legacy Sparkle key), or derives/extracts a public key that does not match `src/Info.plist` `SUPublicEDKey` before any backend update/build mutation.
- Stop if backend update tooling is unusable, cannot resolve an unambiguous latest release decision, fails because of infrastructure/auth/network/filesystem/malformed-response/missing-tool errors, leaves `src/Sources/Resources/cli-proxy-api` dirty after a failed update, or the current backend no longer passes `make backend-version` plus repository verification. Broad output tokens such as `Resolved CLIProxyAPI release:` are not sufficient failure classification. Continue unchanged only when the captured dry-run/update exit codes and explicit success or explicit validation-rejection markers prove either no newer backend was found, or a newer backend candidate was rejected during checksum/extraction/executable/version validation while the existing backend passes `make backend-version`, `make test`, and `make build`. The classifier must recognize the repository script's actual checksum rejection `ERROR:<archive> not found in checksums.txt` using the regex-equivalent marker `ERROR:.* not found in checksums.txt`, because the archive name varies.
- Stop if `make backend-version`, `scripts/test-snapshot-generator.sh`, `make test`, `make build`, or `APP_VERSION=0.3.0 APP_BUILD_NUMBER=13 TARGET_ARCH=arm64 make sparkle-archive` fails.
- Stop if bundle metadata is not `CFBundleShortVersionString=0.3.0` and `CFBundleVersion=13`.
- Stop if `lipo -archs CCProxy.app/Contents/MacOS/CCProxy` does not print exactly `arm64`, or if `file CCProxy.app/Contents/MacOS/CCProxy` reports `x86_64` or `universal`.
- Stop if bundled `CCProxy.app/Contents/Resources/cli-proxy-api` exists and its `lipo`/`file` evidence does not show an arm64/aarch64 backend binary, or if it reports `x86_64` or `universal`; if `lipo` cannot inspect the backend binary, use `file` output as backend binary version/architecture evidence and require arm64/aarch64 with no x86_64/universal tokens.
- Stop if the base64 public key deterministically derived from the UTF-8/base64 `SPARKLE_ED_KEY_FILE` does not exactly equal `SUPublicEDKey` in both `src/Info.plist` and, after bundle build, `CCProxy.app/Contents/Info.plist`; expected public key is `J/BVhBgfSRFP+Su9oERjKjNg69tvrhKBlis1qaMQRcA=`.
- Stop if `appcast.xml` does not match the release URL, version, build, type, archive byte length, or Sparkle EdDSA signature for the exact `CCProxy.app.zip` archive. Verification must extract `sparkle:edSignature` from `appcast.xml` and run `src/.build/artifacts/sparkle/Sparkle/bin/sign_update CCProxy.app.zip --verify "$APPCAST_SIGNATURE" --ed-key-file "$SIGNING_KEY_RESOLVED"` only after the deterministic UTF-8/base64 key-file derivation check passes, and all later signing/verification must use that already validated canonical key path.
- Stop if `src/Info.plist` or the generated bundle changes Sparkle public-key configuration; `SUPublicEDKey` must remain `J/BVhBgfSRFP+Su9oERjKjNg69tvrhKBlis1qaMQRcA=`.
- Stop if the staged upload asset differs byte-for-byte from the worktree archive, if SHA-256 values differ, or if byte sizes differ.
- Stop if generated app artifacts, the Sparkle key, root `.gitignore`, or unexpected files are staged.
- Stop if the committed diff does not match the approved spec/evidence scope.
- Stop if any code review, completion verification, final-review, PR, merge, release creation, or post-publication verification gate fails.
- Stop if `docs/easycode/2026-06-05-app-release-v0-3-0/final-review.md` is created by final-review PASS but is not committed before branch push or PR creation.

## Task 1 — Preflight Release Safety

- [ ] RED check: prove release `v0.3.0` is not already published before artifact work.
  ```bash
  set -euo pipefail
  set +e
  tag_output="$(git ls-remote --exit-code --tags origin refs/tags/v0.3.0 2>&1)"
  tag_rc=$?
  set -e
  case "$tag_rc" in
    0) echo 'remote tag v0.3.0 already exists' >&2; printf '%s\n' "$tag_output" >&2; exit 1 ;;
    2) echo 'remote tag v0.3.0 verified absent' ;;
    *) echo "remote tag v0.3.0 absence unknown; git ls-remote exit $tag_rc" >&2; printf '%s\n' "$tag_output" >&2; exit 1 ;;
  esac
  set +e
  release_output="$(gh release view v0.3.0 --json tagName 2>&1)"
  release_rc=$?
  set -e
  if [ "$release_rc" -eq 0 ]; then echo 'GitHub Release v0.3.0 already exists' >&2; printf '%s\n' "$release_output" >&2; exit 1; fi
  case "$release_output" in
    *'release not found'*|*'Release not found'*|*'not found'*|*'Not Found'*) echo 'GitHub Release v0.3.0 verified absent' ;;
    *) echo "GitHub Release v0.3.0 absence unknown; gh exit $release_rc" >&2; printf '%s\n' "$release_output" >&2; exit 1 ;;
  esac
  echo 'release v0.3.0 is not published'
  ```
  Expected output: `remote tag v0.3.0 verified absent`, `GitHub Release v0.3.0 verified absent`, and `release v0.3.0 is not published`. Exit `0` from the tag check is a blocker; exit `2` verifies absence; any other tag, auth, network, or unknown `gh` result must stop.

- [ ] GREEN preflight: verify worktree, branch, and release working state.
  ```bash
  set -euo pipefail
  pwd && git rev-parse --show-toplevel && git branch --show-current && git status --short
  ```
  Expected output: both path commands print `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0`; branch prints `work/2026-06-05-app-release-v0-3-0`; status is empty except this plan artifact if it has not yet been committed.

- [ ] GREEN preflight: verify the root `.gitignore` caveat remains outside this worktree release diff.
  ```bash
  set -euo pipefail
  git -C /Volumes/storage/workspace/ccproxy status --short -- .gitignore && git status --short -- .gitignore
  ```
  Expected output: the root command may show the pre-existing `.gitignore` modification; the worktree command must print nothing. Do not stage or commit root `.gitignore`.

- [ ] GREEN preflight before any backend update/build mutation: verify Sparkle key environment is safe, UTF-8/base64 encoded, and deterministically derives the checked-in public key without printing key contents.
  ```bash
  set -euo pipefail
  test -n "${SPARKLE_ED_KEY_FILE:-}" || { echo 'SPARKLE_ED_KEY_FILE is unset' >&2; exit 1; }
  case "$SPARKLE_ED_KEY_FILE" in /*) ;; *) echo 'SPARKLE_ED_KEY_FILE must be an absolute path' >&2; exit 1 ;; esac
  SIGNING_KEY_RESOLVED="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$SPARKLE_ED_KEY_FILE")"
  test -n "$SIGNING_KEY_RESOLVED" || { echo 'resolved Sparkle key path is empty' >&2; exit 1; }
  test -f "$SIGNING_KEY_RESOLVED" || { echo "resolved Sparkle key is not a regular file: $SIGNING_KEY_RESOLVED" >&2; exit 1; }
  test -r "$SIGNING_KEY_RESOLVED" || { echo "resolved Sparkle key is not readable: $SIGNING_KEY_RESOLVED" >&2; exit 1; }
  case "$SIGNING_KEY_RESOLVED" in
    /Volumes/storage/workspace/ccproxy|/Volumes/storage/workspace/ccproxy/*|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/*)
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
  DERIVED_PUBLIC_KEY="$(python3 - "$SIGNING_KEY_RESOLVED" <<'PY'
import base64, binascii, sys
raw=open(sys.argv[1],'rb').read()
try:
    text=raw.decode('utf-8')
except UnicodeDecodeError:
    print('SPARKLE_ED_KEY_FILE must be UTF-8 base64 text, not raw binary key data; stop', file=sys.stderr)
    sys.exit(1)
stripped=''.join(text.split())
if not stripped:
    print('SPARKLE_ED_KEY_FILE is empty after whitespace stripping; stop', file=sys.stderr)
    sys.exit(1)
try:
    decoded=base64.b64decode(stripped.encode('ascii'), validate=True)
except (UnicodeEncodeError, binascii.Error):
    print('SPARKLE_ED_KEY_FILE must contain valid ASCII base64 text; stop', file=sys.stderr)
    sys.exit(1)
if len(decoded) == 96:
    print(base64.b64encode(decoded[-32:]).decode('ascii'))
    sys.exit(0)
if len(decoded) == 32:
    try:
        from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
        from cryptography.hazmat.primitives import serialization
    except Exception:
        print('python cryptography is required to derive public key from 32-byte Sparkle seed; stop', file=sys.stderr)
        sys.exit(1)
    print(base64.b64encode(Ed25519PrivateKey.from_private_bytes(decoded).public_key().public_bytes(encoding=serialization.Encoding.Raw, format=serialization.PublicFormat.Raw)).decode('ascii'))
    sys.exit(0)
print(f'SPARKLE_ED_KEY_FILE decoded length must be exactly 32 or 96 bytes, got {len(decoded)}; stop', file=sys.stderr)
sys.exit(1)
PY
  )"
  SOURCE_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' src/Info.plist)"
  test "$DERIVED_PUBLIC_KEY" = 'J/BVhBgfSRFP+Su9oERjKjNg69tvrhKBlis1qaMQRcA=' || { echo 'derived Sparkle public key does not match expected release public key' >&2; exit 1; }
  test "$SOURCE_PUBLIC_KEY" = "$DERIVED_PUBLIC_KEY" || { echo 'derived Sparkle public key does not match src/Info.plist SUPublicEDKey before backend update/build mutation' >&2; exit 1; }
  echo "Sparkle key resolved to safe readable untracked UTF-8/base64 file: $SIGNING_KEY_RESOLVED"
  echo 'derived Sparkle public key matches src/Info.plist SUPublicEDKey before backend update/build mutation'
  ```
  Expected output: `Sparkle key resolved to safe readable untracked UTF-8/base64 file:` followed by the canonical path only, not key contents, and `derived Sparkle public key matches src/Info.plist SUPublicEDKey before backend update/build mutation`. Raw 32-byte or 96-byte binary key files, non-UTF-8 files, invalid base64, empty base64, decoded lengths other than exactly 32 or 96 bytes, and public-key mismatches all stop before Task 2 mutates or builds anything. If the key is a base64-encoded 32-byte seed and `import cryptography` fails, stop before any backend update, build, signing, or appcast generation; do not use fallback derivation tooling.

## Task 2 — Backend Update Check And Optional Update In One Shell Context

This task must not start until Task 1 has proven the canonical `SPARKLE_ED_KEY_FILE` is a safe external UTF-8/base64 key file and its derived public key matches `src/Info.plist` `SUPublicEDKey`. This task intentionally serializes current-version extraction, dry-run classification, current-vs-resolved comparison, and optional mutating update in one executor task and one shell context. Do not split these steps into separate executor tasks because that would require persistent decision state. Do not create backend log files, `.env` files, decision files, or temporary backend state files; keep backend output and decisions in shell variables and command substitution only. It is acceptable for command output to appear in captured executor/tool output.

- [ ] RED check: prove the current committed backend version is readable and extract exactly one normalized version without writing logs or state files.
  ```bash
  set -euo pipefail
  set +e
  current_output="$(make backend-version 2>&1)"
  current_rc=$?
  set -e
  printf '%s\n' "$current_output"
  test "$current_rc" -eq 0 || { echo "make backend-version failed before backend update decision; exit $current_rc" >&2; exit 1; }
  CURRENT_BACKEND_VERSION="$(python3 -c '
import re, sys
text=sys.stdin.read()
matches=re.findall(r"CLIProxyAPI Version:\s*v?([0-9]+(?:\.[0-9]+){1,3})(?:\b|[-+])", text)
unique=sorted(set(matches))
if len(unique) != 1:
    print(f"ambiguous current CLIProxyAPI version parse: {matches}", file=sys.stderr)
    sys.exit(1)
print(unique[0])
' <<< "$current_output")"
  test -n "$CURRENT_BACKEND_VERSION"
  echo "current backend version parsed: $CURRENT_BACKEND_VERSION"
  ```
  Expected output includes `CLIProxyAPI backend version:`, a `CLIProxyAPI Version` line, and `current backend version parsed: <version>`. If `make backend-version` fails or parsing finds zero or multiple versions, stop because the baseline backend version is unreadable or ambiguous. This step must not create files under `/var/folders`, `/tmp`, the repository, or any other path.

- [ ] GREEN safe check and optional implementation: in the same shell context, run the repository dry-run backend update workflow, compare current-vs-resolved versions exactly, and run the mutating update only when the resolved release is newer.
  ```bash
  set -euo pipefail
  set +e
  current_output="$(make backend-version 2>&1)"
  current_rc=$?
  set -e
  printf '%s\n' "$current_output"
  test "$current_rc" -eq 0 || { echo "make backend-version failed before backend update decision; exit $current_rc" >&2; exit 1; }
  CURRENT_BACKEND_VERSION="$(python3 -c '
import re, sys
text=sys.stdin.read()
matches=re.findall(r"CLIProxyAPI Version:\s*v?([0-9]+(?:\.[0-9]+){1,3})(?:\b|[-+])", text)
unique=sorted(set(matches))
if len(unique) != 1:
    print(f"ambiguous current CLIProxyAPI version parse: {matches}", file=sys.stderr)
    sys.exit(1)
print(unique[0])
' <<< "$current_output")"
  echo "current backend version parsed: $CURRENT_BACKEND_VERSION"

  set +e
  dry_run_output="$(scripts/update-cli-proxy-api.sh --dry-run 2>&1)"
  dry_run_rc=$?
  set -e
  printf '%s\n' "$dry_run_output"

  backend_decision="$(python3 -c '
import re, shlex, sys
rc=int(sys.argv[1])
current=sys.argv[2]
text=sys.stdin.read()
required_success_markers=[
  "Resolving latest router-for-me/CLIProxyAPI release...",
  "Resolved CLIProxyAPI release:",
  "Selected asset:",
  "Downloading ",
  "Downloading checksums.txt...",
  "Checksum verified: sha256:",
  "Archive contains executable:",
  "Dry run complete; src/Sources/Resources/cli-proxy-api was not modified.",
]
validation_error_prefixes=(
  "ERROR:Checksum mismatch:",
  "ERROR:API digest (",
  "ERROR:No executable candidates found in archive",
  "ERROR:Multiple executable candidates found in archive:",
  "ERROR:Executable does not report CLIProxyAPI Version:",
  "ERROR:make backend-version failed",
  "ERROR:Backend validation failed",
  "ERROR:expected 1 archive,",
  "ERROR:checksums.txt not found",
)
validation_error_patterns=(
  r"ERROR:.* not found in checksums\.txt",
)
def parse_version(raw):
    m=re.fullmatch(r"v?([0-9]+(?:\.[0-9]+){1,3})(?:[-+].*)?", raw.strip())
    if not m:
        return None, None
    return tuple(int(p) for p in m.group(1).split(".")), m.group(1)
resolved_lines=re.findall(r"^Resolved CLIProxyAPI release:\s*(\S+)\s*$", text, re.M)
success=rc == 0 and all(marker in text for marker in required_success_markers)
validation_rejected=rc != 0 and any(line.startswith(validation_error_prefixes) or any(re.search(pattern, line) for pattern in validation_error_patterns) for line in text.splitlines())
current_tuple,current_norm=parse_version(current)
if current_tuple is None:
    print(f"ambiguous current version comparison: current={current!r}", file=sys.stderr)
    sys.exit(1)
if success:
    if len(set(resolved_lines)) != 1:
        print(f"ambiguous resolved CLIProxyAPI release parse: {resolved_lines}", file=sys.stderr)
        sys.exit(1)
    resolved_tuple,resolved_norm=parse_version(resolved_lines[0])
    if resolved_tuple is None:
        print(f"ambiguous resolved version comparison: resolved={resolved_lines[0]!r}", file=sys.stderr)
        sys.exit(1)
    action="update" if resolved_tuple > current_tuple else "skip"
    values={"BACKEND_ACTION":action,"CURRENT_BACKEND_VERSION":current_norm,"RESOLVED_BACKEND_VERSION":resolved_norm,"DRY_RUN_CLASS":"success"}
    for key,value in values.items():
        print(f"{key}={shlex.quote(value)}")
    sys.exit(0)
if validation_rejected:
    resolved=""
    if len(set(resolved_lines)) == 1:
        resolved=resolved_lines[0]
    values={"BACKEND_ACTION":"validation-rejected","CURRENT_BACKEND_VERSION":current_norm,"RESOLVED_BACKEND_VERSION":resolved,"DRY_RUN_CLASS":"validation-rejected"}
    for key,value in values.items():
        print(f"{key}={shlex.quote(value)}")
    sys.exit(0)
print(f"backend dry-run exit {rc} lacks exact success markers or explicit ERROR validation marker; stop", file=sys.stderr)
sys.exit(1)
' "$dry_run_rc" "$CURRENT_BACKEND_VERSION" <<< "$dry_run_output")"
  eval "$backend_decision"
  test -n "${BACKEND_ACTION:-}" && test -n "${CURRENT_BACKEND_VERSION:-}" && test -n "${DRY_RUN_CLASS:-}"
  case "$BACKEND_ACTION" in update|skip|validation-rejected) ;; *) echo "invalid BACKEND_ACTION=$BACKEND_ACTION" >&2; exit 1 ;; esac
  echo "backend decision: action=$BACKEND_ACTION current=$CURRENT_BACKEND_VERSION resolved=${RESOLVED_BACKEND_VERSION:-} dry_run_class=$DRY_RUN_CLASS"

  if [ "$BACKEND_ACTION" = update ]; then
    set +e
    update_output="$(scripts/update-cli-proxy-api.sh 2>&1)"
    update_rc=$?
    set -e
    printf '%s\n' "$update_output"
    set +e
    python3 -c '
import re, sys
rc=int(sys.argv[1])
text=sys.stdin.read()
success=rc == 0 and all(marker in text for marker in [
  "Resolving latest router-for-me/CLIProxyAPI release...",
  "Resolved CLIProxyAPI release:",
  "Selected asset:",
  "Downloading ",
  "Downloading checksums.txt...",
  "Checksum verified: sha256:",
  "Archive contains executable:",
  "Updating ",
  "Validating updated binary...",
  "Updated successfully:",
])
validation_prefixes=(
  "ERROR:Checksum mismatch:", "ERROR:API digest (", "ERROR:No executable candidates found in archive",
  "ERROR:Multiple executable candidates found in archive:", "ERROR:Executable does not report CLIProxyAPI Version:",
  "ERROR:make backend-version failed", "ERROR:Backend validation failed", "ERROR:expected 1 archive,",
  "ERROR:checksums.txt not found",
)
validation_patterns=(
  r"ERROR:.* not found in checksums\.txt",
)
validation_failure=rc != 0 and any(line.startswith(validation_prefixes) or any(re.search(pattern, line) for pattern in validation_patterns) for line in text.splitlines())
if success:
    print("backend update success marker verified")
    sys.exit(0)
if validation_failure:
    print("backend update explicitly rejected resolved candidate during validation; existing backend must pass verification before continuing")
    sys.exit(2)
print(f"backend update exit {rc} lacks strict success or validation-rejection evidence; stop", file=sys.stderr)
sys.exit(1)
' "$update_rc" <<< "$update_output"
    classified_update_rc=$?
    set -e
    if [ "$classified_update_rc" -eq 0 ]; then
      make backend-version && git status --short -- src/Sources/Resources/cli-proxy-api
    elif [ "$classified_update_rc" -eq 2 ]; then
      test -z "$(git status --short -- src/Sources/Resources/cli-proxy-api)" || { echo 'failed backend update left backend binary dirty; stop' >&2; git status --short -- src/Sources/Resources/cli-proxy-api >&2; exit 1; }
      make backend-version && make test && make build
      echo 'newer backend validation failed; current backend verified, continuing without backend update'
    else
      exit "$classified_update_rc"
    fi
  elif [ "$BACKEND_ACTION" = skip ]; then
    echo "backend mutating update skipped because resolved $RESOLVED_BACKEND_VERSION <= current $CURRENT_BACKEND_VERSION"
    test -z "$(git status --short -- src/Sources/Resources/cli-proxy-api)" || { echo 'dry-run changed backend binary unexpectedly; stop' >&2; git status --short -- src/Sources/Resources/cli-proxy-api >&2; exit 1; }
    make backend-version
  else
    echo 'backend dry-run emitted explicit ERROR validation marker; existing backend must pass verification before continuing'
    test -z "$(git status --short -- src/Sources/Resources/cli-proxy-api)" || { echo 'validation-rejected dry-run left backend binary dirty; stop' >&2; git status --short -- src/Sources/Resources/cli-proxy-api >&2; exit 1; }
    make backend-version && make test && make build
    echo 'newer backend validation failed during dry-run; current backend verified, continuing without backend update'
  fi
  ```
  Expected successful dry-run output includes the actual script markers `Resolving latest router-for-me/CLIProxyAPI release...`, `Resolved CLIProxyAPI release: <tag>`, `Selected asset: <archive>`, `Downloading <archive>...`, `Downloading checksums.txt...`, `Checksum verified: sha256:<hex>`, `Archive contains executable: <basename>`, and `Dry run complete; src/Sources/Resources/cli-proxy-api was not modified.` The classifier then prints `backend decision: action=update current=<current> resolved=<resolved> dry_run_class=success`, `action=skip`, or `action=validation-rejected`. Exact version comparison is done by embedded Python from the current version argument and dry-run stdout. Expected skip output: `backend mutating update skipped because resolved <resolved> <= current <current>`. Expected update output: script output includes exact update markers through `Updated successfully:`, classifier prints `backend update success marker verified`, `make backend-version` prints `CLIProxyAPI Version` for the updated binary, and git status shows `M src/Sources/Resources/cli-proxy-api`. Expected validation-rejection output: dry-run or update output contains actual `ERROR:` validation markers such as `ERROR:Checksum mismatch:`, `ERROR:API digest (`, `ERROR:No executable candidates found in archive`, `ERROR:Multiple executable candidates found in archive:`, `ERROR:Executable does not report CLIProxyAPI Version:`, `ERROR:make backend-version failed`, `ERROR:Backend validation failed`, `ERROR:expected 1 archive,`, or `ERROR:checksums.txt not found`; the existing backend remains clean and passes `make backend-version`, `make test`, and `make build` before continuing. Any ambiguous version parse, missing exact success marker, unexpected output, network/auth/filesystem/tooling failure, malformed response, dirty backend after rejected update, or current-backend verification failure stops the release. This command must not create backend logs, env files, decision files, or other persistent backend coordination artifacts.

- [ ] If the decision is `skip`, record in the executor summary that the backend remains unchanged because the resolved version is less than or equal to the current version. If dry-run or update explicitly rejected a candidate using actual `ERROR:` validation markers, record the rejection marker and the existing-backend verification evidence from captured command output only, not from a persisted log file.
- [ ] If the backend script rejects a resolved archive with `ERROR:<archive> not found in checksums.txt`, classify it as a validation rejection only through the regex-equivalent marker `ERROR:.* not found in checksums.txt`, then verify the existing backend with `make backend-version && make test && make build` before continuing.

- [ ] Focused verification after backend decision.
  ```bash
  set -euo pipefail
  make backend-version && scripts/test-snapshot-generator.sh && make test && make build
  ```
  Expected result: backend version is readable; snapshot generator script prints its pass summary and exits zero; Swift tests pass with `243 tests, 1 skipped, 0 failures` or the current zero-failure Swift test summary plus `✅ Tests passed`; `make build` prints `✅ Build complete: src/.build/debug/CCProxy`.

## Task 3 — Verification Before Packaging

- [ ] RED check: prove the requested archive is not already valid before packaging.
  ```bash
  set -euo pipefail
  test -f CCProxy.app.zip && /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' CCProxy.app/Contents/Info.plist && /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' CCProxy.app/Contents/Info.plist
  ```
  Expected failure mode before packaging: `CCProxy.app.zip` or `CCProxy.app/Contents/Info.plist` is missing, or existing bundle values are not `0.3.0` and `13`.

- [ ] GREEN verification: run supported repository checks before creating release artifacts.
  ```bash
  set -euo pipefail
  make backend-version && scripts/test-snapshot-generator.sh && make test && make build
  ```
  Expected output: backend version prints `CLIProxyAPI Version`; snapshot generator exits zero; `make test` reports zero failures; `make build` prints `✅ Build complete: src/.build/debug/CCProxy`.

- [ ] Focused verification.
  ```bash
  set -euo pipefail
  git status --short
  ```
  Expected output: only intended tracked changes are visible: this plan artifact, and `src/Sources/Resources/cli-proxy-api` only if Task 2 performed a verified backend update. `appcast.xml` is not modified yet. Generated app artifacts must not be staged.

## Task 4 — Build Arm64 Release Archive

- [ ] RED check: prove the app bundle does not yet report requested release metadata.
  ```bash
  set -euo pipefail
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' CCProxy.app/Contents/Info.plist && /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' CCProxy.app/Contents/Info.plist
  ```
  Expected failure mode before building: bundle Info.plist is absent, or values are not `0.3.0` and `13`.

- [ ] GREEN implementation: build the Sparkle archive with explicit release metadata and explicit arm64 target architecture.
  ```bash
  set -euo pipefail
  APP_VERSION=0.3.0 APP_BUILD_NUMBER=13 TARGET_ARCH=arm64 make sparkle-archive
  ```
  Expected output includes `🔨 Building release app bundle...`, `✅ Build complete: CCProxy.app`, `🗜️  Creating Sparkle archive...`, and `✅ Created CCProxy.app.zip`. The command line must include `TARGET_ARCH=arm64`; do not rely on host architecture.

- [ ] Focused verification: verify bundle metadata, arm64 app contents, and archive state.
  ```bash
  set -euo pipefail
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' CCProxy.app/Contents/Info.plist && /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' CCProxy.app/Contents/Info.plist && test -s CCProxy.app.zip && git status --short -- CCProxy.app CCProxy.app.zip
  APP_EXEC='CCProxy.app/Contents/MacOS/CCProxy'
  APP_ARCHS="$(lipo -archs "$APP_EXEC")"
  printf 'CCProxy executable archs: %s\n' "$APP_ARCHS"
  test "$APP_ARCHS" = 'arm64' || { echo "CCProxy executable must be arm64-only, got: $APP_ARCHS" >&2; exit 1; }
  APP_FILE_OUTPUT="$(file "$APP_EXEC")"
  printf '%s\n' "$APP_FILE_OUTPUT"
  case "$APP_FILE_OUTPUT" in *x86_64*|*universal*) echo "CCProxy executable must not contain x86_64 or universal slices: $APP_FILE_OUTPUT" >&2; exit 1 ;; esac
  case "$APP_FILE_OUTPUT" in *arm64*) ;; *) echo "CCProxy executable file output does not report arm64: $APP_FILE_OUTPUT" >&2; exit 1 ;; esac
  BACKEND_EXEC='CCProxy.app/Contents/Resources/cli-proxy-api'
  test -f "$BACKEND_EXEC" || { echo "bundled cli-proxy-api missing: $BACKEND_EXEC" >&2; exit 1; }
  BACKEND_FILE_OUTPUT="$(file "$BACKEND_EXEC")"
  printf '%s\n' "$BACKEND_FILE_OUTPUT"
  case "$BACKEND_FILE_OUTPUT" in *x86_64*|*universal*) echo "bundled cli-proxy-api must not contain x86_64 or universal slices: $BACKEND_FILE_OUTPUT" >&2; exit 1 ;; esac
  BACKEND_ARCHS="$(lipo -archs "$BACKEND_EXEC" 2>/dev/null || true)"
  if [ -n "$BACKEND_ARCHS" ]; then
    printf 'bundled cli-proxy-api archs: %s\n' "$BACKEND_ARCHS"
    case " $BACKEND_ARCHS " in *' arm64 '*) ;; *) echo "bundled cli-proxy-api lipo output must include arm64: $BACKEND_ARCHS" >&2; exit 1 ;; esac
  else
    case "$BACKEND_FILE_OUTPUT" in *arm64*|*aarch64*) echo 'bundled cli-proxy-api file output provides arm64/aarch64 backend binary evidence' ;; *) echo "bundled cli-proxy-api file output lacks arm64/aarch64 evidence: $BACKEND_FILE_OUTPUT" >&2; exit 1 ;; esac
  fi
  test -n "${SPARKLE_ED_KEY_FILE:-}" || { echo 'SPARKLE_ED_KEY_FILE is unset' >&2; exit 1; }
  case "$SPARKLE_ED_KEY_FILE" in /*) ;; *) echo 'SPARKLE_ED_KEY_FILE must be an absolute path' >&2; exit 1 ;; esac
  SIGNING_KEY_RESOLVED="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$SPARKLE_ED_KEY_FILE")"
  test -f "$SIGNING_KEY_RESOLVED" && test -r "$SIGNING_KEY_RESOLVED"
  case "$SIGNING_KEY_RESOLVED" in
    /Volumes/storage/workspace/ccproxy|/Volumes/storage/workspace/ccproxy/*|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/*) echo "resolved Sparkle key is inside forbidden repository/worktree path: $SIGNING_KEY_RESOLVED" >&2; exit 1 ;;
  esac
  DERIVED_PUBLIC_KEY="$(python3 - "$SIGNING_KEY_RESOLVED" <<'PY'
  import base64, binascii, sys
  raw=open(sys.argv[1],'rb').read()
  try:
    text=raw.decode('utf-8')
  except UnicodeDecodeError:
    print('SPARKLE_ED_KEY_FILE must be UTF-8 base64 text, not raw binary key data; stop', file=sys.stderr)
    sys.exit(1)
  stripped=''.join(text.split())
  if not stripped:
    print('SPARKLE_ED_KEY_FILE is empty after whitespace stripping; stop', file=sys.stderr)
    sys.exit(1)
  try:
    decoded=base64.b64decode(stripped.encode('ascii'), validate=True)
  except (UnicodeEncodeError, binascii.Error):
    print('SPARKLE_ED_KEY_FILE must contain valid ASCII base64 text; stop', file=sys.stderr)
    sys.exit(1)
  if len(decoded) == 96:
    print(base64.b64encode(decoded[-32:]).decode('ascii'))
    sys.exit(0)
  if len(decoded) == 32:
    try:
      from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
      from cryptography.hazmat.primitives import serialization
    except Exception:
      print('python cryptography is required to derive public key from 32-byte Sparkle seed; stop', file=sys.stderr)
      sys.exit(1)
    print(base64.b64encode(Ed25519PrivateKey.from_private_bytes(decoded).public_key().public_bytes(encoding=serialization.Encoding.Raw, format=serialization.PublicFormat.Raw)).decode('ascii'))
    sys.exit(0)
  print(f'SPARKLE_ED_KEY_FILE decoded length must be exactly 32 or 96 bytes, got {len(decoded)}; stop', file=sys.stderr)
  sys.exit(1)
  PY
  )"
  SOURCE_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' src/Info.plist)"
  BUNDLE_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' CCProxy.app/Contents/Info.plist)"
  test "$DERIVED_PUBLIC_KEY" = 'J/BVhBgfSRFP+Su9oERjKjNg69tvrhKBlis1qaMQRcA=' || { echo 'derived Sparkle public key does not match expected release public key' >&2; exit 1; }
  test "$SOURCE_PUBLIC_KEY" = "$DERIVED_PUBLIC_KEY" || { echo 'derived Sparkle public key does not match src/Info.plist SUPublicEDKey' >&2; exit 1; }
  test "$BUNDLE_PUBLIC_KEY" = "$DERIVED_PUBLIC_KEY" || { echo 'derived Sparkle public key does not match built app SUPublicEDKey' >&2; exit 1; }
  echo 'derived Sparkle public key matches src/Info.plist and built app SUPublicEDKey before any signing call'
  ```
  Expected output: first line `0.3.0`, second line `13`, `CCProxy executable archs: arm64`, `file` output for `CCProxy` includes `arm64` and does not include `x86_64` or `universal`, bundled `cli-proxy-api` evidence includes arm64/aarch64 and does not include `x86_64` or `universal`, `test -s` exits zero, git status shows generated app artifacts only as untracked or ignored, and `derived Sparkle public key matches src/Info.plist and built app SUPublicEDKey before any signing call`. Do not stage generated artifacts. The arm64-only checks and deterministic UTF-8/base64 key validation must complete before the first `sign_update` invocation in the release flow; if the key is raw binary, invalid, undecodable as UTF-8/base64, mismatched, or the app/backend architecture evidence is not arm64-only, stop without calling Sparkle.

## Task 5 — Generate And Verify Sparkle Appcast

- [ ] RED check: prove current `appcast.xml` is not yet the `v0.3.0 / build 13` release entry.
  ```bash
  set -euo pipefail
  python3 - <<'PY'
  import sys, xml.etree.ElementTree as ET
  ns={'sparkle':'http://www.andymatuschak.org/xml-namespaces/sparkle'}
  root=ET.parse('appcast.xml').getroot()
  item=root.find('./channel/item')
  enc=item.find('enclosure') if item is not None else None
  ok=(item is not None and enc is not None and item.find('title').text=='Version 0.3.0' and item.find('sparkle:shortVersionString', ns).text=='0.3.0' and item.find('sparkle:version', ns).text=='13' and enc.get('url')=='https://github.com/DevNewbie1826/ccproxy/releases/download/v0.3.0/CCProxy.app.zip')
  sys.exit(0 if ok else 1)
  PY
  ```
  Expected failure mode before appcast update: command exits non-zero because committed `appcast.xml` still describes the previous release.

- [ ] GREEN implementation: generate and sign `appcast.xml` inline with explicit key-file signing.
  ```bash
  set -euo pipefail
  test -x src/.build/artifacts/sparkle/Sparkle/bin/sign_update
  test -n "${SPARKLE_ED_KEY_FILE:-}" || { echo 'SPARKLE_ED_KEY_FILE is unset' >&2; exit 1; }
  case "$SPARKLE_ED_KEY_FILE" in /*) ;; *) echo 'SPARKLE_ED_KEY_FILE must be an absolute path' >&2; exit 1 ;; esac
  SIGNING_KEY_RESOLVED="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$SPARKLE_ED_KEY_FILE")"
  test -f "$SIGNING_KEY_RESOLVED" && test -r "$SIGNING_KEY_RESOLVED"
  case "$SIGNING_KEY_RESOLVED" in
    /Volumes/storage/workspace/ccproxy|/Volumes/storage/workspace/ccproxy/*|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/*) echo "resolved Sparkle key is inside forbidden repository/worktree path: $SIGNING_KEY_RESOLVED" >&2; exit 1 ;;
  esac
  DERIVED_PUBLIC_KEY="$(python3 - "$SIGNING_KEY_RESOLVED" <<'PY'
  import base64, binascii, sys
  raw=open(sys.argv[1],'rb').read()
  try:
    text=raw.decode('utf-8')
  except UnicodeDecodeError:
    print('SPARKLE_ED_KEY_FILE must be UTF-8 base64 text, not raw binary key data; stop', file=sys.stderr)
    sys.exit(1)
  stripped=''.join(text.split())
  if not stripped:
    print('SPARKLE_ED_KEY_FILE is empty after whitespace stripping; stop', file=sys.stderr)
    sys.exit(1)
  try:
    decoded=base64.b64decode(stripped.encode('ascii'), validate=True)
  except (UnicodeEncodeError, binascii.Error):
    print('SPARKLE_ED_KEY_FILE must contain valid ASCII base64 text; stop', file=sys.stderr)
    sys.exit(1)
  if len(decoded) == 96:
    print(base64.b64encode(decoded[-32:]).decode('ascii'))
    sys.exit(0)
  if len(decoded) == 32:
    try:
      from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
      from cryptography.hazmat.primitives import serialization
    except Exception:
      print('python cryptography is required to derive public key from 32-byte Sparkle seed; stop', file=sys.stderr)
      sys.exit(1)
    print(base64.b64encode(Ed25519PrivateKey.from_private_bytes(decoded).public_key().public_bytes(encoding=serialization.Encoding.Raw, format=serialization.PublicFormat.Raw)).decode('ascii'))
    sys.exit(0)
  print(f'SPARKLE_ED_KEY_FILE decoded length must be exactly 32 or 96 bytes, got {len(decoded)}; stop', file=sys.stderr)
  sys.exit(1)
  PY
  )"
  SOURCE_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' src/Info.plist)"
  BUNDLE_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' CCProxy.app/Contents/Info.plist)"
  test "$DERIVED_PUBLIC_KEY" = 'J/BVhBgfSRFP+Su9oERjKjNg69tvrhKBlis1qaMQRcA=' || { echo 'derived Sparkle public key does not match expected release public key' >&2; exit 1; }
  test "$SOURCE_PUBLIC_KEY" = "$DERIVED_PUBLIC_KEY" || { echo 'derived Sparkle public key does not match src/Info.plist SUPublicEDKey' >&2; exit 1; }
  test "$BUNDLE_PUBLIC_KEY" = "$DERIVED_PUBLIC_KEY" || { echo 'derived Sparkle public key does not match built app SUPublicEDKey' >&2; exit 1; }
  echo 'Sparkle UTF-8/base64 key file and derived public key validated against src/Info.plist and built app before signing appcast'
  APPCAST_SIGNATURE="$(src/.build/artifacts/sparkle/Sparkle/bin/sign_update --ed-key-file "$SIGNING_KEY_RESOLVED" -p CCProxy.app.zip)"
  test -n "$APPCAST_SIGNATURE" || { echo 'Sparkle sign_update returned an empty signature' >&2; exit 1; }
  export APPCAST_SIGNATURE
  python3 - <<'PY'
  import os, xml.sax.saxutils as x
  archive='CCProxy.app.zip'
  signature=os.environ['APPCAST_SIGNATURE'].strip()
  length=os.path.getsize(archive)
  url='https://github.com/DevNewbie1826/ccproxy/releases/download/v0.3.0/CCProxy.app.zip'
  xml=f'''<?xml version="1.0" encoding="utf-8"?>
  <rss version="2.0"
       xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
       xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
      <title>CCProxy Changelog</title>
      <item>
        <title>Version 0.3.0</title>
        <sparkle:shortVersionString>0.3.0</sparkle:shortVersionString>
        <sparkle:version>13</sparkle:version>
        <enclosure
          url="{x.escape(url)}"
          sparkle:edSignature="{x.escape(signature)}"
          length="{length}"
          type="application/octet-stream" />
      </item>
    </channel>
  </rss>
  '''
  with open('appcast.xml', 'w', encoding='utf-8') as f:
    f.write(xml)
  print('Wrote appcast.xml with inline Sparkle signature for CCProxy.app.zip length', length)
  PY
  ```
  Expected output: `Sparkle UTF-8/base64 key file and derived public key validated against src/Info.plist and built app before signing appcast`, then `Wrote appcast.xml with inline Sparkle signature for CCProxy.app.zip length <bytes>`. The command must not print the key contents and must call `sign_update` only with `--ed-key-file "$SIGNING_KEY_RESOLVED"`, where `SIGNING_KEY_RESOLVED` is the canonical path that just passed the same deterministic UTF-8/base64 validation introduced in Task 1. Do not use `scripts/generate-sparkle-appcast.sh` for actual signing/generation in this release because current script behavior ignores `SPARKLE_ED_KEY_FILE` for `sign_update -p` and does not pass `--ed-key-file`; the script may be fixed in a future approved tooling change, but this plan does not require or allow that script change.

- [ ] Focused verification: verify appcast fields, recomputed EdDSA signature, URL, type, archive length, and unchanged Sparkle public key configuration.
  ```bash
  set -euo pipefail
  test -n "${SPARKLE_ED_KEY_FILE:-}" || { echo 'SPARKLE_ED_KEY_FILE is unset' >&2; exit 1; }
  case "$SPARKLE_ED_KEY_FILE" in /*) ;; *) echo 'SPARKLE_ED_KEY_FILE must be an absolute path' >&2; exit 1 ;; esac
  SIGNING_KEY_RESOLVED="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$SPARKLE_ED_KEY_FILE")"
  test -f "$SIGNING_KEY_RESOLVED" && test -r "$SIGNING_KEY_RESOLVED"
  case "$SIGNING_KEY_RESOLVED" in
    /Volumes/storage/workspace/ccproxy|/Volumes/storage/workspace/ccproxy/*|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/*) echo "resolved Sparkle key is inside forbidden repository/worktree path: $SIGNING_KEY_RESOLVED" >&2; exit 1 ;;
  esac
  DERIVED_PUBLIC_KEY="$(python3 - "$SIGNING_KEY_RESOLVED" <<'PY'
  import base64, binascii, sys
  key_path=sys.argv[1]
  raw=open(key_path,'rb').read()
  try:
    text=raw.decode('utf-8')
  except UnicodeDecodeError:
    print('SPARKLE_ED_KEY_FILE must be UTF-8 base64 text, not raw binary key data; stop', file=sys.stderr)
    sys.exit(1)
  stripped=''.join(text.split())
  if not stripped:
    print('SPARKLE_ED_KEY_FILE is empty after whitespace stripping; stop', file=sys.stderr)
    sys.exit(1)
  try:
    decoded=base64.b64decode(stripped.encode('ascii'), validate=True)
  except (UnicodeEncodeError, binascii.Error):
    print('SPARKLE_ED_KEY_FILE must contain valid ASCII base64 text; stop', file=sys.stderr)
    sys.exit(1)
  if len(decoded) == 96:
    print(base64.b64encode(decoded[-32:]).decode('ascii'))
    sys.exit(0)
  if len(decoded) == 32:
    try:
      from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
      from cryptography.hazmat.primitives import serialization
    except Exception:
      print('python cryptography is required to derive public key from 32-byte Sparkle seed; stop', file=sys.stderr)
      sys.exit(1)
    public=Ed25519PrivateKey.from_private_bytes(decoded).public_key().public_bytes(
      encoding=serialization.Encoding.Raw,
      format=serialization.PublicFormat.Raw,
    )
    print(base64.b64encode(public).decode('ascii'))
    sys.exit(0)
  print(f'SPARKLE_ED_KEY_FILE decoded length must be exactly 32 or 96 bytes, got {len(decoded)}; stop', file=sys.stderr)
  sys.exit(1)
  PY
  )"
  export DERIVED_PUBLIC_KEY
  SOURCE_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' src/Info.plist)"
  BUNDLE_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' CCProxy.app/Contents/Info.plist)"
  test "$DERIVED_PUBLIC_KEY" = 'J/BVhBgfSRFP+Su9oERjKjNg69tvrhKBlis1qaMQRcA=' || { echo 'derived Sparkle public key does not match expected release public key' >&2; exit 1; }
  test "$SOURCE_PUBLIC_KEY" = "$DERIVED_PUBLIC_KEY" || { echo 'derived Sparkle public key does not match src/Info.plist SUPublicEDKey' >&2; exit 1; }
  test "$BUNDLE_PUBLIC_KEY" = "$DERIVED_PUBLIC_KEY" || { echo 'derived Sparkle public key does not match built app SUPublicEDKey' >&2; exit 1; }
  echo 'Sparkle UTF-8/base64 key file and derived public key validated before recomputing appcast signature'
  RECALCULATED_SIGNATURE="$(src/.build/artifacts/sparkle/Sparkle/bin/sign_update --ed-key-file "$SIGNING_KEY_RESOLVED" -p CCProxy.app.zip)"
  export RECALCULATED_SIGNATURE
  APPCAST_SIGNATURE="$(python3 - <<'PY'
  import xml.etree.ElementTree as ET
  enc=ET.parse('appcast.xml').getroot().find('./channel/item/enclosure')
  print(enc.get('{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature') or '')
  PY
  )"
  test -n "$APPCAST_SIGNATURE" || { echo 'appcast sparkle:edSignature is missing' >&2; exit 1; }
  export APPCAST_SIGNATURE
  python3 - <<'PY'
  import os, plistlib, subprocess, sys, xml.etree.ElementTree as ET
  ns={'sparkle':'http://www.andymatuschak.org/xml-namespaces/sparkle'}
  expected_public_key='J/BVhBgfSRFP+Su9oERjKjNg69tvrhKBlis1qaMQRcA='
  derived_public_key=os.environ['DERIVED_PUBLIC_KEY'].strip()
  recalculated=os.environ['RECALCULATED_SIGNATURE'].strip()
  appcast_signature=os.environ['APPCAST_SIGNATURE'].strip()
  root=ET.parse('appcast.xml').getroot()
  item=root.find('./channel/item')
  enc=item.find('enclosure')
  sig=enc.get('{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature')
  with open('src/Info.plist','rb') as f:
    source_info=plistlib.load(f)
  with open('CCProxy.app/Contents/Info.plist','rb') as f:
    bundle_info=plistlib.load(f)
  checks={
    'single item': len(root.findall('./channel/item')) == 1,
    'title': item.find('title').text == 'Version 0.3.0',
    'short': item.find('sparkle:shortVersionString', ns).text == '0.3.0',
    'build': item.find('sparkle:version', ns).text == '13',
    'url': enc.get('url') == 'https://github.com/DevNewbie1826/ccproxy/releases/download/v0.3.0/CCProxy.app.zip',
    'signature extracted from appcast': bool(appcast_signature) and appcast_signature == sig,
    'signature matches recomputed archive signature': bool(sig) and sig == recalculated,
    'length': enc.get('length') == str(os.path.getsize('CCProxy.app.zip')),
    'type': enc.get('type') == 'application/octet-stream',
    'derived public key matches expected SUPublicEDKey': derived_public_key == expected_public_key,
    'source SUPublicEDKey unchanged': source_info.get('SUPublicEDKey') == expected_public_key,
    'bundle SUPublicEDKey unchanged': bundle_info.get('SUPublicEDKey') == expected_public_key,
  }
  failed=[name for name, ok in checks.items() if not ok]
  if failed:
    print('failed appcast checks:', ', '.join(failed), file=sys.stderr)
    sys.exit(1)
  subprocess.run(['git','diff','--exit-code','--','src/Info.plist'], check=True)
  print('derived Sparkle public key matches source and bundle SUPublicEDKey; appcast signature matches recomputed EdDSA signature for CCProxy.app.zip; length', os.path.getsize('CCProxy.app.zip'))
  PY
  src/.build/artifacts/sparkle/Sparkle/bin/sign_update CCProxy.app.zip --verify "$APPCAST_SIGNATURE" --ed-key-file "$SIGNING_KEY_RESOLVED"
  ```
  Expected output: `Sparkle UTF-8/base64 key file and derived public key validated before recomputing appcast signature`, `derived Sparkle public key matches source and bundle SUPublicEDKey; appcast signature matches recomputed EdDSA signature for CCProxy.app.zip; length` followed by the archive byte length, then Sparkle verifies the exact `CCProxy.app.zip` archive using the signature extracted from `appcast.xml` and `--ed-key-file "$SIGNING_KEY_RESOLVED"`. The Python script must not print private key contents and must reject raw binary keys, non-UTF-8 files, invalid base64, empty base64, and decoded lengths other than exactly 32 or 96 bytes. If Python `cryptography` is unavailable for a base64-encoded 32-byte seed, stop; do not use fallback derivation tooling. `git diff --exit-code -- src/Info.plist` must exit zero.

## Task 6 — Stage Archive For Finish Upload

- [ ] RED check: prove the finish upload asset is not already staged.
  ```bash
  set -euo pipefail
  test -s /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip
  ```
  Expected failure mode before staging: command exits non-zero because the staged upload asset is absent.

- [ ] GREEN implementation: copy the generated zip to the approved temporary upload path outside the repository.
  ```bash
  set -euo pipefail
  APP_EXEC='CCProxy.app/Contents/MacOS/CCProxy'
  APP_ARCHS="$(lipo -archs "$APP_EXEC")"
  printf 'CCProxy executable archs before copy to staging path: %s\n' "$APP_ARCHS"
  test "$APP_ARCHS" = 'arm64' || { echo "CCProxy executable must be arm64-only before copy to staging path, got: $APP_ARCHS" >&2; exit 1; }
  APP_FILE_OUTPUT="$(file "$APP_EXEC")"
  printf '%s\n' "$APP_FILE_OUTPUT"
  case "$APP_FILE_OUTPUT" in *x86_64*|*universal*) echo "CCProxy executable must not contain x86_64 or universal slices before copy to staging path: $APP_FILE_OUTPUT" >&2; exit 1 ;; esac
  mkdir -p /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release && rm -f /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip && cp CCProxy.app.zip /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip
  ```
  Expected result: architecture check prints `CCProxy executable archs before copy to staging path: arm64`, `file` output does not include `x86_64` or `universal`, command exits zero, removes only a stale staged `CCProxy.app.zip` at the approved release temp path if present, and creates only the external temp upload copy.

- [ ] Focused verification.
  ```bash
  set -euo pipefail
  APP_EXEC='CCProxy.app/Contents/MacOS/CCProxy'
  APP_ARCHS="$(lipo -archs "$APP_EXEC")"
  printf 'CCProxy executable archs before staging: %s\n' "$APP_ARCHS"
  test "$APP_ARCHS" = 'arm64' || { echo "CCProxy executable must be arm64-only before staging, got: $APP_ARCHS" >&2; exit 1; }
  APP_FILE_OUTPUT="$(file "$APP_EXEC")"
  printf '%s\n' "$APP_FILE_OUTPUT"
  case "$APP_FILE_OUTPUT" in *x86_64*|*universal*) echo "CCProxy executable must not contain x86_64 or universal slices before staging: $APP_FILE_OUTPUT" >&2; exit 1 ;; esac
  test -s /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip
  cmp -s CCProxy.app.zip /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip
  test "$(stat -f%z CCProxy.app.zip)" = "$(stat -f%z /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip)"
  shasum -a 256 CCProxy.app.zip /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip
  python3 - <<'PY'
  import os, sys, xml.etree.ElementTree as ET
  enc=ET.parse('appcast.xml').getroot().find('./channel/item/enclosure')
  expected=str(os.path.getsize('/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip'))
  actual=enc.get('length')
  if actual != expected:
    print(f'appcast length {actual} does not match staged asset length {expected}', file=sys.stderr)
    sys.exit(1)
  print('staged asset matches archive and appcast length', expected)
  PY
  ```
  Expected result: architecture check prints `CCProxy executable archs before staging: arm64`, `file` output does not include `x86_64` or `universal`, existence, byte comparison, and size comparison exit zero; `shasum -a 256` prints identical hashes; Python prints `staged asset matches archive and appcast length`.

## Task 7 — Full Verification Before Commit

- [ ] Run complete repository verification.
  ```bash
  set -euo pipefail
  make backend-version && scripts/test-snapshot-generator.sh && make test && make build
  ```
  Expected result: backend version readable; snapshot generator exits zero; Swift tests pass with zero failures; Swift debug build passes.

- [ ] Verify release bundle and archive metadata.
  ```bash
  set -euo pipefail
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' CCProxy.app/Contents/Info.plist && /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' CCProxy.app/Contents/Info.plist && test -s CCProxy.app.zip && test -s /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip && cmp -s CCProxy.app.zip /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip
  APP_EXEC='CCProxy.app/Contents/MacOS/CCProxy'
  APP_ARCHS="$(lipo -archs "$APP_EXEC")"
  printf 'CCProxy executable archs: %s\n' "$APP_ARCHS"
  test "$APP_ARCHS" = 'arm64' || { echo "CCProxy executable must be arm64-only, got: $APP_ARCHS" >&2; exit 1; }
  APP_FILE_OUTPUT="$(file "$APP_EXEC")"
  printf '%s\n' "$APP_FILE_OUTPUT"
  case "$APP_FILE_OUTPUT" in *x86_64*|*universal*) echo "CCProxy executable must not contain x86_64 or universal slices: $APP_FILE_OUTPUT" >&2; exit 1 ;; esac
  case "$APP_FILE_OUTPUT" in *arm64*) ;; *) echo "CCProxy executable file output does not report arm64: $APP_FILE_OUTPUT" >&2; exit 1 ;; esac
  BACKEND_EXEC='CCProxy.app/Contents/Resources/cli-proxy-api'
  test -f "$BACKEND_EXEC" || { echo "bundled cli-proxy-api missing: $BACKEND_EXEC" >&2; exit 1; }
  BACKEND_FILE_OUTPUT="$(file "$BACKEND_EXEC")"
  printf '%s\n' "$BACKEND_FILE_OUTPUT"
  case "$BACKEND_FILE_OUTPUT" in *x86_64*|*universal*) echo "bundled cli-proxy-api must not contain x86_64 or universal slices: $BACKEND_FILE_OUTPUT" >&2; exit 1 ;; esac
  BACKEND_ARCHS="$(lipo -archs "$BACKEND_EXEC" 2>/dev/null || true)"
  if [ -n "$BACKEND_ARCHS" ]; then
    printf 'bundled cli-proxy-api archs: %s\n' "$BACKEND_ARCHS"
    case " $BACKEND_ARCHS " in *' arm64 '*) ;; *) echo "bundled cli-proxy-api lipo output must include arm64: $BACKEND_ARCHS" >&2; exit 1 ;; esac
  else
    case "$BACKEND_FILE_OUTPUT" in *arm64*|*aarch64*) echo 'bundled cli-proxy-api file output provides arm64/aarch64 backend binary evidence' ;; *) echo "bundled cli-proxy-api file output lacks arm64/aarch64 evidence: $BACKEND_FILE_OUTPUT" >&2; exit 1 ;; esac
  fi
  ```
  Expected output: `0.3.0`, `13`, `CCProxy executable archs: arm64`, `file` output for `CCProxy` includes `arm64` and does not include `x86_64` or `universal`, bundled `cli-proxy-api` evidence includes arm64/aarch64 and does not include `x86_64` or `universal`, and archive existence and byte comparison exit zero.

- [ ] Verify appcast exactly matches generated archive and configured Sparkle public key derived from the private key file.
  ```bash
  set -euo pipefail
  test -n "${SPARKLE_ED_KEY_FILE:-}" || { echo 'SPARKLE_ED_KEY_FILE is unset' >&2; exit 1; }
  case "$SPARKLE_ED_KEY_FILE" in /*) ;; *) echo 'SPARKLE_ED_KEY_FILE must be an absolute path' >&2; exit 1 ;; esac
  SIGNING_KEY_RESOLVED="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$SPARKLE_ED_KEY_FILE")"
  test -f "$SIGNING_KEY_RESOLVED" && test -r "$SIGNING_KEY_RESOLVED"
  case "$SIGNING_KEY_RESOLVED" in
    /Volumes/storage/workspace/ccproxy|/Volumes/storage/workspace/ccproxy/*|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/*) echo "resolved Sparkle key is inside forbidden repository/worktree path: $SIGNING_KEY_RESOLVED" >&2; exit 1 ;;
  esac
  DERIVED_PUBLIC_KEY="$(python3 - "$SIGNING_KEY_RESOLVED" <<'PY'
  import base64, binascii, sys
  raw=open(sys.argv[1],'rb').read()
  try:
    text=raw.decode('utf-8')
  except UnicodeDecodeError:
    print('SPARKLE_ED_KEY_FILE must be UTF-8 base64 text, not raw binary key data; stop', file=sys.stderr)
    sys.exit(1)
  stripped=''.join(text.split())
  if not stripped:
    print('SPARKLE_ED_KEY_FILE is empty after whitespace stripping; stop', file=sys.stderr)
    sys.exit(1)
  try:
    decoded=base64.b64decode(stripped.encode('ascii'), validate=True)
  except (UnicodeEncodeError, binascii.Error):
    print('SPARKLE_ED_KEY_FILE must contain valid ASCII base64 text; stop', file=sys.stderr)
    sys.exit(1)
  if len(decoded) == 96:
    print(base64.b64encode(decoded[-32:]).decode('ascii'))
    sys.exit(0)
  if len(decoded) == 32:
    try:
      from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
      from cryptography.hazmat.primitives import serialization
    except Exception:
      print('python cryptography is required to derive public key from 32-byte Sparkle seed; stop', file=sys.stderr)
      sys.exit(1)
    print(base64.b64encode(Ed25519PrivateKey.from_private_bytes(decoded).public_key().public_bytes(encoding=serialization.Encoding.Raw, format=serialization.PublicFormat.Raw)).decode('ascii'))
    sys.exit(0)
  print(f'SPARKLE_ED_KEY_FILE decoded length must be exactly 32 or 96 bytes, got {len(decoded)}; stop', file=sys.stderr)
  sys.exit(1)
  PY
  )"
  export DERIVED_PUBLIC_KEY
  SOURCE_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' src/Info.plist)"
  BUNDLE_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' CCProxy.app/Contents/Info.plist)"
  test "$DERIVED_PUBLIC_KEY" = 'J/BVhBgfSRFP+Su9oERjKjNg69tvrhKBlis1qaMQRcA=' || { echo 'derived Sparkle public key does not match expected release public key' >&2; exit 1; }
  test "$SOURCE_PUBLIC_KEY" = "$DERIVED_PUBLIC_KEY" || { echo 'derived Sparkle public key does not match src/Info.plist SUPublicEDKey' >&2; exit 1; }
  test "$BUNDLE_PUBLIC_KEY" = "$DERIVED_PUBLIC_KEY" || { echo 'derived Sparkle public key does not match built app SUPublicEDKey' >&2; exit 1; }
  echo 'Sparkle UTF-8/base64 key file and derived public key validated before recomputing appcast signature'
  RECALCULATED_SIGNATURE="$(src/.build/artifacts/sparkle/Sparkle/bin/sign_update --ed-key-file "$SIGNING_KEY_RESOLVED" -p CCProxy.app.zip)"
  export RECALCULATED_SIGNATURE
  APPCAST_SIGNATURE="$(python3 - <<'PY'
  import xml.etree.ElementTree as ET
  enc=ET.parse('appcast.xml').getroot().find('./channel/item/enclosure')
  print(enc.get('{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature') or '')
  PY
  )"
  test -n "$APPCAST_SIGNATURE" || { echo 'appcast sparkle:edSignature is missing' >&2; exit 1; }
  export APPCAST_SIGNATURE
  python3 - <<'PY'
  import os, plistlib, subprocess, sys, xml.etree.ElementTree as ET
  ns={'sparkle':'http://www.andymatuschak.org/xml-namespaces/sparkle'}
  expected_public_key='J/BVhBgfSRFP+Su9oERjKjNg69tvrhKBlis1qaMQRcA='
  derived_public_key=os.environ['DERIVED_PUBLIC_KEY'].strip()
  recalculated=os.environ['RECALCULATED_SIGNATURE'].strip()
  appcast_signature=os.environ['APPCAST_SIGNATURE'].strip()
  root=ET.parse('appcast.xml').getroot()
  item=root.find('./channel/item')
  enc=item.find('enclosure')
  sig=enc.get('{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature')
  with open('src/Info.plist','rb') as f:
    source_info=plistlib.load(f)
  with open('CCProxy.app/Contents/Info.plist','rb') as f:
    bundle_info=plistlib.load(f)
  assert len(root.findall('./channel/item')) == 1
  assert item.find('title').text == 'Version 0.3.0'
  assert item.find('sparkle:shortVersionString', ns).text == '0.3.0'
  assert item.find('sparkle:version', ns).text == '13'
  assert enc.get('url') == 'https://github.com/DevNewbie1826/ccproxy/releases/download/v0.3.0/CCProxy.app.zip'
  assert appcast_signature and appcast_signature == sig
  assert sig and sig == recalculated
  assert enc.get('length') == str(os.path.getsize('CCProxy.app.zip'))
  assert enc.get('type') == 'application/octet-stream'
  assert derived_public_key == expected_public_key
  assert source_info.get('SUPublicEDKey') == expected_public_key
  assert bundle_info.get('SUPublicEDKey') == expected_public_key
  subprocess.run(['git','diff','--exit-code','--','src/Info.plist'], check=True)
  print('verified appcast v0.3.0 build 13 with derived Sparkle public key, recomputed EdDSA signature, and unchanged SUPublicEDKey')
  PY
  src/.build/artifacts/sparkle/Sparkle/bin/sign_update CCProxy.app.zip --verify "$APPCAST_SIGNATURE" --ed-key-file "$SIGNING_KEY_RESOLVED"
  ```
  Expected output: `Sparkle UTF-8/base64 key file and derived public key validated before recomputing appcast signature`, `verified appcast v0.3.0 build 13 with derived Sparkle public key, recomputed EdDSA signature, and unchanged SUPublicEDKey`, followed by successful Sparkle archive verification using `src/.build/artifacts/sparkle/Sparkle/bin/sign_update CCProxy.app.zip --verify "$APPCAST_SIGNATURE" --ed-key-file "$SIGNING_KEY_RESOLVED"`, where `APPCAST_SIGNATURE` was extracted from `appcast.xml`. The private key contents must not be printed; raw binary keys, non-UTF-8 files, invalid base64, empty base64, and decoded lengths other than exactly 32 or 96 bytes must stop; if Python `cryptography` is unavailable for a base64-encoded 32-byte seed, stop; do not use fallback derivation tooling.

- [ ] Verify generated artifacts, root `.gitignore`, and private key are not staged or tracked as release files.
  ```bash
  set -euo pipefail
  git status --short
  git diff -- appcast.xml src/Sources/Resources/cli-proxy-api docs/easycode/2026-06-05-app-release-v0-3-0/plan.md
  git diff --cached --name-only
  git -C /Volumes/storage/workspace/ccproxy status --short -- .gitignore
  git status --short -- .gitignore
  test -n "${SPARKLE_ED_KEY_FILE:-}" || { echo 'SPARKLE_ED_KEY_FILE is unset' >&2; exit 1; }
  SIGNING_KEY_RESOLVED="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$SPARKLE_ED_KEY_FILE")"
  test -f "$SIGNING_KEY_RESOLVED" && test -r "$SIGNING_KEY_RESOLVED"
  case "$SIGNING_KEY_RESOLVED" in /Volumes/storage/workspace/ccproxy|/Volumes/storage/workspace/ccproxy/*|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0|/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/*) echo "resolved Sparkle key is inside forbidden repository/worktree path: $SIGNING_KEY_RESOLVED" >&2; exit 1 ;; esac
  for path in CCProxy.app CCProxy.app.zip "$SIGNING_KEY_RESOLVED"; do
    if git ls-files --error-unmatch "$path" >/dev/null 2>&1; then echo "tracked forbidden path: $path" >&2; exit 1; fi
  done
  echo 'generated app artifacts, root .gitignore, and resolved Sparkle key are excluded from release staging'
  ```
  Expected result: status shows intended tracked modifications only plus generated untracked/ignored artifacts; cached name list is empty before staging; root may show `.gitignore` dirty but worktree `.gitignore` prints nothing; final message prints with zero exit.

## Task 8 — Commit Intended Files Only

- [ ] RED check: verify there is no existing release commit on this branch.
  ```bash
  set -euo pipefail
  git log --oneline --decorate -5 && git status --short
  ```
  Expected result: no commit message `Release v0.3.0`; status shows uncommitted intended release changes.

- [ ] GREEN commit preparation: stage only committed release metadata, this plan artifact, and verified backend binary if changed.
  ```bash
  set -euo pipefail
  git add appcast.xml docs/easycode/2026-06-05-app-release-v0-3-0/plan.md && if ! git diff --quiet -- src/Sources/Resources/cli-proxy-api; then git add src/Sources/Resources/cli-proxy-api; fi && git status --short
  ```
  Expected output: staged `appcast.xml`; staged `docs/easycode/2026-06-05-app-release-v0-3-0/plan.md` if it was not already committed; staged `src/Sources/Resources/cli-proxy-api` only if backend update changed it. `CCProxy.app`, `CCProxy.app.zip`, temp upload path, root `.gitignore`, and private key are not staged.

- [ ] Commit with intended files only.
  ```bash
  set -euo pipefail
  git diff --cached --name-only && git commit -m "Release v0.3.0"
  ```
  Expected output before commit: `appcast.xml`, `docs/easycode/2026-06-05-app-release-v0-3-0/plan.md` if not already committed, and optionally `src/Sources/Resources/cli-proxy-api` only. Commit succeeds with message `Release v0.3.0`.

- [ ] Focused post-commit verification.
  ```bash
  set -euo pipefail
  git status --short && git log --oneline --decorate -3
  ```
  Expected result: branch contains the new `Release v0.3.0` commit; remaining status may show generated `CCProxy.app` and `CCProxy.app.zip` only; no staged changes.

## Code Review Gates Before Final-Review

- [ ] Run `code-spec-reviewer` against the approved spec, evidence, committed diff, and verification output. Expected result: PASS. If FAIL, route back to execute for the smallest safe fix, rerun Task 7, recommit if needed, and rerun both code review gates.
- [ ] Run `code-quality-reviewer` against the committed diff and generated artifact/key safety evidence. Expected result: PASS. If FAIL, route back to execute for the smallest safe fix, rerun Task 7, recommit if needed, and rerun both code review gates.
- [ ] Run `completion-verifier` with final verification commands, appcast checks, archive staging evidence, git status, and commit hash. Expected result: PASS. If FAIL, fix only the verified blocker and rerun required verification and review gates.
- [ ] Proceed to final-review only after all three execute review gates PASS. Expected later artifact: `docs/easycode/2026-06-05-app-release-v0-3-0/final-review.md`.

## Finish Commands After Final-Review PASS

These commands are for the finish stage only after final-review PASS. Do not run them during planning or execute review. The final-review stage creates `docs/easycode/2026-06-05-app-release-v0-3-0/final-review.md`; that artifact must be committed before branch push, PR creation, merge, publication, or cleanup.

- [ ] Verify final-review PASS artifact exists and commit it before publishing the branch.
  ```bash
  set -euo pipefail
  test -s docs/easycode/2026-06-05-app-release-v0-3-0/final-review.md
  python3 - <<'PY'
  import sys
  path='docs/easycode/2026-06-05-app-release-v0-3-0/final-review.md'
  lines=open(path, encoding='utf-8').read().splitlines()
  def first_nonempty_under(section):
    target=f'## {section}'
    for i, line in enumerate(lines):
      if line.strip() == target:
        for value in lines[i+1:]:
          stripped=value.strip()
          if stripped.startswith('## '):
            return None
          if stripped:
            return stripped
        return None
    return None
  verdict=first_nonempty_under('Current Verdict')
  routing=first_nonempty_under('Current Routing Recommendation')
  if verdict != 'PASS':
    print(f'final-review Current Verdict must be exactly PASS, got {verdict!r}', file=sys.stderr)
    sys.exit(1)
  if routing != 'finish':
    print(f'final-review Current Routing Recommendation must be exactly finish, got {routing!r}', file=sys.stderr)
    sys.exit(1)
  print('final-review parsed verdict PASS and routing finish')
  PY
  git status --short
  git diff -- docs/easycode/2026-06-05-app-release-v0-3-0/final-review.md
  git add docs/easycode/2026-06-05-app-release-v0-3-0/final-review.md
  git diff --cached --name-only
  git commit -m "Record final review for v0.3.0"
  git status --short
  git diff --stat
  git log --oneline --decorate -3
  ```
  Expected result: final-review artifact exists; parsed Markdown section `## Current Verdict` has first non-empty value exactly `PASS`; parsed section `## Current Routing Recommendation` has first non-empty value exactly `finish`; staged file list contains only `docs/easycode/2026-06-05-app-release-v0-3-0/final-review.md`; commit succeeds with message `Record final review for v0.3.0`; and post-commit status contains only generated local artifacts such as `CCProxy.app` and `CCProxy.app.zip` with no staged changes. Incidental text such as “not PASS” elsewhere in the artifact is not acceptable evidence. If final-review FAILs, do not commit this artifact or continue to finish; route back through the required review/fix path.

- [ ] Push the release branch from the worktree.
  ```bash
  set -euo pipefail
  git push -u origin work/2026-06-05-app-release-v0-3-0
  ```
  Expected result: remote branch is created or updated without force-push.

- [ ] Create the PR from the worktree.
  ```bash
  set -euo pipefail
  gh pr create --base main --head work/2026-06-05-app-release-v0-3-0 --title "Release v0.3.0" --body "Release CCProxy v0.3.0 build 13 with updated Sparkle appcast and verified arm64 release archive staged for publication."
  ```
  Expected result: command prints the PR URL.

- [ ] Merge the PR from the repository root without deleting the branch while the worktree exists.
  ```bash
  set -euo pipefail
  gh pr merge work/2026-06-05-app-release-v0-3-0 --merge
  ```
  Run from `/Volumes/storage/workspace/ccproxy`. Expected result: PR merges successfully; do not pass `--delete-branch` while the feature worktree still exists.

- [ ] Update local `main` from the repository root.
  ```bash
  set -euo pipefail
  git checkout main && git pull --ff-only origin main
  ```
  Run from `/Volumes/storage/workspace/ccproxy`. Expected result: local `main` fast-forwards to merged `origin/main`; the unrelated root `.gitignore` dirty change remains unstaged and uncommitted.

- [ ] Recompute the merged release commit SHA from updated local main before publication.
  ```bash
  set -euo pipefail
  MERGED_RELEASE_SHA="$(git rev-parse main)"
  ORIGIN_MAIN_SHA="$(git rev-parse origin/main)"
  PR_MERGE_SHA="$(gh pr view work/2026-06-05-app-release-v0-3-0 --json mergeCommit --jq '.mergeCommit.oid')"
  test -n "$MERGED_RELEASE_SHA" && test -n "$ORIGIN_MAIN_SHA" && test -n "$PR_MERGE_SHA"
  test "$MERGED_RELEASE_SHA" = "$ORIGIN_MAIN_SHA"
  test "$MERGED_RELEASE_SHA" = "$PR_MERGE_SHA"
  git log -1 --oneline "$MERGED_RELEASE_SHA"
  ```
  Run from `/Volumes/storage/workspace/ccproxy`. Expected output: local `main`, `origin/main`, and PR merge commit resolve to the same non-empty SHA, then the merged release commit line prints.

- [ ] Reverify the staged zip is preserved and appcast length matches before publication.
  ```bash
  set -euo pipefail
  test -s /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/CCProxy.app.zip
  APP_EXEC='/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/CCProxy.app/Contents/MacOS/CCProxy'
  APP_ARCHS="$(lipo -archs "$APP_EXEC")"
  printf 'CCProxy executable archs before publication: %s\n' "$APP_ARCHS"
  test "$APP_ARCHS" = 'arm64' || { echo "CCProxy executable must be arm64-only before publication, got: $APP_ARCHS" >&2; exit 1; }
  APP_FILE_OUTPUT="$(file "$APP_EXEC")"
  printf '%s\n' "$APP_FILE_OUTPUT"
  case "$APP_FILE_OUTPUT" in *x86_64*|*universal*) echo "CCProxy executable must not contain x86_64 or universal slices before publication: $APP_FILE_OUTPUT" >&2; exit 1 ;; esac
  test -s /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip
  cmp -s /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/CCProxy.app.zip /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip
  WORKTREE_ASSET_SIZE="$(stat -f%z /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/CCProxy.app.zip)"
  STAGED_ASSET_SIZE="$(stat -f%z /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip)"
  test "$WORKTREE_ASSET_SIZE" = "$STAGED_ASSET_SIZE"
  WORKTREE_ASSET_SHA="$(shasum -a 256 /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/CCProxy.app.zip | cut -d ' ' -f 1)"
  STAGED_ASSET_SHA="$(shasum -a 256 /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip | cut -d ' ' -f 1)"
  test -n "$WORKTREE_ASSET_SHA" && test -n "$STAGED_ASSET_SHA" && test "$WORKTREE_ASSET_SHA" = "$STAGED_ASSET_SHA"
  shasum -a 256 /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip
  python3 - <<'PY'
  import os, sys, xml.etree.ElementTree as ET
  appcast='/Volumes/storage/workspace/ccproxy/appcast.xml'
  asset='/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip'
  enc=ET.parse(appcast).getroot().find('./channel/item/enclosure')
  expected=str(os.path.getsize(asset))
  actual=enc.get('length')
  if actual != expected:
    print(f'appcast length {actual} does not match staged asset length {expected}', file=sys.stderr)
    sys.exit(1)
  print('staged release asset preserved with appcast length', expected)
  PY
  ```
  Run from `/Volumes/storage/workspace/ccproxy` before worktree cleanup. Expected result: worktree archive and staged asset both exist, architecture check prints `CCProxy executable archs before publication: arm64`, `file` output does not include `x86_64` or `universal`, `cmp -s` exits zero, sizes and SHA-256 values match, checksum prints, and Python prints `staged release asset preserved with appcast length`.

- [ ] Recheck tag and release absence immediately before publication.
  ```bash
  set -euo pipefail
  set +e
  tag_output="$(git ls-remote --exit-code --tags origin refs/tags/v0.3.0 2>&1)"
  tag_rc=$?
  set -e
  case "$tag_rc" in
    0) echo 'remote tag v0.3.0 already exists' >&2; printf '%s\n' "$tag_output" >&2; exit 1 ;;
    2) echo 'remote tag v0.3.0 verified absent immediately before publication' ;;
    *) echo "remote tag v0.3.0 absence unknown; git ls-remote exit $tag_rc" >&2; printf '%s\n' "$tag_output" >&2; exit 1 ;;
  esac
  set +e
  release_output="$(gh release view v0.3.0 --json tagName 2>&1)"
  release_rc=$?
  set -e
  if [ "$release_rc" -eq 0 ]; then echo 'GitHub Release v0.3.0 already exists' >&2; printf '%s\n' "$release_output" >&2; exit 1; fi
  case "$release_output" in
    *'release not found'*|*'Release not found'*|*'not found'*|*'Not Found'*) echo 'GitHub Release v0.3.0 verified absent immediately before publication' ;;
    *) echo "GitHub Release v0.3.0 absence unknown; gh exit $release_rc" >&2; printf '%s\n' "$release_output" >&2; exit 1 ;;
  esac
  echo 'release v0.3.0 is still unpublished immediately before publication'
  ```
  Expected output: `remote tag v0.3.0 verified absent immediately before publication`, `GitHub Release v0.3.0 verified absent immediately before publication`, and `release v0.3.0 is still unpublished immediately before publication`.

- [ ] Create the GitHub Release with the staged zip asset pinned to the merged SHA.
  ```bash
  set -euo pipefail
  MERGED_RELEASE_SHA="$(git rev-parse main)"
  ORIGIN_MAIN_SHA="$(git rev-parse origin/main)"
  PR_MERGE_SHA="$(gh pr view work/2026-06-05-app-release-v0-3-0 --json mergeCommit --jq '.mergeCommit.oid')"
  test -n "$MERGED_RELEASE_SHA" && test -n "$ORIGIN_MAIN_SHA" && test -n "$PR_MERGE_SHA"
  test "$MERGED_RELEASE_SHA" = "$ORIGIN_MAIN_SHA"
  test "$MERGED_RELEASE_SHA" = "$PR_MERGE_SHA"
  test -s /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/CCProxy.app.zip
  APP_EXEC='/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/CCProxy.app/Contents/MacOS/CCProxy'
  APP_ARCHS="$(lipo -archs "$APP_EXEC")"
  printf 'CCProxy executable archs at release creation: %s\n' "$APP_ARCHS"
  test "$APP_ARCHS" = 'arm64' || { echo "CCProxy executable must be arm64-only at release creation, got: $APP_ARCHS" >&2; exit 1; }
  APP_FILE_OUTPUT="$(file "$APP_EXEC")"
  printf '%s\n' "$APP_FILE_OUTPUT"
  case "$APP_FILE_OUTPUT" in *x86_64*|*universal*) echo "CCProxy executable must not contain x86_64 or universal slices at release creation: $APP_FILE_OUTPUT" >&2; exit 1 ;; esac
  test -s /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip
  cmp -s /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/CCProxy.app.zip /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip
  WORKTREE_ASSET_SHA="$(shasum -a 256 /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/CCProxy.app.zip | cut -d ' ' -f 1)"
  STAGED_ASSET_SHA="$(shasum -a 256 /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip | cut -d ' ' -f 1)"
  test -n "$WORKTREE_ASSET_SHA" && test -n "$STAGED_ASSET_SHA" && test "$WORKTREE_ASSET_SHA" = "$STAGED_ASSET_SHA"
  gh release create v0.3.0 /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip --target "$MERGED_RELEASE_SHA" --title "CCProxy v0.3.0" --notes "Release CCProxy v0.3.0 build 13. This arm64-only app release publishes the current main app state with a verified Sparkle appcast update and CCProxy.app.zip asset."
  ```
  Expected result: architecture check prints `CCProxy executable archs at release creation: arm64`, `file` output does not include `x86_64` or `universal`; `gh release create` creates release `v0.3.0` with `CCProxy.app.zip` attached and targets the freshly verified merged release SHA, not a moving branch name.

- [ ] Verify published release, tag, target SHA, and asset.
  ```bash
  set -euo pipefail
  MERGED_RELEASE_SHA="$(git rev-parse main)"
  ORIGIN_MAIN_SHA="$(git rev-parse origin/main)"
  PR_MERGE_SHA="$(gh pr view work/2026-06-05-app-release-v0-3-0 --json mergeCommit --jq '.mergeCommit.oid')"
  test -n "$MERGED_RELEASE_SHA" && test -n "$ORIGIN_MAIN_SHA" && test -n "$PR_MERGE_SHA"
  test "$MERGED_RELEASE_SHA" = "$ORIGIN_MAIN_SHA"
  test "$MERGED_RELEASE_SHA" = "$PR_MERGE_SHA"
  gh release view v0.3.0 --json tagName,name,assets,url
  git fetch --force origin refs/tags/v0.3.0:refs/tags/v0.3.0
  PUBLISHED_TAG_SHA="$(git rev-list -n 1 v0.3.0)"
  test -n "$PUBLISHED_TAG_SHA"
  test "$PUBLISHED_TAG_SHA" = "$MERGED_RELEASE_SHA"
  echo "remote tag v0.3.0 resolves to merged release commit $MERGED_RELEASE_SHA"
  ```
  Expected result: JSON reports `tagName` `v0.3.0`, release name `CCProxy v0.3.0`, and an asset named `CCProxy.app.zip`; fetched remote tag `v0.3.0` resolves to the same merged release commit SHA used as `--target`.

- [ ] Clean generated worktree-only artifacts and prove the worktree is clean only after successful PR merge, release creation, and publication verification.
  ```bash
  set -euo pipefail
  test -s /var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/ccproxy-v0.3.0-release/CCProxy.app.zip
  rm -rf /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/CCProxy.app /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0/CCProxy.app.zip
  git -C /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0 status --short
  git -C /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0 diff --stat
  test -z "$(git -C /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0 status --short)"
  ```
  Run from `/Volumes/storage/workspace/ccproxy`. Expected result: external staged upload asset still exists, generated worktree-only app artifacts are removed, `git status --short` and `git diff --stat` for the feature worktree print nothing, and the final `test -z` exits zero. This clean status is mandatory after the final-review commit and generated artifact cleanup, before worktree removal or branch deletion. If any uncommitted workflow artifact remains, commit it if allowed by the workflow and verified, or stop for user direction; do not remove a dirty worktree.

- [ ] Remove the EasyCode worktree from the repository root only after successful publication verification and clean-worktree proof.
  ```bash
  set -euo pipefail
  git worktree remove /Volumes/storage/workspace/ccproxy/.worktrees/2026-06-05-app-release-v0-3-0
  ```
  Run from `/Volumes/storage/workspace/ccproxy`. Expected result: EasyCode feature worktree is removed after PR merge, local main update, staged zip verification, GitHub Release creation, published release verification, final-review artifact commit, and clean-worktree proof.

- [ ] Delete the local and remote feature branches after worktree cleanup.
  ```bash
  set -euo pipefail
  git branch -d work/2026-06-05-app-release-v0-3-0 && git push origin --delete work/2026-06-05-app-release-v0-3-0
  ```
  Run from `/Volumes/storage/workspace/ccproxy`. Expected result: local and remote feature branches are deleted after merge and after the EasyCode worktree no longer exists.
