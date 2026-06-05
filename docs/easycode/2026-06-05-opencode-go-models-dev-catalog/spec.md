# OpenCode Go Provider And External Model Catalog Spec

## Goal

Add support for using an OpenCode Go subscription through CCProxy's local proxy, and replace the current Swift hardcoded model-list behavior with an external cached model catalog for all connected providers.

The intended result is that a user with an OpenCode Go subscription can configure CCProxy to route compatible local proxy traffic through OpenCode Go, while model lists exposed by the proxy are generated from a locally cached external catalog. The catalog should use router-for-me/CLIProxyAPI's registry models as the primary source, then fill missing connected-provider/model coverage from models.dev. A build-time bundled snapshot of the combined external catalog should be included so first launch and no-cache states still work. Existing Swift hardcoded model catalogs and alias tables should be removed from the runtime model-list source path rather than retained as fallback catalogs.

## Context

The user wants two related changes:

1. Include the OpenCode Go subscription service as a provider that can be reached through this project's local proxy.
2. Replace the current hardcoded model-list approach with automatic model-list support for all connected providers using cached external catalog sources.

OpenCode Go here means the subscription/provider product at `https://opencode.ai/ko/go`, not the Go programming-language SDK. It exposes OpenAI-compatible and Anthropic-compatible API endpoints and uses model IDs in the form `opencode-go/<model-id>` in OpenCode configuration. Current evidence confirms `opencode-go` as a first-class models.dev provider key, distinct from the separate `opencode` / OpenCode Zen provider.

The user has selected unattended completion after implementation and review gates pass. The active target is: create a PR, merge it, update the local base branch, and clean up the EasyCode worktree and feature branch.

The repository already contains local proxy behavior and `/v1/models` response transformation logic. It also has static provider/model structures that should be evolved rather than bypassed.

## Requirements

1. Add OpenCode Go as a configurable provider for CCProxy.
   - Treat OpenCode Go as a hosted API/provider, not as a Go-language dependency.
   - Support routing through CCProxy's local proxy to OpenCode Go's Anthropic-compatible endpoint supported by the existing CCProxy config path:
     - `https://opencode.ai/zen/go/v1/messages`.
   - Do not add OpenAI-compatible `openai-compatibility` config emission for `https://opencode.ai/zen/go/v1/chat/completions` in this change.
   - Treat `https://opencode.ai/zen/go/v1/models` as model-list discovery/reference only when useful; it is not the routing endpoint for this change.
   - Use the standard `Authorization: Bearer <OPENCODE_API_KEY>` request header for direct OpenCode Go API calls.
   - Keep OpenCode Go credentials out of source control and reuse existing project configuration/auth patterns where possible.
   - Follow the existing API-key provider pattern used by hosted providers such as Z.AI, MiniMax, and Kimi unless implementation evidence proves that a different seam is required.
   - Represent OpenCode Go model IDs with the documented `opencode-go/<model-id>` prefix.

2. Preserve local proxy behavior.
   - Requests from local clients should continue to go through CCProxy rather than requiring users to call OpenCode Go directly.
   - Existing providers and model-list behavior must not regress.
   - If OpenCode Go is not configured, existing provider flows should keep working.

3. Introduce a cached external model catalog for all connected providers.
   - Use `https://github.com/router-for-me/CLIProxyAPI/tree/main/internal/registry/models` as the primary upstream model catalog source, because it is closest to the bundled backend/proxy model registry lineage.
   - Treat the exact primary raw inputs as:
     - `https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/main/internal/registry/models/models.json`.
     - `https://raw.githubusercontent.com/router-for-me/CLIProxyAPI/main/internal/registry/models/codex_client_models.json`.
   - Use `https://models.dev/api.json` as the secondary catalog source for connected providers/models that are missing from the CLIProxyAPI registry source, including provider families such as GLM/Z.AI, MiniMax, Kimi/Moonshot, and OpenCode Go when needed.
   - Apply the combined external catalog to existing CCProxy providers, not only to OpenCode Go.
   - Use confirmed provider-key mappings for existing providers where available:
     - CCProxy `claude` maps to models.dev `anthropic`.
     - CCProxy `codex` maps to models.dev `openai`.
     - CCProxy `zai` maps to models.dev `zai-coding-plan`.
     - CCProxy `kimi` maps to models.dev `moonshotai`.
     - CCProxy `minimax` maps to models.dev `minimax-coding-plan`.
     - CCProxy OpenCode Go maps to models.dev `opencode-go`.
   - Do not invent unsupported models.dev mappings for providers that are not present in models.dev.
   - Define "connected provider" as a provider that CCProxy can determine is configured/enabled/authenticated through its existing provider state, plus OpenCode Go when its credential/configuration is present.
   - Filter model-list output to connected providers rather than returning unrelated providers by default.
   - Do not use existing Swift static/hardcoded model lists or alias tables as runtime fallback catalogs.
   - Cache external catalog data in the project/app data path so `/v1/models` requests do not fetch external sources per request.
   - Generate and bundle a build-time external catalog snapshot during build/release so the app has a valid initial catalog when no runtime cache exists.
   - The bundled snapshot must be generated from the same external sources, not hand-written hardcoded Swift model tables.
   - Use a six-hour cache TTL for external catalog refresh.
   - Use this fallback order for model-list generation:
     1. Fresh runtime cache.
     2. Stale runtime cache when refresh fails.
     3. Bundled build-time snapshot when no runtime cache exists.
     4. Explicit unavailable/empty/failure result only if neither runtime cache nor bundled snapshot is valid.
   - If the runtime cache is fresh, use it without network fetch.
   - If the runtime cache is stale, attempt refresh from the external sources and replace the cache only after a valid parse/merge succeeds.
   - If refresh fails but a prior valid runtime cache exists, continue using the stale cache and surface/log the refresh failure.
   - If no valid external-source-derived runtime cache exists, use the bundled build-time snapshot rather than immediately failing.
   - Introduce minimal provider-id mapping between CCProxy provider names and models.dev provider keys where they differ. This mapping is allowed only to connect provider identities, not to define model catalogs.

4. Update model-list generation/normalization.
   - Adapt the existing `/v1/models` model-list handling to consume the dynamic catalog for all connected providers.
   - Remove hardcoded alias/canonical model catalog data from the runtime model-list source path.
   - Preserve only compatibility normalization that is still necessary for request/response shape correctness and can be justified independently from a hardcoded model catalog.
   - Ensure emitted model-list responses remain compatible with local clients expecting OpenAI-style `/v1/models` responses.

5. Add or update tests.
   - Cover OpenCode Go provider model-list behavior.
   - Cover combined external catalog parsing/filtering for multiple connected providers, including existing providers and OpenCode Go.
   - Cover behavior when primary CLIProxyAPI registry and secondary models.dev sources are unavailable or malformed, including fresh-cache, stale-cache, bundled-snapshot, refresh-success, refresh-failure, and no-cache/no-snapshot cases.
   - Cover removal/non-use of existing hardcoded model catalogs in the runtime `/v1/models` source path.
   - Cover non-regression for `/v1/models` response shape compatibility.

6. Documentation/configuration updates.
   - Document how a user configures OpenCode Go credentials for CCProxy.
   - Document that the CLIProxyAPI registry source is primary, models.dev is secondary, a build-time snapshot is bundled, and external catalog data is cached with a six-hour refresh TTL.

7. Unattended finish target.
   - After implementation, verification, and final-review PASS, create and merge a PR.
   - Update the local base branch after merge.
   - Clean up the EasyCode worktree and feature branch after the branch is no longer checked out by the worktree.
   - Do not publish an app release in this finish target unless the user explicitly re-adds app release publication later.

## Non-Goals

- Do not integrate the Go programming-language SDK `opencode-sdk-go`.
- Do not require users to run the OpenCode TUI to make CCProxy work, except as optional background context.
- Do not remove existing providers.
- Do not hardcode user API keys, subscription secrets, or credentials.
- Do not keep hardcoded model catalogs or alias tables as runtime fallback sources.
- Do not fetch external catalog sources on every model-list request.
- Do not treat models.dev as the sole catalog source when the CLIProxyAPI registry source has the relevant model/provider data.
- Do not add full `openai-compatibility` provider architecture or OpenCode Go `/chat/completions` routing in this change.
- Do not remove small provider-key mapping needed to connect CCProxy provider identifiers to external catalog provider identifiers.
- Do not implement unrelated UI redesigns beyond what is necessary to configure/represent the provider and model catalog.
- Do not publish a release before EasyCode final-review PASS and fresh finish verification.

## User Decisions

- The user wants OpenCode Go subscription support routed through the local proxy.
- The user wants existing hardcoded model-list/catalog behavior removed rather than retained as fallback.
- The user wants the CLIProxyAPI registry models used as the first catalog source, with models.dev used to fill missing providers/models.
- The user wants catalog data cached locally by the project/app and refreshed roughly every six hours instead of fetched per request.
- The user wants a build-time latest external catalog snapshot bundled into the app so missing runtime cache does not immediately fail.
- The user selected unattended completion through PR creation, PR merge, local base update, and EasyCode worktree/branch cleanup.

## Success Criteria

- OpenCode Go can be configured as a provider and used through CCProxy's local proxy.
- The proxy can expose model lists derived from the cached combined external catalog for all connected providers.
- Existing hardcoded model catalogs and alias tables are not used as runtime model-list fallback sources.
- Existing providers continue to work when OpenCode Go is not configured.
- Model-list behavior handles external catalog fetch/parse failure without hardcoded catalog fallback, using valid external-source-derived runtime cache or bundled build-time snapshot when available.
- Tests cover OpenCode Go provider behavior, combined catalog filtering, unavailable/malformed catalog behavior, six-hour cache TTL behavior, bundled snapshot fallback, no-hardcoded-catalog behavior, and model-list response-shape compatibility.
- Documentation explains setup and expected behavior.
- The unattended finish target is completed after final-review PASS, including PR creation, PR merge, local base update, and EasyCode worktree/branch cleanup.

## Risks And Open Questions

- Public OpenCode Go docs do not spell out the auth header in the same place as the endpoint list, but official OpenCode source indicates Bearer-token parsing from the `Authorization` header; implementation should still verify behavior with a configured key.
- CCProxy's current config generator supports `claude-api-key` Anthropic-compatible provider blocks but does not emit `openai-compatibility` blocks. Therefore this change supports OpenCode Go's Anthropic-compatible `/zen/go/v1/messages` endpoint only.
- models.dev model IDs follow AI SDK/provider registry conventions and may not always match every provider's raw API IDs; provider-id and model-id mapping/normalization is required for providers whose CCProxy naming differs from models.dev.
- models.dev provider-key research did not confirm `minimax` as a top-level provider key.
- Follow-up models.dev provider-key research confirmed `opencode-go` as the OpenCode Go provider key, distinct from `opencode` / OpenCode Zen.
- User selected coding-plan provider mappings for CCProxy Z.AI and MiniMax: `zai-coding-plan` and `minimax-coding-plan`.
- External catalog sources may be unavailable or change shape; six-hour caching, stale-cache fallback, and bundled build-time snapshot fallback are required, but fallback must not reintroduce hardcoded Swift model catalogs.
- The implementation must avoid expanding scope into a full provider-management redesign.

## Next Stage

worktree after user approval and spec-reviewer PASS.
