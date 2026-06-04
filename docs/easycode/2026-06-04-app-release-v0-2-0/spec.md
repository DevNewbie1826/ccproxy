# App Release v0.2.0 Spec

## Goal

Release CCProxy app version `v0.2.0` with build number `12`, including the already-merged provider-removal work and a best-effort update of the bundled CLIProxyAPI backend to the latest available upstream release if the repository update script verifies it safely.

## Context

The current published app release is `v0.1.10` with Sparkle build number `11`. The current `main` branch includes the provider-removal merge commit for PR #11, which removed Gemini, GitHub Copilot, Antigravity, and Qwen from the app while keeping Claude Code, Codex, Z.AI, MiniMax, and Kimi.

The user selected `v0.2.0 / build 12` for this release because the provider removal is a user-facing behavioral change. The user also selected "check latest and update" for the bundled CLIProxyAPI backend.

## Requirements

1. Release version and metadata:
   - Use app version `0.2.0`.
   - Use Sparkle build number `12`.
   - Ensure generated app bundle metadata uses `CFBundleShortVersionString=0.2.0` and `CFBundleVersion=12`.
   - Ensure the Sparkle appcast entry uses `shortVersionString=0.2.0` and `version=12`.

2. Backend update:
   - Run the repository-provided CLIProxyAPI update workflow or script to check the latest upstream backend.
   - If a newer backend is available and the script verifies checksum, executable extraction, and `make backend-version`, update `src/Sources/Resources/cli-proxy-api`.
   - If no newer backend is available, keep the existing backend and record that no binary change was needed.
   - If backend update verification fails, stop rather than shipping an unverified backend binary.

3. Build and package:
   - Build the release app archive using the repository release path with `APP_VERSION=0.2.0` and `APP_BUILD_NUMBER=12`.
   - Produce `CCProxy.app.zip` as an untracked release artifact.
   - Do not commit `CCProxy.app`, `CCProxy.app.zip`, Sparkle private keys, temporary staging directories, or other generated artifacts.

4. Sparkle signing and appcast:
   - Use the repository Sparkle signing flow with `SPARKLE_ED_KEY_FILE` pointing to a readable private key outside the repository and worktree.
   - Generate/update `appcast.xml` for `v0.2.0 / build 12` using the GitHub release asset URL `https://github.com/DevNewbie1826/ccproxy/releases/download/v0.2.0/CCProxy.app.zip`.
   - Ensure `sparkle:edSignature` and archive `length` correspond to the generated `CCProxy.app.zip`.

5. Verification:
   - Verify baseline and final release state with repository-supported commands, including `make backend-version`, `make test`, and `make build` or their documented equivalents.
   - Verify the generated archive exists, is non-empty, and remains untracked.
   - Verify appcast fields, signature, length, and release URL match `v0.2.0 / build 12`.
   - Verify remote tag/release `v0.2.0` does not already exist before publishing.

6. PR and publication:
   - Use EasyCode worktree, plan, execute, and final-review gates before publishing.
   - After final-review PASS, create/merge a PR for committed release metadata changes.
   - Update local `main` from the repository root.
   - Clean the EasyCode-owned worktree and feature branches after merge.
   - Publish GitHub Release `v0.2.0` with the staged `CCProxy.app.zip` asset.

7. Root checkout safety:
   - Do not include the existing unrelated root `.gitignore` dirty change in release commits.
   - Do not alter `.codegraph/`, `.worktrees/`, or unrelated workflow artifacts.

## Non-Goals

- Do not add a new versioning policy document.
- Do not publish x86_64 appcast or x86_64 artifacts unless the existing release plan explicitly proves they are required.
- Do not change app functionality beyond backend update and release metadata/artifacts.
- Do not modify provider-removal behavior from PR #11.
- Do not commit generated archives, app bundles, temporary files, private keys, or local signing material.
- Do not force-push, delete branches before worktree cleanup, or rely on `gh pr merge --delete-branch` while the feature worktree exists.

## User Decisions

- User requested an app release.
- User selected release version `0.2.0` and build number `12`.
- User selected checking/updating the bundled CLIProxyAPI backend during the release.
- Existing unrelated root `.gitignore` dirty change must remain outside release commits.

## Success Criteria

- `appcast.xml` contains a valid `v0.2.0 / build 12` item for `CCProxy.app.zip` with correct release URL, archive length, and Sparkle EdDSA signature.
- The release app archive `CCProxy.app.zip` is generated and staged for upload outside committed source.
- The app bundle inside the archive reports version `0.2.0` and build `12`.
- Backend update is either verified and committed or explicitly found unnecessary with evidence.
- Required build/test/backend verification passes.
- PR for release metadata/binary changes is merged into `main` after final-review PASS.
- GitHub Release `v0.2.0` is published with `CCProxy.app.zip` attached.
- Local `main` is updated to `origin/main`, and EasyCode-owned worktree/local/remote feature branches are cleaned up.

## Risks And Open Questions

- The release requires access to a Sparkle EdDSA private key file via `SPARKLE_ED_KEY_FILE`. If the key is unavailable, release packaging must stop before appcast publication.
- The backend update may find no newer upstream release or may fail verification; in that case the plan must route according to the verified outcome rather than guessing.
- Codesigning may fall back depending on local Developer ID availability, following the existing repository script behavior.

## Next Stage

After user approval and spec-reviewer PASS, proceed to `worktree`.
