import XCTest
import AppKit
@testable import CCProxy

final class ProviderIconTests: XCTestCase {

    // MARK: - Task 1: Icon name mapping regression

    func testOpenCodeGoProviderIconNameIsNonEmptyPng() throws {
        let iconName = ProviderIconNames.iconName(for: .opencodeGo)
        XCTAssertFalse(iconName.isEmpty, "opencode-go icon name must not be empty")
        XCTAssertEqual(iconName, "icon-opencode-go.png",
                       "opencode-go icon name must be the expected PNG filename")
    }

    func testOpenCodeGoProviderIconLoadsAsPNGThroughIconCatalogPath() throws {
        let iconName = ProviderIconNames.iconName(for: .opencodeGo)
        XCTAssertFalse(iconName.isEmpty, "icon name must be non-empty before file check")

        // Resolve resource from the Sources/Resources directory used by the package target
        let candidatePaths = [
            // SwiftPM test working dir is typically src/
            "Sources/Resources/\(iconName)",
            // Absolute path via test file location
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Sources/Resources/\(iconName)")
                .path
        ]

        guard let iconPath = candidatePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            XCTFail("PNG resource not found at any candidate path: \(candidatePaths)")
            return
        }

        // Verify the PNG resource file is non-empty
        let data = try Data(contentsOf: URL(fileURLWithPath: iconPath))
        XCTAssertGreaterThan(data.count, 0, "PNG resource must be non-empty")

        // Verify PNG magic bytes: 89 50 4E 47 0D 0A 1A 0A
        let pngMagic: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let header = Array(data.prefix(8))
        XCTAssertEqual(header, pngMagic, "File must start with PNG signature")

        // Verify NSImage can load the file through the same file-path mechanism
        let image = NSImage(contentsOfFile: iconPath)
        XCTAssertNotNil(image, "NSImage must load icon-opencode-go.png from file path")
    }
}
