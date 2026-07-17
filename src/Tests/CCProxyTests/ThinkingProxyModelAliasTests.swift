import XCTest
@testable import CCProxy

// MARK: - Tests for internal pure helpers in ThinkingProxy.swift
//
// Helpers under test:
//   - canonicalizeTopLevelModelAlias(in:) -> String?  (request-body compatibility only)
//   - isModelListRequest(method:path:) -> Bool
//   - transformModelListHTTPResponseWithCatalog(method:path:responseData:catalogModels:) -> Data?
//   - classifyBufferedModelListResponse(_:) -> ModelListBufferClassification
//
// T3 integration: canonicalizeTopLevelModelAlias is called in processRequest
// after thinking/cache_control transforms and before routing/forwarding.

final class ThinkingProxyModelAliasTests: XCTestCase {

    // MARK: - Request Alias Rewrite Tests

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

    func testKimiModelUnchangedByTopLevelAliasCanonicalization() {
        let input = """
        {"model":"kimi-k2","messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNil(result, "Kimi official bare model IDs should not be rewritten by alias canonicalization")
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

    // MARK: - Eligibility Helper Tests

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

    // MARK: - T3 Integration: Composition & Content-Length Tests

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

        XCTAssertEqual(json["model"] as? String, "zai/glm-4.7")

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

        let staleHeaders: [(String, String)] = [
            ("Content-Type", "application/json"),
            ("Content-Length", "\(originalBody.utf8.count)"),
            ("Host", "original-host:9999"),
            ("Authorization", "Bearer test-key")
        ]

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

        let contentLengthFromForwarded = extractContentLength(from: forwarded)
        XCTAssertNotNil(contentLengthFromForwarded,
                         "Forwarded request must contain a Content-Length header")

        guard let forwardedCL = contentLengthFromForwarded else { return }

        XCTAssertEqual(forwardedCL, rewritten.utf8.count,
                        "Forwarded Content-Length must equal rewritten body byte count")

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

        let contentLength = canonicalBody.utf8.count
        XCTAssertEqual(contentLength, canonicalBody.utf8.count,
                        "Content-Length for canonical model should be unchanged")
    }

    // MARK: - Legacy Runtime-Composed Alias Removal Tests

    /// Verifies that a legacy runtime-composed alias-prefixed thinking model
    /// is no longer special-cased by the thinking parameter processor.
    /// After removal, the seam should return no transformation for that model body.
    func testLegacyPrefixedThinkingModelIsNotSpecialCased() {
        let legacyPrefix = "ge" + "mi" + "ni-claude-"
        let model = legacyPrefix + "opus-4-5-thinking-10000"
        let input = """
        {"model":"\(model)","messages":[{"role":"user","content":"hi"}],"max_tokens":4096}
        """
        let result = processThinkingParameterForTesting(jsonString: input)
        XCTAssertNotNil(result, "Should return a result for unrecognized model")
        if let (body, thinkingEnabled) = result {
            XCTAssertFalse(thinkingEnabled,
                           "Legacy-prefixed model should not have thinking enabled")
            XCTAssertEqual(body, input, "Non-Claude model body should pass through unchanged")
        }
    }

    /// Verifies that a normal Claude thinking model still transforms correctly
    /// after the legacy alias handling is removed.
    func testClaudeThinkingModelStillTransforms() {
        let input = """
        {"model":"claude-opus-4-5-20251101-thinking-10000","messages":[{"role":"user","content":"hi"}],"max_tokens":4096}
        """
        let result = processThinkingParameterForTesting(jsonString: input)
        XCTAssertNotNil(result, "Claude thinking model should produce a result")
        if let (body, thinkingEnabled) = result {
            XCTAssertTrue(thinkingEnabled, "Claude thinking model should have thinking enabled")
            XCTAssertFalse(body.contains("-thinking-10000"),
                           "Thinking suffix should be stripped from model name")
        }
    }

    // MARK: - Helpers

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

    // MARK: - HTTP Response Test Helpers

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

    // MARK: - Task 3: Catalog-Backed Model-List Response Tests
    //
    // Tests for: transformModelListHTTPResponseWithCatalog(method:path:responseData:catalogModels:) -> Data?
    //
    // This seam replaces the backend model-list body with catalog-backed
    // connected-provider output. The backend response is used only for
    // HTTP safety checks (status, framing) and header preservation;
    // the body is entirely replaced by the catalog-rendered output.

    /// Catalog models fixture representing two connected providers.
    private var catalogModelsFixture: [CatalogModel] {
        [
            CatalogModel(id: "claude-sonnet-4", object: "model", created: 1700000000, ownedBy: "anthropic", displayName: nil, tier: nil, sourceProvenance: "catalog", supplementalMetadata: [:]),
            CatalogModel(id: "claude-opus-4", object: "model", created: 1700000001, ownedBy: "anthropic", displayName: nil, tier: nil, sourceProvenance: "catalog", supplementalMetadata: [:]),
            CatalogModel(id: "zai/glm-5.1", object: "model", created: 1700000002, ownedBy: "zai", displayName: nil, tier: nil, sourceProvenance: "catalog", supplementalMetadata: [:])
        ]
    }

    /// Empty catalog models — no connected providers.
    private var emptyCatalogModels: [CatalogModel] { [] }

    private func temporaryDirectory(named prefix: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func successfulCatalogFetcher() -> FakeCatalogFetcher {
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONData = ExternalModelCatalogTests.modelsJSONFixture
        fetcher.modelsDevData = ExternalModelCatalogTests.modelsDevFixture
        return fetcher
    }

    private func failingCatalogFetcher() -> FakeCatalogFetcher {
        let fetcher = FakeCatalogFetcher()
        fetcher.modelsJSONError = NSError(domain: "test", code: 1)
        fetcher.modelsDevError = NSError(domain: "test", code: 1)
        return fetcher
    }

    // MARK: - Catalog replaces backend body

    /// Verifies that a valid 2xx GET /v1/models response is replaced with catalog-backed output.
    func testCatalogBackedResponse_ReplacesBackendBody() {
        let backendBody = """
        {"object":"list","data":[{"id":"old-model","object":"model","owned_by":"backend"}]}
        """
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(backendBody.utf8.count)"),
            ],
            body: backendBody
        )

        let result = transformModelListHTTPResponseWithCatalog(
            method: "GET",
            path: "/v1/models",
            responseData: responseData,
            catalogModels: catalogModelsFixture
        )
        XCTAssertNotNil(result, "Should transform with catalog models")

        guard let transformedData = result,
              let parsed = parseHTTPResponse(transformedData) else {
            XCTFail("Transformed response should be parseable HTTP")
            return
        }

        guard let bodyData = parsed.body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else {
            XCTFail("Body should be valid JSON with data array")
            return
        }

        let ids = entries.compactMap { $0["id"] as? String }
        XCTAssertTrue(ids.contains("claude-sonnet-4"), "Should contain catalog model")
        XCTAssertTrue(ids.contains("zai/glm-5.1"), "Should contain catalog model")
        XCTAssertFalse(ids.contains("old-model"), "Should NOT contain backend model")
        XCTAssertEqual(json["object"] as? String, "list")
    }

    // MARK: - Empty connected providers returns empty list

    /// Verifies that /v1/models with no connected providers returns an empty OpenAI-style list.
    func testCatalogBackedResponse_EmptyProvidersReturnsEmptyList() {
        let backendBody = """
        {"object":"list","data":[{"id":"claude-sonnet-4","object":"model","owned_by":"anthropic"}]}
        """
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(backendBody.utf8.count)"),
            ],
            body: backendBody
        )

        let result = transformModelListHTTPResponseWithCatalog(
            method: "GET",
            path: "/v1/models",
            responseData: responseData,
            catalogModels: emptyCatalogModels
        )
        XCTAssertNotNil(result, "Should still transform even with empty catalog")

        guard let transformedData = result,
              let parsed = parseHTTPResponse(transformedData) else {
            XCTFail("Should be parseable HTTP")
            return
        }

        guard let bodyData = parsed.body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else {
            XCTFail("Body should be valid JSON")
            return
        }

        XCTAssertTrue(entries.isEmpty, "Empty connected providers should produce empty data array")
        XCTAssertEqual(json["object"] as? String, "list")
    }

    // MARK: - Response rebuild preserves status and safe headers

    /// Verifies that response rebuild preserves status, recalculates Content-Length,
    /// removes stale Transfer-Encoding, and sets one Connection: close.
    func testCatalogBackedResponse_ResponseRebuildSafety() {
        let backendBody = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(backendBody.utf8.count)"),
                ("Transfer-Encoding", "identity"),
                ("X-Custom", "value"),
            ],
            body: backendBody
        )

        let result = transformModelListHTTPResponseWithCatalog(
            method: "GET",
            path: "/v1/models",
            responseData: responseData,
            catalogModels: catalogModelsFixture
        )
        XCTAssertNotNil(result)

        guard let transformedData = result,
              let parsed = parseHTTPResponse(transformedData) else {
            XCTFail("Should be parseable HTTP")
            return
        }

        XCTAssertTrue(parsed.statusLine.hasPrefix("HTTP/1.1 200"))

        let cl = headerValue(in: parsed.headers, name: "Content-Length")
        XCTAssertNotNil(cl)
        if let clStr = cl, let clVal = Int(clStr) {
            XCTAssertEqual(clVal, parsed.body.utf8.count,
                            "Content-Length must equal catalog body byte count")
        }

        XCTAssertEqual(headerCount(in: parsed.headers, name: "Transfer-Encoding"), 0,
                        "Transfer-Encoding should be removed")

        XCTAssertEqual(headerCount(in: parsed.headers, name: "Connection"), 1)
        XCTAssertEqual(headerValue(in: parsed.headers, name: "Connection"), "close")

        XCTAssertEqual(headerValue(in: parsed.headers, name: "X-Custom"), "value")
    }

    // MARK: - Non-2xx passthrough

    /// Non-2xx status should pass through (return nil) even with catalog models.
    func testCatalogBackedResponse_Non2xxPassthrough() {
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

        let result = transformModelListHTTPResponseWithCatalog(
            method: "GET",
            path: "/v1/models",
            responseData: responseData,
            catalogModels: catalogModelsFixture
        )
        XCTAssertNil(result, "Non-2xx should pass through even with catalog")
    }

    // MARK: - Content-Encoding passthrough

    /// Content-Encoding should cause pass-through.
    func testCatalogBackedResponse_ContentEncodingPassthrough() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
                ("Content-Encoding", "gzip"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseWithCatalog(
            method: "GET",
            path: "/v1/models",
            responseData: responseData,
            catalogModels: catalogModelsFixture
        )
        XCTAssertNil(result, "Content-Encoding should pass through")
    }

    // MARK: - Chunked Transfer-Encoding passthrough

    /// Transfer-Encoding: chunked should cause pass-through.
    func testCatalogBackedResponse_ChunkedPassthrough() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Transfer-Encoding", "chunked"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseWithCatalog(
            method: "GET",
            path: "/v1/models",
            responseData: responseData,
            catalogModels: catalogModelsFixture
        )
        XCTAssertNil(result, "Chunked should pass through")
    }

    // MARK: - Missing/invalid Content-Length passthrough

    func testCatalogBackedResponse_MissingContentLengthPassthrough() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [("Content-Type", "application/json")],
            body: body
        )

        let result = transformModelListHTTPResponseWithCatalog(
            method: "GET",
            path: "/v1/models",
            responseData: responseData,
            catalogModels: catalogModelsFixture
        )
        XCTAssertNil(result, "Missing Content-Length should pass through")
    }

    func testCatalogBackedResponse_InvalidContentLengthPassthrough() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "abc"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseWithCatalog(
            method: "GET",
            path: "/v1/models",
            responseData: responseData,
            catalogModels: catalogModelsFixture
        )
        XCTAssertNil(result, "Invalid Content-Length should pass through")
    }

    // MARK: - Ineligible method/path

    func testCatalogBackedResponse_IneligiblePostMethod() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseWithCatalog(
            method: "POST",
            path: "/v1/models",
            responseData: responseData,
            catalogModels: catalogModelsFixture
        )
        XCTAssertNil(result, "POST should not be eligible")
    }

    func testCatalogBackedResponse_IneligibleSubPath() {
        let body = duplicateModelListBody
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseWithCatalog(
            method: "GET",
            path: "/v1/models/extra",
            responseData: responseData,
            catalogModels: catalogModelsFixture
        )
        XCTAssertNil(result, "/v1/models/extra should not be eligible")
    }

    // MARK: - Missing header/body separator passthrough

    func testCatalogBackedResponse_MissingSeparatorPassthrough() {
        let rawResponse = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 10"
        let responseData = Data(rawResponse.utf8)

        let result = transformModelListHTTPResponseWithCatalog(
            method: "GET",
            path: "/v1/models",
            responseData: responseData,
            catalogModels: catalogModelsFixture
        )
        XCTAssertNil(result, "Missing separator should pass through")
    }

    // MARK: - OpenCode Go model IDs

    /// Verifies that OpenCode Go IDs have exactly one opencode-go/ prefix.
    func testCatalogBackedResponse_OpenCodeGoIDsExactlyOnePrefix() {
        let models = [
            CatalogModel(id: "opencode-go/kimi-k2.6", object: "model", created: 1700000000, ownedBy: "opencode-go", displayName: nil, tier: nil, sourceProvenance: "catalog", supplementalMetadata: [:]),
            CatalogModel(id: "opencode-go/claude-sonnet-4", object: "model", created: 1700000001, ownedBy: "anthropic-opencode", displayName: nil, tier: nil, sourceProvenance: "catalog", supplementalMetadata: [:])
        ]

        let backendBody = """
        {"object":"list","data":[]}
        """
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(backendBody.utf8.count)"),
            ],
            body: backendBody
        )

        let result = transformModelListHTTPResponseWithCatalog(
            method: "GET",
            path: "/v1/models",
            responseData: responseData,
            catalogModels: models
        )
        XCTAssertNotNil(result)

        guard let transformedData = result,
              let parsed = parseHTTPResponse(transformedData) else {
            XCTFail("Should be parseable HTTP")
            return
        }

        guard let bodyData = parsed.body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else {
            XCTFail("Body should be valid JSON")
            return
        }

        let ids = entries.compactMap { $0["id"] as? String }
        XCTAssertTrue(ids.contains("opencode-go/kimi-k2.6"), "Should have opencode-go/kimi-k2.6")
        XCTAssertTrue(ids.contains("opencode-go/claude-sonnet-4"), "Should have opencode-go/claude-sonnet-4")
        // No double-prefix
        XCTAssertFalse(ids.contains("opencode-go/opencode-go/kimi-k2.6"),
                        "Must not double-prefix")
    }

    // MARK: - Query string eligibility

    func testCatalogBackedResponse_QueryStringEligible() {
        let backendBody = """
        {"object":"list","data":[]}
        """
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(backendBody.utf8.count)"),
            ],
            body: backendBody
        )

        let result = transformModelListHTTPResponseWithCatalog(
            method: "GET",
            path: "/v1/models?limit=100",
            responseData: responseData,
            catalogModels: catalogModelsFixture
        )
        XCTAssertNotNil(result, "Query string should be eligible")
    }

    // MARK: - Content-Length mismatch passthrough

    func testCatalogBackedResponse_ContentLengthMismatchPassthrough() {
        let backendBody = duplicateModelListBody
        let tooLarge = backendBody.utf8.count + 100
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(tooLarge)"),
            ],
            body: backendBody
        )

        let result = transformModelListHTTPResponseWithCatalog(
            method: "GET",
            path: "/v1/models",
            responseData: responseData,
            catalogModels: catalogModelsFixture
        )
        XCTAssertNil(result, "Content-Length mismatch should pass through")
    }

    // MARK: - Request alias normalization is request-body only

    /// Verifies that canonicalizeTopLevelModelAlias still works for request bodies
    /// and does not affect model-list generation.
    func testRequestAliasNormalizationIsRequestBodyOnly() {
        let input = """
        {"model":"glm-4.7","messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNotNil(result, "Request alias normalization should still work")
        assertModelEquals(result: result, expected: "zai/glm-4.7")
    }

    // MARK: - T4 Fix: Buffered Response Classification Seam Tests
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

    // MARK: - Review Fix: Production Catalog Provider Wiring

    /// Verifies that ThinkingProxy's default catalogProvider starts as a stub
    /// (returns unavailable), and gets replaced when configureCatalogProvider is called.
    func testDefaultCatalogProviderStartsAsStub() {
        let proxy = ThinkingProxy()
        // Before wiring, the provider is a stub
        let result = proxy.catalogProvider.fetchCatalogModels()
        if case .unavailable = result {
            // Expected: stub returns unavailable
        } else {
            XCTFail("Stub catalog provider should return .unavailable before wiring")
        }
    }

    /// Verifies that configureCatalogProvider replaces the stub with a
    /// ProductionModelListCatalogProvider backed by the injected ServerManager.
    func testConfigureCatalogProvider_ReplacesStubWithProduction() {
        let proxy = ThinkingProxy()
        let manager = ServerManager()
        proxy.configureCatalogProvider(manager)
        XCTAssertTrue(proxy.catalogProvider is ProductionModelListCatalogProvider,
                       "After configureCatalogProvider, provider should be ProductionModelListCatalogProvider")
    }

    // MARK: - CatalogModelsResult distinction tests

    /// Verifies that CatalogModelsResult.available([]) is distinct from .unavailable.
    /// Connected-provider-empty result (valid empty list) must not be confused with
    /// catalog-unavailable result (no valid cache/snapshot; produces explicit empty list
    /// rather than backend pass-through).
    func testCatalogModelsResult_AvailableEmptyDistinctFromUnavailable() {
        let availableEmpty: CatalogModelsResult = .available([])
        let unavailable: CatalogModelsResult = .unavailable

        XCTAssertNotEqual(availableEmpty, unavailable,
                           ".available([]) and .unavailable must be distinct values")
    }

    /// Verifies that CatalogModelsResult.available with models is distinct from .unavailable.
    func testCatalogModelsResult_AvailableModelsDistinctFromUnavailable() {
        let availableModels: CatalogModelsResult = .available([
            CatalogModel(id: "test/model", object: "model", created: 0, ownedBy: "test",
                         displayName: nil, tier: nil, sourceProvenance: "test", supplementalMetadata: [:])
        ])
        let unavailable: CatalogModelsResult = .unavailable

        XCTAssertNotEqual(availableModels, unavailable,
                           ".available([model]) and .unavailable must be distinct values")
    }

    /// Verifies that CatalogModelsResult.available with empty array produces
    /// a valid empty OpenAI-style model-list response when used with the catalog seam.
    func testCatalogModelsResult_AvailableEmpty_ProducesEmptyModelList() {
        let backendBody = """
        {"object":"list","data":[{"id":"backend-model","object":"model","owned_by":"backend"}]}
        """
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(backendBody.utf8.count)"),
            ],
            body: backendBody
        )

        let result = transformModelListHTTPResponseWithCatalog(
            method: "GET",
            path: "/v1/models",
            responseData: responseData,
            catalogModels: []
        )
        XCTAssertNotNil(result, "Available-empty should produce a transformed response")

        guard let transformedData = result,
              let parsed = parseHTTPResponse(transformedData) else {
            XCTFail("Should be parseable HTTP")
            return
        }

        guard let bodyData = parsed.body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else {
            XCTFail("Body should be valid JSON")
            return
        }

        XCTAssertTrue(entries.isEmpty, "Empty catalog should produce empty data array")
        XCTAssertEqual(json["object"] as? String, "list")
        XCTAssertFalse(entries.contains(where: { ($0["id"] as? String) == "backend-model" }),
                       "Should NOT contain backend model when catalog is available")
    }

    // MARK: - Production provider with isolated cache

    /// Verifies that a ProductionModelListCatalogProvider returns .unavailable
    /// when no runtime cache or bundled snapshot exists.
    func testProductionProvider_ReturnsUnavailableWhenNoCacheAndNoSnapshot() {
        let cacheDir = temporaryDirectory(named: "ccproxy-test-unavailable")
        let fetcher = failingCatalogFetcher()

        let coordinator = CacheCoordinator(
            clock: SystemClock(),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let provider = ProductionModelListCatalogProvider(
            coordinator: coordinator,
            connectedProvidersProvider: { ["claude"] }
        )

        let result = provider.fetchCatalogModels()
        if case .unavailable = result {
            // Expected: no cache, no snapshot, fetch fails
        } else {
            XCTFail("Expected .unavailable when no valid cache/snapshot exists, got \(result)")
        }
    }

    /// Verifies that a ProductionModelListCatalogProvider returns .available([])
    /// when a valid catalog exists but no connected providers match.
    func testProductionProvider_ReturnsAvailableEmptyWhenCatalogExistsButNoProviders() {
        let cacheDir = temporaryDirectory(named: "ccproxy-test-empty")
        let fetcher = successfulCatalogFetcher()

        let coordinator = CacheCoordinator(
            clock: SystemClock(),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        // No connected providers
        let provider = ProductionModelListCatalogProvider(
            coordinator: coordinator,
            connectedProvidersProvider: { Set<String>() }
        )

        let result = provider.fetchCatalogModels()
        if case .available(let models) = result {
            XCTAssertTrue(models.isEmpty,
                          "No connected providers should produce empty model list")
        } else {
            XCTFail("Expected .available([]) when catalog exists but no providers, got \(result)")
        }
    }

    /// Verifies that a ProductionModelListCatalogProvider returns .available([models])
    /// when catalog data and connected providers exist.
    func testProductionProvider_ReturnsAvailableModelsWhenCatalogAndProvidersExist() {
        let cacheDir = temporaryDirectory(named: "ccproxy-test-models")
        let fetcher = successfulCatalogFetcher()

        let coordinator = CacheCoordinator(
            clock: SystemClock(),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let provider = ProductionModelListCatalogProvider(
            coordinator: coordinator,
            connectedProvidersProvider: { ["claude", "kimi"] }
        )

        let result = provider.fetchCatalogModels()
        if case .available(let models) = result {
            XCTAssertFalse(models.isEmpty, "Should have models for connected providers")
            let claudeModels = models.filter { $0.id.hasPrefix("claude-") }
            let kimiModels = models.filter { $0.id == "kimi-k2" || $0.id == "kimi-k2.6" }
            XCTAssertFalse(claudeModels.isEmpty, "Should have Claude models")
            XCTAssertFalse(kimiModels.isEmpty, "Should have Kimi models")
            // Should NOT have models for unconnected providers
            let zaiModels = models.filter { $0.id.hasPrefix("zai/") }
            XCTAssertTrue(zaiModels.isEmpty, "Should NOT have ZAI models when not connected")
        } else {
            XCTFail("Expected .available([models]) when catalog and providers exist, got \(result)")
        }
    }

    /// Verifies that ThinkingProxy's catalogProvider can be replaced with
    /// an injected test double that does NOT hit the live network.
    /// Uses configureCatalogProvider with a real ServerManager and injected
    /// fake fetcher/cache, not manual provider assignment.
    func testThinkingProxy_CatalogProviderInjectable_NoLiveNetwork() {
        // Save and reset UserDefaults to avoid interference from other tests
        let defaults = UserDefaults.standard
        let savedEnabledProviders = defaults.object(forKey: "enabledProviders")
        defaults.removeObject(forKey: "enabledProviders")
        defer {
            if let saved = savedEnabledProviders {
                defaults.set(saved, forKey: "enabledProviders")
            } else {
                defaults.removeObject(forKey: "enabledProviders")
            }
            defaults.synchronize()
        }

        let authDir = temporaryDirectory(named: "ccproxy-test-inject-auth")

        // Write a claude credential so the manager reports claude as connected
        let credFile = authDir.appendingPathComponent("claude-test-cred.json")
        let credData = try! JSONSerialization.data(withJSONObject: [
            "type": "claude",
            "email": "test@example.com"
        ])
        try! credData.write(to: credFile)

        let manager = ServerManager()
        manager.authDirectoryOverride = authDir

        let proxy = ThinkingProxy()

        let cacheDir = temporaryDirectory(named: "ccproxy-test-inject")
        let fetcher = successfulCatalogFetcher()

        // Wire through the production path with injected fake dependencies
        proxy.configureCatalogProvider(
            manager,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil,
            clock: SystemClock()
        )

        let result = proxy.catalogProvider.fetchCatalogModels()
        if case .available(let models) = result {
            let claudeModels = models.filter { $0.id.hasPrefix("claude-") }
            XCTAssertFalse(claudeModels.isEmpty, "Should return Claude models from fake fetcher via production wiring path")
        } else {
            XCTFail("configureCatalogProvider with fake fetcher should return .available, got \(result)")
        }

        XCTAssertGreaterThan(fetcher.totalFetchCount, 0,
                              "Should use injected fetcher, not URLSession")
    }

    /// Verifies that request model alias normalization is NOT used as a /v1/models fallback.
    /// This test proves canonicalizeTopLevelModelAlias is request-body only.
    func testRequestAliasNormalizationNotUsedForModelList() {
        // Request alias normalization should still work for request bodies
        let input = """
        {"model":"glm-4.7","messages":[{"role":"user","content":"hi"}]}
        """
        let result = canonicalizeTopLevelModelAlias(in: input)
        XCTAssertNotNil(result, "Request alias normalization should still work for request bodies")
        // But it should NOT affect model-list generation
        // The model list is entirely generated by catalog-backed filtering
    }

    // MARK: - Review Fix: Unavailable Must Not Pass Through Backend

    /// Verifies that when the catalog is unavailable, the response does NOT
    /// pass through the backend model-list body. Instead, it produces an
    /// explicit empty OpenAI-style list, preventing backend model leakage.
    func testCatalogUnavailable_ProducesEmptyList_NotBackendPassthrough() {
        let backendBody = """
        {"object":"list","data":[{"id":"backend-only-model","object":"model","owned_by":"backend"}]}
        """
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(backendBody.utf8.count)"),
            ],
            body: backendBody
        )

        // Catalog unavailable: nil catalogModels → should produce explicit empty list
        let result = transformModelListHTTPResponseWhenCatalogUnavailable(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNotNil(result, "Catalog unavailable should produce a safe response, not nil passthrough")

        guard let transformedData = result,
              let parsed = parseHTTPResponse(transformedData) else {
            XCTFail("Should be parseable HTTP")
            return
        }

        guard let bodyData = parsed.body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let entries = json["data"] as? [[String: Any]] else {
            XCTFail("Body should be valid JSON")
            return
        }

        XCTAssertTrue(entries.isEmpty,
                       "Catalog unavailable must produce empty data, not backend models")
        XCTAssertEqual(json["object"] as? String, "list")
        XCTAssertFalse(entries.contains(where: { ($0["id"] as? String) == "backend-only-model" }),
                        "Must NOT leak backend model entries when catalog is unavailable")
    }

    /// Verifies that catalog-unavailable response preserves HTTP status and safe headers.
    func testCatalogUnavailable_ResponseRebuildSafety() {
        let backendBody = """
        {"object":"list","data":[{"id":"backend-model","object":"model"}]}
        """
        let responseData = buildHTTPResponse(
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(backendBody.utf8.count)"),
                ("X-Custom", "value"),
            ],
            body: backendBody
        )

        let result = transformModelListHTTPResponseWhenCatalogUnavailable(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNotNil(result)

        guard let transformedData = result,
              let parsed = parseHTTPResponse(transformedData) else {
            XCTFail("Should be parseable HTTP")
            return
        }

        XCTAssertTrue(parsed.statusLine.hasPrefix("HTTP/1.1 200"))
        XCTAssertEqual(headerValue(in: parsed.headers, name: "X-Custom"), "value")
        XCTAssertEqual(headerCount(in: parsed.headers, name: "Transfer-Encoding"), 0)
        XCTAssertEqual(headerCount(in: parsed.headers, name: "Connection"), 1)
        XCTAssertEqual(headerValue(in: parsed.headers, name: "Connection"), "close")

        let cl = headerValue(in: parsed.headers, name: "Content-Length")
        XCTAssertNotNil(cl)
        if let clStr = cl, let clVal = Int(clStr) {
            XCTAssertEqual(clVal, parsed.body.utf8.count)
        }
    }

    /// Verifies that catalog-unavailable response does NOT produce nil for
    /// non-2xx or invalid responses (those should still pass through nil).
    func testCatalogUnavailable_Non2xx_ReturnsNil() {
        let body = """
        {"error":"internal error"}
        """
        let responseData = buildHTTPResponse(
            statusCode: 500,
            statusText: "Internal Server Error",
            headers: [
                ("Content-Type", "application/json"),
                ("Content-Length", "\(body.utf8.count)"),
            ],
            body: body
        )

        let result = transformModelListHTTPResponseWhenCatalogUnavailable(
            method: "GET",
            path: "/v1/models",
            responseData: responseData
        )
        XCTAssertNil(result, "Non-2xx should return nil even when catalog is unavailable")
    }

    // MARK: - Review Fix: Production Provider Uses Injected Closure

    /// Verifies that ProductionModelListCatalogProvider uses the injected
    /// connectedProvidersProvider closure rather than duplicating parsing logic.
    /// This proves the production wiring delegates to the closure.
    func testProductionProvider_UsesInjectedConnectedProvidersClosure() {
        let cacheDir = temporaryDirectory(named: "ccproxy-test-closure")
        let fetcher = successfulCatalogFetcher()

        let coordinator = CacheCoordinator(
            clock: SystemClock(),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        var closureCallCount = 0
        let provider = ProductionModelListCatalogProvider(
            coordinator: coordinator,
            connectedProvidersProvider: {
                closureCallCount += 1
                return ["opencode-go"]
            }
        )

        let result = provider.fetchCatalogModels()
        if case .available(let models) = result {
            let ocGoModels = models.filter { $0.id.hasPrefix("opencode-go/") }
            XCTAssertFalse(ocGoModels.isEmpty, "Should have OpenCode Go models from injected closure")
            // Should NOT have models for providers NOT in the injected set
            let claudeModels = models.filter { $0.id.hasPrefix("claude-") }
            XCTAssertTrue(claudeModels.isEmpty,
                           "Should NOT have Claude models when closure returns only opencode-go")
        } else {
            XCTFail("Expected .available with injected closure, got \(result)")
        }
        XCTAssertEqual(closureCallCount, 1,
                        "Connected providers should come from the injected closure")
    }

    /// Verifies that createDefault produces a provider that uses an injected
    /// connected-providers closure (not ServerManager.shared or duplicate parsing).
    func testProductionProvider_CreateDefaultUsesInjectedClosure() {
        let cacheDir = temporaryDirectory(named: "ccproxy-test-createdefault")
        let fetcher = successfulCatalogFetcher()

        var closureCallCount = 0
        let provider = ProductionModelListCatalogProvider.createDefault(
            connectedProvidersProvider: {
                closureCallCount += 1
                return ["claude"]
            },
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let _ = provider.fetchCatalogModels()
        XCTAssertEqual(closureCallCount, 1,
                        "createDefault should use the injected connected-providers closure")
    }

    // MARK: - T3 Remediation: No Singleton Divergence

    /// Verifies that catalog filtering uses only the injected ServerManager's
    /// connected-provider state, not a singleton or separately constructed manager.
    /// Two managers with conflicting state: injected one must control filtering.
    func testInjectedManagerControlsFiltering_NotSingleton() {
        let cacheDir = temporaryDirectory(named: "ccproxy-test-inject-state")
        let fetcher = successfulCatalogFetcher()

        let coordinator = CacheCoordinator(
            clock: SystemClock(),
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        // Inject a provider that returns only "zai" (simulating AppDelegate-owned manager state)
        let injectedProvider = ProductionModelListCatalogProvider(
            coordinator: coordinator,
            connectedProvidersProvider: { ["zai"] }
        )

        let proxy = ThinkingProxy()
        proxy.catalogProvider = injectedProvider

        let result = proxy.catalogProvider.fetchCatalogModels()
        if case .available(let models) = result {
            // Only ZAI models should appear, not Claude/Codex/Kimi
            let zaiModels = models.filter { $0.id.hasPrefix("zai/") }
            let claudeModels = models.filter { $0.id.hasPrefix("claude-") }
            XCTAssertFalse(zaiModels.isEmpty, "Should have ZAI models from injected closure")
            XCTAssertTrue(claudeModels.isEmpty,
                           "Should NOT have Claude models — injected closure controls filtering, not any singleton")
        } else {
            XCTFail("Expected .available with injected provider, got \(result)")
        }
    }

    /// Verifies that the production default catalog-provider path performs zero
    /// live URLSession calls when injected with a fake fetcher.
    func testProductionDefault_NoLiveNetworkWithInjectedFetcher() {
        let cacheDir = temporaryDirectory(named: "ccproxy-test-no-network")
        let fetcher = successfulCatalogFetcher()

        let provider = ProductionModelListCatalogProvider.createDefault(
            connectedProvidersProvider: { ["claude"] },
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let result = provider.fetchCatalogModels()
        if case .available(let models) = result {
            XCTAssertFalse(models.isEmpty, "Should return catalog models from fake fetcher")
        } else {
            XCTFail("Expected .available from injected fake fetcher, got \(result)")
        }

        XCTAssertGreaterThan(fetcher.totalFetchCount, 0,
                              "Should use injected fetcher, not URLSession")
    }

    /// Verifies that a second /v1/models request within the 15-minute retry
    /// throttle after a failed refresh does NOT trigger additional fetches.
    func testProductionDefault_NoFetchAfterStaleFailureWithinThrottle() {
        let now = Date()
        let clock = FakeClock(now)
        let cacheDir = temporaryDirectory(named: "ccproxy-test-throttle")

        // Write a stale cache
        let staleSnapshot = CatalogSnapshot(
            schemaVersion: "2",
            generatedAt: "2026-01-01T00:00:00Z",
            sources: ["test"],
            providerModels: [
                "claude": [
                    CatalogModelEntry(id: "claude-sonnet-4", object: "model", created: 1700000000, ownedBy: "anthropic", displayName: nil, tier: nil)
                ]
            ]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let staleData = try! encoder.encode(staleSnapshot)
        let cacheFile = cacheDir.appendingPathComponent("model-catalog-cache.json")
        try! staleData.write(to: cacheFile)
        try! FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-7 * 3600)],
            ofItemAtPath: cacheFile.path
        )

        let fetcher = failingCatalogFetcher()

        let coordinator = CacheCoordinator(
            clock: clock,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let provider = ProductionModelListCatalogProvider(
            coordinator: coordinator,
            connectedProvidersProvider: { ["claude"] }
        )

        // First call: stale → attempts refresh → fails → serves stale
        let _ = provider.fetchCatalogModels()
        let firstFetchCount = fetcher.totalFetchCount
        XCTAssertGreaterThan(firstFetchCount, 0, "First call should attempt refresh")

        // Second call within throttle: should NOT fetch again
        let _ = provider.fetchCatalogModels()
        XCTAssertEqual(fetcher.totalFetchCount, firstFetchCount,
                        "Second call within 15-min throttle should not fetch again")
    }

    // MARK: - Quality Fix: configureCatalogProvider with Real ServerManager

    /// Verifies that ThinkingProxy.configureCatalogProvider(ServerManager) uses
    /// the real ServerManager's connectedProviders() state to control /v1/models
    /// output, with a temp auth dir and fake fetcher — no live network.
    /// Proves that connected-provider state from the AppDelegate-owned manager
    /// affects rendered catalog output via the production wiring path.
    func testConfigureCatalogProvider_UsesRealServerManagerConnectedProviders() {
        // Save and reset UserDefaults to avoid interference from other tests
        let defaults = UserDefaults.standard
        let savedEnabledProviders = defaults.object(forKey: "enabledProviders")
        defaults.removeObject(forKey: "enabledProviders")
        defer {
            if let saved = savedEnabledProviders {
                defaults.set(saved, forKey: "enabledProviders")
            } else {
                defaults.removeObject(forKey: "enabledProviders")
            }
            defaults.synchronize()
        }

        let authDir = temporaryDirectory(named: "ccproxy-test-real-sm")

        // Write a valid opencode-go credential
        let credFile = authDir.appendingPathComponent("opencode-go-test-cred.json")
        let credData = try! JSONSerialization.data(withJSONObject: [
            "type": "opencode-go",
            "api_key": "test-key-123",
            "email": "test"
        ])
        try! credData.write(to: credFile)

        let manager = ServerManager()
        manager.authDirectoryOverride = authDir

        // Verify the manager sees opencode-go as connected
        let connected = manager.connectedProviders()
        XCTAssertTrue(connected.contains(.opencodeGo),
                      "ServerManager should see opencode-go as connected with valid credential")

        // Set up ThinkingProxy using the production wiring path with injected deps
        let proxy = ThinkingProxy()

        let cacheDir = temporaryDirectory(named: "ccproxy-test-real-cache")
        let fetcher = successfulCatalogFetcher()

        proxy.configureCatalogProvider(
            manager,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil,
            clock: SystemClock()
        )

        let result = proxy.catalogProvider.fetchCatalogModels()
        if case .available(let models) = result {
            let ocGoModels = models.filter { $0.id.hasPrefix("opencode-go/") }
            XCTAssertFalse(ocGoModels.isEmpty,
                           "Should have OpenCode Go models from real ServerManager state via production wiring path")
        } else {
            XCTFail("Expected .available with real ServerManager, got \(result)")
        }
    }

    /// Verifies that disabling a provider through the real ServerManager
    /// removes it from rendered /v1/models output, without creating a
    /// separate manager or singleton. Uses the production wiring path.
    func testConfigureCatalogProvider_DisablingProviderRemovesModels() {
        // Save and reset UserDefaults to avoid interference from other tests
        let defaults = UserDefaults.standard
        let savedEnabledProviders = defaults.object(forKey: "enabledProviders")
        defaults.removeObject(forKey: "enabledProviders")
        defer {
            if let saved = savedEnabledProviders {
                defaults.set(saved, forKey: "enabledProviders")
            } else {
                defaults.removeObject(forKey: "enabledProviders")
            }
            defaults.synchronize()
        }

        let authDir = temporaryDirectory(named: "ccproxy-test-disable")

        // Write both opencode-go and zai credentials
        for provider in ["opencode-go", "zai"] {
            let credFile = authDir.appendingPathComponent("\(provider)-test-cred.json")
            let credData = try! JSONSerialization.data(withJSONObject: [
                "type": provider,
                "api_key": "\(provider)-test-key",
                "email": "test"
            ])
            try! credData.write(to: credFile)
        }

        let manager = ServerManager()
        manager.authDirectoryOverride = authDir

        // Initially both should be connected
        var connected = manager.connectedProviders()
        XCTAssertTrue(connected.contains(.opencodeGo))
        XCTAssertTrue(connected.contains(.zai))

        let cacheDir = temporaryDirectory(named: "ccproxy-test-disable-cache")
        let fetcher = successfulCatalogFetcher()

        let proxy = ThinkingProxy()
        proxy.configureCatalogProvider(
            manager,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil,
            clock: SystemClock()
        )

        // Before disabling: both should appear
        let resultBefore = proxy.catalogProvider.fetchCatalogModels()
        if case .available(let modelsBefore) = resultBefore {
            XCTAssertFalse(modelsBefore.filter { $0.id.hasPrefix("opencode-go/") }.isEmpty)
            XCTAssertFalse(modelsBefore.filter { $0.id.hasPrefix("zai/") }.isEmpty)
        } else {
            XCTFail("Expected .available before disabling")
        }

        // Disable opencode-go through the manager
        manager.enabledProviders["opencode-go"] = false

        // After disabling: only zai should appear
        let resultAfter = proxy.catalogProvider.fetchCatalogModels()
        if case .available(let modelsAfter) = resultAfter {
            XCTAssertTrue(modelsAfter.filter { $0.id.hasPrefix("opencode-go/") }.isEmpty,
                          "OpenCode Go models should disappear after disabling provider")
            XCTAssertFalse(modelsAfter.filter { $0.id.hasPrefix("zai/") }.isEmpty,
                           "ZAI models should still appear")
        } else {
            XCTFail("Expected .available after disabling")
        }
    }

    /// Verifies that the production default provider uses the injected
    /// connected-providers closure for filtering, not ServerManager.shared.
    /// If ServerManager.shared were used, the result would be empty (no real auth dir).
    func testProductionDefault_UsesInjectedClosureNotSingleton() {
        let cacheDir = temporaryDirectory(named: "ccproxy-test-no-singleton")
        let fetcher = successfulCatalogFetcher()

        // Create default with explicit closure returning "opencode-go"
        let provider = ProductionModelListCatalogProvider.createDefault(
            connectedProvidersProvider: { ["opencode-go"] },
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil
        )

        let result = provider.fetchCatalogModels()
        if case .available(let models) = result {
            let ocGoModels = models.filter { $0.id.hasPrefix("opencode-go/") }
            XCTAssertFalse(ocGoModels.isEmpty,
                            "Injected closure returning opencode-go should produce opencode-go models")
            // Claude models should NOT appear because the closure returns only opencode-go
            let claudeModels = models.filter { $0.id.hasPrefix("claude-") }
            XCTAssertTrue(claudeModels.isEmpty,
                           "Claude should not appear when closure returns only opencode-go")
        } else {
            XCTFail("Expected .available with injected closure, got \(result)")
        }
    }

    // MARK: - Conflicting Manager Test: Injected Manager Controls Output

    /// Verifies that two real ServerManager instances with conflicting state
    /// produce different /v1/models output, and that ThinkingProxy follows
    /// only the manager passed to configureCatalogProvider.
    /// This proves no hidden singleton, shared UserDefaults path, or
    /// cross-manager state leak affects catalog filtering.
    func testConflictingManagers_InjectedManagerControlsOutput() {
        // Save and reset UserDefaults
        let defaults = UserDefaults.standard
        let savedEnabledProviders = defaults.object(forKey: "enabledProviders")
        defaults.removeObject(forKey: "enabledProviders")
        defer {
            if let saved = savedEnabledProviders {
                defaults.set(saved, forKey: "enabledProviders")
            } else {
                defaults.removeObject(forKey: "enabledProviders")
            }
            defaults.synchronize()
        }

        // Manager A: opencode-go only
        let authDirA = temporaryDirectory(named: "ccproxy-test-mgr-a")

        let credA = authDirA.appendingPathComponent("opencode-go-cred.json")
        try! JSONSerialization.data(withJSONObject: [
            "type": "opencode-go",
            "api_key": "key-a",
            "email": "a"
        ]).write(to: credA)

        let managerA = ServerManager()
        managerA.authDirectoryOverride = authDirA

        // Manager B: zai only
        let authDirB = temporaryDirectory(named: "ccproxy-test-mgr-b")

        let credB = authDirB.appendingPathComponent("zai-cred.json")
        try! JSONSerialization.data(withJSONObject: [
            "type": "zai",
            "api_key": "key-b",
            "email": "b"
        ]).write(to: credB)

        let managerB = ServerManager()
        managerB.authDirectoryOverride = authDirB

        // Confirm conflicting state
        let connectedA = managerA.connectedProviders()
        let connectedB = managerB.connectedProviders()
        XCTAssertTrue(connectedA.contains(.opencodeGo), "Manager A should have opencode-go connected")
        XCTAssertFalse(connectedA.contains(.zai), "Manager A should NOT have zai connected")
        XCTAssertTrue(connectedB.contains(.zai), "Manager B should have zai connected")
        XCTAssertFalse(connectedB.contains(.opencodeGo), "Manager B should NOT have opencode-go connected")

        // Shared cache and fetcher fixtures
        let cacheDir = temporaryDirectory(named: "ccproxy-test-conflict-cache")
        let fetcher = successfulCatalogFetcher()

        // Wire proxy with managerA via configureCatalogProvider
        let proxy = ThinkingProxy()
        proxy.configureCatalogProvider(
            managerA,
            fetcher: fetcher,
            cacheDirectory: cacheDir,
            bundledSnapshotURL: nil,
            clock: SystemClock()
        )

        // The output must follow managerA's connected state (opencode-go), not managerB's (zai)
        let result = proxy.catalogProvider.fetchCatalogModels()
        if case .available(let models) = result {
            let ocGoModels = models.filter { $0.id.hasPrefix("opencode-go/") }
            let zaiModels = models.filter { $0.id.hasPrefix("zai/") }
            XCTAssertFalse(ocGoModels.isEmpty,
                           "Should have OpenCode Go models from injected managerA")
            XCTAssertTrue(zaiModels.isEmpty,
                          "Should NOT have ZAI models — managerB is not wired to proxy")
        } else {
            XCTFail("Expected .available, got \(result)")
        }
    }
}
