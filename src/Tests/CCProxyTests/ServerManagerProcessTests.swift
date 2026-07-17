import XCTest
@testable import CCProxy

final class ServerManagerProcessTests: XCTestCase {

    func testRunAuthCommandUsesKimiLoginArgument() throws {
        try assertRunAuthCommand(.kimiLogin, containsArgument: "-kimi-login")
    }

    func testRunAuthCommandUsesXAILoginArgument() throws {
        try assertRunAuthCommand(.xaiLogin, containsArgument: "-xai-login")
    }

    func testTerminateActiveAuthProcessTerminatesRunningProcess() throws {
        let manager = ServerManager()
        let sleepProcess = Process()
        sleepProcess.executableURL = URL(fileURLWithPath: "/bin/sleep")
        sleepProcess.arguments = ["300"]

        addTeardownBlock { [weak sleepProcess] in
            if let proc = sleepProcess, proc.isRunning {
                proc.terminate()
            }
        }

        try sleepProcess.run()

        XCTAssertTrue(sleepProcess.isRunning, "Sleep process should be running")

        manager.activeAuthProcess = sleepProcess
        XCTAssertNotNil(manager.activeAuthProcess, "activeAuthProcess should be set")

        manager.terminateActiveAuthProcessIfNeeded(reason: "test")

        XCTAssertFalse(sleepProcess.isRunning,
                       "Previous auth process should be terminated by terminateActiveAuthProcessIfNeeded")
        XCTAssertNil(manager.activeAuthProcess,
                     "activeAuthProcess should be nil after termination")
    }

    func testTerminateActiveAuthProcessIsNoOpWhenNil() {
        let manager = ServerManager()

        XCTAssertNil(manager.activeAuthProcess)
        manager.terminateActiveAuthProcessIfNeeded(reason: "test nil")
        XCTAssertNil(manager.activeAuthProcess)
    }

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

    private func assertRunAuthCommand(_ command: AuthCommand, containsArgument expectedArgument: String) throws {
        let manager = ServerManager()
        defer { manager.terminateActiveAuthProcessIfNeeded(reason: "test cleanup") }

        let resourceDir = try makeFakeResourceDirectory()
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
    }

    private func makeFakeResourceDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ccproxy-auth-command-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "test-config".write(to: root.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)

        let executable = root.appendingPathComponent("cli-proxy-api")
        try "#!/bin/sh\nsleep 5\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)

        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
}
