# App Release v0.2.0 Evidence

## Internal Evidence

- `appcast.xml:8-16` currently publishes `Version 0.1.10`, `sparkle:shortVersionString` `0.1.10`, Sparkle build `11`, and asset URL `https://github.com/DevNewbie1826/ccproxy/releases/download/v0.1.10/CCProxy.app.zip`.
- `src/Info.plist:17-22` contains baseline template values `CFBundleShortVersionString=0.1.0` and `CFBundleVersion=1`, which are overwritten by the release script.
- `create-app-bundle.sh:99-106` reads `APP_VERSION` and `APP_BUILD_NUMBER` and writes those values into the app bundle `Info.plist`.
- `Makefile:14-23` defines release packaging targets, including `make release` and `make sparkle-archive`, which creates `CCProxy.app.zip`.
- `Makefile:46-49` defines `make test` as `cd src && swift test`.
- `Makefile:81-89` defines `make backend-version` for probing the bundled CLIProxyAPI binary.
- `scripts/update-cli-proxy-api.sh` is the repository-provided script for resolving, downloading, checksum-verifying, extracting, replacing, and validating the bundled CLIProxyAPI binary.
- `scripts/generate-sparkle-appcast.sh` documents the appcast fields and Sparkle signing inputs: `APP_VERSION`, `APP_BUILD_NUMBER`, `RELEASE_URL`, archive path, and signing output.
- `src/Info.plist:31-40` contains Sparkle update configuration, including `SUFeedURL` and `SUPublicEDKey`.
- `docs/easycode/2026-06-03-app-release-v0-1-10/spec.md` and `plan.md` document the most recent release workflow for `v0.1.10 / build 11`, including build, signing, appcast update, PR/merge, local main update, worktree cleanup, and GitHub Release creation.
- `docs/easycode/2026-06-03-app-release-v0-1-10/evidence.md` records that prior release version and build were user-selected.
- `docs/easycode/2026-06-04-remove-oauth-providers-cleanup/final-review.md` records PASS for provider-removal work.
- Git command evidence from root checkout:
  - `git log --oneline --decorate -10` shows `73606e9` on `main` and `origin/main`, merging PR #11 provider-removal work.
  - `git status --short --branch` shows root `main...origin/main` plus an unrelated dirty `.gitignore` change.
  - `git ls-remote --tags origin` shows remote tags through `refs/tags/v0.1.10`; no `v0.2.0` tag was listed.
  - `gh release list --limit 10` shows latest GitHub release `CCProxy v0.1.10` on tag `v0.1.10`.

## External Evidence

No additional external documentation is required for the spec. The release process, Sparkle appcast fields, signing flow, and backend update flow are repository-owned and documented in scripts and prior EasyCode release artifacts.

## Checked Scope

- Checked release process files: `appcast.xml`, `src/Info.plist`, `Makefile`, `create-app-bundle.sh`, `scripts/generate-sparkle-appcast.sh`, `scripts/update-cli-proxy-api.sh`, `src/Package.swift`, `.gitignore`, and `README.md` release/update references.
- Checked prior release workflow artifacts under `docs/easycode/2026-06-03-app-release-v0-1-10/`.
- Checked prior backend update/release artifacts under `docs/easycode/2026-06-03-cliproxyapi-update-worktree/` and `docs/easycode/2026-06-03-cliproxyapi-auto-update-script/`.
- Checked current provider-removal workflow artifacts under `docs/easycode/2026-06-04-remove-oauth-providers-cleanup/`.
- Checked root git state, recent commits, local tags, remote tags, and recent GitHub releases with read-only commands.

## Unchecked Scope

- Sparkle private key availability was not checked during spec because it must remain outside repository artifacts and should be verified during execute.
- Actual backend latest-version check was not run during spec; it should be done in execute using the repository update script so changes can occur only inside the approved worktree.
- Release archive generation and signing were not run during spec.
- GitHub Release `v0.2.0` publication was not attempted during spec.

## Unresolved Uncertainty

- Whether a newer CLIProxyAPI release exists and passes repository verification at execute time.
- Whether `SPARKLE_ED_KEY_FILE` is available and readable in the execute environment.
- Whether local codesigning uses Developer ID or script fallback behavior; the existing release script controls this.
