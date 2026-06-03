# CLIProxyAPI Update Deployment Evidence

## Internal Evidence

- User request: “무인모드로 pr 생성, 병합. 워크트리 브랜치 정리. 로컬코드 최신화. 릴리즈 배포까지 진행해줘.”
- User decision: release version `v0.1.9` and build number `10`.
- User confirmation: the dirty `src/Sources/Resources/cli-proxy-api` change in the worktree was uploaded intentionally.
- Worktree status check in `.worktrees/2026-06-03-cliproxyapi-update-worktree`: branch `work/2026-06-03-cliproxyapi-update-worktree` with `M src/Sources/Resources/cli-proxy-api`.
- Root checkout status check: `main...origin/main [ahead 1]` with an unrelated dirty `.gitignore` change.
- Explorer reported repository release commands from `Makefile`: `make release` runs `create-app-bundle.sh`, `make sparkle-archive` creates `CCProxy.app.zip`, `make test` runs Swift tests, and `make backend-version` checks `src/Sources/Resources/cli-proxy-api --version`.
- Explorer reported `scripts/generate-sparkle-appcast.sh` requires `APP_VERSION`, `APP_BUILD_NUMBER`, and `RELEASE_URL` and uses Sparkle `sign_update` to produce a Sparkle signature.
- Explorer reported `appcast.xml` currently represents release `v0.1.8` build `9`.
- Explorer reported `create-app-bundle.sh` injects `APP_VERSION` and `APP_BUILD_NUMBER` into the app bundle and signs bundled binaries depending on signing configuration.
- Explorer reported `.worktrees/` is ignored, so worktree contents are only included through committed feature-branch changes.

## External Evidence

- Librarian reported official GitHub CLI documentation supports non-interactive `gh pr create` with `--title`, `--body`, `--base`, and `--head` flags: https://cli.github.com/manual/gh_pr_create
- Librarian reported official GitHub CLI documentation supports `gh pr merge <ref>` with merge strategy flags and branch cleanup flags, but EasyCode cleanup ordering forbids relying on `--delete-branch` while the worktree still checks out the branch: https://cli.github.com/manual/gh_pr_merge
- Librarian reported official GitHub CLI documentation supports creating GitHub releases and uploading assets with `gh release create` and `gh release upload`: https://cli.github.com/manual/gh_release_create and https://cli.github.com/manual/gh_release_upload
- Librarian reported official Sparkle publishing documentation supports signing update archives with `sign_update` and that CI/unattended signing should avoid deprecated insecure `-s` key passing, preferring stdin or keychain-based key access where needed: https://github.com/sparkle-project/sparkle-project.github.io/blob/master/documentation/publishing/index.md

## Checked Scope

- User's current deployment request and release version decision.
- Existing EasyCode worktree branch and dirty uploaded binary status.
- Root checkout status relevant to local update and cleanup safety.
- Repository release-related files summarized by explorer: `Makefile`, `create-app-bundle.sh`, `scripts/generate-sparkle-appcast.sh`, `appcast.xml`, `src/Info.plist`, `.gitignore`, and current worktree git metadata.
- Official external documentation for GitHub CLI PR/release commands and Sparkle update signing, summarized by librarian.

## Unchecked Scope

- Actual uploaded CLIProxyAPI binary version output.
- Whether `gh` is installed, authenticated, and authorized for this repository.
- Whether `sign_update` exists in the expected Sparkle build artifact path after the selected build command.
- Whether a Sparkle signing key or keychain entry is available for unattended appcast signature generation.
- Whether tag/release `v0.1.9` already exists remotely.
- Whether remote branch or PR conflicts already exist.
- Whether release validation will require codesigning identities beyond ad-hoc signing.

## Unresolved Uncertainty

- Release deployment may block if GitHub authentication, signing credentials, tag/release uniqueness, merge checks, or root checkout cleanliness are not sufficient.
- The root checkout has an unrelated dirty `.gitignore` change; cleanup/local update must not overwrite it and may require stopping if it blocks a safe update.
- The uploaded CLIProxyAPI binary's exact version string and compatibility are unknown until execution validation captures it.
