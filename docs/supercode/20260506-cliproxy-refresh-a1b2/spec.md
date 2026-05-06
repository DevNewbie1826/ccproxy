# Work ID

20260506-cliproxy-refresh-a1b2

# Objective

Update CCProxy from its stale VibeProxy-derived baseline while preserving CCProxy's core provider philosophy: Z.AI, Kimi, and MiniMax are exposed as Claude-compatible upstreams through generated `claude-api-key` entries. The bundled CLIProxyAPI binary will be supplied manually by the user, so this work must prepare the codebase, configuration, tests, and release scripts around that binary without downloading, generating, or committing a replacement binary automatically. As part of moving away from the deleted/obsolete CLIProxyAPIPlus naming, the backend resource name should move from `cli-proxy-api-plus` to the official-style `cli-proxy-api`.

# Current State

- CCProxy is a macOS menu-bar app derived from `automazeio/vibeproxy`.
- The app runs a local `ThinkingProxy` on port `8317`, forwarding to a bundled CLIProxyAPI-compatible backend on port `8328`.
- The current bundled backend resource is `src/Sources/Resources/cli-proxy-api-plus` and reports `CLIProxyAPI Version: 6.9.18-0-plus`.
- Official CLIProxyAPI release tarballs contain a backend binary named `cli-proxy-api`, so the refreshed CCProxy integration should use `src/Sources/Resources/cli-proxy-api` going forward.
- The bundled config lives at `src/Sources/Resources/config.yaml` and includes `request-timeout: "10m"`.
- Current CCProxy provider integration is implemented mostly inline in `ServerManager.swift`:
  - `zai-*.json`, `kimi-*.json`, and `minimax-*.json` credential files are scanned under `~/.cli-proxy-api/`.
  - Active Z.AI, Kimi, and MiniMax keys are rendered as `claude-api-key` entries with provider-specific `prefix`, `base-url`, and `models`.
  - Disabled OAuth providers are rendered under `oauth-excluded-models` with `"*"`.
- VibeProxy latest public history shows notable updates after CCProxy's baseline:
  - CLIProxyAPI moved forward to approximately `6.10.8`.
  - `request-timeout` remains in VibeProxy's sample config but is not referenced in its Swift config composition/server code, and the official CLIProxyAPI v6.10.8 schema does not expose that key.
  - Stability fixes were added around `ThinkingProxy.stop()`, pipe/process cleanup, stale auth process cleanup, and thread-safety queues.
  - VibeProxy introduced more structured provider/config management through `ConfigComposer`, `ProviderCatalog`, credential stores, config fingerprinting, and optional custom provider management.

# Desired Outcome

CCProxy should be prepared for a user-supplied official CLIProxyAPI binary refresh while retaining CCProxy's existing Claude-compatible provider behavior. The first implementation cycle is a bounded maintenance refresh, not a provider architecture rewrite.

Expected result:

- The codebase supports replacing the bundled backend manually at `src/Sources/Resources/cli-proxy-api` without requiring GitHub Actions automation.
- `request-timeout` is removed from the bundled config and any tests/fixtures that assert it, unless a direct repository or official CLIProxyAPI source reference proves it is consumed at runtime.
- YAML/config generation is safer for API keys containing special characters.
- Provider enable/disable behavior remains explicit and tested:
  - OAuth providers are excluded through `oauth-excluded-models`.
  - Z.AI/Kimi/MiniMax are included or omitted as Claude-compatible `claude-api-key` entries based on credentials and enabled state.
- A fixed, evidence-based set of VibeProxy stability fixes is checked against named upstream files/PRs and either backported or documented as not applicable using the applicability rules below.
- The project is ready for the user to drop in the refreshed binary at `src/Sources/Resources/cli-proxy-api`. Final review for this implementation cycle may pass without the refreshed binary because the binary is user-supplied and explicitly out of assistant control.

# Scope

## In Scope

1. **Binary integration preparation**
   - Keep manual binary replacement as the workflow.
   - Rename the backend resource path from `src/Sources/Resources/cli-proxy-api-plus` to `src/Sources/Resources/cli-proxy-api` in code, scripts, tests, and docs.
   - Do not add compatibility fallback paths for `cli-proxy-api-plus` unless needed only for a temporary migration test; the final code path should use `cli-proxy-api`.
   - Add or update only a lightweight manual verification command or script target that runs `src/Sources/Resources/cli-proxy-api` in a non-mutating way and displays the backend version string.
   - Target manual replacement version: official `router-for-me/CLIProxyAPI` `v6.10.8` or newer official release supplied by the user at verification time.

2. **Config compatibility cleanup**
   - Remove `request-timeout` from CCProxy config/tests/fixtures unless planning finds a direct runtime consumer in this repository or official CLIProxyAPI documentation/source.
   - Keep `host: 127.0.0.1`, `port: 8328`, `auth-dir: ~/.cli-proxy-api`, `claude-api-key`, and `oauth-excluded-models` semantics compatible with current CCProxy behavior.

3. **Provider config safety**
   - Strengthen YAML escaping/serialization for generated provider entries so API key values containing YAML-sensitive characters parse back to the exact original values.
   - Add or update tests covering at least colon (`:`), hash (`#`), single quote, double quote, backslash, leading/trailing spaces, and newline in generated API key values.

4. **Fixed VibeProxy stability backport candidate set**
   - Evaluate only these VibeProxy stability candidate areas in this cycle:
     1. `ThinkingProxy.stop()` race/cleanup behavior by comparing CCProxy `src/Sources/ThinkingProxy.swift` with VibeProxy `src/Sources/ThinkingProxy.swift` at commit `14c9bd36c20b94c31ea890c3d6578a1015dff305`, focusing only on `stop()`, listener/socket/channel teardown, and state synchronization.
     2. Server process pipe cleanup by comparing CCProxy `src/Sources/ServerManager.swift` with VibeProxy `src/Sources/ServerManager.swift` at commit `14c9bd36c20b94c31ea890c3d6578a1015dff305`, focusing only on stdout/stderr pipe handlers, termination handlers, and process cleanup around backend launch/stop.
     3. Auth retry cleanup from VibeProxy PR #344 (`https://github.com/automazeio/vibeproxy/pull/344`) and VibeProxy `ServerManager.swift` at commit `14c9bd36c20b94c31ea890c3d6578a1015dff305`, focusing only on active auth process tracking, terminating an existing auth attempt before a new one, and stale auth listener cleanup.
   - A candidate is **applicable** only if CCProxy contains the same or equivalent code path and the fix can be implemented without adding Amp, TunnelManager, Copilot, Factory, Vercel, or broad VibeProxy architecture.
   - A candidate is **not applicable** if CCProxy lacks the affected code path, already contains equivalent protection, or the upstream fix depends on out-of-scope features.
   - For each candidate, the plan and final-review artifact must record one of: `ported`, `already equivalent`, or `not applicable`, with the file/function evidence used for that decision.
   - Keep CCProxy-specific authorization and provider routing behavior intact.

5. **Provider constants extraction only**
   - Extract provider key/model/base-url constants only if doing so directly supports the config cleanup or tests in this cycle.
   - Do not introduce full VibeProxy `ConfigComposer`, `CustomProviderCredentialStore`, or `openai-compatibility` architecture in this cycle.
   - Do not change Z.AI/Kimi/MiniMax from Claude-compatible upstreams to VibeProxy's OpenAI-compatible/custom-provider model in this cycle.

6. **Tests and verification**
   - Update existing tests and add focused tests for config generation, provider enable/disable behavior, YAML escaping, and any backported stability behavior that can be unit-tested.

## Out of Scope

- Automatically downloading, replacing, or committing the CLIProxyAPI binary.
- Keeping the obsolete `cli-proxy-api-plus` name as the primary final runtime path.
- GitHub Actions automation for CLIProxyAPI updates or full release automation.
- Automatic Sparkle release publishing, notarization, or appcast automation changes beyond what is necessary for compatibility.
- Replacing CCProxy's provider model with VibeProxy's full `openai-compatibility`/custom provider architecture.
- Introducing full `ConfigComposer`, `ConfigInputFingerprint`, or custom provider UI architecture from VibeProxy.
- Adding Amp CLI integration.
- Adding GitHub Copilot, Factory alias routing, or Vercel AI Gateway expansion.
- Adding Intel/x86_64 release support.
- Changing the app's branding, bundle ID, or product name.
- Broad UI redesign.

# Constraints

- The user will manually provide the refreshed backend binary; implementation must not fetch or vendor a new binary automatically.
- The backend resource path must become `src/Sources/Resources/cli-proxy-api` in final code/scripts/docs.
- Preserve CCProxy's current user-facing provider model unless an explicit later decision changes it.
- Do not silently change ports: `ThinkingProxy` remains on `8317`; backend remains on `8328` unless planning discovers a required compatibility issue and routes for approval.
- Preserve localhost-only exposure for local services.
- Keep changes small enough for one implementation cycle.
- Stability-backport work is limited to the three candidate areas listed in Scope item 4.
- Any code changes must be developed in an isolated worktree after this spec is approved and committed.
- Behavior-changing work requires tests first during execution.

# Success Criteria

- The final implementation does not include an auto-downloaded or assistant-supplied backend binary.
- The final backend resource path is `src/Sources/Resources/cli-proxy-api`; final code/scripts/docs do not use `cli-proxy-api-plus` as the primary runtime path.
- The project builds/tests with the existing binary before manual replacement, and has a documented command/check to re-run after the user manually replaces the binary.
- Final review may pass before the user supplies the refreshed binary if all code/config/tests pass with the existing binary and the manual backend-version verification command is documented.
- `request-timeout` is removed from bundled config/tests/fixtures unless a direct runtime consumer is found and cited.
- Generated config for Z.AI/Kimi/MiniMax remains Claude-compatible and includes the expected `prefix`, `base-url`, and `models` entries when credentials are present and enabled.
- Disabled OAuth providers continue to generate `oauth-excluded-models` entries with `"*"`.
- API keys with YAML-sensitive characters are safely represented in generated config and covered by tests.
- Each of the three named stability candidates is either ported, marked already equivalent, or marked not applicable using the spec's applicability rules and cited upstream/local file-function evidence.
- No out-of-scope features such as Amp, Copilot, Factory aliases, Intel build automation, or CLIProxyAPI auto-update workflows are introduced.

# Risks / Unknowns

- The official CLIProxyAPI binary supplied by the user may have behavioral differences from `6.9.18-0-plus`, especially around config keys and provider routing.
- `request-timeout` appears unused in VibeProxy/official CLIProxyAPI schema, but removing it must be validated against real CCProxy behavior.
- VibeProxy stability fixes may depend on surrounding architecture that differs from CCProxy; backports must be selective.
- Multi-account/round-robin behavior for multiple `claude-api-key` entries may depend on CLIProxyAPI internals and is not guaranteed in this cycle.

# Revisions

- 2026-05-06: Initial spec drafted from repository and upstream VibeProxy/CLIProxyAPI research. User clarified that the binary will be supplied manually and automation should not be included in the first work cycle.
