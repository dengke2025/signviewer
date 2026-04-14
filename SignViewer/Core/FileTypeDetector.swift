import Foundation
import UniformTypeIdentifiers

struct FileTypeDetector {
    static func detect(url: URL) -> FileType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "app":
            return .app
        case "pkg", "mpkg":
            return .pkg
        case "dmg":
            return .dmg
        default:
            break
        }

        // Check if it's a .app bundle directory
        if url.pathExtension == "app" || url.lastPathComponent.hasSuffix(".app") {
            return .app
        }

        // Check if it's a Mach-O binary by reading magic bytes
        if isMachO(url: url) {
            return .machO
        }

        return .unknown
    }

    static func isMachO(url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { handle.closeFile() }
        guard let data = try? handle.read(upToCount: 4), data.count == 4 else { return false }
        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        // MH_MAGIC, MH_CIGAM, MH_MAGIC_64, MH_CIGAM_64, FAT_MAGIC, FAT_CIGAM
        let machOMagics: Set<UInt32> = [0xFEEDFACE, 0xCEFAEDFE, 0xFEEDFACF, 0xCFFAEDFE, 0xCAFEBABE, 0xBEBAFECA]
        return machOMagics.contains(magic)
    }

    static var hasCommandLineTools: Bool {
        FileManager.default.isExecutableFile(atPath: "/usr/bin/codesign")
    }
}
