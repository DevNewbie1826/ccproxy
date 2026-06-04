# Remove OAuth Providers And Cleanup Spec

## Goal

Remove the Gemini, GitHub Copilot, Antigravity, and Qwen providers completely from the application, while keeping Claude Code, Codex, Z.AI, MiniMax, and Kimi. As part of the same work, clean directly related provider code so the remaining provider implementation is consistent and easier to maintain.

## Context

The current provider set contains 9 providers:

- OAuth providers: Claude Code, Codex, Gemini, GitHub Copilot, Antigravity, Qwen.
- API-key input providers: Z.AI, MiniMax, Kimi.

The target provider set is 5 providers:

- Claude Code and Codex as the only OAuth providers.
- Z.AI, MiniMax, and Kimi as API-key input providers.

The user clarified that the four removed providers must be removed, not merely excluded, hidden, or disabled. The user also approved directly related cleanup work, approved removing `gemini-claude-*` handling, and chose not to add UserDefaults cleanup for stale removed-provider keys.

## Requirements

1. Remove these providers from the product surface and source code:
   - Gemini.
   - GitHub Copilot / Copilot.
   - Antigravity.
   - Qwen.

2. Keep these providers functional:
   - Claude Code.
   - Codex.
   - Z.AI.
   - MiniMax.
   - Kimi.

3. Update provider registry and auth model:
   - `ServiceType` must contain exactly the five kept providers.
   - `AuthCommand` must contain only the remaining OAuth login commands for Claude Code and Codex.
   - OAuth provider configuration must only reference Claude Code and Codex.

4. Remove removed-provider UI and state:
   - Delete Service rows, icons, prompts, state variables, connect flows, and success messages for Gemini, GitHub Copilot, Antigravity, and Qwen.
   - Delete Qwen email-prompt behavior entirely.

5. Remove removed-provider runtime and config handling:
   - Delete Copilot device-code capture logic.
   - Delete Gemini auth newline/default-project logic.
   - Delete Qwen email automation.
   - Delete Antigravity login handling.
   - Delete `gemini-claude-*` ThinkingProxy handling.
   - Remove removed-provider bundled icons and preload references.
   - Clean bundled config comments and remove the Gemini-specific `generative-language-api-key: []` key.

6. Include directly related maintainability cleanup:
   - Consolidate duplicated API-key save logic for Z.AI, MiniMax, and Kimi where practical.
   - Consolidate duplicated API-key scanning logic where practical.
   - Consolidate duplicated API-key sheet/UI logic where practical.
   - Replace provider literal strings in provider-related code with `ServiceType.rawValue` or equivalent centralized provider metadata where practical.
   - Keep the cleanup scoped to provider-related duplication and naming consistency.

7. Tests and verification must be updated:
   - Add or update tests proving `ServiceType.allCases` contains exactly Claude Code, Codex, Z.AI, MiniMax, and Kimi.
   - Add or update tests proving OAuth provider keys/config generation only uses Claude Code and Codex.
   - Add or update tests proving removed provider strings do not appear in active source/test paths except explicitly accepted historical docs, if any.
   - Existing provider config tests must still pass for the three API-key providers.

8. Existing stale UserDefaults keys for removed providers must not be actively migrated or cleaned in this work. They may remain as inert unused data.

## Non-Goals

- Do not merely hide or disable the four removed providers; they are to be removed from active code and product surfaces.
- Do not rewrite the auth process lifecycle beyond deleting provider-specific dead branches.
- Do not rewrite ThinkingProxy beyond removing `gemini-claude-*` removed-provider handling.
- Do not introduce a general YAML parser.
- Do not add UserDefaults migration/cleanup for removed-provider keys.
- Do not change unrelated app behavior, unrelated providers, release automation, or bundled backend behavior.
- Do not create workflow enforcement machinery, persistent workflow state files, or external process artifacts.

## User Decisions

- Remove, not exclude, Gemini, GitHub Copilot, Antigravity, and Qwen.
- Keep API-key input providers: Z.AI, MiniMax, and Kimi.
- Include directly related cleanup for consistency and maintainability.
- Remove `gemini-claude-*` ThinkingProxy handling.
- Leave existing stale UserDefaults keys for removed providers as inert unused data.
- CodeGraph indexing was approved for repository analysis; `.codegraph/` was already ignored before indexing.

## Success Criteria

- The app exposes exactly five providers: Claude Code, Codex, Z.AI, MiniMax, and Kimi.
- The four removed providers have no active UI rows, auth commands, provider registry cases, OAuth config keys, bundled icons, or runtime auth branches.
- `gemini-claude-*` handling is removed from active ThinkingProxy logic.
- Provider-related duplication is reduced without changing behavior of the five kept providers.
- Tests cover the exact remaining provider list and OAuth key set.
- The repository's discovered build/test commands pass, including Swift build/test if applicable.
- The bundled backend starts from a temporary config with `generative-language-api-key: []` removed.
- A targeted search confirms removed provider names are absent from active source/test/resource paths, except any explicitly documented historical files that are intentionally left untouched.

## Risks And Open Questions

- The bundled `cli-proxy-api` binary is opaque and still exposes backend flags outside Swift app control. This work removes provider support from the CCProxy app source, resources, config template, and UI; it does not patch or rebuild the opaque backend binary.
- Existing users may have stale enabled-provider settings for removed providers. The user chose not to clean these keys, so they are accepted as inert residue.
- Historical docs may mention removed providers. Those references should not block active-code cleanup unless they are user-facing current documentation.

## Next Stage

After user approval and spec-reviewer PASS, proceed to `worktree`.
