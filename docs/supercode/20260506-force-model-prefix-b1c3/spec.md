# Work ID

20260506-force-model-prefix-b1c3

# Objective

Hotfix CCProxy so Z.AI/Kimi/MiniMax Claude-compatible provider models are exposed only through their provider-prefixed model IDs, not duplicated as both raw model IDs and prefixed model IDs.

# Current State

- CCProxy v0.1.7 bundles official CLIProxyAPI 6.10.8 as `src/Sources/Resources/cli-proxy-api`.
- CCProxy v0.1.7 already added proxy-layer model-list de-duplication and request alias canonicalization, but the user-reported post-release behavior still does not satisfy the expected model exposure behavior.
- CCProxy generates Z.AI/Kimi/MiniMax provider entries under `claude-api-key` with `prefix`, `base-url`, and `models`.
- Local reproduction against the backend `/v1/models` showed duplicated Z.AI models, for example:
  - `glm-5`
  - `zai/glm-5`
  - `glm-5-turbo`
  - `zai/glm-5-turbo`
- CLIProxyAPI v6.10.8 source behavior explains this: when `force-model-prefix` is false, prefixed credentials expose both raw and prefixed model IDs.
- CLIProxyAPI supports global `force-model-prefix: true`, which suppresses raw model IDs for prefixed credentials while keeping prefixed model IDs.

# Desired Outcome

CCProxy-generated configuration should set `force-model-prefix: true` so provider-prefixed models such as `zai/glm-5` remain available while raw duplicates such as `glm-5` are not exposed from prefixed provider credentials.

This is an additional v0.1.7 follow-up hotfix targeting backend-generated model exposure at the configuration source, not a replacement for the existing proxy-layer compatibility behavior.

# Scope

## In Scope

- Add `force-model-prefix: true` to CCProxy's bundled CLIProxyAPI config.
- Add/update tests that verify generated config includes `force-model-prefix: true`.
- Verify the generated config and live backend `/v1/models` behavior no longer exposes raw Z.AI model duplicates when Z.AI credentials are present.
- Prepare a hotfix PR and, after review/merge, release as the next patch version after v0.1.7.

## Out of Scope

- Changing Z.AI/Kimi/MiniMax from `claude-api-key` providers to `openai-compatibility` providers.
- Per-provider `excluded-models` filtering unless `force-model-prefix` is proven insufficient.
- Adding provider UI changes.
- Changing model names, prefixes, ports, auth flow, or local ThinkingProxy behavior.
- Replacing the bundled backend binary.

# Non-Goals

- Do not alter unrelated OAuth provider model listings.
- Do not introduce CLIProxyAPI auto-update automation.
- Do not perform a broad VibeProxy sync.

# Constraints

- Preserve CCProxy's provider-prefix routing model.
- Prefer the minimal config-level fix.
- Tests must be isolated from real user credentials where possible.
- Live backend verification must redact secrets and avoid printing API keys.
- If `force-model-prefix: true` does not remove raw duplicates in live verification, route back to planning for an `excluded-models` fallback.

# Success Criteria

- `src/Sources/Resources/config.yaml` contains `force-model-prefix: true`.
- Config generation tests pass and assert the setting is present.
- `swift test` passes.
- Live `/v1/models` verification with the local generated config shows prefixed Z.AI model IDs remain and raw `glm-*` duplicates are absent.
- No provider architecture rewrite or backend binary replacement is introduced.

# Risks / Unknowns

- `force-model-prefix: true` is global; it may also affect other prefixed providers. This is expected and aligned with CCProxy's prefix-based provider model, but live verification should confirm no obvious regression.
- Existing user `merged-config.yaml` may need regeneration by app startup/config generation before the setting takes effect.

# Revisions

- 2026-05-06: Initial hotfix spec drafted after reproducing duplicate `glm-*` and `zai/glm-*` model exposure and confirming CLIProxyAPI `force-model-prefix` behavior.
- 2026-05-06: Revised current state to reflect that v0.1.7 proxy-layer de-duplication was already released but user-reported behavior still requires a config-source follow-up hotfix.
