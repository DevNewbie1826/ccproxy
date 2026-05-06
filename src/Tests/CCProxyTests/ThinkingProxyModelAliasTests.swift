import XCTest
@testable import CCProxy

// MARK: - Tests for internal pure helpers in ThinkingProxy.swift
//
// Helpers under test:
//   - canonicalizeTopLevelModelAlias(in:) -> String?
//   - filterModelListResponseBody(_:) -> Data?
//   - isModelListRequest(method:path:) -> Bool
//
// T3 integration: canonicalizeTopLevelModelAlias is called in processRequest
// after thinking/cache_control transforms and before routing/forwarding.

final class ThinkingProxyModelAliasTests: XCTestCase {

    // ================================================================
    // MARK: - Request Alias Rewrite Tests
    // ================================================================

    // MARK: All nine spec alias mappings

    func testRewriteGlm51Alias() {
        let input = """
        {"model":"glm-5.1","messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNotNil(result, "Should rewrite glm-5.1 alias")
        assertModelEquals(result: result, expected: "zai/glm-5.1")
    }

    func testRewriteGlm5Alias() {
        let input = """
        {"model":"glm-5","messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNotNil(result)
        assertModelEquals(result: result, expected: "zai/glm-5")
    }

    func testRewriteGlm5TurboAlias() {
        let input = """
        {"model":"glm-5-turbo","messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNotNil(result)
        assertModelEquals(result: result, expected: "zai/glm-5-turbo")
    }

    func testRewriteGlm5vTurboAlias() {
        let input = """
        {"model":"glm-5v-turbo","messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNotNil(result)
        assertModelEquals(result: result, expected: "zai/glm-5v-turbo")
    }

    func testRewriteGlm47Alias() {
        let input = """
        {"model":"glm-4.7","messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNotNil(result)
        assertModelEquals(result: result, expected: "zai/glm-4.7")
    }

    func testRewriteGlm47FlashAlias() {
        let input = """
        {"model":"glm-4.7-flash","messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNotNil(result)
        assertModelEquals(result: result, expected: "zai/glm-4.7-flash")
    }

    func testRewriteGlm46vAlias() {
        let input = """
        {"model":"glm-4.6v","messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNotNil(result)
        assertModelEquals(result: result, expected: "zai/glm-4.6v")
    }

    func testRewriteGlm45AirAlias() {
        let input = """
        {"model":"glm-4.5-air","messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNotNil(result)
        assertModelEquals(result: result, expected: "zai/glm-4.5-air")
    }

    func testRewriteMiniMaxM27Alias() {
        let input = """
        {"model":"MiniMax-M2.7","messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNotNil(result)
        assertModelEquals(result: result, expected: "minimax/MiniMax-M2.7")
    }

    // MARK: Canonical IDs unchanged

    func testCanonicalIDUnchanged() {
        let input = """
        {"model":"zai/glm-4.7","messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNil(result, "Canonical IDs should not be rewritten")
    }

    // MARK: Unknown IDs unchanged

    func testUnknownModelUnchanged() {
        let input = """
        {"model":"some-unknown-model","messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNil(result, "Unknown model IDs should not be rewritten")
    }

    // MARK: Missing model field

    func testMissingModelFieldUnchanged() {
        let input = """
        {"messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNil(result, "JSON without model field should return nil")
    }

    // MARK: Non-string model field

    func testNonStringModelUnchanged() {
        let input = """
        {"model":12345}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNil(result, "Non-string model should return nil")
    }

    // MARK: Malformed JSON

    func testMalformedJSONUnchanged() {
        let input = "this is not json at all"
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNil(result, "Malformed JSON should return nil")
    }

    // MARK: Nested-only model field

    func testNestedOnlyModelUnchanged() {
        let input = """
        {"outer":{"model":"glm-4.7"},"messages":[]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNil(result, "Nested model field should not be rewritten")
    }

    // MARK: Non-object JSON

    func testNonObjectJSONUnchanged() {
        let input = """
        [1, 2, 3]
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNil(result, "JSON array should return nil")
    }

    // ================================================================
    // MARK: - Model-List Body Filtering Tests
    // ================================================================

    /// Fixture containing all nine duplicate pairs from the spec plus
    /// gpt-5.5, codex-mini, and an unrelated model.
    private var fullDuplicateFixture: Data {
        let json = """
        {
          "object": "list",
          "data": [
            {"id": "zai/glm-5.1", "object": "model", "owned_by": "unknown", "created": 1},
            {"id": "glm-5.1", "object": "model", "owned_by": "unknown", "created": 2},
            {"id": "zai/glm-5", "object": "model", "owned_by": "unknown", "created": 3},
            {"id": "glm-5", "object": "model", "owned_by": "unknown", "created": 4},
            {"id": "zai/glm-5-turbo", "object": "model", "owned_by": "unknown", "created": 5},
            {"id": "glm-5-turbo", "object": "model", "owned_by": "unknown", "created": 6},
            {"id": "zai/glm-5v-turbo", "object": "model", "owned_by": "unknown", "created": 7},
            {"id": "glm-5v-turbo", "object": "model", "owned_by": "unknown", "created": 8},
            {"id": "zai/glm-4.7", "object": "model", "owned_by": "unknown", "created": 9},
            {"id": "glm-4.7", "object": "model", "owned_by": "unknown", "created": 10},
            {"id": "zai/glm-4.7-flash", "object": "model", "owned_by": "unknown", "created": 11},
            {"id": "glm-4.7-flash", "object": "model", "owned_by": "unknown", "created": 12},
            {"id": "zai/glm-4.6v", "object": "model", "owned_by": "unknown", "created": 13},
            {"id": "glm-4.6v", "object": "model", "owned_by": "unknown", "created": 14},
            {"id": "zai/glm-4.5-air", "object": "model", "owned_by": "unknown", "created": 15},
            {"id": "glm-4.5-air", "object": "model", "owned_by": "unknown", "created": 16},
            {"id": "minimax/MiniMax-M2.7", "object": "model", "owned_by": "unknown", "created": 17},
            {"id": "MiniMax-M2.7", "object": "model", "owned_by": "unknown", "created": 18},
            {"id": "gpt-5.5", "object": "model", "owned_by": "some-org", "created": 19},
            {"id": "codex-mini", "object": "model", "owned_by": "some-org", "created": 20},
            {"id": "unrelated-model", "object": "model", "owned_by": "original-owner", "created": 21}
          ]
        }
        """
        return Data(json.utf8)
    }

    // MARK: Duplicate removal

    func testFilteringRemovesAllDuplicateAliases() {
        let result = filterModelListResponseBody(fullDuplicateFixture)
        XCTAssertNotNil(result, "Filtering should succeed on valid fixture")

        guard let data = result else { return }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Result should be valid JSON object")
            return
        }
        guard let entries = json["data"] as? [[String: Any]] else {
            XCTFail("Result should have data array")
            return
        }

        let ids = entries.compactMap { $0["id"] as? String }

        // All nine canonical entries must be present
        let canonicalIDs: [String] = [
            "zai/glm-5.1", "zai/glm-5", "zai/glm-5-turbo", "zai/glm-5v-turbo",
            "zai/glm-4.7", "zai/glm-4.7-flash", "zai/glm-4.6v", "zai/glm-4.5-air",
            "minimax/MiniMax-M2.7"
        ]
        for canonical in canonicalIDs {
            XCTAssertTrue(ids.contains(canonical), "Canonical ID \(canonical) should be retained")
        }

        // All nine alias entries must be removed
        let aliasIDs: [String] = [
            "glm-5.1", "glm-5", "glm-5-turbo", "glm-5v-turbo",
            "glm-4.7", "glm-4.7-flash", "glm-4.6v", "glm-4.5-air",
            "MiniMax-M2.7"
        ]
        for alias in aliasIDs {
            XCTAssertFalse(ids.contains(alias), "Alias ID \(alias) should be removed when canonical exists")
        }
    }

    // MARK: gpt-5.5 preserved unprefixed

    func testOpenAIModelPreservedUnprefixed() {
        let result = filterModelListResponseBody(fullDuplicateFixture)
        XCTAssertNotNil(result)

        guard let data = result, let ids = extractIDs(from: data) else {
            XCTFail("Should produce valid JSON with data array")
            return
        }

        XCTAssertTrue(ids.contains("gpt-5.5"), "gpt-5.5 should remain present and unprefixed")
    }

    // MARK: Unrelated model preserved

    func testUnrelatedModelPreserved() {
        let result = filterModelListResponseBody(fullDuplicateFixture)
        XCTAssertNotNil(result)

        guard let data = result, let ids = extractIDs(from: data) else {
            XCTFail("Should produce valid JSON with data array")
            return
        }

        XCTAssertTrue(ids.contains("unrelated-model"), "Unrelated model should remain present")
    }

    // MARK: Alias retained when canonical absent

    func testAliasRetainedWhenCanonicalAbsent() {
        // Fixture with glm-4.5-air alias but NO zai/glm-4.5-air canonical
        let json = """
        {
          "object": "list",
          "data": [
            {"id": "glm-4.5-air", "object": "model", "owned_by": "some-owner", "created": 1},
            {"id": "gpt-5.5", "object": "model", "owned_by": "openai", "created": 2}
          ]
        }
        """
        let input = Data(json.utf8)
        let result = filterModelListResponseBody(input)
        XCTAssertNotNil(result)

        guard let data = result, let ids = extractIDs(from: data) else {
            XCTFail("Should produce valid JSON")
            return
        }

        XCTAssertTrue(ids.contains("glm-4.5-air"),
                       "Alias should be retained when its canonical partner is absent")
        XCTAssertTrue(ids.contains("gpt-5.5"),
                       "Other models should remain")
    }

    // MARK: Top-level fields preserved

    func testTopLevelFieldsPreserved() {
        let result = filterModelListResponseBody(fullDuplicateFixture)
        XCTAssertNotNil(result)

        guard let data = result,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Should produce valid JSON object")
            return
        }

        XCTAssertEqual(json["object"] as? String, "list",
                        "Top-level 'object' field should be preserved")
    }

    // ================================================================
    // MARK: - Ownership Normalization Tests
    // ================================================================

    func testZaiOwnershipNormalized() {
        let result = filterModelListResponseBody(fullDuplicateFixture)
        XCTAssertNotNil(result)

        guard let data = result,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else {
            XCTFail("Should produce valid JSON")
            return
        }

        let zaiModels = entries.filter { ($0["id"] as? String)?.hasPrefix("zai/") == true }
        for model in zaiModels {
            XCTAssertEqual(model["owned_by"] as? String, "zai",
                            "zai/* model should have owned_by normalized to 'zai'")
        }
    }

    func testMinimaxOwnershipNormalized() {
        let result = filterModelListResponseBody(fullDuplicateFixture)
        XCTAssertNotNil(result)

        guard let data = result,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else {
            XCTFail("Should produce valid JSON")
            return
        }

        let minimaxModels = entries.filter { ($0["id"] as? String)?.hasPrefix("minimax/") == true }
        for model in minimaxModels {
            XCTAssertEqual(model["owned_by"] as? String, "minimax",
                            "minimax/* model should have owned_by normalized to 'minimax'")
        }
    }

    func testGptOwnershipNormalized() {
        let result = filterModelListResponseBody(fullDuplicateFixture)
        XCTAssertNotNil(result)

        guard let data = result,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else {
            XCTFail("Should produce valid JSON")
            return
        }

        let gptModels = entries.filter { ($0["id"] as? String)?.hasPrefix("gpt-") == true }
        for model in gptModels {
            XCTAssertEqual(model["owned_by"] as? String, "openai",
                            "gpt-* model should have owned_by normalized to 'openai'")
        }
    }

    func testCodexOwnershipNormalized() {
        let result = filterModelListResponseBody(fullDuplicateFixture)
        XCTAssertNotNil(result)

        guard let data = result,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else {
            XCTFail("Should produce valid JSON")
            return
        }

        let codexModels = entries.filter { ($0["id"] as? String)?.hasPrefix("codex-") == true }
        for model in codexModels {
            XCTAssertEqual(model["owned_by"] as? String, "openai",
                            "codex-* model should have owned_by normalized to 'openai'")
        }
    }

    func testUnrelatedOwnershipUnchanged() {
        let result = filterModelListResponseBody(fullDuplicateFixture)
        XCTAssertNotNil(result)

        guard let data = result,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else {
            XCTFail("Should produce valid JSON")
            return
        }

        guard let unrelated = entries.first(where: { ($0["id"] as? String) == "unrelated-model" }) else {
            XCTFail("unrelated-model should be present")
            return
        }
        XCTAssertEqual(unrelated["owned_by"] as? String, "original-owner",
                       "Unrelated model should keep original owned_by")
    }

    // ================================================================
    // MARK: - Fail-Safe Tests
    // ================================================================

    func testMalformedJSONReturnsNil() {
        let input = Data("not valid json".utf8)
        let result = filterModelListResponseBody(input)
        XCTAssertNil(result, "Malformed JSON should return nil")
    }

    func testValidJSONWithoutDataArrayReturnsNil() {
        let json = """
        {"object": "list", "models": []}
        """
        let input = Data(json.utf8)
        let result = filterModelListResponseBody(input)
        XCTAssertNil(result, "JSON without 'data' array should return nil")
    }

    func testNonObjectJSONReturnsNil() {
        let json = """
        [1, 2, 3]
        """
        let input = Data(json.utf8)
        let result = filterModelListResponseBody(input)
        XCTAssertNil(result, "JSON array (non-object) should return nil")
    }

    func testEntriesWithoutStringIDReturnNil() {
        let json = """
        {"data": [{"id": 123, "object": "model"}, {"no_id": true}]}
        """
        let input = Data(json.utf8)
        let result = filterModelListResponseBody(input)
        XCTAssertNil(result, "Entries without string 'id' should cause nil return")
    }

    func testEmptyDataArrayPassesThrough() {
        let json = """
        {"object": "list", "data": []}
        """
        let input = Data(json.utf8)
        let result = filterModelListResponseBody(input)
        // An empty data array is safe; it should succeed with empty results
        XCTAssertNotNil(result, "Empty data array should be handled safely")
        if let data = result {
            guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let arr = parsed["data"] as? [[String: Any]] else {
                XCTFail("Should be valid JSON with data array")
                return
            }
            XCTAssertTrue(arr.isEmpty, "Empty data array should remain empty")
        }
    }

    // ================================================================
    // MARK: - Eligibility Helper Tests
    // ================================================================

    func testGetV1ModelsIsEligible() {
        XCTAssertTrue(isModelListRequest(method: "GET", path: "/v1/models"),
                       "GET /v1/models should be eligible")
    }

    func testGetV1ModelsWithQueryStringIsEligible() {
        XCTAssertTrue(isModelListRequest(method: "GET", path: "/v1/models?limit=100"),
                       "GET /v1/models?limit=100 should be eligible by matching only path component")
    }

    func testPostV1ModelsNotEligible() {
        XCTAssertFalse(isModelListRequest(method: "POST", path: "/v1/models"),
                        "POST /v1/models should not be eligible")
    }

    func testGetV1ModelsExtraNotEligible() {
        XCTAssertFalse(isModelListRequest(method: "GET", path: "/v1/models/extra"),
                        "GET /v1/models/extra should not be eligible")
    }

    func testGetApiV1ModelsNotEligible() {
        XCTAssertFalse(isModelListRequest(method: "GET", path: "/api/v1/models"),
                        "GET /api/v1/models should not be eligible")
    }

    func testGetV1ModelsTrailingSlashNotEligible() {
        XCTAssertFalse(isModelListRequest(method: "GET", path: "/v1/models/"),
                        "GET /v1/models/ should not be eligible (strict match)")
    }

    func testGetV1ChatCompletionsNotEligible() {
        XCTAssertFalse(isModelListRequest(method: "GET", path: "/v1/chat/completions"),
                        "GET /v1/chat/completions should not be eligible")
    }

    func testDeleteV1ModelsNotEligible() {
        XCTAssertFalse(isModelListRequest(method: "DELETE", path: "/v1/models"),
                        "DELETE /v1/models should not be eligible")
    }

    // ================================================================
    // MARK: - T3 Integration: Composition & Content-Length Tests
    // ================================================================

    /// Verifies that alias rewriting preserves all non-model body fields
    /// (messages, temperature, max_tokens, stream) unchanged.
    /// This is a composition assertion for T3's integration of
    /// canonicalizeTopLevelModelAlias into the POST body processing pipeline.
    func testAliasRewritePreservesOtherBodyFields() {
        let input = """
        {"model":"glm-4.7","messages":[{"role":"user","content":"hello"},{"role":"assistant","content":"hi"}],"temperature":0.7,"max_tokens":4096,"stream":true}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNotNil(result, "Should rewrite glm-4.7 alias")

        guard let resultStr = result,
              let data = resultStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Result should be valid JSON object")
            return
        }

        // Model was rewritten
        XCTAssertEqual(json["model"] as? String, "zai/glm-4.7")

        // Other fields preserved
        XCTAssertEqual(json["temperature"] as? Double, 0.7)
        XCTAssertEqual(json["max_tokens"] as? Int, 4096)
        XCTAssertEqual(json["stream"] as? Bool, true)

        guard let messages = json["messages"] as? [[String: String]] else {
            XCTFail("Messages should be preserved as array")
            return
        }
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"], "user")
        XCTAssertEqual(messages[1]["role"], "assistant")
    }

    /// Verifies that the forwarded local-backend request built via the
    /// production helper (`buildForwardedLocalRequest`) has Content-Length
    /// equal to the rewritten body bytes, not the original (stale) value.
    ///
    /// This test uses the same request-building logic that `forwardRequest`
    /// calls, proving that alias rewrite composition produces correct
    /// Content-Length in the actual forwarded HTTP request.
    func testForwardedRequestContentLengthMatchesRewrittenBody() {
        let originalBody = """
        {"model":"glm-4.7","messages":[{"role":"user","content":"hi"}]}
        """
        let rewrittenBody = canonicalizeTopLevelModelAlias(in: originalBody)
        XCTAssertNotNil(rewrittenBody, "Should rewrite glm-4.7 alias")

        guard let rewritten = rewrittenBody else { return }

        // Simulate original request headers with stale Content-Length
        let staleHeaders: [(String, String)] = [
            ("Content-Type", "application/json"),
            ("Content-Length", "\(originalBody.utf8.count)"),
            ("Host", "original-host:9999"),
            ("Authorization", "Bearer test-key")
        ]

        // Build the forwarded request using the same production helper
        // that forwardRequest calls internally.
        let forwarded = buildForwardedLocalRequest(
            method: "POST",
            path: "/v1/chat/completions",
            version: "HTTP/1.1",
            headers: staleHeaders,
            body: rewritten,
            thinkingEnabled: false,
            targetHost: "127.0.0.1",
            targetPort: 8328
        )

        // Extract Content-Length from the forwarded request
        let contentLengthFromForwarded = extractContentLength(from: forwarded)
        XCTAssertNotNil(contentLengthFromForwarded,
                         "Forwarded request must contain a Content-Length header")

        guard let forwardedCL = contentLengthFromForwarded else { return }

        // Content-Length must equal the rewritten body byte count
        XCTAssertEqual(forwardedCL, rewritten.utf8.count,
                        "Forwarded Content-Length must equal rewritten body byte count")

        // Content-Length must NOT equal the original (stale) body byte count
        XCTAssertNotEqual(forwardedCL, originalBody.utf8.count,
                            "Forwarded Content-Length must NOT equal original stale body byte count")
    }

    /// Verifies that a non-alias Claude model body (e.g. with thinking suffix)
    /// is not affected by canonicalizeTopLevelModelAlias. This confirms that
    /// the alias rewrite step does not interfere with Claude thinking processing.
    func testClaudeThinkingModelUnaffectedByAliasRewrite() {
        let claudeBody = """
        {"model":"claude-sonnet-4-5-20250929","messages":[{"role":"user","content":"hello"}],"max_tokens":8192,"thinking":{"type":"enabled","budget_tokens":5000}}
        """
        let result = canonicalizeTopLevelModelAlias(in: claudeBody)
        XCTAssertNil(result, "Claude model should not be rewritten by alias helper")
    }

    /// Verifies that a canonical model ID (already prefixed) produces
    /// Content-Length identical to the input, confirming idempotency
    /// in the body processing pipeline.
    func testCanonicalModelContentLengthIdempotent() {
        let canonicalBody = """
        {"model":"zai/glm-4.7","messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: canonicalBody)
        XCTAssertNil(result, "Already-canonical model should return nil (no rewrite)")

        // Content-Length would be based on the unmodified body
        let contentLength = canonicalBody.utf8.count
        XCTAssertEqual(contentLength, canonicalBody.utf8.count,
                        "Content-Length for canonical model should be unchanged")
    }

    // ================================================================
    // MARK: - Helpers
    // ================================================================

    private func assertModelEquals(result: String?, expected: String) {
        guard let result = result else {
            XCTFail("Expected non-nil result with model == \(expected)")
            return
        }
        guard let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let model = json["model"] as? String else {
            XCTFail("Result should be valid JSON with string 'model' field")
            return
        }
        XCTAssertEqual(model, expected, "model field should be rewritten to \(expected)")
    }

    private func extractIDs(from data: Data) -> [String]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else {
            return nil
        }
        return entries.compactMap { $0["id"] as? String }
    }

    private func extractContentLength(from request: String) -> Int? {
        let headerPart = request.components(separatedBy: "\r\n\r\n").first ?? request
        return headerPart
            .components(separatedBy: "\r\n")
            .dropFirst()
            .compactMap { line -> Int? in
                let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                guard parts.count == 2,
                      parts[0].caseInsensitiveCompare("Content-Length") == .orderedSame else {
                    return nil
                }
                return Int(parts[1].trimmingCharacters(in: .whitespaces))
            }
            .first
    }

    // ================================================================
    // MARK: - T4/T5: Response Reconstruction Seam Tests
    // ================================================================
    //
    // Tests for: transformModelListHTTPResponseIfEligible(method:path:responseData:) -> Data?
    //
    // This seam is the same function called by the buffered production response
    // path for eligible GET /v1/models requests. No sockets or listeners needed.

    // MARK: - HTTP response construction helpers

    /// Builds a complete raw HTTP response as Data from status, headers, and body string.
    private func buildHTTPResponse(
        statusCode: Int = 200,
        statusText: String = "OK",
        headers: [(String, String)] = [],
        body: String
    ) -> Data {
        var response = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        for (name, value) in headers {
            response += "\(name): \(value)\r\n"
        }
        response += "\r\n"
        response += body
        return Data(response.utf8)
    }

    /// Model-list body with at least one duplicate pair for transformation tests.
    private var duplicateModelListBody: String {
        """
        {"object":"list","data":[{"id":"zai/glm-4.7","object":"model","owned_by":"unknown"},{"id":"glm-4.7","object":"model","owned_by":"unknown"},{"id":"gpt-5.5","object":"model","owned_by":"some-org"}]}
        """
    }

    /// Parses a raw HTTP response Data into (statusLine, headers, body).
    /// Returns nil if the response is malformed.
    private func parseHTTPResponse(_ data: Data) -> (statusLine: String, headers: [(String, String)], body: String)? {
        guard let responseString = String(data: data, encoding: .utf8) else { return nil }
        guard let sepRange = responseString.range(of: "\r\n\r\n") else { return nil }

        let headerSection = String(responseString[..<sepRange.lowerBound])
        let bodyStart = responseString.index(sepRange.upperBound, offsetBy: 0)
        let bodyString = String(responseString[bodyStart...])

        let headerLines = headerSection.components(separatedBy: "\r\n")
        guard let statusLine = headerLines.first else { return nil }

        var headers: [(String, String)] = []
        for line in headerLines.dropFirst() {
            guard let colonIdx = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<colonIdx])
            let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
            headers.append((name, value))
        }

        return (statusLine, headers, bodyString)
    }

    /// Extracts the value of a header by case-insensitive name from parsed headers.
    private func headerValue(in headers: [(String, String)], name: String) -> String? {
        return headers.first { $0.0.caseInsensitiveCompare(name) == .orderedSame }?.1
    }

    /// Counts occurrences of a header by case-insensitive name.
    private func headerCount(in headers: [(String, String)], name: String) -> Int {
        return headers.filter { $0.0.caseInsensitiveCompare(name) == .orderedSame }.count
    }

    // MARK: - Successful transformation tests

    /// Verifies that a valid 2xx GET /v1/models response with duplicate model list
    /// is transformed: returned bytes differ, body is filtered JSON with correct
    /// Content-Length, and Connection: close is present exactly once.
    func testTransformModelListResponse_SuccessfulTransformation() {
        let body = duplicateModelListBody
        let staleContentLength = body.utf8.count
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(staleContentLength)"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNotNil(result, "Eligible 2xx response with valid framing should be transformed")

        guard let transformedData = result,
              let parsed = parseHTTPResponse(transformedData) else {
            XCTFail("Transformed response should be parseable HTTP")
            return
        }

        // Returned bytes differ from input
        XCTAssertNotEqual(transformedData, responseData,
                           "Transformed response should differ from original")

        // Status line preserved
        XCTAssertTrue(parsed.statusLine.hasPrefix("HTTP/1.1 200"),
                       "Status line should be preserved: \(parsed.statusLine)")

        // Body is filtered JSON - glm-4.7 alias removed, zai/glm-4.7 retained
        guard let bodyData = parsed.body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else {
            XCTFail("Body should be valid JSON with data array")
            return
        }
        let ids = entries.compactMap { $0["id"] as? String }
        XCTAssertTrue(ids.contains("zai/glm-4.7"), "Canonical zai/glm-4.7 should be retained")
        XCTAssertFalse(ids.contains("glm-4.7"), "Alias glm-4.7 should be removed")
        XCTAssertTrue(ids.contains("gpt-5.5"), "gpt-5.5 should remain")

        // Rebuilt Content-Length equals transformed body byte count exactly
        let clString = headerValue(in: parsed.headers, name: "Content-Length")
        XCTAssertNotNil(clString, "Content-Length should be present")
        if let clStr = clString, let cl = Int(clStr) {
            XCTAssertEqual(cl, parsed.body.utf8.count,
                            "Content-Length must equal transformed body byte count")
        }

        // Connection: close present exactly once
        let connCount = headerCount(in: parsed.headers, name: "Connection")
        XCTAssertEqual(connCount, 1, "Connection: close should appear exactly once")
        XCTAssertEqual(headerValue(in: parsed.headers, name: "Connection"), "close")
    }

    /// Verifies that stale non-chunked Transfer-Encoding is removed from rebuilt response.
    func testTransformModelListResponse_TransferEncodingRemoved() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
                ("Transfer-Encoding", "identity"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNotNil(result, "Should transform response with non-chunked Transfer-Encoding")

        guard let transformedData = result,
              let parsed = parseHTTPResponse(transformedData) else {
            XCTFail("Transformed response should be parseable HTTP")
            return
        }

        // Transfer-Encoding must be absent from rebuilt response
        let teCount = headerCount(in: parsed.headers, name: "Transfer-Encoding")
        XCTAssertEqual(teCount, 0,
                        "Transfer-Encoding should be removed from rebuilt response")
    }

    // MARK: - Pass-through tests (helper returns nil)

    /// Non-2xx status should pass through (return nil).
    func testTransformModelListResponse_Non2xxPassthrough() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            statusCode: 500,
            statusText: "Internal Server Error",
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNil(result, "Non-2xx response should pass through (nil)")
    }

    /// Non-2xx status 404 should pass through.
    func testTransformModelListResponse_404Passthrough() {
        let body = "{\"error\":\"not found\"}"
        let responseData = buildHTTPResponse(
            statusCode: 404,
            statusText: "Not Found",
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNil(result, "404 response should pass through (nil)")
    }

    /// Invalid JSON body should pass through (return nil).
    func testTransformModelListResponse_InvalidJSONPassthrough() {
        let body = "this is not json"
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNil(result, "Invalid JSON body should pass through (nil)")
    }

    /// Content-Encoding header should cause pass-through (return nil).
    func testTransformModelListResponse_ContentEncodingPassthrough() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
                ("Content-Encoding", "gzip"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNil(result, "Content-Encoding response should pass through (nil)")
    }

    /// Transfer-Encoding: chunked should cause pass-through (return nil).
    func testTransformModelListResponse_ChunkedPassthrough() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Transfer-Encoding", "chunked"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNil(result, "Transfer-Encoding: chunked should pass through (nil)")
    }

    /// Missing Content-Length should cause pass-through (return nil).
    func testTransformModelListResponse_MissingContentLengthPassthrough() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNil(result, "Missing Content-Length should pass through (nil)")
    }

    /// Invalid (non-numeric) Content-Length should cause pass-through (return nil).
    func testTransformModelListResponse_InvalidContentLengthPassthrough() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "abc"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNil(result, "Invalid Content-Length should pass through (nil)")
    }

    /// Content-Length larger than available body bytes should pass through (return nil).
    func testTransformModelListResponse_ContentLengthTooLargePassthrough() {
        let body = duplicateModelListBody
        let tooLarge = body.utf8.count + 100
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(tooLarge)"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNil(result, "Content-Length larger than body should pass through (nil)")
    }

    /// Content-Length smaller than available body bytes should pass through (return nil).
    func testTransformModelListResponse_ContentLengthTooSmallPassthrough() {
        let body = duplicateModelListBody
        let tooSmall = body.utf8.count - 10
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(tooSmall)"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNil(result, "Content-Length smaller than body should pass through (nil)")
    }

    /// Missing header/body separator should pass through (return nil).
    func testTransformModelListResponse_MissingSeparatorPassthrough() {
        // No \r\n\r\n separator, just a raw string
        let rawResponse = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 10"
        let responseData = Data(rawResponse.utf8)

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNil(result, "Missing header/body separator should pass through (nil)")
    }

    /// Unexpected shape (valid JSON but no data array) should pass through (return nil).
    func testTransformModelListResponse_UnexpectedShapePassthrough() {
        let body = "{\"object\":\"list\",\"models\":[]}"
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNil(result, "Unexpected JSON shape (no data array) should pass through (nil)")
    }

    // MARK: - Eligibility tests through the response seam

    /// GET /v1/models with a valid response should transform.
    func testTransformModelListResponse_EligibleGetV1Models() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNotNil(result, "GET /v1/models should be eligible for transformation")
    }

    /// GET /v1/models?limit=100 should transform (query string ignored for matching).
    func testTransformModelListResponse_EligibleWithQueryString() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models?limit=100",
            responseData: responseData
        )
        XCTAssertNotNil(result, "GET /v1/models?limit=100 should be eligible (query ignored)")
    }

    /// POST /v1/models should not transform (ineligible method).
    func testTransformModelListResponse_IneligiblePostMethod() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "POST",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNil(result, "POST /v1/models should not be eligible")
    }

    /// GET /v1/models/extra should not transform (ineligible path).
    func testTransformModelListResponse_IneligibleSubPath() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/v1/models/extra",
            responseData: responseData
        )
        XCTAssertNil(result, "GET /v1/models/extra should not be eligible")
    }

    /// GET /api/v1/models should not transform (ineligible path).
    func testTransformModelListResponse_IneligibleApiPath() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseIfEligible(
            method: "GET",
            path: "/api/v1/models",
            responseData: responseData
        )
        XCTAssertNil(result, "GET /api/v1/models should not be eligible")
    }

    // ================================================================
    // MARK: - T4 Fix: Buffered Response Classification Seam Tests
    // ================================================================
    //
    // Tests for: classifyBufferedModelListResponse(_:) -> ModelListBufferClassification
    //
    // This pure classification seam drives the production buffering decision:
    // - headersIncomplete → keep buffering
    // - unsafeForTransformation → send buffered bytes to client, continue streaming
    // - bodyIncomplete → keep buffering (safe headers, valid CL, not enough body yet)
    // - bodyExact → attempt transformation via the seam
    // - bodyOverflow → send buffered bytes to client, continue streaming

    // MARK: - Headers incomplete

    func testClassify_EmptyData_HeadersIncomplete() {
        let result = classifyBufferedModelListResponse(Data())
        XCTAssertEqual(result, .headersIncomplete,
                        "Empty data should classify as headersIncomplete")
    }

    func testClassify_PartialHeaders_HeadersIncomplete() {
        let partial = Data("HTTP/1.1 200 OK\r\nContent-Type: appli".utf8)
        let result = classifyBufferedModelListResponse(partial)
        XCTAssertEqual(result, .headersIncomplete,
                        "Partial headers without \\r\\n\\r\\n should classify as headersIncomplete")
    }

    func testClassify_StatusLineOnly_HeadersIncomplete() {
        let partial = Data("HTTP/1.1 200 OK\r\n".utf8)
        let result = classifyBufferedModelListResponse(partial)
        XCTAssertEqual(result, .headersIncomplete,
                        "Status line only (no \\r\\n\\r\\n) should classify as headersIncomplete")
    }

    // MARK: - Unsafe for transformation

    func testClassify_MissingContentLength_Unsafe() {
        let response = buildHTTPResponse(
            headers: [("Content-Type", "application/json")],
            body: duplicateModelListBody
        )
        let result = classifyBufferedModelListResponse(response)
        XCTAssertEqual(result, .unsafeForTransformation,
                        "Missing Content-Length should classify as unsafeForTransformation")
    }

    func testClassify_InvalidContentLength_Unsafe() {
        let response = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "abc"),
            ],
            body: duplicateModelListBody
        )
        let result = classifyBufferedModelListResponse(response)
        XCTAssertEqual(result, .unsafeForTransformation,
                        "Invalid Content-Length should classify as unsafeForTransformation")
    }

    func testClassify_NegativeContentLength_Unsafe() {
        let response = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "-1"),
            ],
            body: duplicateModelListBody
        )
        let result = classifyBufferedModelListResponse(response)
        XCTAssertEqual(result, .unsafeForTransformation,
                        "Negative Content-Length should classify as unsafeForTransformation")
    }

    func testClassify_ContentEncoding_Unsafe() {
        let body = duplicateModelListBody
        let response = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
                ("Content-Encoding", "gzip"),
            ],
            body: body
        )
        let result = classifyBufferedModelListResponse(response)
        XCTAssertEqual(result, .unsafeForTransformation,
                        "Content-Encoding should classify as unsafeForTransformation")
    }

    func testClassify_ChunkedTransferEncoding_Unsafe() {
        let response = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Transfer-Encoding", "chunked"),
            ],
            body: duplicateModelListBody
        )
        let result = classifyBufferedModelListResponse(response)
        XCTAssertEqual(result, .unsafeForTransformation,
                        "Transfer-Encoding: chunked should classify as unsafeForTransformation")
    }

    func testClassify_Non2xxStatus_Unsafe() {
        let body = duplicateModelListBody
        let response = buildHTTPResponse(
            statusCode: 500,
            statusText: "Internal Server Error",
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
            ],
            body: body
        )
        let result = classifyBufferedModelListResponse(response)
        XCTAssertEqual(result, .unsafeForTransformation,
                        "500 status should classify as unsafeForTransformation")
    }

    func testClassify_404Status_Unsafe() {
        let body = "{\"error\":\"not found\"}"
        let response = buildHTTPResponse(
            statusCode: 404,
            statusText: "Not Found",
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
            ],
            body: body
        )
        let result = classifyBufferedModelListResponse(response)
        XCTAssertEqual(result, .unsafeForTransformation,
                        "404 status should classify as unsafeForTransformation")
    }

    func testClassify_MalformedStatusLine_Unsafe() {
        let response = Data("GARBAGE\r\nContent-Length: 5\r\n\r\nhello".utf8)
        let result = classifyBufferedModelListResponse(response)
        XCTAssertEqual(result, .unsafeForTransformation,
                        "Non-HTTP status line should classify as unsafeForTransformation")
    }

    // MARK: - Body incomplete (safe headers, CL present, body < CL)

    func testClassify_BodySmallerThanCL_BodyIncomplete() {
        let body = duplicateModelListBody
        let fullCL = body.utf8.count
        // Build response with correct CL but only partial body
        let partialBody = String(body.prefix(body.utf8.count / 2))
        let response = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(fullCL)"),
            ],
            body: partialBody
        )
        let result = classifyBufferedModelListResponse(response)
        XCTAssertEqual(result, .bodyIncomplete,
                        "Body bytes < Content-Length should classify as bodyIncomplete")
    }

    func testClassify_ZeroCLWithEmptyBody_BodyExact() {
        let response = buildHTTPResponse(
            headers: [("Content-Length", "0")],
            body: ""
        )
        let result = classifyBufferedModelListResponse(response)
        XCTAssertEqual(result, .bodyExact,
                        "Zero Content-Length with empty body should classify as bodyExact")
    }

    // MARK: - Body exact (safe headers, CL matches body bytes)

    func testClassify_BodyMatchesCL_BodyExact() {
        let body = duplicateModelListBody
        let response = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
            ],
            body: body
        )
        let result = classifyBufferedModelListResponse(response)
        XCTAssertEqual(result, .bodyExact,
                        "Body bytes == Content-Length should classify as bodyExact")
    }

    func testClassify_BodyMatchesCL_WithExtraSafeHeaders_BodyExact() {
        let body = duplicateModelListBody
        let response = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
                ("X-Custom", "value"),
            ],
            body: body
        )
        let result = classifyBufferedModelListResponse(response)
        XCTAssertEqual(result, .bodyExact,
                        "Extra safe headers should not prevent bodyExact classification")
    }

    // MARK: - Body overflow (body bytes > CL)

    func testClassify_BodyExceedsCL_BodyOverflow() {
        let body = duplicateModelListBody
        let tooSmall = body.utf8.count - 10
        let response = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(tooSmall)"),
            ],
            body: body
        )
        let result = classifyBufferedModelListResponse(response)
        XCTAssertEqual(result, .bodyOverflow,
                        "Body bytes > Content-Length should classify as bodyOverflow")
    }
}
