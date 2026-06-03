# CLIProxyAPI Auto Update Script Spec

## Goal

Add a reusable repository script that automatically resolves the latest public `router-for-me/CLIProxyAPI` release, downloads the macOS arm64 release archive, verifies its checksum, replaces the bundled `src/Sources/Resources/cli-proxy-api` binary, and validates the updated binary.

## Context

After publishing CCProxy `v0.1.9` with CLIProxyAPI `7.1.40`, the user noticed CLIProxyAPI `v7.1.43` was already available at `https://github.com/router-for-me/CLIProxyAPI/releases/tag/v7.1.43`. The user chose to add an automation script rather than perform another one-off binary update. The requested script should default to the latest CLIProxyAPI release instead of requiring a specific tag.

## Requirements

- Add a shell script under `scripts/` for updating the bundled CLIProxyAPI binary; the default intended path is `scripts/update-cli-proxy-api.sh` unless the approved plan finds a clearer existing naming convention.
- Follow existing repository shell-script conventions: Bash, strict error handling, script-relative repository root detection, clear status output, and no broad cleanup.
- Resolve the latest published public release from `router-for-me/CLIProxyAPI` without requiring GitHub authentication.
- Select the macOS arm64 archive asset matching the latest release, currently represented by the `darwin_aarch64` tarball naming pattern.
- Download both the selected archive and the same-release `checksums.txt` file.
- Verify the archive SHA-256 checksum against `checksums.txt` before extracting or replacing the bundled binary.
- Extract the downloaded archive into a temporary directory and identify the CLIProxyAPI executable unambiguously; stop if the archive shape is missing or ambiguous.
- Replace only `src/Sources/Resources/cli-proxy-api`, preserve executable permissions, and remove macOS quarantine metadata from the replacement if present.
- Validate the replacement by running `make backend-version` or an equivalent direct `--version` check and requiring output that contains `CLIProxyAPI Version`.
- Provide a safe dry-run or preview mode that resolves the latest release and verifies the downloadable asset/checksum without replacing the tracked binary.
- Avoid `make clean`, because it removes `src/Sources/Resources/cli-proxy-api`.
- Do not require or expose private Sparkle signing keys.
- Do not commit downloaded archives, extracted temporary contents, generated app bundles, or unrelated files.
- Stop and report a clear error if network access, latest release lookup, asset selection, checksum verification, archive extraction, binary execution, or validation fails.

## Non-Goals

- Performing a one-off update to CLIProxyAPI `v7.1.43` as part of this request.
- Publishing a new CCProxy release, updating `appcast.xml`, creating a GitHub release, or handling Sparkle signing.
- Creating a PR, merging, or cleaning branches unless requested later during finish.
- Supporting Windows or Linux CLIProxyAPI assets.
- Supporting Intel macOS assets unless the approved plan proves this can be added safely without expanding complexity.
- Refactoring Swift application code, tests, release scripts, EasyCode workflow artifacts, agents, plugins, or MCP configuration.
- Modifying the unrelated dirty root `.gitignore` change.

## User Decisions

- The user wants an automation script added to the repository.
- The user chose the script mode `latest 자동`, meaning it should resolve the latest CLIProxyAPI release by default instead of requiring a version argument.
- The user did not request immediate redeployment of CLIProxyAPI `v7.1.43` in this scope.

## Success Criteria

- The approved script exists under `scripts/` and is executable.
- The script can resolve the latest `router-for-me/CLIProxyAPI` release and identify the macOS arm64 archive asset and `checksums.txt`.
- Dry-run or preview mode completes without replacing `src/Sources/Resources/cli-proxy-api` and reports the selected latest tag/asset.
- Update mode downloads the archive, verifies SHA-256 checksum, extracts a single valid CLIProxyAPI executable, replaces `src/Sources/Resources/cli-proxy-api`, and validates the replacement with `make backend-version` or equivalent.
- Repository validation selected by the approved plan passes, including at least script dry-run verification and existing project baseline checks relevant to the script change.
- No unrelated tracked files are changed, and downloaded/generated artifacts are not committed.

## Risks And Open Questions

- The exact archive internal layout for `CLIProxyAPI_7.1.43_darwin_aarch64.tar.gz` has not yet been inspected; implementation must verify it before assuming a path.
- Future CLIProxyAPI releases might change asset naming or checksum format; the script must fail clearly rather than guessing.
- Unauthenticated GitHub API usage may be rate-limited in some environments.
- The root checkout currently has an unrelated dirty `.gitignore` change that must remain untouched.
- Network-dependent verification can fail due to connectivity or GitHub availability rather than script logic.

## Next Stage

worktree, after user approval and `spec-reviewer` PASS.
