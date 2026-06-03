# CLIProxyAPI Auto Update Script Evidence

## Internal Evidence

- User reported a new CLIProxyAPI release at `https://github.com/router-for-me/CLIProxyAPI/releases/tag/v7.1.43` and asked whether it can be automatically downloaded and updated.
- User selected `자동화 스크립트 추가` rather than a one-off update.
- User selected script input mode `latest 자동`.
- Explorer reported repository script conventions from `create-app-bundle.sh` and `scripts/generate-sparkle-appcast.sh`: Bash scripts, strict error handling, script-relative root detection, and status output patterns.
- Explorer reported the bundled backend binary path is `src/Sources/Resources/cli-proxy-api`.
- Explorer reported `make backend-version` validates the bundled binary by running `./src/Sources/Resources/cli-proxy-api --version` and checking for `CLIProxyAPI Version`.
- Explorer reported `make clean` removes `src/Sources/Resources/cli-proxy-api`, so the updater must not rely on `make clean`.
- Explorer reported `.gitignore` ignores generated artifacts such as `.build/`, `CCProxy.app/`, `.worktrees/`, and `.codegraph/`, but does not ignore the tracked backend binary.
- Explorer reported root checkout status includes an unrelated dirty `.gitignore` change.

## External Evidence

- Librarian reported `router-for-me/CLIProxyAPI` release `v7.1.43` includes macOS arm64 asset `CLIProxyAPI_7.1.43_darwin_aarch64.tar.gz` and `checksums.txt`.
- Librarian reported the v7.1.43 macOS arm64 asset download URL is `https://github.com/router-for-me/CLIProxyAPI/releases/download/v7.1.43/CLIProxyAPI_7.1.43_darwin_aarch64.tar.gz`.
- Librarian reported the v7.1.43 asset digest is `sha256:758f6e40de683bcc707c3263c512d99fc529ed1942f93700ef00b2bfdc722d95` and that `checksums.txt` is available in the same release.
- Librarian reported official GitHub REST API documentation supports `GET /repos/{owner}/{repo}/releases/latest`, returning a release object with `tag_name` and `assets` containing `name`, `browser_download_url`, `size`, and `digest`.
- Librarian reported official GitHub CLI documentation supports `gh release download` without a tag to download assets from the latest release when `--pattern` or `--archive` is provided, but REST API plus `curl` is suitable for public unauthenticated scripts.

## Checked Scope

- User choices in the current conversation.
- Repository script conventions, binary path, validation target, generated/ignored files, and root dirty-state concern.
- Public GitHub release metadata for `router-for-me/CLIProxyAPI` `v7.1.43`.
- Official GitHub release API and GitHub CLI release download behavior for latest release lookup and asset download.

## Unchecked Scope

- The internal file layout of `CLIProxyAPI_7.1.43_darwin_aarch64.tar.gz`.
- Whether future CLIProxyAPI releases always preserve the same asset naming and checksum format.
- Whether unauthenticated GitHub API rate limits will affect all user environments.
- Whether the updater should later be wired into a Makefile target or release workflow; this is not included in the current approved scope.

## Unresolved Uncertainty

- The implementation must inspect the downloaded archive during execution and fail clearly if the executable path cannot be determined safely.
- Network-dependent checks can fail for environmental reasons.
- The root `.gitignore` dirty change remains unrelated and must not be modified by this work.
