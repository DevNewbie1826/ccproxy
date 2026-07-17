import Darwin
import Foundation

enum SecureFileWriter {
    static func write(_ data: Data, to destination: URL) throws {
        let fileManager = FileManager.default
        let directory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var template = Array(directory
            .appendingPathComponent(".\(destination.lastPathComponent).XXXXXX")
            .path
            .utf8CString)

        let fileDescriptor = template.withUnsafeMutableBufferPointer { buffer in
            mkstemp(buffer.baseAddress)
        }
        guard fileDescriptor >= 0 else {
            throw posixError()
        }

        let tempPath = String(cString: template)
        var shouldClose = true
        var didRename = false

        do {
            if fchmod(fileDescriptor, mode_t(S_IRUSR | S_IWUSR)) == -1 {
                throw posixError()
            }

            try data.withUnsafeBytes { buffer in
                guard let baseAddress = buffer.baseAddress else { return }
                var offset = 0
                while offset < buffer.count {
                    let bytesWritten = Darwin.write(fileDescriptor, baseAddress.advanced(by: offset), buffer.count - offset)
                    if bytesWritten == -1 {
                        if errno == EINTR { continue }
                        throw posixError()
                    }
                    offset += bytesWritten
                }
            }

            if close(fileDescriptor) == -1 {
                shouldClose = false
                throw posixError()
            }
            shouldClose = false

            if rename(tempPath, destination.path) == -1 {
                throw posixError()
            }
            didRename = true
        } catch {
            if shouldClose {
                close(fileDescriptor)
            }
            if !didRename {
                try? fileManager.removeItem(atPath: tempPath)
            }
            throw error
        }
    }

    private static func posixError() -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
}
