# CLIProxyAPI Update Worktree Spec

## Goal

Prepare an isolated EasyCode git worktree where the user can upload files for a future CLIProxyAPI update.

## Context

The user requested a worktree for updating CLIProxyAPI and stated that they will upload the update into that worktree. This stage is limited to preparing the worktree safely; it does not implement or validate the CLIProxyAPI update itself.

## Requirements

- Use work ID `2026-06-03-cliproxyapi-update-worktree`.
- After user approval and `spec-reviewer` PASS, create or verify the EasyCode worktree at `.worktrees/2026-06-03-cliproxyapi-update-worktree`.
- Create or verify the worktree branch as `work/2026-06-03-cliproxyapi-update-worktree`.
- Use the current repository checkout/HEAD as the base unless the user requests a different base before approval.
- Checkpoint the approved `spec.md` and `evidence.md` before creating the worktree, as required by EasyCode.
- Report the final worktree path and branch to the user so they can upload their files there.
- Do not make CLIProxyAPI implementation changes during this spec/worktree preparation request.
- If the worktree cannot be created or verified safely, stop and report the blocker instead of guessing or forcing changes.

## Non-Goals

- Implementing the CLIProxyAPI update.
- Reviewing, validating, committing, merging, or creating a pull request for uploaded files.
- Running a plan, execute, final-review, or finish stage for the CLIProxyAPI update content before the user provides the update and asks to continue.
- Changing runtime behavior, tests, application code, agents, skills, or MCP/plugin configuration as part of this worktree-only request.

## User Decisions

- The user wants an isolated worktree for a CLIProxyAPI update.
- The user intends to upload the update into the prepared worktree.
- Pending approval: use the current repository checkout/HEAD as the worktree base.

## Success Criteria

- The approved spec and evidence artifacts are present under `docs/easycode/2026-06-03-cliproxyapi-update-worktree/`.
- The approved spec and evidence are checkpointed before worktree creation.
- `.worktrees/2026-06-03-cliproxyapi-update-worktree` exists and is on branch `work/2026-06-03-cliproxyapi-update-worktree`.
- The user receives the worktree path and branch and can upload files there.

## Risks And Open Questions

- The exact CLIProxyAPI update content is unknown until the user uploads it.
- The current repository checkout/HEAD is assumed to be the intended base unless the user changes that decision.
- Git status, existing branches, and `.worktrees/` ignore-safety must still be verified during the worktree stage.

## Next Stage

worktree, after user approval and `spec-reviewer` PASS.
