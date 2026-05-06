# Work ID

20260506-model-list-dedupe-b7d3

# Goal

Make `GET /v1/models` through `ThinkingProxy` on port `8317` return a de-duplicated canonical model list, and preserve compatibility for request bodies that submit the spec-listed short model aliases by rewriting only a top-level JSON `model` string to its canonical ID before forwarding to CLIProxyAPI.

# Source Spec

`/Volumes/storage/workspace/ccproxy/.worktrees/20260506-model-list-dedupe-b7d3/docs/supercode/20260506-model-list-dedupe-b7d3/spec.md`

# Architecture / Design Strategy

- Keep the change in the Swift proxy layer, centered in `src/Sources/ThinkingProxy.swift`, because `/v1/models` is produced by the bundled CLIProxyAPI backend.
- Add small `internal` pure helpers on or near `ThinkingProxy` so tests can cover alias rewrite and model-list filtering without network-heavy proxy integration.
- Use one explicit alias-to-canonical table matching the spec exactly:
  - `glm-5.1` -> `zai/glm-5.1`
  - `glm-5` -> `zai/glm-5`
  - `glm-5-turbo` -> `zai/glm-5-turbo`
  - `glm-5v-turbo` -> `zai/glm-5v-turbo`
  - `glm-4.7` -> `zai/glm-4.7`
  - `glm-4.7-flash` -> `zai/glm-4.7-flash`
  - `glm-4.6v` -> `zai/glm-4.6v`
  - `glm-4.5-air` -> `zai/glm-4.5-air`
  - `MiniMax-M2.7` -> `minimax/MiniMax-M2.7`
- Request path: after existing POST body transformations (`processThinkingParameter`, `stripCacheControl`) and before Vercel/backend routing decisions, rewrite a top-level JSON `model` string if it is one of the explicit aliases. Preserve non-JSON, missing-model, non-string-model, canonical, and unknown models unchanged.
- Response path: detect eligible `GET /v1/models` requests before forwarding to CLIProxyAPI by matching method `GET` and URL path component exactly `/v1/models` while ignoring query string for matching. Buffer only eligible responses when a safe complete body boundary is known, preferably a valid exact `Content-Length`; transform only complete unencoded/non-chunked JSON bodies, update response headers for the transformed body, then close the client connection. All other responses, including unsafe or indeterminate framing, continue/pass through using the current streaming behavior unchanged.
- Model-list filtering rule: parse OpenAI-compatible JSON with a top-level `data` array of model objects; if both alias ID and canonical ID from the table are present in the same response, retain the canonical object and drop the alias object. If canonical is absent, keep the alias object unchanged.
- Ownership normalization: for retained entries only, set `owned_by` for IDs with deterministic mappings: `zai/*` -> `zai`, `minimax/*` -> `minimax`, IDs beginning `gpt-` or `codex-` -> `openai`; leave other retained entries unchanged.
- Fail-safe behavior: if parsing, expected-shape validation, serialization, HTTP response reconstruction, or HTTP framing is unsafe, pass the backend response through unchanged rather than crashing, waiting indefinitely, or partially transforming. Responses with `Content-Encoding`, `Transfer-Encoding: chunked`, missing/invalid `Content-Length`, incomplete body bytes relative to `Content-Length`, or keep-alive framing without a deterministic body boundary must pass through/stream unchanged unless the implementation explicitly and safely determines a complete body; this plan does not require decoding or indefinite buffering.

# Scope

In scope:

- Add pure helper tests and production helpers for alias request rewrite and model-list response filtering.
- Add proxy response buffering/reconstruction only for successful `GET /v1/models` responses through `ThinkingProxy`.
- Update `Content-Length` and connection-related headers for transformed `/v1/models` responses.
- Add mandatory deterministic tests around complete HTTP response reconstruction and the smallest response-transformation test seam, without starting sockets or CLIProxyAPI.
- Preserve existing authorization, thinking-parameter handling, cache-control stripping, Vercel gateway routing, `/provider/` path normalization, and non-model-list streaming behavior.

Out of scope:

- CLIProxyAPI binary/source changes.
- Provider credential discovery or generated YAML alias fields.
- User-configurable alias registry or UI.
- Kimi aliasing or inferred aliases outside the explicit spec table.
- Transforming streaming completion/chat responses.

# Assumptions

- The approved spec is authoritative and planning-ready.
- `/v1/models` responses are small enough to buffer as stated in the spec risks.
- Tests can use `@testable import CCProxy` to call `internal` helper APIs from `ThinkingProxy.swift`.
- No external dependencies are needed; `Foundation.JSONSerialization` is sufficient for conservative JSON transforms.
- The existing package test command remains `swift test` from the worktree `src` directory.

# Source Spec Alignment

- Spec lines 20-25: response filtering retains canonical provider-prefixed IDs and normalizes known ownership metadata.
- Spec lines 28-40: one explicit alias table drives both request rewrites and duplicate filtering.
- Spec lines 46-50: plan adds proxy-layer filtering and automated tests for filtering/rewrite behavior.
- Spec lines 70-76: response handling is conservative, table-driven, retains aliases when canonical is absent, and updates HTTP headers after transformation.
- Spec lines 77-78: existing auth, thinking/cache-control, Vercel routing, and path normalization are protected by sequencing and regression checks.
- Spec lines 82-88: tasks include fixture coverage for all listed duplicate pairs, OpenAI model preservation, alias-without-canonical preservation, request rewrite coverage, and full test-suite verification.

# Execution Policy

- TDD required: create focused failing tests for pure helpers before production helper implementation.
- Keep implementation narrow: modify only `ThinkingProxy.swift` and tests unless execution discovers a compile-only need directly tied to these files.
- Do not add dependencies, config files, generated YAML aliases, or network integration tests unless pure helper coverage cannot verify the required behavior.
- Preserve existing code paths for non-`GET /v1/models` responses by defaulting to current `receiveResponse` / `streamNextChunk` behavior.
- Run targeted tests after each implementation task and `swift test` before completion.
- Use AST/LSP diagnostics on changed Swift files after production/test edits where available.

# File Structure

- `src/Sources/ThinkingProxy.swift`
  - Existing proxy implementation.
  - Add `internal` pure helper(s), alias table, request rewrite integration, and model-list response buffering/reconstruction for `GET /v1/models`.
- `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`
  - New focused XCTest file for pure alias rewrite and model-list filtering helpers.
- `src/Tests/CCProxyTests/ThinkingProxyPortTests.swift`
  - Existing tests remain unchanged unless execution needs a minimal regression assertion related to public proxy behavior; prefer not modifying.
- `src/Tests/CCProxyTests/ServerManagerConfigTests.swift`
  - Existing tests remain unchanged and continue asserting no generated YAML `alias:` field.

# File Responsibilities

- `ThinkingProxy.swift`
  - Owns request authorization, body transformations, path normalization, Vercel routing, backend forwarding, and response forwarding.
  - New responsibility: table-driven model alias canonicalization for request bodies and safe `/v1/models` response transformation.
  - Must expose only test-focused `internal` helpers needed by `@testable` tests, including the smallest seam that lets tests exercise eligible response transformation/reconstruction without socket I/O; keep network plumbing private.
- `ThinkingProxyModelAliasTests.swift`
  - Owns deterministic unit coverage for the alias table, top-level request-body rewrite boundaries, model-list duplicate filtering, ownership normalization, eligible response reconstruction, forwarded request `Content-Length` consistency where exposed by a helper seam, and fail-safe unchanged behavior.
  - Must not start listeners or require CLIProxyAPI.

# Task Sections

## Task 1

- Task id: T1
- Task name: Add focused failing tests for alias rewrite and model-list filtering helpers
- Purpose: Establish TDD coverage for all spec-required pure transformation behavior before production changes.
- Files to create / modify / test:
  - Create: `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`
  - Test command target: `swift test --filter ThinkingProxyModelAliasTests`
- Concrete steps:
  1. Add a new XCTest case class `ThinkingProxyModelAliasTests` using `@testable import CCProxy`.
  2. Add request rewrite tests that call the planned internal helper and assert:
     - `{"model":"glm-4.7"}` rewrites to top-level `model == "zai/glm-4.7"`.
     - `{"model":"MiniMax-M2.7"}` rewrites to top-level `model == "minimax/MiniMax-M2.7"`.
     - Canonical IDs, unknown IDs, missing `model`, non-string `model`, malformed JSON, and nested-only `model` values remain unchanged.
  3. Add a model-list fixture with top-level OpenAI-compatible shape, including at minimum all duplicate pairs required by spec success criterion line 83 plus `gpt-5.5`, `codex-*`, an unrelated model, and an alias whose canonical partner is absent.
  4. Add filtering assertions that retained IDs include all canonical `zai/*` and `minimax/*` entries, exclude duplicate short aliases only when the matching canonical exists, keep the alias whose canonical is absent, and keep `gpt-5.5` unprefixed.
  5. Add ownership assertions for retained `zai/*`, `minimax/*`, `gpt-*`, and `codex-*` entries, plus an assertion that unrelated retained entries keep their original `owned_by`.
  6. Add fail-safe tests asserting malformed JSON, valid JSON without a `data` array, or `data` entries without string `id` return unchanged / no transformation according to the helper contract.
  7. Add eligibility helper tests asserting method/path matching only:
     - `GET /v1/models` is eligible.
     - `GET /v1/models?limit=100` is eligible by matching only the URL path component.
     - `POST /v1/models`, `GET /v1/models/extra`, and `GET /api/v1/models` are not eligible.
  8. Run the targeted test command and confirm it fails because helpers do not exist or behavior is not implemented yet.
- Explicit QA / verification:
  - `cd /Volumes/storage/workspace/ccproxy/.worktrees/20260506-model-list-dedupe-b7d3/src && swift test --filter ThinkingProxyModelAliasTests`
  - Expected at this stage: compile failure for missing helper symbols or failing assertions, documenting the red TDD state.
- Expected result:
  - A focused test file exists and captures the alias table, filtering rules, ownership normalization, eligibility matching, and fail-safe boundaries for pure JSON helpers.
  - Targeted tests fail before production implementation.
- Dependency notes:
  - No dependencies on other tasks.
- Parallel eligibility:
  - Not parallelizable with production implementation because this is the required first TDD step.

## Task 2

- Task id: T2
- Task name: Implement pure alias rewrite and model-list filtering helpers
- Purpose: Satisfy T1 with deterministic, testable transformations independent of network I/O.
- Files to create / modify / test:
  - Modify: `src/Sources/ThinkingProxy.swift`
  - Test: `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`
- Concrete steps:
  1. Add one internal alias table in `ThinkingProxy.swift` containing exactly the nine alias-to-canonical mappings from the spec.
  2. Add an internal helper for request bodies, for example `canonicalizeTopLevelModelAlias(in jsonString: String) -> String?`, that:
     - Parses only JSON objects.
     - Rewrites only a top-level string `model` matching the alias table.
     - Returns serialized modified JSON only when a rewrite occurs.
     - Returns `nil` for malformed JSON, non-object JSON, missing/non-string/unknown/canonical model, or nested-only model values.
  3. Add an internal helper for model-list response bodies, for example `filterModelListResponseBody(_ bodyData: Data) -> Data?`, that:
     - Parses JSON object bodies using `JSONSerialization`.
     - Requires a top-level `data` array; if absent or unsafe, returns `nil`.
     - Identifies canonical IDs present in the response.
     - Drops alias objects only when their mapped canonical ID is present in the same response.
     - Keeps alias objects unchanged when the canonical partner is absent.
     - Normalizes `owned_by` only for retained objects with `zai/*`, `minimax/*`, `gpt-*`, or `codex-*` IDs.
     - Preserves unrelated top-level fields and unrelated object fields where serialization permits.
     - Returns serialized JSON data only when transformation succeeds safely.
  4. Add an internal URL-path eligibility helper, for example `isModelListRequest(method:path:) -> Bool`, that parses/strips any query string and returns true only when method is exactly `GET` and the URL path component is exactly `/v1/models`.
  5. Keep helper access `internal` for `@testable` visibility; do not expose public API.
  6. Run targeted tests from T1 and fix only helper behavior needed to pass them; alias/filtering/eligibility helper tests must pass before moving to integration.
- Explicit QA / verification:
  - `cd /Volumes/storage/workspace/ccproxy/.worktrees/20260506-model-list-dedupe-b7d3/src && swift test --filter ThinkingProxyModelAliasTests`
  - `lsp_diagnostics` or equivalent diagnostics on `src/Sources/ThinkingProxy.swift` and `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`.
- Expected result:
  - Pure alias/filtering/eligibility helper tests pass.
  - Alias table exactly matches the spec.
  - No network behavior is changed yet except helper availability.
- Dependency notes:
  - Depends on T1 tests.
- Parallel eligibility:
  - Not parallelizable with T1. Can be followed by T3 after targeted tests pass.

## Task 3

- Task id: T3
- Task name: Integrate request alias rewrite into POST body processing
- Purpose: Preserve short-alias client compatibility by canonicalizing known top-level model aliases before forwarding requests.
- Files to create / modify / test:
  - Modify: `src/Sources/ThinkingProxy.swift`
  - Test: `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`
- Concrete steps:
  1. In `processRequest`, within the existing `if method == "POST" && !bodyString.isEmpty` block, call the request alias helper after `processThinkingParameter` and `stripCacheControl` have had a chance to update `modifiedBody`.
  2. If the helper returns rewritten JSON, assign it to `modifiedBody`; otherwise leave `modifiedBody` unchanged.
  3. Ensure `thinkingEnabled` semantics are not changed: alias rewrite must not enable/disable thinking headers.
  4. Ensure Vercel routing still evaluates against the final `modifiedBody` and remains limited to Claude/Gemini-Claude matching.
  5. Do not modify request method, path, headers, query strings, nested model fields, or authorization behavior.
  6. Confirm the forwarded request builder uses the final `modifiedBody` byte count when rebuilding `Content-Length`; stale original request `Content-Length` must never be forwarded after alias rewrite.
  7. If there is no existing testable seam for forwarded request construction, extract the smallest internal helper needed to build forwarded request bytes from method/path/version/headers/body/thinking inputs without opening a network connection.
  8. Add or complete the mandatory test that an aliased body rewritten from `glm-4.7` to `zai/glm-4.7` produces a forwarded request with `Content-Length` equal to the rewritten body UTF-8 byte count and not the original body byte count.
  9. If needed for coverage, add one narrowly scoped helper-level test demonstrating composition does not alter non-alias Claude thinking models; avoid network tests.
- Explicit QA / verification:
  - `cd /Volumes/storage/workspace/ccproxy/.worktrees/20260506-model-list-dedupe-b7d3/src && swift test --filter ThinkingProxyModelAliasTests`
  - `cd /Volumes/storage/workspace/ccproxy/.worktrees/20260506-model-list-dedupe-b7d3/src && swift test --filter ThinkingProxyPortTests`
- Expected result:
  - Known short aliases in top-level POST JSON bodies are rewritten before backend forwarding.
  - Forwarded request `Content-Length` is rebuilt from rewritten body bytes after alias rewrite.
  - Existing authorization port tests still pass.
- Dependency notes:
  - Depends on T2 helper implementation.
- Parallel eligibility:
  - Not parallelizable with T2. Could be implemented before T4 after T2 passes, but verify independently.

## Task 4

- Task id: T4
- Task name: Add safe `/v1/models` response buffering and header reconstruction
- Purpose: Apply model-list filtering only to successful `GET /v1/models` proxy responses while preserving streaming behavior elsewhere.
- Files to create / modify / test:
  - Modify: `src/Sources/ThinkingProxy.swift`
  - Test: `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`
- Concrete steps:
  1. Track whether a forwarded request is eligible for model-list transformation using the T2 eligibility helper: method exactly `GET` and URL path component exactly `/v1/models`; ignore query string for matching by stripping text after `?` from the current parser's `path` value. If the current parser makes query stripping impossible, stop and revise the plan/spec rather than guessing.
  2. Extend the local backend forwarding path so `forwardRequest` / `receiveResponse` can receive a Boolean such as `shouldFilterModelListResponse` without changing default behavior for all existing call sites; derive the Boolean once from the final normalized/forwarded path.
  3. For non-eligible responses, continue calling the existing `streamNextChunk` path unchanged.
  4. For eligible responses, buffer the complete backend response data before sending to the client.
  5. Add the smallest internal response transformation seam, for example `transformModelListHTTPResponseIfEligible(method:path:responseData:) -> Data?` or an equivalent split of eligibility + complete-response reconstruction, so tests can invoke the same logic the buffered response path uses without sockets.
  6. Parse the buffered HTTP response into status line, headers, and body only after headers are complete. Transform only successful `2xx` responses with a safe complete body boundary; otherwise pass through unchanged.
  7. Require a deterministic body boundary before transformation, preferably a valid non-negative `Content-Length` whose byte count exactly matches the buffered body bytes. If `Content-Length` is absent, invalid, or does not match the available body bytes, pass through/stream unchanged; do not guess body completeness.
  8. Enforce HTTP framing constraints before body transformation: if `Content-Encoding` is present, pass through unchanged; if `Transfer-Encoding: chunked` is present, pass through unchanged; if the backend response is keep-alive/framed without a known complete body boundary, continue streaming/pass through unchanged rather than waiting indefinitely. Do not attempt to decode compressed/chunked bodies or indefinitely buffer close-delimited keep-alive responses in this work.
  9. Apply the model-list body helper from T2. If it returns `nil`, send the original buffered response unchanged.
  10. When transformed, rebuild the HTTP response with the original status line, preserve safe response headers, remove or replace stale `Content-Length`, remove stale non-chunked `Transfer-Encoding` metadata if present, set `Content-Length` to the transformed body byte count, set/ensure `Connection: close`, then append transformed body bytes.
  11. Send the rebuilt response once, then complete and cancel connections consistently with current close behavior.
  12. Keep `receiveResponseWith404Retry` behavior unchanged unless execution finds the same forwarding hook is required; `/v1/models` currently starts with `/v1/` and should not use the retry path.
  13. Avoid transforming Vercel responses; this path is only for local backend `/v1/models`.
- Explicit QA / verification:
  - `cd /Volumes/storage/workspace/ccproxy/.worktrees/20260506-model-list-dedupe-b7d3/src && swift test --filter ThinkingProxyModelAliasTests`
  - `cd /Volumes/storage/workspace/ccproxy/.worktrees/20260506-model-list-dedupe-b7d3/src && swift test --filter ThinkingProxyPortTests`
  - `lsp_diagnostics` or equivalent diagnostics on `src/Sources/ThinkingProxy.swift`.
  - Confirm by test or direct code inspection that eligible response transformation requires a known complete body boundary and does not wait indefinitely for absent/invalid framing.
- Expected result:
  - Eligible successful `/v1/models` responses are filtered and have consistent `Content-Length` / `Connection` headers.
  - Malformed, non-JSON, unexpected, non-2xx, encoded, chunked, missing/invalid `Content-Length`, incomplete, keep-alive without known body boundary, or otherwise unsafe eligible responses pass through/stream unchanged.
  - All non-model-list responses continue streaming unchanged.
- Dependency notes:
  - Depends on T2 helper implementation. Should be done after T3 to reduce request-path conflicts in `ThinkingProxy.swift`.
- Parallel eligibility:
  - Not parallelizable with T3 because both modify `ThinkingProxy.swift` request/forwarding flow.

## Task 5

- Task id: T5
- Task name: Complete mandatory response reconstruction and eligibility seam tests
- Purpose: Verify complete HTTP response reconstruction, HTTP framing pass-through, and integration invocation through a small internal seam without adding full socket tests.
- Files to create / modify / test:
  - Modify: `src/Sources/ThinkingProxy.swift` only if T4 did not already extract the smallest internal response transformation seam.
  - Modify: `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`
- Concrete steps:
  1. Ensure T4 exposes the smallest internal test seam that the buffered response path calls for eligible model-list transformation. The seam must accept enough inputs to cover method/path eligibility and complete HTTP response bytes, or a clearly equivalent split where tests cover both eligibility and reconstruction.
  2. Add/complete a test for a complete successful `GET /v1/models` HTTP response with duplicate model-list body and stale `Content-Length`; assert:
     - Returned bytes differ from input.
     - Response body bytes decode to filtered JSON with duplicate aliases removed.
     - Rebuilt `Content-Length` equals the transformed body byte count exactly.
     - `Connection: close` is present exactly once or replaces any prior connection value.
  3. Add/complete a test for transformed responses that include stale non-chunked `Transfer-Encoding` metadata; assert `Transfer-Encoding` is absent from the rebuilt transformed response.
  4. Add/complete pass-through tests asserting the seam returns unchanged input or `nil` according to the helper contract for:
     - Non-2xx status.
     - Invalid JSON body.
     - Missing HTTP header/body separator.
     - Unexpected model-list shape.
     - Any `Content-Encoding` header.
     - `Transfer-Encoding: chunked`.
     - Missing `Content-Length`.
     - Invalid/non-numeric `Content-Length`.
     - `Content-Length` larger than the available body bytes.
     - `Content-Length` smaller than the available body bytes unless the implementation has a clearly safe exact-body rule; default expectation is pass-through rather than guessing.
     - Keep-alive response framing without a deterministic complete body boundary.
  5. Add/complete eligibility invocation tests through the same seam or an adjacent internal helper:
     - `GET /v1/models` transforms when response is otherwise safe.
     - `GET /v1/models?limit=100` transforms by ignoring query string for matching.
     - `POST /v1/models`, `GET /v1/models/extra`, and `GET /api/v1/models` do not transform.
  6. Confirm no test starts a listener, opens a network connection, or requires CLIProxyAPI.
- Explicit QA / verification:
  - `cd /Volumes/storage/workspace/ccproxy/.worktrees/20260506-model-list-dedupe-b7d3/src && swift test --filter ThinkingProxyModelAliasTests`
  - Confirm the response reconstruction tests exercise the same internal seam called by the buffered proxy response path.
  - Confirm tests prove transformation happens only when the seam receives a valid exact `Content-Length` boundary for the complete body, and prove missing/invalid/mismatched length pass-through.
  - Confirm no new external dependency or server startup is introduced by the tests.
- Expected result:
  - Complete HTTP response reconstruction is mandatorily covered for stale `Content-Length`, transformed body bytes, stale `Transfer-Encoding` removal, and `Connection: close`.
  - Fail-safe pass-through is covered for non-2xx, invalid JSON, unsafe shape, encoded, chunked, missing/invalid/mismatched `Content-Length`, incomplete body, and keep-alive without known body boundary responses.
  - Eligibility matching is covered through a small seam without socket tests.
- Dependency notes:
  - Depends on T4 response reconstruction design and seam extraction.
- Parallel eligibility:
  - Not parallelizable with T4. This task is mandatory and must not be skipped.

## Task 6

- Task id: T6
- Task name: Run full regression verification and inspect changed-file diagnostics
- Purpose: Confirm the complete change satisfies the spec and does not regress existing behavior.
- Files to create / modify / test:
  - Test: whole Swift package under `src`
  - Inspect diagnostics for changed Swift files:
    - `src/Sources/ThinkingProxy.swift`
    - `src/Tests/CCProxyTests/ThinkingProxyModelAliasTests.swift`
- Concrete steps:
  1. Run all targeted tests one final time if any changes occurred after the last targeted run.
  2. Run the full suite with `swift test` from the worktree `src` directory.
  3. Run changed-file LSP diagnostics or equivalent compiler diagnostics.
  4. Inspect the final diff to ensure only planned files changed unless a compile-required supporting change is explicitly justified.
  5. Confirm the final alias table still contains exactly the nine spec mappings and does not include Kimi or inferred aliases.
  6. Confirm `ServerManagerConfigTests` still passes and no generated YAML `alias:` behavior was added.
- Explicit QA / verification:
  - `cd /Volumes/storage/workspace/ccproxy/.worktrees/20260506-model-list-dedupe-b7d3/src && swift test --filter ThinkingProxyModelAliasTests`
  - `cd /Volumes/storage/workspace/ccproxy/.worktrees/20260506-model-list-dedupe-b7d3/src && swift test --filter ThinkingProxyPortTests`
  - `cd /Volumes/storage/workspace/ccproxy/.worktrees/20260506-model-list-dedupe-b7d3/src && swift test`
  - `lsp_diagnostics` or equivalent diagnostics on changed Swift files.
- Expected result:
  - Full test suite passes.
  - Changed-file diagnostics have no new errors.
  - Final implementation remains within spec scope.
- Dependency notes:
  - Depends on T1-T5 completion. T5 is mandatory and must not be skipped.
- Parallel eligibility:
  - Not parallelizable; final verification must run after implementation tasks.

# QA Standard

- TDD red/green evidence is required for the new pure helper tests:
  - Red: `swift test --filter ThinkingProxyModelAliasTests` fails before helper implementation.
  - Green: the same command passes after helper implementation.
- Minimum targeted commands:
  - `cd /Volumes/storage/workspace/ccproxy/.worktrees/20260506-model-list-dedupe-b7d3/src && swift test --filter ThinkingProxyModelAliasTests`
  - `cd /Volumes/storage/workspace/ccproxy/.worktrees/20260506-model-list-dedupe-b7d3/src && swift test --filter ThinkingProxyPortTests`
- Required final command:
  - `cd /Volumes/storage/workspace/ccproxy/.worktrees/20260506-model-list-dedupe-b7d3/src && swift test`
- Required behavioral checks:
  - All nine spec alias pairs are covered by tests.
  - Duplicate aliases are removed only when the canonical ID is present.
  - Alias entries remain unchanged when canonical ID is absent.
  - `zai/*`, `minimax/*`, `gpt-*`, and `codex-*` ownership normalization is covered.
  - Unknown/unrelated model entries retain original IDs and `owned_by` values.
  - Request alias rewriting affects only top-level JSON string `model` values.
  - Forwarded request `Content-Length` is rebuilt from the final rewritten body bytes after alias rewrite.
  - `/v1/models` response transformation eligibility is method `GET` plus URL path component exactly `/v1/models`; query strings are ignored for matching, while sibling/prefixed paths are not eligible.
  - Malformed or unexpected JSON responses fail safely without crashing and without partial transforms.
  - Complete HTTP response reconstruction tests are mandatory and cover stale `Content-Length`, transformed body bytes, stale `Transfer-Encoding` removal, `Connection: close`, non-2xx pass-through, invalid JSON pass-through, `Content-Encoding` pass-through, and `Transfer-Encoding: chunked` pass-through.
  - Model-list response transformation requires a safe complete body boundary, preferably exact valid `Content-Length`; tests must cover missing, invalid, and mismatched `Content-Length`, incomplete bodies, and keep-alive/unknown-boundary framing as pass-through/stream unchanged cases.
  - Implementation must not wait indefinitely or guess response completeness for `/v1/models`; unsafe framing falls back to unchanged streaming/pass-through behavior.
  - The response transformation seam used by tests is the same seam invoked by the eligible buffered proxy response path; no socket/listener test is required.
  - Transformed HTTP responses have a correct `Content-Length` and `Connection: close` behavior.
  - Non-`GET /v1/models` responses remain on the existing streaming path.

# Revisions

- Initial plan created for approved spec `20260506-model-list-dedupe-b7d3` using the provided Evidence Packet plus direct reads of `ThinkingProxy.swift`, `ThinkingProxyPortTests.swift`, and `ServerManagerConfigTests.swift`.
- Revised after plan-challenger feedback to make complete HTTP response reconstruction tests mandatory, require request `Content-Length` verification after alias rewrite, define `/v1/models` eligibility by URL path component with query ignored, add HTTP framing pass-through constraints for encoded/chunked responses, and require a smallest response-transformation test seam.
- Revised after remaining plan-challenger risk to require model-list transformation only with a safe complete response body boundary, preferably exact valid `Content-Length`, and to mandate pass-through/stream unchanged behavior for missing/invalid/mismatched length, incomplete body, keep-alive without known boundary, or otherwise unsafe framing.
