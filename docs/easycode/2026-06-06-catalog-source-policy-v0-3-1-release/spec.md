# Catalog Source Policy And v0.3.1 Release Spec

## Goal

Update CCProxy's model catalog source policy so official CLIProxyAPI OAuth providers expose only models from the CLIProxyAPI official registry, while compatible/API-key providers use models.dev catalog data. Ship the change as CCProxy `v0.3.1` build `14` through the unattended EasyCode flow: PR creation, PR merge, local main update, app release publication, and EasyCode worktree/branch cleanup.

## Context

The current model catalog pipeline merges CLIProxyAPI registry sources with models.dev supplemental data for multiple providers. This can expose models that are visible in models.dev but not officially supported by CLIProxyAPI OAuth flows. The user wants OAuth providers such as OpenAI/Codex, Claude, and future Grok/xAI to use the CLIProxyAPI official registry only, while compatible/API-key providers use models.dev.

The user clarified that “container reflection” was a typo and is not in scope.

## Requirements

1. Provider source policy:
   - Official CLIProxyAPI OAuth providers must use only the CLIProxyAPI official registry source at the pinned release-backend commit, not models.dev.
   - Compatible/API-key providers must use models.dev catalog data and must not be supplemented from the CLIProxyAPI official OAuth registry unless separately approved.
   - The policy must be encoded in source and tests, not only in documentation.

2. Current CCProxy provider classification:
   - `claude`: official CLIProxyAPI OAuth provider; source from CLIProxyAPI `models.json` only.
   - `codex`: official CLIProxyAPI OAuth provider; source from CLIProxyAPI `models.json` plus `codex_client_models.json` only.
   - `zai`: compatible/API-key provider; source from models.dev.
   - `minimax`: compatible/API-key provider; source from models.dev.
   - `kimi`: compatible/API-key provider in this project; source from models.dev.
   - `opencode-go`: compatible/API-key provider; source from models.dev.
   - `grok`/`xai`: not currently a CCProxy provider key. If added later as official OAuth, it must use CLIProxyAPI `models.json` only.

3. Expected implementation shape:
   - Remove OAuth providers from the models.dev secondary mapping: `claude` and `codex` must not map to `anthropic` or `openai` in the secondary source path.
   - Remove compatible/API-key providers from the CLIProxyAPI primary mapping when they are currently present only because the upstream registry has a key; specifically, `kimi` must be sourced from models.dev under this policy.
   - Keep source and snapshot-generator mappings in sync.
   - Regenerate or verify the bundled catalog snapshot according to repository conventions.
   - Add or update tests that lock the policy, including a guard that official OAuth provider keys are absent from models.dev secondary mappings.

4. Verification requirements:
   - Run focused catalog tests and snapshot-generator tests.
   - Run the repository test/build verification discovered in the project, including `make test`, `make build`, and any release-relevant snapshot checks.
   - Verify that generated `/v1/models` catalog behavior no longer includes models.dev-only entries for OAuth providers.
   - Verify that compatible/API-key providers continue to receive models.dev catalog data.

5. Release requirements:
   - Produce CCProxy app release `v0.3.1` build `14`.
   - Use Sparkle private key only from the absolute path `/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key`.
   - Do not print private key contents or decoded private key bytes.
   - Preserve the previous release safety constraints: verify app metadata, arm64-only archive, appcast signature, exact archive length, SHA-256, and release asset/tag target.
   - Update `appcast.xml` for `v0.3.1` build `14` with a freshly signed Sparkle entry for the generated archive.
   - Create and merge a PR, update local `main`, publish GitHub Release `v0.3.1`, verify release/tag/asset, then clean the EasyCode worktree and local/remote feature branches.

6. Unattended target:
   - After this spec is approved by unattended-mode approval and passes `spec-reviewer`, proceed through worktree, plan, execute, final-review, and finish without additional approval prompts unless a hard gate fails or destructive/ambiguous action requires clarification.

## Non-Goals

- Do not implement container reflection, Docker updates, or deployment container changes.
- Do not add a new `grok`/`xai` provider in this work.
- Do not add live network fetching at `/v1/models` request time.
- Do not redesign OAuth credential handling.
- Do not change Sparkle private key storage or print key material.
- Do not publish any generated `.app` or `.zip` artifact into git.

## User Decisions

- Use unattended mode through PR creation, merge, local main update, app release publication, and worktree/branch cleanup.
- Release version/build: `v0.3.1` / `14`.
- Sparkle private key absolute path: `/Volumes/storage/artifact/sparkle/sparkle_ed25519_private_key`.
- Container reflection was a typo and is out of scope.
- Provider source policy: official CLIProxyAPI OAuth providers use CLIProxyAPI registry only; compatible/API-key providers use models.dev.

## Success Criteria

- Source and snapshot-generation mappings enforce the provider source policy.
- Tests prove `claude` and `codex` do not receive models.dev-only models and that compatible/API-key providers continue to receive models.dev models.
- Repository verification passes, including snapshot-generator checks, tests, and build.
- A signed arm64-only CCProxy `v0.3.1` build `14` archive is generated and verified.
- `appcast.xml` points to GitHub Release `v0.3.1` with correct build, length, and Sparkle EdDSA signature for the exact archive.
- A PR is created, merged, local `main` is updated, GitHub Release `v0.3.1` is published at the merged commit, release asset verification passes, and EasyCode-owned worktree/branches are cleaned.

## Risks And Open Questions

- The current catalog generator already treats secondary data as additive and non-overriding, but OAuth providers can still receive models.dev-only entries; tests must cover this exact regression.
- The current CLIProxyAPI registry pinned at backend commit `5753d1a0896fd5bb9ace47adb17b0174ceb79e4d` includes provider keys beyond the current CCProxy provider set. This work must not add new provider keys unless already present in CCProxy.
- If upstream CLIProxyAPI changes provider keys before execution, the plan must pin or validate the intended registry source before release.
- Release publication can fail due to GitHub permissions, tag collision, or network issues; such failures route through finish-stage failure handling.

## Next Stage

worktree
