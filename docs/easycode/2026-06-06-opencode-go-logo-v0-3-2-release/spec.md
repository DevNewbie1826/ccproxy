# OpenCode Go Logo And v0.3.2 Release Spec

## Goal

Convert the provided OpenCode Go SVG data URI logo into a PNG resource, add it to the `opencode-go` provider row in CCProxy, verify the existing PNG-based UI icon rendering path, and release the signed macOS app as `v0.3.2` build `15` through the unattended EasyCode PR, merge, local update, cleanup, and GitHub Release flow.

## Context

The `opencode-go` provider currently appears in the settings UI without a logo because its `ServiceRow` is configured with an empty icon name. Existing provider icons are PNG resources loaded through `IconCatalog` from bundled resource filenames. The user supplied an exact URL-encoded SVG data URI, then decided it should be converted to PNG to match the existing provider icon convention. The user also requested unattended PR creation, merge, local base update, worktree/branch cleanup, and app release. The previous released version is `v0.3.1` build `14`, so this standalone logo patch targets `v0.3.2` build `15`.

Provided logo data URI:

```text
data:image/svg+xml,%3csvg%20width='54'%20height='30'%20viewBox='0%200%2054%2030'%20fill='none'%20xmlns='http://www.w3.org/2000/svg'%3e%3cpath%20d='M24%2030H0V0H24V6H6V24H18V18H12V12H24V30Z'%20fill='%23F1ECEC'/%3e%3cpath%20d='M12%2018H18V24H6V12H12V18Z'%20fill='%234B4646'/%3e%3cpath%20d='M48%2012V24H36V12H48Z'%20fill='%234B4646'/%3e%3cpath%20d='M54%2030H30V0H54V30ZM36%2024H48V6H36V24Z'%20fill='%23F1ECEC'/%3e%3c/svg%3e
```

## Requirements

- Convert the provided URL-encoded SVG data URI into a PNG resource matching the repository's existing provider icon convention.
- Add the converted PNG resource under `src/Sources/Resources/`, with an intended filename such as `icon-opencode-go.png` unless planning finds a stronger repository naming convention.
- Update the `opencode-go` settings row so it references the new PNG resource instead of an empty icon slot.
- Preserve existing provider logos and behavior for `claude`, `codex`, `zai`, `minimax`, and `kimi`.
- Reuse the existing `IconCatalog.image(named:resizedTo:template:)` filename-based rendering path; do not add a new SVG data URI runtime rendering path unless the approved plan later proves PNG conversion is impossible.
- Add focused regression coverage so `opencode-go` can no longer regress to an empty logo configuration.
- Ensure the PNG is derived from the exact supplied SVG data URI; do not substitute a different logo or redraw unless implementation proves the supplied SVG cannot be converted, in which case stop and route back for user/spec approval.
- Do not add or change providers, credentials, catalog source policy, model catalog behavior, Sparkle key storage, or release-signing machinery.
- Prepare and sign an arm64-only macOS release archive for `v0.3.2` build `15`.
- Update `appcast.xml` for `v0.3.2` build `15` using the exact archive byte length and Sparkle EdDSA signature produced by `sign_update --ed-key-file /Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key`.
- Stage the release asset outside the repository at `/Volumes/storage/artifact/ccproxy/releases/v0.3.2/CCProxy.app.zip`.
- Do not commit generated `.app`, `.zip`, external staged artifacts, Sparkle private key files, decoded key bytes, or unrelated root checkout changes.
- After final-review PASS and fresh finish verification, unattended finish may push the branch, create the PR, merge it, update local `main`, publish GitHub Release `v0.3.2`, verify the release/tag/asset, and clean up only the EasyCode-owned worktree and feature branches.

## Non-Goals

- No redesign of provider metadata, authentication, settings layout, catalog sources, model aliases, or updater behavior.
- No addition of `grok`, `xai`, or other providers.
- No x86_64 release artifact unless the approved plan later proves the repository has an active x86_64 release path requiring it.
- No changes to Sparkle private key location or storage.
- No edits to root checkout `.gitignore`; it has a known pre-existing dirty change outside this work.
- No runtime workflow-enforcement machinery, permission changes, MCP changes, or persistent workflow state files.

## User Decisions

- Use the exact supplied OpenCode Go SVG data URI as the source image, converted to a PNG resource to match the existing provider icon convention.
- Use Sparkle private key path `/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key`.
- Run unattended through PR creation, merge, local update, worktree/branch cleanup, and app release after all EasyCode gates pass.
- Release target is `v0.3.2` build `15`, derived from the current `v0.3.1` build `14` release unless the user changes it before approval.

## Success Criteria

- `opencode-go` provider row renders a non-empty logo from the converted PNG resource.
- The new PNG resource exists in the bundled resources and is referenced by the `opencode-go` row.
- Focused tests verify `opencode-go` no longer uses an empty icon and the referenced PNG resource can be loaded by the existing icon path.
- Existing relevant provider/config tests remain passing.
- Full repository verification passes using repository conventions, including at minimum `make backend-version`, `scripts/test-snapshot-generator.sh`, `make test`, and `make build` when supported.
- `APP_VERSION=0.3.2 APP_BUILD_NUMBER=15 TARGET_ARCH=arm64 make sparkle-archive` produces a verified arm64 app archive.
- Built app metadata reports version `0.3.2` and build `15`; binary architecture is arm64; codesign verification passes.
- Sparkle public key derived from the approved private key matches `SUPublicEDKey` in both source and built app plists without printing private key material.
- `appcast.xml` points to `https://github.com/DevNewbie1826/ccproxy/releases/download/v0.3.2/CCProxy.app.zip`, has build `15`, and its signature/length match the exact staged archive.
- GitHub Release `v0.3.2` exists after finish, its tag resolves to the merged release commit, and its `CCProxy.app.zip` asset size matches the verified archive.
- Feature worktree and local/remote feature branches are cleaned up after merge/release; root checkout remains on updated `main` with only the pre-existing dirty `.gitignore` if still present.

## Risks And Open Questions

- The repository currently has filename-based PNG icon loading, so PNG conversion is lower risk than adding a new runtime SVG data URI renderer.
- Existing tests do not cover settings-row icon rendering, so new focused coverage is required.
- `create-app-bundle.sh` references an x86_64 appcast feed name for Intel builds, but current release evidence only confirms `appcast.xml` and arm64 release flow. The plan should confirm whether any x86_64 appcast file exists before release work.

## Next Stage

After user approval and `spec-reviewer` PASS, move to `worktree`.
