# CCProxy v0.1.10 App Release Evidence

## Internal Evidence

- User request: “이제 앱릴리즈 진행”.
- User selected release version `v0.1.10 / build 11`.
- User confirmed finish intent as PR creation, PR merge, worktree/branch cleanup, and local main update; app release scope excludes adding more updater automation.
- Explorer reported current `appcast.xml` is `0.1.9` / build `10`, so `v0.1.10` / build `11` is the next release target.
- Explorer reported `scripts/update-cli-proxy-api.sh` exists and implements latest-release resolution, checksum verification, executable validation, dry-run mode, update mode, and `make backend-version` validation.
- Explorer reported `Makefile` release-related targets: `make release`, `make sparkle-archive`, and `make backend-version`.
- Explorer reported `scripts/generate-sparkle-appcast.sh` requires `APP_VERSION`, `APP_BUILD_NUMBER`, and `RELEASE_URL`, uses Sparkle `sign_update`, and writes `appcast.xml`.
- Explorer reported `create-app-bundle.sh` injects `APP_VERSION` and `APP_BUILD_NUMBER` into Info.plist and sets Sparkle feed URLs.
- Explorer reported the current backend baseline from prior plan evidence as `CLIProxyAPI Version: 7.1.40, Commit: 02d0d92a, BuiltAt: 2026-06-02T11:31:42Z`.
- Explorer reported the root checkout has an unrelated dirty `.gitignore` change.

## External Evidence

- Librarian reported current latest `router-for-me/CLIProxyAPI` release is `v7.1.43`, published by `github-actions[bot]`, with tag `v7.1.43`.
- Librarian reported official GitHub CLI documentation supports `gh release create` and release asset upload behavior.
- Librarian reported official Sparkle publishing documentation supports `sign_update` EdDSA signing for update archives.
- Earlier external evidence for the updater script reported the `v7.1.43` macOS arm64 asset as `CLIProxyAPI_7.1.43_darwin_aarch64.tar.gz` with checksum support through `checksums.txt`.

## Checked Scope

- User's app release request and selected release version/build.
- Current repository release script and appcast workflow as summarized by explorer.
- Existing updater script availability and intended behavior as summarized by explorer.
- Current external latest CLIProxyAPI release and official GitHub/Sparkle release-publishing mechanics as summarized by librarian.

## Unchecked Scope

- Running the updater script in release worktree to confirm the exact updated backend version output.
- Whether Sparkle signing key access remains available in the release worktree execution environment.
- Whether GitHub release/tag `v0.1.10` already exists.
- Whether PR mergeability or branch conflicts will block finish.
- Whether unauthenticated GitHub API rate limits or network failures will affect execution.

## Unresolved Uncertainty

- Exact updated CLIProxyAPI version output must be captured during execute after running `scripts/update-cli-proxy-api.sh`.
- Release may block if signing key access, network access, tag/release uniqueness, or PR mergeability fails.
- The unrelated dirty root `.gitignore` change must remain untouched and may constrain safe local update operations.
