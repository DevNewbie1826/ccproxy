import XCTest
@testable import CCProxy

// MARK: - TDD RED phase tests for planned internal helpers
//
// These tests target internal pure helpers planned in ThinkingProxy.swift:
//   - canonicalizeTopLevelModelAlias(in:) -> String?
//   - filterModelListResponseBody(_:) -> Data?
//   - isModelListRequest(method:path:) -> Bool
//
// Expected state: compile failure because helpers do not exist yet.

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
}
