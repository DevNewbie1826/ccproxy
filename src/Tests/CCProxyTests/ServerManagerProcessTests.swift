import XCTest
@testable import CCProxy

/// Focused tests for ServerManager auth process lifecycle tracking.
///
/// These tests verify that the active auth process is tracked and properly
/// terminated when a new auth attempt begins, preventing orphaned auth processes.
final class ServerManagerProcessTests: XCTestCase {

    func testRunAuthCommandUsesKimiLoginArgument() {
        assertRunAuthCommand(.kimiLogin, containsArgument: "-kimi-login")
    }

    func testRunAuthCommandUsesXAILoginArgument() {
        assertRunAuthCommand(.xaiLogin, containsArgument: "-xai-login")
    }

    // MARK: - Auth Process Tracking

    /// Calling terminateActiveAuthProcessIfNeeded must terminate a running tracked
    /// auth process and clear the reference.
    func testTerminateActiveAuthProcessTerminatesRunningProcess() {
        let manager = ServerManager()

        // Create a real process that will run for a while
        let sleepProcess = Process()
        sleepProcess.executableURL = URL(fileURLWithPath: "/bin/sleep")
        sleepProcess.arguments = ["300"]

        // Guarantee cleanup even if assertions fail
        addTeardownBlock { [weak sleepProcess] in
            if let proc = sleepProcess, proc.isRunning {
                proc.terminate()
            }
        }

        do {
            try sleepProcess.run()
        } catch {
            XCTFail("Failed to start sleep process for test: \(error)")
            return
        }

        XCTAssertTrue(sleepProcess.isRunning, "Sleep process should be running")

        // Set as active auth process (thread-safe via computed property)
        manager.activeAuthProcess = sleepProcess
        XCTAssertNotNil(manager.activeAuthProcess, "activeAuthProcess should be set")

        // Terminate it via the method under test
        manager.terminateActiveAuthProcessIfNeeded(reason: "test")

        XCTAssertFalse(sleepProcess.isRunning,
                       "Previous auth process should be terminated by terminateActiveAuthProcessIfNeeded")
        XCTAssertNil(manager.activeAuthProcess,
                     "activeAuthProcess should be nil after termination")
    }

    /// Calling terminateActiveAuthProcessIfNeeded when no process is tracked should
    /// be a no-op without error.
    func testTerminateActiveAuthProcessIsNoOpWhenNil() {
        let manager = ServerManager()

        XCTAssertNil(manager.activeAuthProcess)
        // Should not crash or assert
        manager.terminateActiveAuthProcessIfNeeded(reason: "test nil")
        XCTAssertNil(manager.activeAuthProcess)
    }

    /// clearActiveAuthProcess should only clear the reference when the process matches.
    func testClearActiveAuthProcessClearsMatchingProcess() {
        let manager = ServerManager()

        let processA = Process()
        let processB = Process()

        manager.activeAuthProcess = processA
        manager.clearActiveAuthProcess(processB)
        XCTAssertNotNil(manager.activeAuthProcess,
                        "clearActiveAuthProcess should not clear when process does not match")

        manager.clearActiveAuthProcess(processA)
        XCTAssertNil(manager.activeAuthProcess,
                     "clearActiveAuthProcess should clear when process matches")
    }

    private func assertRunAuthCommand(_ command: AuthCommand, containsArgument expectedArgument: String) {
        let manager = ServerManager()
        let resourceDir = makeFakeResourceDirectory()
        manager.bundledResourcePathOverride = resourceDir.path

        let expectation = expectation(description: "Auth command starts")
        manager.runAuthCommand(command) { success, output in
            XCTAssertTrue(success, output)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 3.0)

        let arguments = manager.activeAuthProcess?.arguments ?? []
        XCTAssertTrue(arguments.contains(expectedArgument),
                      "Expected auth arguments \(arguments) to contain \(expectedArgument)")
        XCTAssertTrue(arguments.contains("--config"),
                      "Auth command should pass the generated config flag")
        XCTAssertTrue(arguments.contains(resourceDir.appendingPathComponent("config.yaml").path),
                      "Auth command should pass the resource config path")

        manager.terminateActiveAuthProcessIfNeeded(reason: "test cleanup")
    }

    private func makeFakeResourceDirectory() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccproxy-auth-command-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try "test-config".write(to: root.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
            let executable = root.appendingPathComponent("cli-proxy-api")
            try "#!/bin/sh\nsleep 5\n".write(to: executable, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
            addTeardownBlock { try? FileManager.default.removeItem(at: root) }
            return root
        } catch {
            XCTFail("Failed to create fake resource directory: \(error)")
            return root
        }
    }
}
