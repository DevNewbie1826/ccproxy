import XCTest
import AppKit
@testable import CCProxy

final class ProviderIconTests: XCTestCase {

    func testOpenCodeGoProviderIconNameIsNonEmptyPng() throws {
        assertProviderIconName(.opencodeGo, equals: "icon-opencode-go.png")
    }

    func testXaiProviderIconNameIsNonEmptyPng() throws {
        assertProviderIconName(.xai, equals: "icon-xai.png")
    }

    func testOpenCodeGoProviderIconLoadsAsPNGThroughIconCatalogPath() throws {
        try assertProviderIconLoadsAsPNG(.opencodeGo)
    }

    func testXaiProviderIconLoadsAsPNGThroughIconCatalogPath() throws {
        try assertProviderIconLoadsAsPNG(.xai)
    }

    private func assertProviderIconLoadsAsPNG(_ serviceType: ServiceType) throws {
        let iconName = ProviderIconNames.iconName(for: serviceType)
        XCTAssertFalse(iconName.isEmpty, "icon name must be non-empty before file check")

        let candidatePaths = [
            "Sources/Resources/\(iconName)",
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

        let data = try Data(contentsOf: URL(fileURLWithPath: iconPath))
        XCTAssertGreaterThan(data.count, 0, "PNG resource must be non-empty")

        let pngMagic: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        let header = Array(data.prefix(8))
        XCTAssertEqual(header, pngMagic, "File must start with PNG signature")

        let image = NSImage(contentsOfFile: iconPath)
        XCTAssertNotNil(image, "NSImage must load \(iconName) from file path")
    }

    private func assertProviderIconName(_ serviceType: ServiceType, equals expectedIconName: String) {
        let iconName = ProviderIconNames.iconName(for: serviceType)
        XCTAssertFalse(iconName.isEmpty, "\(serviceType.rawValue) icon name must not be empty")
        XCTAssertEqual(iconName, expectedIconName,
                       "\(serviceType.rawValue) icon name must be the expected PNG filename")
    }
}
