# CCProxy v0.1.10 App Release Spec

## Goal

Release CCProxy `v0.1.10` build `11` with the bundled CLIProxyAPI updated to the latest public `router-for-me/CLIProxyAPI` release, then publish the signed Sparkle appcast metadata and GitHub release asset.

## Context

CCProxy `v0.1.9` build `10` was published with CLIProxyAPI `7.1.40`. A reusable updater script now exists at `scripts/update-cli-proxy-api.sh`, and the user requested an app release. The user selected release version `v0.1.10` and build number `11`. Current external release evidence shows the latest CLIProxyAPI release is `v7.1.43`.

## Requirements

- Use work ID `2026-06-03-app-release-v0-1-10`.
- Start from the current repository `main` after the merged auto-update script work.
- Use `scripts/update-cli-proxy-api.sh` to update `src/Sources/Resources/cli-proxy-api` to the latest CLIProxyAPI release.
- Verify the updated backend with `make backend-version`, requiring output that contains `CLIProxyAPI Version` and recording the detected version.
- Build and test the app with the repository baseline commands selected by the approved plan, including at least `make test` and `make build`.
- Build release artifacts for app version `0.1.10` and build number `11` using the repository release flow.
- Produce `CCProxy.app.zip` for Sparkle/GitHub release upload.
- Generate `appcast.xml` for release URL `https://github.com/DevNewbie1826/ccproxy/releases/download/v0.1.10/CCProxy.app.zip`, app version `0.1.10`, and build number `11`.
- Sign the Sparkle update metadata with the existing Sparkle EdDSA private key mechanism used successfully for the prior release; do not commit, copy, or print private key contents.
- Commit only intended release changes, expected to include `src/Sources/Resources/cli-proxy-api`, `appcast.xml`, and approved EasyCode workflow artifacts.
- After execute and final-review PASS, create and merge a pull request, update local `main`, remove the EasyCode worktree, delete the local and remote feature branches, and publish GitHub release `v0.1.10` with `CCProxy.app.zip`.
- Run merge, local base update, worktree removal, and branch deletion commands from the main repository root.
- Do not use `gh pr merge --delete-branch` while the feature worktree still checks out the branch.
- Do not overwrite or clean the unrelated dirty root `.gitignore` change.
- Stop and report a blocker if latest CLIProxyAPI lookup/update, checksum validation, signing key access, release artifact generation, appcast generation, tests/builds, PR mergeability, tag/release uniqueness, or safe cleanup fails.

## Non-Goals

- Adding new updater-script functionality beyond using the existing approved script.
- Supporting additional CLIProxyAPI platforms or Intel macOS assets.
- Changing Swift application behavior beyond bundling the updated backend and release metadata.
- Refactoring Swift code, tests, build scripts, agents, skills, plugins, MCP configuration, or prompt/runtime hooks.
- Publishing any version other than CCProxy `v0.1.10` build `11`.
- Modifying the unrelated dirty root `.gitignore` change.

## User Decisions

- The user requested app release after the updater script was merged.
- The user selected app release version `v0.1.10` and build number `11`.
- The user confirmed the intended finish outcome is PR creation, PR merge, worktree/branch cleanup, and local main update.
- The user did not request adding more updater automation in this release scope.

## Success Criteria

- `scripts/update-cli-proxy-api.sh` updates the bundled backend to the latest CLIProxyAPI release and `make backend-version` reports the updated version.
- `make test` and `make build` pass after the backend update.
- `CCProxy.app.zip` is generated for app version `0.1.10` build `11`.
- `appcast.xml` is updated for `v0.1.10`, build `11`, the correct GitHub release URL, archive length, and Sparkle EdDSA signature.
- Intended release changes are committed on the feature branch and reviewed through EasyCode execute/final-review gates.
- The pull request is created and merged successfully.
- Local `main` is updated safely from the main repository root without overwriting unrelated root `.gitignore` changes.
- The EasyCode worktree and local/remote feature branches are cleaned up in safe order.
- GitHub release `v0.1.10` exists with uploaded asset `CCProxy.app.zip`.

## Risks And Open Questions

- Latest CLIProxyAPI release metadata or asset layout can change; the updater script should fail clearly rather than guess.
- GitHub API/network availability and rate limits can block the update script.
- Sparkle signing depends on access to the existing EdDSA private key mechanism; missing key access blocks release publishing.
- Release `v0.1.10` or tag `v0.1.10` may already exist and must be checked before publishing.
- The root checkout has an unrelated dirty `.gitignore` change that must remain untouched.

## Next Stage

worktree, after user approval and `spec-reviewer` PASS.
