# Stability Backport Decisions

Work ID: `20260506-cliproxy-refresh-a1b2`

This document records the evidence-based evaluation of each approved VibeProxy stability candidate
against CCProxy's local code. Each candidate is recorded as `ported`, `already equivalent`, or
`not applicable` with exact upstream permalink/snippet evidence and exact local symbol/function
evidence.

---

## Candidate 1: ThinkingProxy stop cleanup

**Status: `already equivalent`**

### Upstream evidence

- Repository: `automazeio/vibeproxy`
- Commit: `14c9bd36c20b94c31ea890c3d6578a1015dff305`
- File: `src/Sources/ThinkingProxy.swift`
- Permalink: https://github.com/automazeio/vibeproxy/blob/14c9bd36c20b94c31ea890c3d6578a1015dff305/src/Sources/ThinkingProxy.swift

**Upstream properties (lines 25–31):**
```swift
class ThinkingProxy {
    private var listener: NWListener?
    let proxyPort: UInt16 = 8317
    private let targetPort: UInt16 = 8318
    private let targetHost = "127.0.0.1"
    private(set) var isRunning = false
    private let stateQueue = DispatchQueue(label: "io.automaze.vibeproxy.thinking-proxy-state")
```

**Upstream `stop()` (lines 98–107):**
```swift
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
```

### Local evidence

- File: `src/Sources/ThinkingProxy.swift`
- Local class: `ThinkingProxy` (line 25)

**Local properties (lines 25–31):**
```swift
class ThinkingProxy {
    private var listener: NWListener?          // line 26
    let proxyPort: UInt16 = 8317               // line 27
    private let targetPort: UInt16 = 8328      // line 28
    private let targetHost = "127.0.0.1"       // line 29
    private(set) var isRunning = false         // line 30
    private let stateQueue = DispatchQueue(label: "com.devnewbie1826.ccproxy.thinking-proxy-state")  // line 31
```

**Local `stop()` (lines 102–113):**
```swift
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
```

### Comparison

| Aspect | Upstream (VibeProxy) | Local (CCProxy) | Equivalent? |
|--------|---------------------|-----------------|-------------|
| `listener` property | `private var listener: NWListener?` | `private var listener: NWListener?` | Yes |
| `isRunning` property | `private(set) var isRunning = false` | `private(set) var isRunning = false` | Yes |
| `stateQueue` property | `DispatchQueue` with sync serialization | `DispatchQueue` with sync serialization | Yes |
| `stop()` thread safety | `stateQueue.sync { ... }` | `stateQueue.sync { ... }` | Yes |
| `stop()` idempotency guard | `guard isRunning else { return }` | `guard isRunning else { return }` | Yes |
| `stop()` listener cancel | `listener?.cancel()` | `listener?.cancel()` | Yes |
| `stop()` listener nil | `listener = nil` | `listener = nil` | Yes |
| `stop()` state update | `DispatchQueue.main.async { self?.isRunning = false }` | `DispatchQueue.main.async { self?.isRunning = false }` | Yes |
| `start()` guard | `guard !isRunning` | `guard !isRunning` | Yes |
| `start()` state handler | `.ready`/`.failed`/`.cancelled` all set `isRunning` on main queue | Identical | Yes |

The only differences are:
1. `targetPort`: upstream uses `8318`, local uses `8328` — this is an expected CCProxy-specific port difference, not a stability concern.
2. `stateQueue` label: upstream uses `"io.automaze.vibeproxy.thinking-proxy-state"`, local uses `"com.devnewbie1826.ccproxy.thinking-proxy-state"` — cosmetic only.

### Decision

**Already equivalent.** The local `ThinkingProxy.stop()`, listener teardown, and state synchronization
are structurally identical to the upstream VibeProxy at commit `14c9bd36`. Both use the same
`stateQueue.sync` serialization, idempotency guard, listener cancel + nil, and async main-queue
state update pattern. No production change is needed.

### Non-testability note

Since this candidate is already equivalent and no production change is required, no focused lifecycle
test file (`ThinkingProxyLifecycleTests.swift`) is created for this candidate. The existing test
suite covers build correctness and basic port behavior. The stop/start/listener teardown behavior
is verified by code review comparison above.

---

## Candidate 2: ServerManager pipe/process cleanup

**Status: `already equivalent`**

### Upstream evidence

- Repository: `automazeio/vibeproxy`
- Commit: `14c9bd36c20b94c31ea890c3d6578a1015dff305`
- File: `src/Sources/ServerManager.swift`
- Permalink: https://github.com/automazeio/vibeproxy/blob/14c9bd36c20b94c31ea890c3d6578a1015dff305/src/Sources/ServerManager.swift

**Upstream pipe setup and termination handler (lines 248–281):**
```swift
// Setup pipes for output
let outputPipe = Pipe()
let errorPipe = Pipe()
process?.standardOutput = outputPipe
process?.standardError = errorPipe

// Handle output
outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
    let data = handle.availableData
    if let output = String(data: data, encoding: .utf8), !output.isEmpty {
        self?.addLog(output)
    }
}

errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
    let data = handle.availableData
    if let output = String(data: data, encoding: .utf8), !output.isEmpty {
        self?.addLog("⚠️ \(output)")
    }
}

// Handle termination
process?.terminationHandler = { [weak self] process in
    // Clear pipe handlers to prevent memory leaks
    outputPipe.fileHandleForReading.readabilityHandler = nil
    errorPipe.fileHandleForReading.readabilityHandler = nil
    
    DispatchQueue.main.async {
        self?.isRunning = false
        self?.activeConfigPath = ""
        self?.addLog("Server stopped with code: \(process.terminationStatus)")
        NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
    }
}
```

**Upstream `stop()` (lines 308–349):**
```swift
func stop(completion: (() -> Void)? = nil) {
    guard let process = process else { ... }
    let pid = process.processIdentifier
    addLog("Stopping server (PID: \(pid))...")
    processQueue.async { [weak self] in
        guard let self = self else { return }
        process.terminate()
        let deadline = Date().addingTimeInterval(Timing.gracefulTerminationTimeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: Timing.terminationPollInterval)
        }
        if process.isRunning {
            self.addLog("⚠️ Server didn't stop gracefully, force killing...")
            kill(pid, SIGKILL)
        }
        process.waitUntilExit()
        DispatchQueue.main.async {
            self.process = nil
            self.isRunning = false
            self.activeConfigPath = ""
            self.addLog("✓ Server stopped")
            NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
            completion?()
        }
    }
}
```

### Local evidence

- File: `src/Sources/ServerManager.swift`
- Local class: `ServerManager` (line 47)

**Local pipe setup and termination handler (lines 191–222):**
```swift
// Setup pipes for output
let outputPipe = Pipe()
let errorPipe = Pipe()
process?.standardOutput = outputPipe
process?.standardError = errorPipe

// Handle output
outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
    let data = handle.availableData
    if let output = String(data: data, encoding: .utf8), !output.isEmpty {
        self?.addLog(output)
    }
}

errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
    let data = handle.availableData
    if let output = String(data: data, encoding: .utf8), !output.isEmpty {
        self?.addLog("⚠️ \(output)")
    }
}

// Handle termination
process?.terminationHandler = { [weak self] process in
    // Clear pipe handlers to prevent memory leaks
    outputPipe.fileHandleForReading.readabilityHandler = nil
    errorPipe.fileHandleForReading.readabilityHandler = nil
    
    DispatchQueue.main.async {
        self?.isRunning = false
        self?.addLog("Server stopped with code: \(process.terminationStatus)")
        NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
    }
}
```

**Local `stop()` (lines 249–289):**
```swift
func stop(completion: (() -> Void)? = nil) {
    guard let process = process else { ... }
    let pid = process.processIdentifier
    addLog("Stopping server (PID: \(pid))...")
    processQueue.async { [weak self] in
        guard let self = self else { return }
        process.terminate()
        let deadline = Date().addingTimeInterval(Timing.gracefulTerminationTimeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: Timing.terminationPollInterval)
        }
        if process.isRunning {
            self.addLog("⚠️ Server didn't stop gracefully, force killing...")
            kill(pid, SIGKILL)
        }
        process.waitUntilExit()
        DispatchQueue.main.async {
            self.process = nil
            self.isRunning = false
            self.addLog("✓ Server stopped")
            NotificationCenter.default.post(name: .serverStatusChanged, object: nil)
            completion?()
        }
    }
}
```

### Comparison

| Aspect | Upstream (VibeProxy) | Local (CCProxy) | Equivalent? |
|--------|---------------------|-----------------|-------------|
| Pipe setup | `outputPipe`/`errorPipe` with readabilityHandlers | Same pattern | Yes |
| Pipe cleanup in termination handler | `outputPipe.fileHandleForReading.readabilityHandler = nil` + `errorPipe` | Same (lines 214–216) | Yes |
| Graceful stop SIGTERM | `process.terminate()` on processQueue | Same (line 265) | Yes |
| SIGKILL fallback | `kill(pid, SIGKILL)` after timeout | Same (line 274) | Yes |
| `waitUntilExit` | After SIGKILL check | Same (line 276) | Yes |
| Process niling | `self.process = nil` on main queue | Same (line 280) | Yes |
| Process queue | Serial `DispatchQueue` for process ops | Same (line 99) | Yes |
| Deinit backend cleanup | Terminates running backend process | Same — unchanged by T05 (lines 150–152) | Yes |
| `activeConfigPath` | Tracked and cleared | CCProxy does not track this — not a stability concern | N/A |

The only difference is that upstream tracks `activeConfigPath` and clears it in `stop()` and the termination handler. CCProxy does not have this property. This is a config-path tracking convenience in VibeProxy's broader config management architecture, not a pipe/process stability fix.

**Note on deinit:** T05 added auth process cleanup to `deinit` (calling `terminateActiveAuthProcessIfNeeded(reason: "deinit cleanup")`) which is documented under Candidate 3. The backend process cleanup (`if let process, process.isRunning { process.terminate() }`) was already present before T05 and was not modified by Candidate 2.

### Decision

**Already equivalent.** CCProxy's `start()` already clears pipe readability handlers in the termination handler (lines 214–216), uses a serial process queue for stop operations, performs graceful SIGTERM + SIGKILL fallback + `waitUntilExit`, and nils the process reference on the main queue. All pipe/process cleanup patterns from the upstream are already present. No production change is needed for this candidate.

### Non-testability note

Since this candidate is already equivalent and no production change is required, no focused process lifecycle test is created for pipe/process cleanup. The existing test suite covers build correctness. The pipe handler cleanup, termination handler, graceful stop, and process niling behavior is verified by code review comparison above.

---

## Candidate 3: Auth retry/stale cleanup

**Status: `ported` (active auth process tracking) / `not applicable` (stale auth process pgrep/pkill cleanup)**

This candidate has two distinct sub-parts evaluated separately.

### Sub-part A: Active auth process tracking — `ported`

#### Upstream evidence

- Repository: `automazeio/vibeproxy`
- Commit: `14c9bd36c20b94c31ea890c3d6578a1015dff305`
- File: `src/Sources/ServerManager.swift`
- Permalink: https://github.com/automazeio/vibeproxy/blob/14c9bd36c20b94c31ea890c3d6578a1015dff305/src/Sources/ServerManager.swift

**VibeProxy PR #344 (auth retry/stale cleanup):**
- PR URL: https://github.com/automazeio/vibeproxy/pull/344
- Title: "Fix CLIProxyAPI workflow source and auth retry cleanup"
- Merge commit: `24929c8eb71858bc9f009ae79289640270c39f53`
- Summary (from PR body):
  > - track and terminate active auth login processes before starting a new auth attempt
  > - clean up stale auth listener processes so users can retry authentication without restarting VibeProxy
- Fixes: #299. Helps: #200, #242.

**Upstream `activeAuthProcess` property (line 55):**
```swift
private var activeAuthProcess: Process?
```

**Upstream `runAuthCommand` integration (lines 351–353):**
```swift
func runAuthCommand(_ command: AuthCommand, completion: @escaping (Bool, String) -> Void) {
    terminateActiveAuthProcessIfNeeded(reason: "starting a new auth attempt")
    cleanupStaleAuthProcesses()
    ...
```

**Upstream process assignment before run (lines 477–478):**
```swift
activeAuthProcess = authProcess
try authProcess.run()
```

**Upstream `terminateActiveAuthProcessIfNeeded` (lines 553–573):**
```swift
private func terminateActiveAuthProcessIfNeeded(reason: String) {
    guard let authProcess = activeAuthProcess else {
        return
    }

    if authProcess.isRunning {
        addLog("⚠️ Terminating previous auth process (\(authProcess.processIdentifier)) before retry: \(reason)")
        authProcess.terminate()

        let deadline = Date().addingTimeInterval(Timing.gracefulTerminationTimeout)
        while authProcess.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: Timing.terminationPollInterval)
        }

        if authProcess.isRunning {
            kill(authProcess.processIdentifier, SIGKILL)
        }
    }

    activeAuthProcess = nil
}
```

**Upstream `clearActiveAuthProcess` (lines 575–579):**
```swift
private func clearActiveAuthProcess(_ process: Process) {
    if activeAuthProcess === process {
        activeAuthProcess = nil
    }
}
```

**Upstream termination handler integration (lines 463–466):**
```swift
authProcess.terminationHandler = { [weak self] process in
    let exitCode = process.terminationStatus
    NSLog("[Auth] Process terminated with exit code: %d", exitCode)
    self?.clearActiveAuthProcess(process)
    ...
```

**Upstream deinit integration (lines 206–211):**
```swift
deinit {
    terminateActiveAuthProcessIfNeeded(reason: "deinit cleanup")
    stop()
    killOrphanedProcesses()
}
```

#### Local evidence

- File: `src/Sources/ServerManager.swift`
- Local class: `ServerManager` (line 47)

Before T05, CCProxy's `runAuthCommand` had no `activeAuthProcess` tracking. Each auth attempt created
a new `Process()` without terminating any previous one. The termination handler posted a notification
but did not clear any tracked reference. The `deinit` only cleaned up the backend `process`, not auth
processes.

#### Changes ported to local code

The following symbols were added to `ServerManager`:

1. **`private let authProcessQueue`** (line 51) — Serial `DispatchQueue` protecting `_activeAuthProcess` access across threads (main-thread set/terminate vs termination-handler-thread clear).

2. **`private var _activeAuthProcess: Process?`** (line 52) — Backing storage for the active auth process.

3. **`var activeAuthProcess: Process?`** (lines 55–57) — Thread-safe computed property wrapping `_activeAuthProcess` with `authProcessQueue.sync`. Internal scope for test access via `@testable import`.

4. **`func terminateActiveAuthProcessIfNeeded(reason:)`** (lines 302–328) — Atomically reads and clears `_activeAuthProcess` under `authProcessQueue`, then terminates any running process with graceful SIGTERM + SIGKILL fallback. Mapped from upstream lines 553–573.

5. **`func clearActiveAuthProcess(_:)`** (lines 332–338) — Clears `_activeAuthProcess` under `authProcessQueue` only when the process identity matches. Mapped from upstream lines 575–579.

6. **`runAuthCommand` integration** (line 340) — Calls `terminateActiveAuthProcessIfNeeded(reason: "starting a new auth attempt")` at the start of `runAuthCommand`. Mapped from upstream lines 351–352.

7. **`runAuthCommand` process assignment** (line 449) — Sets `activeAuthProcess = authProcess` (thread-safe) before `try authProcess.run()`. Mapped from upstream line 477.

8. **`runAuthCommand` termination handler** (lines 454–455) — Calls `self?.clearActiveAuthProcess(process)` in the auth process termination handler. Mapped from upstream line 466.

9. **`runAuthCommand` catch block** (line 521) — Calls `clearActiveAuthProcess(authProcess)` on launch failure. Mapped from upstream line 547.

10. **`deinit` integration** (line 147) — Calls `terminateActiveAuthProcessIfNeeded(reason: "deinit cleanup")` to reuse the same graceful SIGTERM + SIGKILL fallback path. Mapped from upstream line 208. Backend process cleanup (lines 149–152) is unchanged from pre-T05 and is documented under Candidate 2.

#### Test coverage

- Test file: `src/Tests/CCProxyTests/ServerManagerProcessTests.swift`
- `testTerminateActiveAuthProcessTerminatesRunningProcess` — Verifies that `terminateActiveAuthProcessIfNeeded` terminates a real running process and clears the reference.
- `testTerminateActiveAuthProcessIsNoOpWhenNil` — Verifies the method is safe when no process is tracked.
- `testClearActiveAuthProcessClearsMatchingProcess` — Verifies `clearActiveAuthProcess` only clears when the process identity matches.

#### Decision

**Ported.** Active auth process tracking and termination was missing from CCProxy. The upstream pattern of tracking `activeAuthProcess`, terminating it before new auth attempts, clearing the reference on termination, and cleaning up in deinit has been ported using only owned child process tracking — no global process name matching is used. The deinit reuses the same `terminateActiveAuthProcessIfNeeded` graceful SIGTERM + SIGKILL fallback path rather than a weaker direct terminate. Additionally, a serial `authProcessQueue` protects all reads and writes of the backing `_activeAuthProcess` storage, ensuring thread safety between the main-thread set/terminate path and the termination-handler-thread clear path.

### Sub-part B: Stale auth process cleanup via pgrep/pkill — `not applicable`

#### Upstream evidence

- Repository: `automazeio/vibeproxy`
- Commit: `14c9bd36c20b94c31ea890c3d6578a1015dff305`
- File: `src/Sources/ServerManager.swift`
- Permalink: https://github.com/automazeio/vibeproxy/blob/14c9bd36c20b94c31ea890c3d6578a1015dff305/src/Sources/ServerManager.swift
- PR #344: https://github.com/automazeio/vibeproxy/pull/344 (introduced `cleanupStaleAuthProcesses`)

**Upstream `cleanupStaleAuthProcesses` (lines 581–623):**
```swift
private func cleanupStaleAuthProcesses() {
    let backendPID = process?.processIdentifier
    let patterns = [
        "cli-proxy-api-plus.*-claude-login",
        "cli-proxy-api-plus.*-codex-login",
        "cli-proxy-api-plus.*-github-copilot-login",
        "cli-proxy-api-plus.*-qwen-login",
        "cli-proxy-api-plus.*-antigravity-login",
        "cli-proxy-api-plus.* -login"
    ]

    for pattern in patterns {
        let checkTask = Process()
        checkTask.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        checkTask.arguments = ["-f", pattern]

        let outputPipe = Pipe()
        checkTask.standardOutput = outputPipe
        checkTask.standardError = Pipe()

        do {
            try checkTask.run()
            checkTask.waitUntilExit()
            guard checkTask.terminationStatus == 0 else {
                continue
            }

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let pids = output.components(separatedBy: .newlines).compactMap { Int32($0) }

            for pid in pids {
                if pid == backendPID {
                    continue
                }
                kill(pid, SIGKILL)
                addLog("⚠️ Cleaned up stale auth listener process: \(pid)")
            }
        } catch {
            // best-effort cleanup only
        }
    }
}
```

#### Non-applicability evidence

The upstream `cleanupStaleAuthProcesses` uses `pgrep -f` with binary-name patterns to find and kill
processes matching `cli-proxy-api-plus.*-claude-login` and similar. This is exactly the pattern
forbidden by the approved plan and spec:

> "For stale auth cleanup, do not use generic `pgrep/pkill -f cli-proxy-api`; cleanup must be scoped
> to owned child process tracking / backend PID exclusion / auth-specific ownership evidence, or mark
> not applicable."

The upstream approach kills any process matching the pattern, regardless of whether CCProxy launched
it. This creates a risk of killing unrelated `cli-proxy-api` processes not owned by this CCProxy
instance. There is no mechanism to prove CCProxy owns the matched process beyond the command-line
pattern.

Furthermore, the upstream patterns use `cli-proxy-api-plus` which is the old binary name. CCProxy
uses `cli-proxy-api`, so the patterns would need updating even if this approach were acceptable.

The owned child process tracking ported in Sub-part A (`activeAuthProcess` + `terminateActiveAuthProcessIfNeeded`) addresses the core stability concern — preventing orphaned auth processes when a new auth attempt begins — without the risks of global process-name killing.

#### Decision

**Not applicable.** The upstream `cleanupStaleAuthProcesses` uses generic `pgrep -f` / `kill` by binary
name pattern, which is forbidden by the approved spec and plan. The owned child process tracking
ported in Sub-part A provides the safe, scoped alternative for preventing orphaned auth processes.

---

# Summary

| # | Candidate | Status | Production Change | Test File Created |
|---|-----------|--------|-------------------|-------------------|
| 1 | ThinkingProxy stop cleanup | `already equivalent` | No | No |
| 2 | ServerManager pipe/process cleanup | `already equivalent` | No | No |
| 3a | Auth retry — active process tracking | `ported` | Yes | Yes: `ServerManagerProcessTests.swift` |
| 3b | Auth stale — pgrep/pkill cleanup | `not applicable` | No | No |
