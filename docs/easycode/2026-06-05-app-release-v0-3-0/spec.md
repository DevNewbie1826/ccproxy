# App Release v0.3.0 Spec

## Goal

Publish CCProxy app release `v0.3.0` with Sparkle build number `13`, shipping the already-merged OpenCode Go provider and external model catalog work from current `main`.

## Context

The current latest published app release is `v0.2.0` / Sparkle build `12`. Current `main` includes the merged OpenCode Go hosted provider and external model catalog subsystem, which was intentionally not published during that feature workflow. This release should package and publish that current `main` state as an arm64 app release.

## Requirements

- Release version must be `0.3.0` and GitHub/Sparkle tag must be `v0.3.0`.
- Sparkle build number must be `13`.
- Release architecture must be arm64-only, matching the prior release pattern.
- Before release publication, check whether a newer CLIProxyAPI backend is available using the repository release/update workflow.
  - If a newer backend resolves, validates, and passes repository verification, include the updated `src/Sources/Resources/cli-proxy-api` binary in the release commit.
  - If no newer backend is available or validation fails, keep the current backend and record the result.
- Build the app using repository release tooling, including Sparkle archive generation and appcast generation/signing.
- Use a Sparkle EdDSA private key only from a safe external path supplied through `SPARKLE_ED_KEY_FILE`; never commit or copy the key into the repository.
- Update `appcast.xml` for `v0.3.0` / build `13` with exactly the new release item, correct archive URL, length, and EdDSA signature.
- Stage the generated `CCProxy.app.zip` upload asset outside the repository before publication and verify it matches the worktree archive byte-for-byte.
- Commit only intended release files, expected to be:
  - `appcast.xml`
  - `src/Sources/Resources/cli-proxy-api` only if the backend update succeeds and changes the binary
  - EasyCode release workflow artifacts under `docs/easycode/2026-06-05-app-release-v0-3-0/` as allowed by workflow stages
- After final-review PASS, create and merge a PR, update local `main`, then create GitHub Release `v0.3.0` using the verified archive and the merged release commit SHA.
- After successful release verification, clean up only the EasyCode-owned release worktree and feature branch.

## Non-Goals

- Do not add or change app features beyond packaging the current `main` state.
- Do not publish x86_64 or universal artifacts unless a later approved spec revision explicitly adds them.
- Do not change release tooling unless required to complete this release safely.
- Do not change Sparkle public key configuration or key management.
- Do not commit generated app bundle/zip artifacts into the repository.
- Do not touch the pre-existing unrelated root `.gitignore` dirty change.

## User Decisions

- User requested: “앱 릴리즈 해”.
- User selected release version/build: `v0.3.0` / build `13`.
- User selected backend policy: check latest CLIProxyAPI and update if validation succeeds.
- User selected architecture: arm64-only.

## Success Criteria

- `v0.3.0` tag and GitHub Release are created at the merged release commit.
- GitHub Release includes the verified `CCProxy.app.zip` asset.
- `appcast.xml` on `main` points to the `v0.3.0` release asset and contains correct Sparkle metadata: short version `0.3.0`, build `13`, length, EdDSA signature, and URL.
- App bundle metadata verifies `CFBundleShortVersionString=0.3.0` and `CFBundleVersion=13`.
- Required verification passes before publication, including at minimum:
  - `make backend-version`
  - `scripts/update-cli-proxy-api.sh --dry-run`, then mutating backend update only if applicable
  - `make test`
  - `make build`
  - `APP_VERSION=0.3.0 APP_BUILD_NUMBER=13 make sparkle-archive`
  - appcast XML field validation
  - staged upload asset byte/SHA match
  - immediate pre-publication remote tag/release absence checks
  - post-publication tag/release/asset verification
- Workflow completes with final-review PASS and cleanup of EasyCode-owned worktree/feature branch after publication.

## Risks And Open Questions

- `SPARKLE_ED_KEY_FILE` must be set to a readable private key outside the repository during execute; if absent, release publication is blocked.
- A newer CLIProxyAPI release may not exist or may fail validation; in that case the release should continue with the current backend only if verification passes and the result is recorded.
- Live GitHub tag/release absence must be rechecked immediately before publication to avoid overwriting or duplicating a release.
- The pre-existing root `.gitignore` dirty change must remain untouched and unstaged.

## Next Stage

worktree after user approval and spec-reviewer PASS.
