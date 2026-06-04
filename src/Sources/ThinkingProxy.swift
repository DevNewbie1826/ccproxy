import Foundation
import Network

/**
 A lightweight HTTP proxy that intercepts requests to add extended thinking parameters
 for Claude models based on model name suffixes.
 
 Model name pattern:
 - `*-thinking-NUMBER` → Custom token budget (e.g., claude-sonnet-4-5-20250929-thinking-5000)
 
 The proxy strips the suffix and adds the `thinking` parameter to the request body
 before forwarding to CLIProxyAPI.
 
 Examples:
 - claude-sonnet-4-5-20250929-thinking-2000 → 2,000 token budget
 - claude-sonnet-4-5-20250929-thinking-8000 → 8,000 token budget
 */
struct VercelGatewayConfig {
    var enabled: Bool
    var apiKey: String

    var isActive: Bool { enabled && !apiKey.isEmpty }
}

class ThinkingProxy {
    private var listener: NWListener?
    let proxyPort: UInt16 = 8317
    private let targetPort: UInt16 = 8328
    private let targetHost = "127.0.0.1"
    private(set) var isRunning = false
    private let stateQueue = DispatchQueue(label: "com.devnewbie1826.ccproxy.thinking-proxy-state")

    var vercelConfig = VercelGatewayConfig(enabled: false, apiKey: "")

    private var localProxySecret: String {
        UserDefaults.standard.string(forKey: "managementSecretKey") ?? ""
    }
    
    private enum Config {
        static let hardTokenCap = 32000
        static let minimumHeadroom = 1024
        static let headroomRatio = 0.1
        static let vercelGatewayHost = "ai-gateway.vercel.sh"
        static let anthropicVersion = "2023-06-01"
    }
    
    /**
     Starts the thinking proxy server on port 8317
     */
    func start() {
        guard !isRunning else {
            NSLog("[ThinkingProxy] Already running")
            return
        }
        
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            
            guard let port = NWEndpoint.Port(rawValue: proxyPort) else {
                NSLog("[ThinkingProxy] Invalid port: %d", proxyPort)
                return
            }
            listener = try NWListener(using: parameters, on: port)
            
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    DispatchQueue.main.async {
                        self?.isRunning = true
                    }
                    NSLog("[ThinkingProxy] Listening on port \(self?.proxyPort ?? 0)")
                case .failed(let error):
                    NSLog("[ThinkingProxy] Failed: \(error)")
                    DispatchQueue.main.async {
                        self?.isRunning = false
                    }
                case .cancelled:
                    NSLog("[ThinkingProxy] Cancelled")
                    DispatchQueue.main.async {
                        self?.isRunning = false
                    }
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
            
        } catch {
            NSLog("[ThinkingProxy] Failed to start: \(error)")
        }
    }
    
    /**
     Stops the thinking proxy server
     */
    func stop() {
        stateQueue.sync {
            guard isRunning else { return }
            
            listener?.cancel()
            listener = nil
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
            }
            NSLog("[ThinkingProxy] Stopped")
        }
    }
    
    /**
     Handles an incoming connection from a client
     */
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        receiveRequest(from: connection)
    }
    
    /**
     Receives the HTTP request from the client
     Accumulates data until full request is received (handles large payloads)
     */
    private func receiveRequest(from connection: NWConnection, accumulatedData: Data = Data()) {
        // Start the iterative receive loop
        receiveNextChunk(from: connection, accumulatedData: accumulatedData)
    }
    
    /**
     Receives request data iteratively (uses async scheduling instead of recursion to avoid stack buildup)
     */
    private func receiveNextChunk(from connection: NWConnection, accumulatedData: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1048576) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                NSLog("[ThinkingProxy] Receive error: \(error)")
                connection.cancel()
                return
            }
            
            guard let data = data, !data.isEmpty else {
                if isComplete {
                    connection.cancel()
                }
                return
            }
            
            var newAccumulatedData = accumulatedData
            newAccumulatedData.append(data)
            
            // Check if we have a complete HTTP request
            if let requestString = String(data: newAccumulatedData, encoding: .utf8),
               let headerEndRange = requestString.range(of: "\r\n\r\n") {
                
                // Extract Content-Length if present
                let headerEndIndex = requestString.distance(from: requestString.startIndex, to: headerEndRange.upperBound)
                let headerPart = String(requestString.prefix(headerEndIndex))
                
                if let contentLengthLine = headerPart.components(separatedBy: "\r\n").first(where: { $0.lowercased().starts(with: "content-length:") }) {
                    let contentLengthStr = contentLengthLine.components(separatedBy: ":")[1].trimmingCharacters(in: .whitespaces)
                    if let contentLength = Int(contentLengthStr) {
                        let bodyStartIndex = headerEndIndex
                        let currentBodyLength = newAccumulatedData.count - bodyStartIndex
                        
                        // If we haven't received the full body yet, schedule next iteration
                        if currentBodyLength < contentLength {
                            self.receiveNextChunk(from: connection, accumulatedData: newAccumulatedData)
                            return
                        }
                    }
                }
                
                // We have a complete request, process it
                self.processRequest(data: newAccumulatedData, connection: connection)
            } else if !isComplete {
                // Haven't found header end yet, schedule next iteration
                self.receiveNextChunk(from: connection, accumulatedData: newAccumulatedData)
            } else {
                // Complete but malformed, process what we have
                self.processRequest(data: newAccumulatedData, connection: connection)
            }
        }
    }
    
    /**
     Processes the HTTP request, modifies it if needed, and forwards to CLIProxyAPI
     */
    private func processRequest(data: Data, connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendError(to: connection, statusCode: 400, message: "Invalid request")
            return
        }
        
        // Parse HTTP request
        let lines = requestString.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendError(to: connection, statusCode: 400, message: "Invalid request line")
            return
        }
        
        // Extract method, path, and HTTP version
        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 3 else {
            sendError(to: connection, statusCode: 400, message: "Invalid request format")
            return
        }
        
        let method = parts[0]
        let path = parts[1]
        let httpVersion = parts[2]
        NSLog("[ThinkingProxy] Incoming request: \(method) \(path)")

        // Collect headers while preserving original casing
        var headers: [(String, String)] = []
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            guard let separatorIndex = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<separatorIndex]).trimmingCharacters(in: .whitespaces)
            let valueStart = line.index(after: separatorIndex)
            let value = String(line[valueStart...]).trimmingCharacters(in: .whitespaces)
            headers.append((name, value))
        }

        guard isRequestAuthorized(headers: headers) else {
            NSLog("[ThinkingProxy] Rejecting unauthorized request")
            sendUnauthorized(to: connection)
            return
        }

        // Find the body start
        guard let bodyStartRange = requestString.range(of: "\r\n\r\n") else {
            NSLog("[ThinkingProxy] Error: Could not find body separator in request")
            sendError(to: connection, statusCode: 400, message: "Invalid request format - no body separator")
            return
        }
        
        let bodyStart = requestString.distance(from: requestString.startIndex, to: bodyStartRange.upperBound)
        let bodyString = String(requestString[requestString.index(requestString.startIndex, offsetBy: bodyStart)...])
        
        // Try to parse and modify JSON body for POST requests
        var modifiedBody = bodyString
        var thinkingEnabled = false

        if method == "POST" && !bodyString.isEmpty {
            if let result = processThinkingParameter(jsonString: bodyString) {
                modifiedBody = result.0
                thinkingEnabled = result.1
            }
            // Strip cache_control fields that cause 400 errors via the OAuth route
            if let stripped = stripCacheControl(from: modifiedBody) {
                modifiedBody = stripped
            }
            // Canonicalize known short model aliases before forwarding
            if let rewritten = canonicalizeTopLevelModelAlias(in: modifiedBody) {
                modifiedBody = rewritten
            }
        }

        // Normalize paths for local backend compatibility
        var forwardPath = path
        if path.starts(with: "/provider/") {
            forwardPath = "/api" + path
            NSLog("[ThinkingProxy] Normalizing provider path: \(path) -> \(forwardPath)")
        }

        // Route Claude requests through Vercel AI Gateway when configured
        if vercelConfig.isActive && method == "POST" && isClaudeModelRequest(body: modifiedBody) {
            NSLog("[ThinkingProxy] Routing Claude request via Vercel AI Gateway")
            forwardToVercel(method: method, path: "/v1/messages", version: httpVersion, headers: headers, body: modifiedBody, thinkingEnabled: thinkingEnabled, originalConnection: connection)
            return
        }

        forwardRequest(method: method, path: forwardPath, version: httpVersion, headers: headers, body: modifiedBody, thinkingEnabled: thinkingEnabled, originalConnection: connection)
    }
    
    private func isClaudeModelRequest(body: String) -> Bool {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let model = json["model"] as? String else { return false }
        return model.starts(with: "claude-")
    }

    func isRequestAuthorized(headers: [(String, String)]) -> Bool {
        guard !localProxySecret.isEmpty else { return true }
        guard let authorization = headers.first(where: { $0.0.caseInsensitiveCompare("Authorization") == .orderedSame })?.1 else {
            return false
        }
        return authorization == "Bearer \(localProxySecret)"
    }

    /// Strips `cache_control` fields from the request body that cause 400 errors via the OAuth route
    private func stripCacheControl(from jsonString: String) -> String? {
        guard let jsonData = jsonString.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        var modified = false

        func stripFromDictArray(_ array: inout [[String: Any]]) {
            for i in array.indices {
                if array[i]["cache_control"] != nil {
                    array[i].removeValue(forKey: "cache_control")
                    modified = true
                }
                // Recurse into nested content arrays
                if var nested = array[i]["content"] as? [[String: Any]] {
                    stripFromDictArray(&nested)
                    array[i]["content"] = nested
                }
            }
        }

        if var system = json["system"] as? [[String: Any]] {
            stripFromDictArray(&system)
            if modified { json["system"] = system }
        }

        if var messages = json["messages"] as? [[String: Any]] {
            stripFromDictArray(&messages)
            if modified { json["messages"] = messages }
        }

        if var tools = json["tools"] as? [[String: Any]] {
            stripFromDictArray(&tools)
            if modified { json["tools"] = tools }
        }

        guard modified else { return nil }

        guard let modifiedData = try? JSONSerialization.data(withJSONObject: json),
              let modifiedString = String(data: modifiedData, encoding: .utf8) else {
            return nil
        }

        NSLog("[ThinkingProxy] Stripped cache_control fields from request body")
        return modifiedString
    }
    
    /**
     Processes the JSON body to add thinking parameter if model name has a thinking suffix
     Returns tuple of (modifiedJSON, needsTransformation)
     */
    private func processThinkingParameter(jsonString: String) -> (String, Bool)? {
        return processThinkingParameterForTesting(jsonString: jsonString, hardTokenCap: Config.hardTokenCap, minimumHeadroom: Config.minimumHeadroom, headroomRatio: Config.headroomRatio)
    }
    
    /**
     Forwards Claude requests to Vercel AI Gateway (ai-gateway.vercel.sh)
     */
    private func forwardToVercel(method: String, path: String, version: String, headers: [(String, String)], body: String, thinkingEnabled: Bool, originalConnection: NWConnection) {
        let tlsOptions = NWProtocolTLS.Options()
        let parameters = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(Config.vercelGatewayHost), port: 443)
        let targetConnection = NWConnection(to: endpoint, using: parameters)
        let apiKey = vercelConfig.apiKey
        
        targetConnection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                var forwardedRequest = "\(method) \(path) \(version)\r\n"
                
                let excludedHeaders: Set<String> = ["host", "content-length", "connection", "transfer-encoding", "authorization", "x-api-key"]
                var existingBetaHeader: String? = nil
                
                for (name, value) in headers {
                    let lower = name.lowercased()
                    if excludedHeaders.contains(lower) { continue }
                    if lower == "anthropic-beta" {
                        existingBetaHeader = value
                        continue
                    }
                    forwardedRequest += "\(name): \(value)\r\n"
                }
                
                // Vercel auth
                forwardedRequest += "x-api-key: \(apiKey)\r\n"
                forwardedRequest += "anthropic-version: \(Config.anthropicVersion)\r\n"
                forwardedRequest += "content-type: application/json\r\n"
                
                // Thinking beta header
                if thinkingEnabled {
                    var betaValue = BetaHeaders.interleavedThinking
                    if let existing = existingBetaHeader, !existing.contains(BetaHeaders.interleavedThinking) {
                        betaValue = "\(existing),\(BetaHeaders.interleavedThinking)"
                    }
                    forwardedRequest += "anthropic-beta: \(betaValue)\r\n"
                } else if let existing = existingBetaHeader {
                    forwardedRequest += "anthropic-beta: \(existing)\r\n"
                }
                
                forwardedRequest += "Host: \(Config.vercelGatewayHost)\r\n"
                forwardedRequest += "Connection: close\r\n"
                
                let contentLength = body.utf8.count
                forwardedRequest += "Content-Length: \(contentLength)\r\n"
                forwardedRequest += "\r\n"
                forwardedRequest += body
                
                if let requestData = forwardedRequest.data(using: .utf8) {
                    targetConnection.send(content: requestData, completion: .contentProcessed({ error in
                        if let error = error {
                            NSLog("[ThinkingProxy] Vercel send error: \(error)")
                            targetConnection.cancel()
                            originalConnection.cancel()
                        } else {
                            self.receiveResponse(from: targetConnection, originalConnection: originalConnection)
                        }
                    }))
                }
                
            case .failed(let error):
                NSLog("[ThinkingProxy] Vercel connection failed: \(error)")
                self.sendError(to: originalConnection, statusCode: 502, message: "Bad Gateway - Could not connect to Vercel AI Gateway")
                targetConnection.cancel()
                
            default:
                break
            }
        }
        
        targetConnection.start(queue: .global(qos: .userInitiated))
    }
    
    private enum BetaHeaders {
        static let interleavedThinking = "interleaved-thinking-2025-05-14"
    }
    
    /**
     Forwards the request to CLIProxyAPI on port 8328 (pass-through for non-thinking requests)
     */
    private func forwardRequest(method: String, path: String, version: String, headers: [(String, String)], body: String, thinkingEnabled: Bool = false, originalConnection: NWConnection, retryWithApiPrefix: Bool = false) {
        // Create connection to CLIProxyAPI
        guard let port = NWEndpoint.Port(rawValue: targetPort) else {
            NSLog("[ThinkingProxy] Invalid target port: %d", targetPort)
            sendError(to: originalConnection, statusCode: 500, message: "Internal Server Error")
            return
        }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(targetHost), port: port)
        let parameters = NWParameters.tcp
        let targetConnection = NWConnection(to: endpoint, using: parameters)
        
        targetConnection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let forwardedRequest = buildForwardedLocalRequest(
                    method: method,
                    path: path,
                    version: version,
                    headers: headers,
                    body: body,
                    thinkingEnabled: thinkingEnabled,
                    targetHost: self.targetHost,
                    targetPort: self.targetPort,
                    interleavedThinkingHeader: BetaHeaders.interleavedThinking
                )

                if thinkingEnabled {
                    NSLog("[ThinkingProxy] Added interleaved thinking beta header")
                }
                
                // Send to CLIProxyAPI
                if let requestData = forwardedRequest.data(using: .utf8) {
                    targetConnection.send(content: requestData, completion: .contentProcessed({ error in
                        if let error = error {
                            NSLog("[ThinkingProxy] Send error: \(error)")
                            targetConnection.cancel()
                            originalConnection.cancel()
                        } else {
                            // Receive response from CLIProxyAPI (with 404 retry capability)
                            if retryWithApiPrefix {
                                self.receiveResponseWith404Retry(from: targetConnection, originalConnection: originalConnection, 
                                                                 method: method, path: path, version: version, 
                                                                 headers: headers, body: body)
                            } else if isModelListRequest(method: method, path: path) {
                                // Buffer complete model-list response for transformation
                                self.receiveBufferedModelListResponseChunk(
                                    from: targetConnection,
                                    to: originalConnection,
                                    method: method,
                                    path: path,
                                    accumulatedData: Data()
                                )
                            } else {
                                self.receiveResponse(from: targetConnection, originalConnection: originalConnection)
                            }
                        }
                    }))
                }
                
            case .failed(let error):
                NSLog("[ThinkingProxy] Target connection failed: \(error)")
                self.sendError(to: originalConnection, statusCode: 502, message: "Bad Gateway")
                targetConnection.cancel()
                
            default:
                break
            }
        }
        
        targetConnection.start(queue: .global(qos: .userInitiated))
    }
    
    /**
     Buffers eligible GET /v1/models backend responses using a deterministic
     Content-Length boundary instead of waiting for NWConnection.isComplete.

     Decision loop per received chunk:
     1. Classify the accumulated data via `classifyBufferedModelListResponse`.
     2. `headersIncomplete` → keep buffering.
     3. `unsafeForTransformation` → send buffered bytes to client, then continue
        streaming remaining backend chunks via `streamNextChunk`.
     4. `bodyIncomplete` → keep buffering until body bytes reach Content-Length.
     5. `bodyExact` → attempt transformation via `transformModelListHTTPResponseIfEligible`;
        send transformed or original data, then close.
     6. `bodyOverflow` → send buffered bytes to client, then continue streaming.

     If the backend connection closes (isComplete) before reaching `bodyExact`,
     the accumulated data is sent to the client as-is (no transformation).
     */
    private func receiveBufferedModelListResponseChunk(
        from targetConnection: NWConnection,
        to originalConnection: NWConnection,
        method: String,
        path: String,
        accumulatedData: Data
    ) {
        targetConnection.receive(minimumIncompleteLength: 1, maximumLength: 1048576) { [weak self] data, _, isComplete, error in
            guard let self = self else {
                targetConnection.cancel()
                originalConnection.cancel()
                return
            }

            if let error = error {
                NSLog("[ThinkingProxy] Buffered model-list receive error: \(error)")
                targetConnection.cancel()
                originalConnection.cancel()
                return
            }

            var newData = accumulatedData
            if let data = data, !data.isEmpty {
                newData.append(data)
            }

            let classification = classifyBufferedModelListResponse(newData)

            switch classification {
            case .headersIncomplete:
                if isComplete {
                    // Connection closed before headers complete — send what we have
                    self.sendAndCloseBuffered(
                        data: newData,
                        targetConnection: targetConnection,
                        originalConnection: originalConnection
                    )
                } else {
                    // Keep buffering
                    self.receiveBufferedModelListResponseChunk(
                        from: targetConnection,
                        to: originalConnection,
                        method: method,
                        path: path,
                        accumulatedData: newData
                    )
                }

            case .unsafeForTransformation:
                // Unsafe framing detected — send buffered bytes to client, then
                // continue streaming remaining backend chunks unchanged.
                NSLog("[ThinkingProxy] Model-list response unsafe for transformation, falling back to streaming")
                self.sendBufferedThenStream(
                    bufferedData: newData,
                    targetConnection: targetConnection,
                    originalConnection: originalConnection
                )

            case .bodyIncomplete:
                if isComplete {
                    // Connection closed before body complete — send what we have
                    NSLog("[ThinkingProxy] Model-list response connection closed before body complete, sending buffered (\(newData.count) bytes)")
                    self.sendAndCloseBuffered(
                        data: newData,
                        targetConnection: targetConnection,
                        originalConnection: originalConnection
                    )
                } else {
                    // Keep buffering until body reaches Content-Length
                    self.receiveBufferedModelListResponseChunk(
                        from: targetConnection,
                        to: originalConnection,
                        method: method,
                        path: path,
                        accumulatedData: newData
                    )
                }

            case .bodyExact:
                // Deterministic boundary reached — attempt transformation
                let transformed = transformModelListHTTPResponseIfEligible(
                    method: method,
                    path: path,
                    responseData: newData
                )
                let dataToSend = transformed ?? newData

                if transformed != nil {
                    NSLog("[ThinkingProxy] Transformed model-list response (original \(newData.count) bytes -> transformed \(dataToSend.count) bytes)")
                } else {
                    NSLog("[ThinkingProxy] Model-list response bodyExact but transformation returned nil, sending original (\(newData.count) bytes)")
                }

                self.sendAndCloseBuffered(
                    data: dataToSend,
                    targetConnection: targetConnection,
                    originalConnection: originalConnection
                )

            case .bodyOverflow:
                // Body exceeds Content-Length — unsafe, fall back to streaming
                NSLog("[ThinkingProxy] Model-list response body overflow (buffered exceeds Content-Length), falling back to streaming")
                self.sendBufferedThenStream(
                    bufferedData: newData,
                    targetConnection: targetConnection,
                    originalConnection: originalConnection
                )
            }
        }
    }

    /**
     Sends buffered data to the client and closes both connections.
     Used for terminal states (bodyExact, early close).
     */
    private func sendAndCloseBuffered(
        data: Data,
        targetConnection: NWConnection,
        originalConnection: NWConnection
    ) {
        originalConnection.send(content: data, completion: .contentProcessed({ sendError in
            if let sendError = sendError {
                NSLog("[ThinkingProxy] Buffered send error: \(sendError)")
            }
            targetConnection.cancel()
            originalConnection.send(content: nil, isComplete: true, completion: .contentProcessed({ _ in
                originalConnection.cancel()
            }))
        }))
    }

    /**
     Sends already-buffered bytes to the client, then continues streaming
     remaining backend response chunks via `streamNextChunk`.
     Used when framing is unsafe or body overflows Content-Length.
     */
    private func sendBufferedThenStream(
        bufferedData: Data,
        targetConnection: NWConnection,
        originalConnection: NWConnection
    ) {
        originalConnection.send(content: bufferedData, completion: .contentProcessed({ [weak self] sendError in
            if let sendError = sendError {
                NSLog("[ThinkingProxy] Buffered send error during stream fallback: \(sendError)")
            }
            // Continue streaming remaining chunks from backend to client
            self?.streamNextChunk(from: targetConnection, to: originalConnection)
        }))
    }

    /**
     Receives response and retries with /api/ prefix on 404
     */
    private func receiveResponseWith404Retry(from targetConnection: NWConnection, originalConnection: NWConnection, 
                                             method: String, path: String, version: String, 
                                             headers: [(String, String)], body: String) {
        targetConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                NSLog("[ThinkingProxy] Receive error: \(error)")
                targetConnection.cancel()
                originalConnection.cancel()
                return
            }
            
            if let data = data, !data.isEmpty {
                // Check if response is a 404
                if let responseString = String(data: data, encoding: .utf8) {
                    // Log first 200 chars to debug
                    let preview = String(responseString.prefix(200))
                    NSLog("[ThinkingProxy] Response preview for \(path): \(preview)")
                    
                    // Check for 404 in status line OR in body
                    let is404 = responseString.contains("HTTP/1.1 404") || 
                               responseString.contains("HTTP/1.0 404") ||
                               responseString.contains("404 page not found")
                    
                    if is404 {
                        // Check if path doesn't already start with /api/
                        if !path.starts(with: "/api/") && !path.starts(with: "/v1/") {
                            NSLog("[ThinkingProxy] Got 404 for \(path), retrying with /api prefix")
                            targetConnection.cancel()
                            
                            // Retry with /api/ prefix
                            let newPath = "/api" + path
                            self.forwardRequest(method: method, path: newPath, version: version, headers: headers, 
                                              body: body, originalConnection: originalConnection, retryWithApiPrefix: false)
                            return
                        }
                    }
                }
                
                // Not a 404 or already has /api/, forward response as-is
                originalConnection.send(content: data, completion: .contentProcessed({ sendError in
                    if let sendError = sendError {
                        NSLog("[ThinkingProxy] Send error: \(sendError)")
                    }
                    
                    if isComplete {
                        targetConnection.cancel()
                        originalConnection.send(content: nil, isComplete: true, completion: .contentProcessed({ _ in
                            originalConnection.cancel()
                        }))
                    } else {
                        // Continue streaming
                        self.streamNextChunk(from: targetConnection, to: originalConnection)
                    }
                }))
            } else if isComplete {
                targetConnection.cancel()
                originalConnection.send(content: nil, isComplete: true, completion: .contentProcessed({ _ in
                    originalConnection.cancel()
                }))
            }
        }
    }
    
    /**
     Receives response from CLIProxyAPI
     Starts the streaming loop for response data
     */
    private func receiveResponse(from targetConnection: NWConnection, originalConnection: NWConnection) {
        // Start the streaming loop
        streamNextChunk(from: targetConnection, to: originalConnection)
    }
    
    /**
     Streams response chunks iteratively (uses async scheduling instead of recursion to avoid stack buildup)
     */
    private func streamNextChunk(from targetConnection: NWConnection, to originalConnection: NWConnection) {
        targetConnection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            
            if let error = error {
                NSLog("[ThinkingProxy] Receive response error: \(error)")
                targetConnection.cancel()
                originalConnection.cancel()
                return
            }
            
            if let data = data, !data.isEmpty {
                // Forward response chunk to original client
                originalConnection.send(content: data, completion: .contentProcessed({ sendError in
                    if let sendError = sendError {
                        NSLog("[ThinkingProxy] Send response error: \(sendError)")
                    }
                    
                    if isComplete {
                        targetConnection.cancel()
                        // Always close client connection - no keep-alive/pipelining support
                        originalConnection.send(content: nil, isComplete: true, completion: .contentProcessed({ _ in
                            originalConnection.cancel()
                        }))
                    } else {
                        // Schedule next iteration of the streaming loop
                        self.streamNextChunk(from: targetConnection, to: originalConnection)
                    }
                }))
            } else if isComplete {
                targetConnection.cancel()
                // Always close client connection - no keep-alive/pipelining support
                originalConnection.send(content: nil, isComplete: true, completion: .contentProcessed({ _ in
                    originalConnection.cancel()
                }))
            }
        }
    }
    
    private func sendUnauthorized(to connection: NWConnection) {
        let message = "Unauthorized"
        guard let bodyData = "{\"error\":\"unauthorized\"}".data(using: .utf8) else {
            connection.cancel()
            return
        }

        let headers = "HTTP/1.1 401 \(message)\r\n" +
                     "Content-Type: application/json\r\n" +
                     "Content-Length: \(bodyData.count)\r\n" +
                     "Connection: close\r\n" +
                     "\r\n"

        guard let headerData = headers.data(using: .utf8) else {
            connection.cancel()
            return
        }

        var responseData = Data()
        responseData.append(headerData)
        responseData.append(bodyData)

        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }

    /**
     Sends an error response to the client
     */
    private func sendError(to connection: NWConnection, statusCode: Int, message: String) {
        // Build response with proper CRLF line endings and correct byte count
        guard let bodyData = message.data(using: .utf8) else {
            connection.cancel()
            return
        }
        
        let headers = "HTTP/1.1 \(statusCode) \(message)\r\n" +
                     "Content-Type: text/plain\r\n" +
                     "Content-Length: \(bodyData.count)\r\n" +
                     "Connection: close\r\n" +
                     "\r\n"
        
        guard let headerData = headers.data(using: .utf8) else {
            connection.cancel()
            return
        }
        
        var responseData = Data()
        responseData.append(headerData)
        responseData.append(bodyData)
        
        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }

}

// MARK: - Thinking Parameter Processing Seam

/// Internal pure seam for testing thinking parameter processing.
/// Does not touch networking or instance state.
internal func processThinkingParameterForTesting(
    jsonString: String,
    hardTokenCap: Int = 32000,
    minimumHeadroom: Int = 1024,
    headroomRatio: Double = 0.1
) -> (String, Bool)? {
    guard let jsonData = jsonString.data(using: .utf8),
          var json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
          let model = json["model"] as? String else {
        return nil
    }

    // Only process Claude models
    guard model.starts(with: "claude-") else {
        return (jsonString, false)
    }

    // Check for thinking suffix pattern: -thinking-NUMBER
    let thinkingPrefix = "-thinking-"
    if let thinkingRange = model.range(of: thinkingPrefix, options: .backwards),
       thinkingRange.upperBound < model.endIndex {

        let budgetString = String(model[thinkingRange.upperBound...])

        let cleanModel = String(model[..<thinkingRange.lowerBound])
        json["model"] = cleanModel

        if let budget = Int(budgetString), budget > 0 {
            let effectiveBudget = min(budget, hardTokenCap - 1)

            let isAdaptiveModel = cleanModel.contains("opus-4-6") || cleanModel.contains("opus-4-7")
            if isAdaptiveModel {
                json["thinking"] = ["type": "adaptive"]
            } else {
                json["thinking"] = [
                    "type": "enabled",
                    "budget_tokens": effectiveBudget
                ]
            }

            let tokenHeadroom = max(minimumHeadroom, Int(Double(effectiveBudget) * headroomRatio))
            let desiredMaxTokens = effectiveBudget + tokenHeadroom
            var requiredMaxTokens = min(desiredMaxTokens, hardTokenCap)
            if requiredMaxTokens <= effectiveBudget {
                requiredMaxTokens = min(effectiveBudget + 1, hardTokenCap)
            }

            let hasMaxOutputTokensField = json.keys.contains("max_output_tokens")
            var adjusted = false

            if let currentMaxTokens = json["max_tokens"] as? Int {
                if currentMaxTokens <= effectiveBudget {
                    json["max_tokens"] = requiredMaxTokens
                }
                adjusted = true
            }

            if let currentMaxOutputTokens = json["max_output_tokens"] as? Int {
                if currentMaxOutputTokens <= effectiveBudget {
                    json["max_output_tokens"] = requiredMaxTokens
                }
                adjusted = true
            }

            if !adjusted {
                if hasMaxOutputTokensField {
                    json["max_output_tokens"] = requiredMaxTokens
                } else {
                    json["max_tokens"] = requiredMaxTokens
                }
            }
        }

        if let modifiedData = try? JSONSerialization.data(withJSONObject: json),
           let modifiedString = String(data: modifiedData, encoding: .utf8) {
            return (modifiedString, true)
        }
    } else if model.hasSuffix("-thinking") || model.contains("-thinking(") {
        return (jsonString, true)
    }

    return (jsonString, false)
}

// MARK: - Model Alias Canonicalization & Model-List Filtering Helpers

/// Builds the HTTP request bytes/string forwarded to the local CLIProxyAPI backend.
///
/// This is the pure production seam used by `ThinkingProxy.forwardRequest`, exposed
/// internally so tests can verify forwarded header reconstruction without opening
/// sockets. It preserves the local-forwarding behavior: incoming `Content-Length`,
/// `Host`, and `Transfer-Encoding` headers are excluded; `anthropic-beta` is merged
/// when thinking is enabled; local backend `Host`, `Connection: close`, and a fresh
/// `Content-Length` based on the final body bytes are generated; the body is appended
/// unchanged as the final request body.
internal func buildForwardedLocalRequest(
    method: String,
    path: String,
    version: String,
    headers: [(String, String)],
    body: String,
    thinkingEnabled: Bool = false,
    targetHost: String,
    targetPort: UInt16,
    interleavedThinkingHeader: String = "interleaved-thinking-2025-05-14"
) -> String {
    var forwardedRequest = "\(method) \(path) \(version)\r\n"
    let excludedHeaders: Set<String> = ["content-length", "host", "transfer-encoding"]
    var existingBetaHeader: String? = nil

    for (name, value) in headers {
        let lowercasedName = name.lowercased()
        if excludedHeaders.contains(lowercasedName) {
            continue
        }
        // Capture existing anthropic-beta header for merging
        if lowercasedName == "anthropic-beta" {
            existingBetaHeader = value
            continue
        }
        forwardedRequest += "\(name): \(value)\r\n"
    }

    // Add/merge anthropic-beta header when thinking is enabled
    if thinkingEnabled {
        var betaValue = interleavedThinkingHeader
        if let existing = existingBetaHeader {
            // Merge with existing header if not already present
            if !existing.contains(interleavedThinkingHeader) {
                betaValue = "\(existing),\(interleavedThinkingHeader)"
            } else {
                betaValue = existing
            }
        }
        forwardedRequest += "anthropic-beta: \(betaValue)\r\n"
    } else if let existing = existingBetaHeader {
        // Pass through existing header when thinking not enabled
        forwardedRequest += "anthropic-beta: \(existing)\r\n"
    }

    // Override Host header
    forwardedRequest += "Host: \(targetHost):\(targetPort)\r\n"
    // Always close connections - this proxy doesn't support keep-alive/pipelining
    forwardedRequest += "Connection: close\r\n"

    let contentLength = body.utf8.count
    forwardedRequest += "Content-Length: \(contentLength)\r\n"
    forwardedRequest += "\r\n"
    forwardedRequest += body

    return forwardedRequest
}

/// Exact alias-to-canonical mapping table from the spec.
/// Only these nine mappings are recognized; nothing is inferred.
internal let modelAliasToCanonical: [String: String] = [
    "glm-5.1":       "zai/glm-5.1",
    "glm-5":         "zai/glm-5",
    "glm-5-turbo":   "zai/glm-5-turbo",
    "glm-5v-turbo":  "zai/glm-5v-turbo",
    "glm-4.7":       "zai/glm-4.7",
    "glm-4.7-flash": "zai/glm-4.7-flash",
    "glm-4.6v":      "zai/glm-4.6v",
    "glm-4.5-air":   "zai/glm-4.5-air",
    "MiniMax-M2.7":  "minimax/MiniMax-M2.7"
]

/// Rewrites a top-level JSON `model` string from alias to canonical form.
///
/// - Parameter jsonString: A raw JSON string potentially containing a top-level `"model"` key.
/// - Returns: Serialized modified JSON string when a rewrite occurred, or `nil` for
///   malformed JSON, non-object JSON, missing/non-string/unknown/canonical model,
///   or nested-only model values.
internal func canonicalizeTopLevelModelAlias(in jsonString: String) -> String? {
    guard let jsonData = jsonString.data(using: .utf8),
          var json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
          let model = json["model"] as? String else {
        return nil
    }

    // Look up the alias table
    guard let canonical = modelAliasToCanonical[model] else {
        return nil // unknown or already canonical
    }

    json["model"] = canonical

    guard let modifiedData = try? JSONSerialization.data(withJSONObject: json),
          let modifiedString = String(data: modifiedData, encoding: .utf8) else {
        return nil
    }

    return modifiedString
}

/// Filters a model-list response body by removing alias entries whose canonical
/// partner is also present, and normalizes `owned_by` for retained entries with
/// deterministic provider prefixes.
///
/// - Parameter bodyData: Raw JSON data of an OpenAI-compatible model-list response.
/// - Returns: Serialized filtered JSON data when transformation succeeds safely,
///   or `nil` for malformed JSON, unexpected shape, or entries without string `id`.
internal func filterModelListResponseBody(_ bodyData: Data) -> Data? {
    guard let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
          let dataArray = json["data"] as? [[String: Any]] else {
        return nil
    }

    // Every entry must have a string `id`; fail-safe if any does not.
    for entry in dataArray {
        guard entry["id"] is String else {
            return nil
        }
    }

    // Build set of IDs present in the response
    let presentIDs = Set(dataArray.compactMap { $0["id"] as? String })

    // Build reverse map: canonical ID -> alias IDs
    var canonicalToAliases: [String: [String]] = [:]
    for (alias, canonical) in modelAliasToCanonical {
        canonicalToAliases[canonical, default: []].append(alias)
    }

    // Set of alias IDs to remove (only when canonical is present)
    var aliasesToRemove: Set<String> = []
    for (canonical, aliases) in canonicalToAliases {
        if presentIDs.contains(canonical) {
            for alias in aliases {
                aliasesToRemove.insert(alias)
            }
        }
    }

    // Filter entries and normalize ownership
    var filteredEntries: [[String: Any]] = []
    for var entry in dataArray {
        guard let id = entry["id"] as? String else { continue }

        // Skip alias entries whose canonical partner is present
        if aliasesToRemove.contains(id) {
            continue
        }

        // Normalize owned_by for retained entries
        normalizeOwnedBy(for: &entry, id: id)
        filteredEntries.append(entry)
    }

    // Rebuild the response object preserving unrelated top-level fields
    var result = json
    result["data"] = filteredEntries

    guard let resultData = try? JSONSerialization.data(withJSONObject: result) else {
        return nil
    }

    return resultData
}

/// Normalizes the `owned_by` field for model entries with deterministic provider prefixes.
private func normalizeOwnedBy(for entry: inout [String: Any], id: String) {
    if id.hasPrefix("zai/") {
        entry["owned_by"] = "zai"
    } else if id.hasPrefix("minimax/") {
        entry["owned_by"] = "minimax"
    } else if id.hasPrefix("gpt-") || id.hasPrefix("codex-") {
        entry["owned_by"] = "openai"
    }
    // Other entries keep their original owned_by
}

/// Determines whether an HTTP request is an eligible `GET /v1/models` request.
///
/// Strips any query string from the path before matching. Returns `true` only when
/// the method is exactly `"GET"` and the URL path component is exactly `"/v1/models"`.
internal func isModelListRequest(method: String, path: String) -> Bool {
    guard method == "GET" else { return false }

    // Strip query string
    let pathComponent: String
    if let queryStart = path.firstIndex(of: "?") {
        pathComponent = String(path[..<queryStart])
    } else {
        pathComponent = path
    }

    return pathComponent == "/v1/models"
}

// MARK: - Response Classification & Transformation Seams

/// Classification of a buffered HTTP response for model-list transformation decisions.
///
/// The production buffered response path calls `classifyBufferedModelListResponse`
/// after each received chunk to decide whether to keep buffering, attempt
/// transformation, or fall back to streaming — without waiting indefinitely
/// for `NWConnection.isComplete`.
internal enum ModelListBufferClassification: Equatable {
    /// Header section not yet complete (no `\r\n\r\n` found). Keep buffering.
    case headersIncomplete
    /// Response is unsafe for transformation (non-2xx, Content-Encoding, chunked TE,
    /// missing/invalid Content-Length, malformed status line).
    /// Production should send already-buffered bytes to the client and continue
    /// streaming remaining backend chunks via `streamNextChunk`.
    case unsafeForTransformation
    /// Headers are safe and Content-Length is valid, but buffered body bytes are
    /// less than Content-Length. Keep buffering.
    case bodyIncomplete
    /// Buffered body bytes exactly match Content-Length. Safe to attempt
    /// transformation via `transformModelListHTTPResponseIfEligible`.
    case bodyExact
    /// Buffered body bytes exceed Content-Length. Unsafe framing.
    /// Production should send already-buffered bytes and continue streaming.
    case bodyOverflow
}

/// Pure classification seam for buffered HTTP response data.
///
/// Parses the buffered data to determine the safe next action for the
/// production model-list response buffering path. This function makes no
/// network calls and holds no state.
///
/// Uses raw byte-level search for `\r\n\r\n` to avoid Swift Character
/// counting mismatches with UTF-8 byte offsets (e.g. `\r\n` is one Swift
/// Character but two UTF-8 bytes).
///
/// - Parameter data: Buffered HTTP response bytes received so far.
/// - Returns: Classification indicating the next production action.
internal func classifyBufferedModelListResponse(_ data: Data) -> ModelListBufferClassification {
    // 1. Need at least some data
    guard !data.isEmpty else {
        return .headersIncomplete
    }

    // 2. Find \r\n\r\n separator in raw bytes
    guard let headerEndByteOffset = findHeaderBodySeparatorByteOffset(in: data) else {
        return .headersIncomplete
    }

    let bodyBytesBuffered = data.count - headerEndByteOffset

    // 3. Parse header section as string (header bytes before the 4-byte separator)
    let headerData = data.subdata(in: 0..<(headerEndByteOffset - 4))
    guard let headerSection = String(data: headerData, encoding: .utf8) else {
        return .unsafeForTransformation
    }

    // 4. Parse status line
    let headerLines = headerSection.components(separatedBy: "\r\n")
    guard let statusLine = headerLines.first, statusLine.hasPrefix("HTTP/") else {
        return .unsafeForTransformation
    }

    let statusParts = statusLine.components(separatedBy: " ")
    guard statusParts.count >= 2,
          let statusCode = Int(statusParts[1]),
          statusCode >= 200, statusCode < 300 else {
        return .unsafeForTransformation
    }

    // 5. Parse headers
    var headers: [(String, String)] = []
    for line in headerLines.dropFirst() {
        guard let colonIdx = line.firstIndex(of: ":") else { continue }
        let name = String(line[..<colonIdx])
        let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
        headers.append((name, value))
    }

    // 6. Safety checks on headers
    if headerValueCI(headers: headers, name: "Content-Encoding") != nil {
        return .unsafeForTransformation
    }

    if let teValue = headerValueCI(headers: headers, name: "Transfer-Encoding"),
       teValue.lowercased() == "chunked" {
        return .unsafeForTransformation
    }

    // 7. Content-Length check
    guard let clStr = headerValueCI(headers: headers, name: "Content-Length"),
          let contentLength = Int(clStr),
          contentLength >= 0 else {
        return .unsafeForTransformation
    }

    // 8. Compare body bytes to Content-Length
    if bodyBytesBuffered < contentLength {
        return .bodyIncomplete
    } else if bodyBytesBuffered == contentLength {
        return .bodyExact
    } else {
        return .bodyOverflow
    }
}

/// Transforms a complete buffered HTTP response for eligible `GET /v1/models` requests.
///
/// This is the internal pure helper seam called by the production buffered response path
/// for model-list responses. Tests exercise this same function without sockets.
///
/// **Eligibility:** method must be `"GET"` and URL path component must be exactly `"/v1/models"`
/// (query string ignored). Ineligible method/path returns `nil`.
///
/// **Safety checks** (all must pass or `nil` is returned for pass-through):
/// - Response must contain a valid `\r\n\r\n` header/body separator.
/// - Status must be 2xx.
/// - No `Content-Encoding` header present.
/// - No `Transfer-Encoding: chunked` header present.
/// - A valid numeric `Content-Length` must exist and **exactly** match the body byte count.
///
/// **Transformation:**
/// - Applies `filterModelListResponseBody` to the body bytes.
/// - If the filter returns `nil`, this function also returns `nil` (pass-through).
/// - Rebuilds the HTTP response preserving the original status line and safe headers.
/// - Removes stale `Content-Length` and `Transfer-Encoding`.
/// - Sets `Content-Length` to the transformed body byte count.
/// - Ensures exactly one `Connection: close` header.
/// - Appends the transformed body bytes.
///
/// - Parameters:
///   - method: The HTTP method of the original request.
///   - path: The URL path of the original request (may include query string).
///   - responseData: The complete buffered HTTP response bytes from the backend.
/// - Returns: Rebuilt HTTP response `Data`, or `nil` if the response should be
///   passed through unchanged.
internal func transformModelListHTTPResponseIfEligible(
    method: String,
    path: String,
    responseData: Data
) -> Data? {
    // 1. Eligibility check
    guard isModelListRequest(method: method, path: path) else {
        return nil
    }

    // 2. Find header/body separator at byte level
    guard let headerEndByteOffset = findHeaderBodySeparatorByteOffset(in: responseData) else {
        return nil
    }

    // 3. Split into header bytes and body bytes using byte offsets
    let headerData = responseData.subdata(in: 0..<(headerEndByteOffset - 4))
    let bodyBytes = responseData.subdata(in: headerEndByteOffset..<responseData.count)

    guard let headerSection = String(data: headerData, encoding: .utf8) else {
        return nil
    }

    // 4. Parse status line
    let headerLines = headerSection.components(separatedBy: "\r\n")
    guard let statusLine = headerLines.first, statusLine.hasPrefix("HTTP/") else {
        return nil
    }

    // Extract status code from status line: "HTTP/1.1 200 OK"
    let statusParts = statusLine.components(separatedBy: " ")
    guard statusParts.count >= 2,
          let statusCode = Int(statusParts[1]),
          statusCode >= 200, statusCode < 300 else {
        return nil
    }

    // 5. Parse headers
    var headers: [(String, String)] = []
    for line in headerLines.dropFirst() {
        guard let colonIdx = line.firstIndex(of: ":") else { continue }
        let name = String(line[..<colonIdx])
        let value = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
        headers.append((name, value))
    }

    // 6. Safety checks on headers
    //    - No Content-Encoding
    if headerValueCI(headers: headers, name: "Content-Encoding") != nil {
        return nil
    }

    //    - No Transfer-Encoding: chunked
    if let teValue = headerValueCI(headers: headers, name: "Transfer-Encoding"),
       teValue.lowercased() == "chunked" {
        return nil
    }

    //    - Valid Content-Length must exist and exactly match body bytes
    guard let clStr = headerValueCI(headers: headers, name: "Content-Length"),
          let contentLength = Int(clStr),
          contentLength >= 0,
          contentLength == bodyBytes.count else {
        return nil
    }

    // 7. Attempt model-list body transformation
    guard let transformedBodyData = filterModelListResponseBody(bodyBytes) else {
        return nil
    }

    guard let transformedBodyString = String(data: transformedBodyData, encoding: .utf8) else {
        return nil
    }

    // 8. Rebuild the HTTP response
    let excludedHeaders: Set<String> = [
        "content-length", "transfer-encoding", "connection"
    ]

    var rebuilt = statusLine + "\r\n"
    for (name, value) in headers {
        if excludedHeaders.contains(name.lowercased()) {
            continue
        }
        rebuilt += "\(name): \(value)\r\n"
    }
    rebuilt += "Content-Length: \(transformedBodyData.count)\r\n"
    rebuilt += "Connection: close\r\n"
    rebuilt += "\r\n"
    rebuilt += transformedBodyString

    guard let resultData = rebuilt.data(using: .utf8) else {
        return nil
    }

    return resultData
}

/// Case-insensitive header lookup from a list of (name, value) tuples.
private func headerValueCI(headers: [(String, String)], name: String) -> String? {
    return headers.first { $0.0.caseInsensitiveCompare(name) == .orderedSame }?.1
}

/// Finds the byte offset immediately after the first `\r\n\r\n` sequence in `data`.
///
/// Uses raw byte comparison to avoid Swift `Character` / UTF-8 byte count
/// mismatches (e.g. `\r\n` is one extended grapheme cluster but two UTF-8 bytes).
///
/// - Parameter data: Raw HTTP response bytes.
/// - Returns: Byte offset after the `\r\n\r\n` separator, or `nil` if not found.
internal func findHeaderBodySeparatorByteOffset(in data: Data) -> Int? {
    let pattern: [UInt8] = [0x0D, 0x0A, 0x0D, 0x0A] // \r\n\r\n
    guard data.count >= 4 else { return nil }
    for i in 0...(data.count - 4) {
        if data[i] == pattern[0] && data[i + 1] == pattern[1] &&
           data[i + 2] == pattern[2] && data[i + 3] == pattern[3] {
            return i + 4
        }
    }
    return nil
}
