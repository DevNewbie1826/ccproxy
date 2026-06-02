# CLIProxyAPI Update Deployment Spec

## Goal

Validate and deploy the user-uploaded CLIProxyAPI binary update through an unattended release workflow: commit the update, create and merge a pull request, update local code, clean the EasyCode worktree/branch, and publish the `v0.1.9` release artifacts.

## Context

The approved EasyCode worktree already exists at `.worktrees/2026-06-03-cliproxyapi-update-worktree` on branch `work/2026-06-03-cliproxyapi-update-worktree`. The user uploaded a new `src/Sources/Resources/cli-proxy-api` binary into that worktree and confirmed the dirty binary change is intentional. The user then requested unattended PR creation, merge, worktree/branch cleanup, local code update, and release deployment. The release version decision is `v0.1.9` with build number `10`.

## Requirements

- Use work ID `2026-06-03-cliproxyapi-update-worktree` and the existing worktree at `.worktrees/2026-06-03-cliproxyapi-update-worktree`.
- Preserve the user-uploaded `src/Sources/Resources/cli-proxy-api` binary change; do not revert or replace it unless verification proves it unusable.
- Validate the uploaded CLIProxyAPI binary version with `make backend-version` or an equivalent direct `--version` check.
- Run repository baseline validation before committing release changes, including at least `make test` and `make build` or stricter release-equivalent validation when required by the plan.
- Build release artifacts for version `0.1.9` and build number `10` using the repository release flow.
- Produce `CCProxy.app.zip` and update `appcast.xml` for tag `v0.1.9`, build `10`, and the GitHub release asset URL for `CCProxy.app.zip`.
- Commit only intended deployment changes on branch `work/2026-06-03-cliproxyapi-update-worktree`, expected to include the uploaded CLIProxyAPI binary and release metadata such as `appcast.xml` when generated.
- Create a pull request from `work/2026-06-03-cliproxyapi-update-worktree` to the repository base branch using non-interactive GitHub CLI flags.
- After required verification and final review pass, merge the pull request, update the local base branch from the main repository root, remove the EasyCode-owned worktree, delete the local feature branch after worktree removal, and delete the remote feature branch after merge/cleanup no longer depends on it.
- Publish the `v0.1.9` GitHub release with the generated `CCProxy.app.zip` asset after the merged code and appcast state are safe for release.
- Run merge, local base update, worktree removal, and branch deletion commands from the main repository root, not from inside the feature worktree.
- Do not force-push, overwrite unrelated root checkout changes, or rely on `gh pr merge --delete-branch` while the feature worktree still exists.
- If GitHub authentication, signing, release asset generation, appcast signing, merge safety, or root checkout cleanliness blocks unattended deployment, stop and report the blocker instead of guessing or forcing.

## Non-Goals

- Changing application behavior beyond bundling the uploaded CLIProxyAPI update and required release metadata.
- Refactoring Swift application code, test code, build scripts, skills, agents, plugins, or MCP configuration.
- Adding new runtime hooks or workflow state files.
- Cleaning unrelated dirty files in the root checkout, including the existing `.gitignore` change, unless separately approved.
- Publishing a release version other than `v0.1.9` build `10`.

## User Decisions

- The uploaded `src/Sources/Resources/cli-proxy-api` binary change is intentional.
- The user requested unattended mode for PR creation, PR merge, worktree/branch cleanup, local code update, and release deployment.
- The release version is `v0.1.9` and the build number is `10`.
- The existing EasyCode worktree and branch should be used for this deployment.

## Success Criteria

- The updated spec and evidence artifacts are approved and reviewed.
- The worktree is verified on branch `work/2026-06-03-cliproxyapi-update-worktree` with the intended uploaded CLIProxyAPI change.
- Validation commands selected by the approved plan pass, including binary version validation and repository baseline validation.
- Release artifacts are generated for `v0.1.9` build `10`, including `CCProxy.app.zip` and updated `appcast.xml` with a valid Sparkle signature.
- Intended changes are committed and pushed to the feature branch.
- A pull request is created and merged successfully.
- The local base branch is updated from the main repository root after merge.
- `.worktrees/2026-06-03-cliproxyapi-update-worktree` is removed only after the merge no longer depends on it.
- Local and remote feature branches are deleted only after safe merge/worktree cleanup ordering.
- The `v0.1.9` GitHub release is published with the `CCProxy.app.zip` asset.

## Risks And Open Questions

- GitHub CLI authentication and repository permissions must be available for PR, merge, and release commands.
- Sparkle signing depends on the repository's `sign_update` path and available signing key or keychain configuration; if unavailable, release deployment must stop before publishing invalid appcast metadata.
- The root checkout currently has an unrelated dirty `.gitignore` change and local `main` is ahead of `origin/main`; local base update must not overwrite unrelated work.
- The exact CLIProxyAPI binary version string is not yet recorded for the uploaded binary and must be captured during execution.
- Existing GitHub release/tag `v0.1.9` conflicts, branch conflicts, merge conflicts, or failing checks would block unattended completion.

## Next Stage

worktree, after user approval and `spec-reviewer` PASS.
