# OpenCode Go Logo And v0.3.2 Release Implementation Plan

> **For agentic workers:** Each task is dispatched to the `executor` agent. Follow the EasyCode `execute` stage: per-task TDD cycle, `code-spec-reviewer` and `code-quality-reviewer` review gates, and `completion-verifier` for final evidence. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the supplied OpenCode Go logo as a converted PNG provider icon, cover the regression, and prepare the signed arm64 `v0.3.2` build `15` release.

**Architecture:** CCProxy is a Swift Package macOS menu bar app whose provider rows are declared in `src/Sources/SettingsView.swift`. Provider icons are PNG resources copied from `src/Sources/Resources/` and loaded by `IconCatalog` using bundled resource filenames, so this change should stay on that existing filename-based path rather than adding runtime SVG rendering. Release packaging is driven by `make sparkle-archive`, `create-app-bundle.sh`, Sparkle's `sign_update`, and `appcast.xml`.

**Tech Stack:** Swift 5.9, SwiftPM/XCTest, SwiftUI/AppKit, macOS command-line tools, Sparkle 2.x CLI tools, Make, Git, GitHub CLI.

## Approved Inputs And Baseline

- Work ID: `2026-06-06-opencode-go-logo-v0-3-2-release`
- Approved spec: `docs/easycode/2026-06-06-opencode-go-logo-v0-3-2-release/spec.md`
- Approved evidence: `docs/easycode/2026-06-06-opencode-go-logo-v0-3-2-release/evidence.md`
- User approval summary: the user approved the revised spec to convert the supplied OpenCode Go SVG data URI into a PNG resource, update the `opencode-go` settings row to use that PNG through the existing provider icon path, add focused regression coverage for the logo, and proceed unattended through PR creation, merge, local `main` update, EasyCode worktree/branch cleanup, and GitHub Release `v0.3.2` build `15` after all EasyCode gates pass.
- Worktree path: `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-opencode-go-logo-v0-3-2-release`
- Branch: `work/2026-06-06-opencode-go-logo-v0-3-2-release`
- Checkpoint commit at planning: `a8a28f49cd0830572df8630f1556a72874269f01`
- Worktree status at planning: `## work/2026-06-06-opencode-go-logo-v0-3-2-release` with no uncommitted files before `plan.md` was added.
- Baseline command: `make backend-version && scripts/test-snapshot-generator.sh && make test && make build`
- Baseline result: passed; output recorded at `/Users/mirage/.local/share/opencode/tool-output/tool_e9af64cc10012Pu00Y8ztseASr`; 259 tests executed, 1 skipped, 0 failures; build passed.
- Degraded baseline caveat: none.
- Spec-reviewer result: PASS; micro route rejected, full workflow required.
- CodeGraph note: `codegraph_files` was checked with project path `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-opencode-go-logo-v0-3-2-release`; it reported the available index belongs to the root checkout, so this plan uses direct repository reads/grep evidence instead of relying on stale CodeGraph source.

## Approved User Decisions

- The approved image source is exactly the supplied URL-encoded SVG data URI in `spec.md`; no substitute logo, redraw, or runtime SVG renderer is in scope.
- The approved implementation shape is a converted PNG resource under `src/Sources/Resources/`, referenced by the `opencode-go` settings row through the existing filename-based `IconCatalog` path.
- The approved verification scope includes a focused regression test that fails before the mapping/resource fix and passes after the minimal PNG resource and row update.
- The approved release scope is arm64-only `v0.3.2` build `15`, with Sparkle signing using `/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key`, external archive staging at `/Volumes/storage/artifact/ccproxy/releases/v0.3.2/CCProxy.app.zip`, and unattended finish through PR, merge, local update, cleanup, and GitHub Release only after execute, review, final-review, and finish gates pass.

## File Structure

Create:

- `src/Sources/Resources/icon-opencode-go.png` — PNG converted from the exact approved SVG data URI.
- `src/Tests/CCProxyTests/ProviderIconTests.swift` — focused regression tests for the OpenCode Go icon mapping and PNG loading path.
- `docs/easycode/2026-06-06-opencode-go-logo-v0-3-2-release/plan.md` — this plan artifact only during plan stage.
- `docs/easycode/2026-06-06-opencode-go-logo-v0-3-2-release/final-review.md` — later final-review stage artifact only, not during execute.

Modify:

- `src/Sources/SettingsView.swift` — replace the `.opencodeGo` empty icon name with the new icon filename and, if needed for testability, introduce a small internal provider icon filename helper used by the rows.
- `src/Sources/IconCatalog.swift` — only if needed to support focused tests through the existing file-path loading logic; keep `IconCatalog.shared` defaulting to `Bundle.main` and avoid changing runtime behavior.
- `appcast.xml` — update from `v0.3.1` build `14` to `v0.3.2` build `15` after the exact release archive is built and signed.

Do not modify:

- Root checkout `.gitignore`; it has a known pre-existing dirty change outside this work.
- Provider/auth/catalog behavior files except for minimal testability if required by the icon regression.
- Sparkle key files, generated `.app`, generated `.zip`, or external staged release artifacts inside git.

## Preflight Before Implementation

- [ ] Enforce the plan-stage gate before any execute/preflight/implementation work:

  ```bash
  printf '%s\n' 'Required before execute: plan-checker PASS, plan-challenger PASS, and user/unattended plan approval for this exact plan.md revision.'
  ```

  Expected output: the printed gate statement. Execute must not start until both plan reviewers return PASS and the user/unattended approval gate approves this revised `docs/easycode/2026-06-06-opencode-go-logo-v0-3-2-release/plan.md`. If any gate is missing, stop and return to the plan stage; do not run preflight, tests, implementation edits, commits, release packaging, PR, or finish commands.

- [ ] Confirm the executor is in the isolated worktree, not the root checkout:

  ```bash
  pwd && git rev-parse --show-toplevel && git status --short --branch
  ```

  Expected output: both paths are `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-opencode-go-logo-v0-3-2-release`; branch is `work/2026-06-06-opencode-go-logo-v0-3-2-release`; only the already-approved plan artifact may be present before execute starts.

- [ ] Confirm release/tag absence before spending release time:

  ```bash
  git tag --list v0.3.2
  git ls-remote --tags origin refs/tags/v0.3.2
  gh release view v0.3.2 --repo DevNewbie1826/ccproxy
  ```

  Expected output: the first two commands print nothing; `gh release view` exits non-zero with a not-found style message. If any command shows an existing `v0.3.2` tag or release, stop for finish/spec routing.

- [ ] Confirm no x86_64 appcast file is in scope:

  ```bash
  test ! -e appcast-x86_64.xml
  ```

  Expected output: no output and exit 0. If `appcast-x86_64.xml` exists, stop for spec clarification because the approved scope is arm64-only.

- [ ] Confirm Sparkle CLI and key material path are usable without printing private bytes:

  ```bash
  test -x src/.build/artifacts/sparkle/Sparkle/bin/sign_update && test -f "/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key" && test -r "/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key"
  ```

  Expected output: no output and exit 0. If this fails, stop for environment setup; do not print private key contents.

## Task 1 — Lock The OpenCode Go Icon Regression With RED Tests

- [ ] Add `src/Tests/CCProxyTests/ProviderIconTests.swift` with two focused tests before changing production icon behavior:
  - `testOpenCodeGoProviderIconNameIsNonEmptyPng` expects the app's provider icon mapping for `.opencodeGo` to equal `icon-opencode-go.png` and not be empty.
  - `testOpenCodeGoProviderIconLoadsAsPNGThroughIconCatalogPath` expects the referenced PNG resource to exist under `src/Sources/Resources/`, be non-empty, start with the PNG magic bytes `89 50 4E 47 0D 0A 1A 0A`, and load through the same file-path/`NSImage(contentsOfFile:)` mechanism used by `IconCatalog.image(named:resizedTo:template:)`.

- [ ] If production code has no testable provider icon mapping, make the RED test reference a small intended helper such as `ProviderIconNames.iconName(for: .opencodeGo)`. This helper does not exist yet, so the initial RED result may be a compile failure.

- [ ] Run the focused RED test command:

  ```bash
  cd src && swift test --filter ProviderIconTests
  ```

  Expected RED result: fail before implementation. Acceptable failures are either a compile error that `ProviderIconTests`, `ProviderIconNames`, or a testability initializer/member does not yet exist, or assertion/file-load failures showing `opencode-go` still has an empty icon or `icon-opencode-go.png` is missing. If tests pass before production/resource changes, stop because the regression is not proving the approved bug.

## Task 2 — Convert The Exact SVG Data URI Into A PNG Resource

- [ ] Decode the exact approved data URI to a temporary SVG outside the repository:

  ```bash
  python3 - <<'PY'
  from pathlib import Path
  from urllib.parse import unquote
  uri = "data:image/svg+xml,%3csvg%20width='54'%20height='30'%20viewBox='0%200%2054%2030'%20fill='none'%20xmlns='http://www.w3.org/2000/svg'%3e%3cpath%20d='M24%2030H0V0H24V6H6V24H18V18H12V12H24V30Z'%20fill='%23F1ECEC'/%3e%3cpath%20d='M12%2018H18V24H6V12H12V18Z'%20fill='%234B4646'/%3e%3cpath%20d='M48%2012V24H36V12H48Z'%20fill='%234B4646'/%3e%3cpath%20d='M54%2030H30V0H54V30ZM36%2024H48V6H36V24Z'%20fill='%23F1ECEC'/%3e%3c/svg%3e"
  prefix = "data:image/svg+xml,"
  if not uri.startswith(prefix):
      raise SystemExit("approved URI prefix mismatch")
  svg = unquote(uri[len(prefix):])
  expected = "<svg width='54' height='30' viewBox='0 0 54 30' fill='none' xmlns='http://www.w3.org/2000/svg'><path d='M24 30H0V0H24V6H6V24H18V18H12V12H24V30Z' fill='#F1ECEC'/><path d='M12 18H18V24H6V12H12V18Z' fill='#4B4646'/><path d='M48 12V24H36V12H48Z' fill='#4B4646'/><path d='M54 30H30V0H54V30ZM36 24H48V6H36V24Z' fill='#F1ECEC'/></svg>"
  if svg != expected:
      raise SystemExit("decoded SVG does not match approved literal")
  out = Path('/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/opencode-go-logo.svg')
  out.parent.mkdir(parents=True, exist_ok=True)
  out.write_text(svg, encoding='utf-8')
  print(out)
  PY
  ```

  Expected output: `/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/opencode-go-logo.svg`. If the decoded SVG mismatch check fails, stop for spec revision.

- [ ] Choose a local SVG renderer with this exact preflight:

  ```bash
  if command -v rsvg-convert >/dev/null 2>&1; then printf 'rsvg-convert\n'; elif command -v magick >/dev/null 2>&1; then printf 'magick\n'; elif command -v qlmanage >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then printf 'qlmanage+sips\n'; else printf 'NO_SUPPORTED_RENDERER\n'; exit 64; fi
  ```

  Expected output: one of `rsvg-convert`, `magick`, or `qlmanage+sips`. If output is `NO_SUPPORTED_RENDERER`, stop for tooling/spec routing; do not substitute a different logo and do not add runtime SVG rendering.

- [ ] Convert to `src/Sources/Resources/icon-opencode-go.png` using the selected renderer:
  - For `rsvg-convert`:

    ```bash
    rsvg-convert -w 54 -h 30 "/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/opencode-go-logo.svg" -o "src/Sources/Resources/icon-opencode-go.png"
    ```

  - For `magick`:

    ```bash
    magick -background none -density 144 "/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/opencode-go-logo.svg" -resize 54x30 "src/Sources/Resources/icon-opencode-go.png"
    ```

  - For `qlmanage+sips`:

    ```bash
    rm -rf "/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/opencode-go-logo-rendered" && mkdir -p "/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/opencode-go-logo-rendered" && qlmanage -t -s 108 -o "/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/opencode-go-logo-rendered" "/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/opencode-go-logo.svg" && sips -s format png -z 30 54 "/var/folders/v0/g2h4nhxd64j63j7tnr3rc87c0000gn/T/opencode/opencode-go-logo-rendered/opencode-go-logo.svg.png" --out "src/Sources/Resources/icon-opencode-go.png"
    ```

  Expected output: renderer-specific success output and a created PNG at `src/Sources/Resources/icon-opencode-go.png`.

- [ ] Verify the PNG is non-empty, has the PNG signature, AppKit can decode it, and deterministic pixel samples prove it is derived from the approved SVG rather than merely being a `54x30` PNG:

  ```bash
  python3 - <<'PY'
  from pathlib import Path
  p = Path('src/Sources/Resources/icon-opencode-go.png')
  data = p.read_bytes()
  if len(data) == 0:
      raise SystemExit('PNG is empty')
  if data[:8] != b'\x89PNG\r\n\x1a\n':
      raise SystemExit('PNG signature mismatch')
  print(f'{p} {len(data)} bytes')
  PY
  swift - <<'SWIFT'
import AppKit
struct ExpectedPixel {
    let x: Int
    let y: Int
    let rgba: (Int, Int, Int, Int)
    let label: String
}
struct ExpectedTransparentPixel {
    let x: Int
    let y: Int
    let label: String
}
func byte(_ value: CGFloat) -> Int { Int(round(value * 255.0)) }
func assertPixel(_ rep: NSBitmapImageRep, _ expected: ExpectedPixel) {
    guard let color = rep.colorAt(x: expected.x, y: expected.y)?.usingColorSpace(.sRGB) else { fatalError("missing color at (\(expected.x),\(expected.y))") }
    let actual = (byte(color.redComponent), byte(color.greenComponent), byte(color.blueComponent), byte(color.alphaComponent))
    if actual != expected.rgba { fatalError("\(expected.label) pixel at (\(expected.x),\(expected.y)) expected RGBA \(expected.rgba), got \(actual)") }
}
func assertTransparent(_ rep: NSBitmapImageRep, _ expected: ExpectedTransparentPixel) {
    guard let color = rep.colorAt(x: expected.x, y: expected.y)?.usingColorSpace(.sRGB) else { fatalError("missing color at (\(expected.x),\(expected.y))") }
    let alpha = byte(color.alphaComponent)
    if alpha != 0 { fatalError("\(expected.label) pixel at (\(expected.x),\(expected.y)) expected transparent alpha 0, got alpha \(alpha)") }
}
let path = "src/Sources/Resources/icon-opencode-go.png"
guard let image = NSImage(contentsOfFile: path) else { fatalError("NSImage failed to load icon-opencode-go.png") }
guard let rep = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: path))) else { fatalError("NSBitmapImageRep failed to decode icon-opencode-go.png") }
if rep.pixelsWide != 54 || rep.pixelsHigh != 30 { fatalError("PNG canvas must be exactly 54x30, got \(rep.pixelsWide)x\(rep.pixelsHigh)") }
let exactSamples = [
    ExpectedPixel(x: 3, y: 3, rgba: (0xF1, 0xEC, 0xEC, 0xFF), label: "left light #F1ECEC fill"),
    ExpectedPixel(x: 32, y: 3, rgba: (0xF1, 0xEC, 0xEC, 0xFF), label: "right light #F1ECEC fill"),
    ExpectedPixel(x: 9, y: 15, rgba: (0x4B, 0x46, 0x46, 0xFF), label: "left dark #4B4646 fill"),
    ExpectedPixel(x: 42, y: 18, rgba: (0x4B, 0x46, 0x46, 0xFF), label: "right dark #4B4646 fill")
]
for sample in exactSamples { assertPixel(rep, sample) }
let transparentSamples = [
    ExpectedTransparentPixel(x: 27, y: 15, label: "transparent center gap"),
    ExpectedTransparentPixel(x: 42, y: 8, label: "transparent right inner hole")
]
for sample in transparentSamples { assertTransparent(rep, sample) }
var minX = 54, maxX = -1, minY = 30, maxY = -1
for y in 0..<rep.pixelsHigh {
    for x in 0..<rep.pixelsWide {
        guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
        if color.alphaComponent > 0.01 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
}
if minX != 0 || minY != 0 || maxX != 53 || maxY != 29 { fatalError("PNG visible bounds indicate thumbnail/padding/scaling mistake: x=\(minX)...\(maxX) y=\(minY)...\(maxY)") }
print("NSImage loaded exact 54x30 canvas; transparent samples and #F1ECEC/#4B4646 fill samples match approved SVG")
SWIFT
   ```

  Expected output: byte count greater than zero and `NSImage loaded exact 54x30 canvas; transparent samples and #F1ECEC/#4B4646 fill samples match approved SVG`. The exact sample points must verify transparent background alpha at `(27,15)` and `(42,8)`, light filled pixels matching exact RGBA `#F1ECEC` with alpha 255 at `(3,3)` and `(32,3)`, and dark filled pixels matching exact RGBA `#4B4646` with alpha 255 at `(9,15)` and `(42,18)`. If the canvas is not exactly `54x30`, if visible pixels do not touch all four expected SVG bounds, if any representative transparent or filled pixel differs, or if the renderer/fallback creates a thumbnail, padding, antialiased/scaled sample mismatch, or any output that cannot prove these checks deterministically, stop for tooling/spec routing; do not hand-edit or substitute the image.

- [ ] Run focused RED again:

  ```bash
  cd src && swift test --filter ProviderIconTests
  ```

  Expected result after only adding the resource: still RED because production mapping still points `.opencodeGo` at an empty icon name or the intended helper still does not exist.

## Task 3 — Implement The Minimal Icon Mapping And Existing Path Support

- [ ] Edit `src/Sources/SettingsView.swift` minimally:
  - Replace the `.opencodeGo` row's `iconName: ""` with `iconName: "icon-opencode-go.png"`.
  - If Task 1 used a helper for TDD, add a small internal helper in `SettingsView.swift`, such as `enum ProviderIconNames`, with mappings for `claude`, `codex`, `zai`, `minimax`, `kimi`, and `opencodeGo`; then update existing `ServiceRow` calls to use that helper without changing provider order, titles, help text, toggle behavior, auth callbacks, or template flags.
  - Preserve `.opencodeGo` `isTemplateIcon: false` unless visual verification proves the PNG must be treated as a template; changing template behavior requires a spec/risk check.

- [ ] Edit `src/Sources/IconCatalog.swift` only if the test needs a controllable resource path. The allowed minimal change is adding an internal initializer or resource-path override while keeping `IconCatalog.shared` and default runtime behavior based on `Bundle.main.resourcePath`. Do not add SVG/data URI logic.

- [ ] Run focused GREEN:

  ```bash
  cd src && swift test --filter ProviderIconTests
  ```

  Expected GREEN result: `ProviderIconTests` build and pass; failures indicate either the mapping is still empty, the PNG is missing/invalid, or the testability seam changed runtime behavior.

- [ ] Run adjacent regression tests:

  ```bash
  cd src && swift test --filter OpenCodeGoProviderTests
  ```

  Expected result: OpenCode Go provider behavior tests pass; no auth/config behavior changes.

- [ ] Refactor only while tests stay green. If helper extraction caused churn beyond icon mapping, use the `simplify` skill discipline during execute: lock behavior with passing tests, inventory only the cleanup target, remove one smell at a time, and verify after each pass.

## Task 4 — Run Full Pre-Release Verification Before Release Metadata

- [ ] Run the repository baseline verification from the approved handoff:

  ```bash
  make backend-version && scripts/test-snapshot-generator.sh && make test && make build
  ```

  Expected result: backend version prints successfully; snapshot generator tests pass; Swift tests pass with the prior skipped metadata test still skipped; debug build completes.

- [ ] Inspect the implementation diff before release packaging:

  ```bash
  git status --short && git diff -- src/Sources/SettingsView.swift src/Sources/IconCatalog.swift src/Tests/CCProxyTests/ProviderIconTests.swift appcast.xml docs/easycode/2026-06-06-opencode-go-logo-v0-3-2-release/plan.md && git diff --stat
  ```

  Expected result: changes are limited to the approved files and `src/Sources/Resources/icon-opencode-go.png`; `appcast.xml` is not changed yet at this point. If unrelated files appear, stop and clean or route back.

- [ ] Commit the icon/resource/test implementation before release archive work:

  ```bash
  git add src/Sources/SettingsView.swift src/Sources/IconCatalog.swift src/Sources/Resources/icon-opencode-go.png src/Tests/CCProxyTests/ProviderIconTests.swift docs/easycode/2026-06-06-opencode-go-logo-v0-3-2-release/plan.md && git status --short && git commit -m "Add OpenCode Go provider icon"
  ```

  Expected result: only intended files are staged; commit succeeds. If `src/Sources/IconCatalog.swift` was not modified, omit it from `git add`. Do not stage root `.gitignore`, generated app bundles, generated zips, Sparkle keys, or external artifacts.

## Task 5 — Build And Verify The v0.3.2 arm64 Archive

- [ ] Do not record the final archive/release source SHA yet. The final `ARCHIVE_SOURCE_SHA` must be recorded only after all archive regeneration, Sparkle signing, `appcast.xml` updates, and any required appcast recommit cycles are complete.

- [ ] Build the arm64 archive:

  ```bash
  APP_VERSION=0.3.2 APP_BUILD_NUMBER=15 TARGET_ARCH=arm64 make sparkle-archive
  ```

  Expected result: release build completes; app bundle is signed or ad-hoc signed per available local identity; `CCProxy.app.zip` is created in the worktree root.

- [ ] Verify version, build, architecture, code signature, and bundled resource:

  ```bash
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' CCProxy.app/Contents/Info.plist && /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' CCProxy.app/Contents/Info.plist && file CCProxy.app/Contents/MacOS/CCProxy && codesign --verify --deep --strict --verbose=2 CCProxy.app && test -s CCProxy.app/Contents/Resources/icon-opencode-go.png
  ```

  Expected output: `0.3.2`, `15`, `arm64` in the binary description, codesign verification success, and no output from `test -s`.

- [ ] Validate Sparkle public key without printing private material:

  ```bash
  DERIVED_PUBLIC_KEY="$(swift - <<'SWIFT'
  import Foundation
  import CryptoKit
  let path = "/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key"
  let text = try String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
  guard let seed = Data(base64Encoded: text) else { fatalError("private key file is not base64") }
  let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
  print(key.publicKey.rawRepresentation.base64EncodedString())
  SWIFT
  )" && SOURCE_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' src/Info.plist)" && BUILT_PUBLIC_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' CCProxy.app/Contents/Info.plist)" && test "$DERIVED_PUBLIC_KEY" = "$SOURCE_PUBLIC_KEY" && test "$DERIVED_PUBLIC_KEY" = "$BUILT_PUBLIC_KEY" && printf 'Sparkle public key matches source and built app plists\n'
  ```

  Expected output: `Sparkle public key matches source and built app plists`. The command must not print the private key or decoded private bytes. If CryptoKit cannot derive the key from the file format, stop for release-signing investigation; do not use `cat` or print the key.

- [ ] Stage the external release asset outside git:

  ```bash
  mkdir -p "/Volumes/storage/artifact/ccproxy/releases/v0.3.2" && cp -f "CCProxy.app.zip" "/Volumes/storage/artifact/ccproxy/releases/v0.3.2/CCProxy.app.zip" && stat -f%z "CCProxy.app.zip" && stat -f%z "/Volumes/storage/artifact/ccproxy/releases/v0.3.2/CCProxy.app.zip"
  ```

  Expected result: both byte counts match and are greater than zero. The staged archive remains outside the repository.

## Task 6 — Sign The Archive And Update appcast.xml

- [ ] Derive and verify the exact installed Sparkle `sign_update` syntax before appcast signing, without printing private material:

  ```bash
  SIGN_UPDATE="src/.build/artifacts/sparkle/Sparkle/bin/sign_update" && test -x "$SIGN_UPDATE" && HELP="$($SIGN_UPDATE --help 2>&1 || true)" && printf '%s\n' "$HELP" && printf '%s\n' "$HELP" | grep -- '--ed-key-file' && printf '%s\n' "$HELP" | grep -- '--verify-ed-signature'
  ```

  Expected output: help/usage text from the installed Sparkle CLI showing both `--ed-key-file` and `--verify-ed-signature`. If either supported option is absent or the CLI usage indicates a different required syntax, stop for release-signing investigation and do not sign or edit `appcast.xml`.

- [ ] Sign the exact staged archive using the supported Sparkle `sign_update --ed-key-file /Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key` syntax, parse the real `sparkle:edSignature` and `length` attributes, verify the signature with the supported CLI syntax, and update `appcast.xml` from the parsed values:

  ```bash
  SIGN_UPDATE="src/.build/artifacts/sparkle/Sparkle/bin/sign_update" ARCHIVE="/Volumes/storage/artifact/ccproxy/releases/v0.3.2/CCProxy.app.zip" KEY="/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key" python3 - <<'PY'
  import os, re, subprocess
  from pathlib import Path
  sign_update = os.environ['SIGN_UPDATE']
  archive = os.environ['ARCHIVE']
  key = os.environ['KEY']
  out = subprocess.check_output([sign_update, '--ed-key-file', key, archive], text=True, stderr=subprocess.STDOUT)
  sig_match = re.search(r'sparkle:edSignature="([^"]+)"', out)
  len_match = re.search(r'\blength="([0-9]+)"', out)
  if not sig_match or not len_match:
      raise SystemExit(f'sign_update output missing sparkle:edSignature or length attributes: {out!r}')
  signature = sig_match.group(1)
  length = len_match.group(1)
  actual_length = str(os.stat(archive).st_size)
  if length != actual_length:
      raise SystemExit(f'sign_update length {length} does not match archive length {actual_length}')
  if not signature or any(c.isspace() for c in signature):
      raise SystemExit('invalid sparkle:edSignature value')
  subprocess.check_call([sign_update, '--verify-ed-signature', signature, archive])
  Path('appcast.xml').write_text(f'''<?xml version="1.0" encoding="utf-8"?>\n<rss version="2.0"\n     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"\n     xmlns:dc="http://purl.org/dc/elements/1.1/">\n  <channel>\n    <title>CCProxy Changelog</title>\n    <item>\n      <title>Version 0.3.2</title>\n      <sparkle:shortVersionString>0.3.2</sparkle:shortVersionString>\n      <sparkle:version>15</sparkle:version>\n      <enclosure\n        url="https://github.com/DevNewbie1826/ccproxy/releases/download/v0.3.2/CCProxy.app.zip"\n        sparkle:edSignature="{signature}"\n        length="{length}"\n        type="application/octet-stream" />\n    </item>\n  </channel>\n</rss>\n''', encoding='utf-8')
  print(f'sign_update parsed and verified sparkle:edSignature length={len(signature)} archive_length={length}; appcast.xml updated')
  PY
  ```

  Expected output: `sign_update parsed and verified sparkle:edSignature length=<non-zero> archive_length=<positive bytes>; appcast.xml updated`. The command passes the private key only as `--ed-key-file /Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key`; it must not print the private key or decoded private bytes. If parsing or `--verify-ed-signature` fails, stop for release-signing investigation. The resulting `appcast.xml` must contain `0.3.2`, build `15`, the v0.3.2 GitHub release URL, the exact parsed `sparkle:edSignature`, and exact parsed archive length.

- [ ] Verify `appcast.xml` against the staged archive:

  ```bash
  python3 - <<'PY'
  import re
  from pathlib import Path
  appcast = Path('appcast.xml').read_text(encoding='utf-8')
  expected_url = 'https://github.com/DevNewbie1826/ccproxy/releases/download/v0.3.2/CCProxy.app.zip'
  length = str(Path('/Volumes/storage/artifact/ccproxy/releases/v0.3.2/CCProxy.app.zip').stat().st_size)
  assert '<sparkle:shortVersionString>0.3.2</sparkle:shortVersionString>' in appcast
  assert '<sparkle:version>15</sparkle:version>' in appcast
  assert expected_url in appcast
  assert f'length="{length}"' in appcast
  sig = re.search(r'sparkle:edSignature="([^"]+)"', appcast)
  assert sig and sig.group(1)
  print(f'appcast verified length={length} signature_length={len(sig.group(1))}')
  PY
  src/.build/artifacts/sparkle/Sparkle/bin/sign_update --verify-ed-signature "$(python3 - <<'PY'
  import re
  print(re.search(r'sparkle:edSignature="([^"]+)"', open('appcast.xml', encoding='utf-8').read()).group(1))
  PY
  )" "/Volumes/storage/artifact/ccproxy/releases/v0.3.2/CCProxy.app.zip"
  ```

  Expected result: Python prints verified length and signature length; `sign_update --verify-ed-signature` succeeds using the supported CLI syntax discovered earlier.

- [ ] Run full verification again after appcast update:

  ```bash
  make backend-version && scripts/test-snapshot-generator.sh && make test && make build
  ```

  Expected result: all checks pass as in the baseline, with the new icon regression test included.

- [ ] Commit release metadata:

  ```bash
  git add appcast.xml && git status --short && git commit -m "Prepare v0.3.2 appcast"
  ```

  Expected result: only `appcast.xml` is staged for this commit; commit succeeds.

## Task 7 — Execute-Stage Final Checks And Review Gate Handoff

- [ ] Confirm no generated app/archive artifacts or secret files are tracked:

  ```bash
  git status --short && test "$(git ls-files -- CCProxy.app CCProxy.app.zip)" = "" && test -f "/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key" && test -f "/Volumes/storage/artifact/ccproxy/releases/v0.3.2/CCProxy.app.zip" && test ! -e "src/Sources/Resources/sparkle_ed25519_private_key" && printf 'no generated repo artifacts tracked; external key/archive exist only at approved external paths\n'
  ```

  Expected result: `git status --short` is clean after commits and the command prints `no generated repo artifacts tracked; external key/archive exist only at approved external paths`. The `git ls-files` check uses only repo-relative paths; external key/archive validation uses filesystem checks only.

- [ ] Run final execute verification:

  ```bash
  make backend-version && scripts/test-snapshot-generator.sh && make test && make build && APP_VERSION=0.3.2 APP_BUILD_NUMBER=15 TARGET_ARCH=arm64 make sparkle-archive
  ```

  Expected result: tests/build pass; archive is regenerated successfully for final evidence. Re-run the Task 5 and Task 6 archive/appcast validation commands after regeneration; if archive bytes changed, update the staged archive, re-run the `sign_update` parse/verify command, update and recommit `appcast.xml`, and repeat until archive bytes, appcast signature, and appcast length are stable.

- [ ] After all appcast signing/recommit cycles are complete, record the archive/release source SHA for review and finish:

  ```bash
  ARCHIVE_SOURCE_SHA="$(git rev-parse HEAD)" && printf 'ARCHIVE_SOURCE_SHA=%s\n' "$ARCHIVE_SOURCE_SHA"
  ```

  Expected output: `ARCHIVE_SOURCE_SHA=<current HEAD SHA>` after the final `Prepare v0.3.2 appcast` commit or later stable appcast recommit. Preserve this value in execute evidence. Do not record or use an earlier SHA from before appcast signing/recommit cycles.

- [ ] Capture diff and commit list for code review gates:

  ```bash
  git status --short && git log --oneline --decorate -5 && git diff --stat a8a28f49cd0830572df8630f1556a72874269f01..HEAD && git diff --name-only a8a28f49cd0830572df8630f1556a72874269f01..HEAD
  ```

  Expected result: committed diff includes only approved files: `SettingsView.swift`, optional `IconCatalog.swift`, `icon-opencode-go.png`, `ProviderIconTests.swift`, `appcast.xml`, and this plan.

- [ ] Submit to `code-spec-reviewer` and `code-quality-reviewer` per execute-stage rules. Expected result: both PASS. If either fails, return to the executor with reviewer findings; do not proceed to final-review or finish.

- [ ] Submit to `completion-verifier` with fresh local evidence. Expected result: PASS confirming the implementation and release preparation are supported by local verification.

## Final-Review Stage Requirements

- [ ] After execute completes and reviewer gates pass, final-review may create only `docs/easycode/2026-06-06-opencode-go-logo-v0-3-2-release/final-review.md` as its stage artifact.

- [ ] Final-review must verify:
  - OpenCode Go row now uses `icon-opencode-go.png`.
  - PNG exists, is non-empty, is valid PNG, and loads through the existing file-path icon mechanism.
  - No provider/auth/catalog behavior changed outside approved icon mapping/testability seams.
  - `appcast.xml` version/build/signature/length match the exact staged archive.
  - Sparkle public key in source and built app matches the approved private key's derived public key without printing private material.
  - Full verification passed freshly.

## Finish Plan After Final-Review PASS

- [ ] Before pushing, confirm the branch is clean and includes final-review if final-review created a commit:

  ```bash
  git status --short && git log --oneline --decorate -10 && FINAL_REVIEWED_HEAD_SHA="$(git rev-parse HEAD)" && ARCHIVE_SOURCE_SHA="$(git log --format=%H --grep='Prepare v0.3.2 appcast' -n 1 "$FINAL_REVIEWED_HEAD_SHA")" && test -n "$ARCHIVE_SOURCE_SHA" && printf 'ARCHIVE_SOURCE_SHA=%s\nFINAL_REVIEWED_HEAD_SHA=%s\n' "$ARCHIVE_SOURCE_SHA" "$FINAL_REVIEWED_HEAD_SHA" && git diff --name-only "$ARCHIVE_SOURCE_SHA" "$FINAL_REVIEWED_HEAD_SHA"
  ```

  Expected result: clean worktree. The command explicitly defines `ARCHIVE_SOURCE_SHA` as the latest `Prepare v0.3.2 appcast` commit reachable from the reviewed feature head and `FINAL_REVIEWED_HEAD_SHA` as the current feature head. The diff from `ARCHIVE_SOURCE_SHA` to `FINAL_REVIEWED_HEAD_SHA` is empty, or contains only `docs/easycode/2026-06-06-opencode-go-logo-v0-3-2-release/final-review.md`. If final-review created `final-review.md`, it is committed separately and is the only allowed non-archive-source diff after the archive source commit.

- [ ] Push the feature branch:

  ```bash
  git push -u origin work/2026-06-06-opencode-go-logo-v0-3-2-release
  ```

  Expected result: branch pushed to origin.

- [ ] Create the PR:

  ```bash
  gh pr create --repo DevNewbie1826/ccproxy --base main --head work/2026-06-06-opencode-go-logo-v0-3-2-release --title "Add OpenCode Go logo and prepare v0.3.2" --body "Adds the OpenCode Go PNG provider icon, regression coverage, and v0.3.2 build 15 Sparkle appcast metadata."
  ```

  Expected result: GitHub returns the PR URL.

- [ ] Merge the PR after required checks/reviews are satisfied:

  ```bash
  gh pr merge --repo DevNewbie1826/ccproxy --merge --delete-branch
  ```

  Expected result: PR merged and remote feature branch deleted by GitHub. If repository policy requires squash or rebase instead of merge, stop for finish-choice routing before changing merge method.

- [ ] Update local `main` from the root checkout, protecting the known dirty root `.gitignore`:

  ```bash
  cd /Volumes/storage/workspace/ccproxy && STATUS="$(git status --porcelain=v1 --untracked-files=normal)" && if [ -n "$STATUS" ] && [ "$STATUS" != " M .gitignore" ]; then printf '%s\n' "$STATUS"; exit 65; fi && git diff --cached --quiet && git diff --diff-filter=U --quiet && printf 'root checkout status guard passed; only known dirty .gitignore is allowed\n' && git switch main && git pull --ff-only origin main
  ```

  Expected result: the root checkout guard prints `root checkout status guard passed; only known dirty .gitignore is allowed`, then local `main` fast-forwards to the merged PR. Before `git switch main`/`git pull`, the root checkout may be clean or may show only unstaged ` M .gitignore`; any other dirty file, staged file, untracked file, or conflict exits non-zero and must stop finish. Do not stage, reset, or edit root `.gitignore`.

- [ ] Resolve the merged release SHA and compare it to the archive source SHA:

  ```bash
  cd /Volumes/storage/workspace/ccproxy && MERGED_RELEASE_SHA="$(git rev-parse HEAD)" && if git rev-parse -q --verify HEAD^2 >/dev/null; then FINAL_REVIEWED_HEAD_SHA="$(git rev-parse HEAD^2)"; else FINAL_REVIEWED_HEAD_SHA="$MERGED_RELEASE_SHA"; fi && ARCHIVE_SOURCE_SHA="$(git log --format=%H --grep='Prepare v0.3.2 appcast' -n 1 "$FINAL_REVIEWED_HEAD_SHA")" && test -n "$ARCHIVE_SOURCE_SHA" && printf 'ARCHIVE_SOURCE_SHA=%s\nFINAL_REVIEWED_HEAD_SHA=%s\nMERGED_RELEASE_SHA=%s\n' "$ARCHIVE_SOURCE_SHA" "$FINAL_REVIEWED_HEAD_SHA" "$MERGED_RELEASE_SHA" && git diff --name-only "$ARCHIVE_SOURCE_SHA" "$MERGED_RELEASE_SHA"
  ```

  Expected result: the command explicitly recomputes `ARCHIVE_SOURCE_SHA`, `FINAL_REVIEWED_HEAD_SHA`, and `MERGED_RELEASE_SHA`; the merged SHA is the release commit/tag target. The diff from `ARCHIVE_SOURCE_SHA` to `MERGED_RELEASE_SHA` is empty, or contains only `docs/easycode/2026-06-06-opencode-go-logo-v0-3-2-release/final-review.md`. If code, resources, or `appcast.xml` differ, stop and rebuild/restage/resign before publishing.

- [ ] Create and push tag `v0.3.2` at the merged release SHA:

  ```bash
  cd /Volumes/storage/workspace/ccproxy && MERGED_RELEASE_SHA="$(git rev-parse HEAD)" && if git rev-parse -q --verify HEAD^2 >/dev/null; then FINAL_REVIEWED_HEAD_SHA="$(git rev-parse HEAD^2)"; else FINAL_REVIEWED_HEAD_SHA="$MERGED_RELEASE_SHA"; fi && ARCHIVE_SOURCE_SHA="$(git log --format=%H --grep='Prepare v0.3.2 appcast' -n 1 "$FINAL_REVIEWED_HEAD_SHA")" && test -n "$ARCHIVE_SOURCE_SHA" && DIFF_NAMES="$(git diff --name-only "$ARCHIVE_SOURCE_SHA" "$MERGED_RELEASE_SHA")" && if [ -n "$DIFF_NAMES" ] && [ "$DIFF_NAMES" != "docs/easycode/2026-06-06-opencode-go-logo-v0-3-2-release/final-review.md" ]; then printf '%s\n' "$DIFF_NAMES"; exit 66; fi && git tag -a v0.3.2 -m "Release v0.3.2" "$MERGED_RELEASE_SHA" && git push origin v0.3.2
  ```

  Expected result: the same shell invocation recomputes `MERGED_RELEASE_SHA`, `FINAL_REVIEWED_HEAD_SHA`, and `ARCHIVE_SOURCE_SHA`, confirms the merged release commit differs from the archive source only by an optional final-review artifact, then creates and pushes the annotated tag. If the tag exists or the diff guard reports code/resource/appcast changes after the archive source commit, stop for release routing.

- [ ] Publish the GitHub Release with the staged external archive:

  ```bash
  cd /Volumes/storage/workspace/ccproxy && MERGED_RELEASE_SHA="$(git rev-parse HEAD)" && if git rev-parse -q --verify HEAD^2 >/dev/null; then FINAL_REVIEWED_HEAD_SHA="$(git rev-parse HEAD^2)"; else FINAL_REVIEWED_HEAD_SHA="$MERGED_RELEASE_SHA"; fi && ARCHIVE_SOURCE_SHA="$(git log --format=%H --grep='Prepare v0.3.2 appcast' -n 1 "$FINAL_REVIEWED_HEAD_SHA")" && test -n "$ARCHIVE_SOURCE_SHA" && DIFF_NAMES="$(git diff --name-only "$ARCHIVE_SOURCE_SHA" "$MERGED_RELEASE_SHA")" && if [ -n "$DIFF_NAMES" ] && [ "$DIFF_NAMES" != "docs/easycode/2026-06-06-opencode-go-logo-v0-3-2-release/final-review.md" ]; then printf '%s\n' "$DIFF_NAMES"; exit 66; fi && gh release create v0.3.2 "/Volumes/storage/artifact/ccproxy/releases/v0.3.2/CCProxy.app.zip" --repo DevNewbie1826/ccproxy --target "$MERGED_RELEASE_SHA" --title "CCProxy v0.3.2" --notes "Adds the OpenCode Go provider logo and publishes the v0.3.2 build 15 arm64 Sparkle update."
  ```

  Expected result: the same shell invocation recomputes `MERGED_RELEASE_SHA`, `FINAL_REVIEWED_HEAD_SHA`, and `ARCHIVE_SOURCE_SHA`, confirms the merged release commit differs from the archive source only by an optional final-review artifact, then creates GitHub Release `v0.3.2` with `CCProxy.app.zip` asset targeting the recomputed merged release SHA. Do not rely on `MERGED_RELEASE_SHA` from a prior Bash tool call.

- [ ] Verify release, local main/tag state, remote peeled tag target, and asset size before cleanup:

  ```bash
  cd /Volumes/storage/workspace/ccproxy && MERGED_RELEASE_SHA="$(git rev-parse HEAD)" && LOCAL_MAIN_SHA="$(git rev-parse main)" && test "$LOCAL_MAIN_SHA" = "$MERGED_RELEASE_SHA" && LOCAL_TAG_TARGET="$(git rev-parse v0.3.2^{})" && test "$LOCAL_TAG_TARGET" = "$MERGED_RELEASE_SHA" && REMOTE_PEELED_TAG_TARGET="$(git ls-remote --tags origin 'refs/tags/v0.3.2^{}' | cut -f1)" && test -n "$REMOTE_PEELED_TAG_TARGET" && test "$REMOTE_PEELED_TAG_TARGET" = "$MERGED_RELEASE_SHA" && gh release view v0.3.2 --repo DevNewbie1826/ccproxy && REMOTE_SIZE="$(gh release view v0.3.2 --repo DevNewbie1826/ccproxy --json assets --jq '.assets[] | select(.name=="CCProxy.app.zip") | .size')" && LOCAL_SIZE="$(stat -f%z "/Volumes/storage/artifact/ccproxy/releases/v0.3.2/CCProxy.app.zip")" && test "$REMOTE_SIZE" = "$LOCAL_SIZE" && printf 'release verified: main=%s local_tag=%s remote_peeled_tag=%s asset_size=%s bytes\n' "$MERGED_RELEASE_SHA" "$LOCAL_TAG_TARGET" "$REMOTE_PEELED_TAG_TARGET" "$LOCAL_SIZE"
  ```

  Expected result: the same shell invocation recomputes `MERGED_RELEASE_SHA` from local `main`, confirms local `main` is at that SHA, confirms the local annotated tag target `v0.3.2^{}` equals that SHA, confirms the mandatory remote peeled tag target `refs/tags/v0.3.2^{}` equals that SHA, confirms GitHub Release `v0.3.2` exists, and confirms the remote asset size equals the local staged archive size. If the remote peeled tag target is missing or differs from `MERGED_RELEASE_SHA`, stop before cleanup.

- [ ] Clean up only EasyCode-owned worktree and local feature branch after release verification:

  ```bash
  cd /Volumes/storage/workspace/ccproxy && git worktree remove "/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-opencode-go-logo-v0-3-2-release" && git branch -d work/2026-06-06-opencode-go-logo-v0-3-2-release
  ```

  Expected result: EasyCode worktree is removed and local feature branch is deleted. Do not delete unrelated branches or touch root `.gitignore`.

## Stop Conditions

- Stop if the executor is not in `/Volumes/storage/workspace/ccproxy/.worktrees/2026-06-06-opencode-go-logo-v0-3-2-release` on branch `work/2026-06-06-opencode-go-logo-v0-3-2-release`.
- Stop if the approved spec or evidence paths are missing or differ from the scope in this plan.
- Stop if `.gitignore` appears in the worktree or root checkout staging area; it is explicitly out of scope.
- Stop if `v0.3.2` tag or release already exists before finish.
- Stop if no supported local SVG renderer is available, if PNG conversion fails validation, or if the decoded SVG does not exactly match the approved literal.
- Stop if implementing the icon requires runtime SVG data URI rendering, provider metadata redesign, auth/catalog changes, or x86_64 release work.
- Stop if any RED test unexpectedly passes before implementation, or any GREEN/full verification command fails after implementation.
- Stop if archive regeneration changes `CCProxy.app.zip` after `appcast.xml` was signed and committed; update the staged archive, regenerate signature/length, recommit `appcast.xml`, and reverify before review.
- Stop if Sparkle public key validation cannot be performed without exposing private key material.
- Stop if the archive source commit and merged release SHA differ by anything other than the final-review artifact.
- Stop if git status contains unrelated files, generated `.app`/`.zip`, external release artifacts, Sparkle keys, or source changes not named in this plan.
