# Interview Summary: Project EasyCode/OpenCode Ignore and Local Config

## Work ID

`2026-06-17-opencode-easycode-config`

## Purpose

Configure this repository so project-local OpenCode/EasyCode files under `.opencode/` are ignored locally and remotely, while creating the local ignored EasyCode project config requested by the user.

## Approved Scope

- Add `.opencode/` to the repository `.gitignore` so the ignore rule is applied locally and can be committed/pushed to the remote repository.
- Preserve the existing approved `.codegraph/` ignore entry in `.gitignore`; the user explicitly approved including the pre-existing `.codegraph/` ignore change.
- Create `.opencode/` locally.
- Create `.opencode/easycode.json` locally from the upstream EasyCode README/config evidence.
- Treat files inside `.opencode/` as ignored local-only contents; do not stage, commit, or push `.opencode/easycode.json`.
- Terminal target requested by the user: apply locally and remotely, meaning commit and push the tracked `.gitignore` change after verification and required review gates.

## Non-Goals

- Do not commit `.opencode/` or any file inside it.
- Do not change OpenCode runtime behavior beyond creating the ignored local EasyCode config file.
- Do not edit repository application source code.
- Do not merge any pull request or delete branches/worktrees.
- Do not change secrets or add real API keys.

## Success Criteria

- `.gitignore` contains `.opencode/` and preserves `.codegraph/`.
- `.opencode/easycode.json` exists locally and is ignored by Git.
- `git status --short --ignored` shows `.opencode/` as ignored and does not show `.opencode/easycode.json` as a tracked/staged change.
- The tracked `.gitignore` change is committed and pushed only after plan/goal approval, verification, and required reviews.

## Evidence Checked

- Local `.gitignore` previously contained `.worktrees/` and already had an uncommitted `.codegraph/` addition.
- User explicitly approved including the `.codegraph/` ignore entry.
- Upstream EasyCode public repository evidence provided by librarian research:
  - `DevNewbie1826/easycode` README documents project config at `.opencode/easycode.json`.
  - `src/easycode-config.ts` loads project config from `.opencode/easycode.json` and global config from `~/.config/opencode/easycode.json`.
  - The documented minimal config shape contains `mcp.context7`, `mcp.grep_app`, `mcp.websearch`, and `mcp.codegraph` enabled entries, with `websearch.apiKey` left empty.

## Unresolved Uncertainty

- None for the requested filename or minimal config shape.
- Availability of each MCP server/API key is environment-dependent; the local config will not include secrets.

## Approval Status

Approved by user in chat for full workflow after scope clarification.
