import XCTest
@testable import CCProxy

/// Focused tests for ServerManager auth process lifecycle tracking.
///
/// These tests verify that the active auth process is tracked and properly
/// terminated when a new auth attempt begins, preventing orphaned auth processes.
final class ServerManagerProcessTests: XCTestCase {

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
}
