import Foundation
import Security

struct MachOSignatureReader: SignatureReader {
    private let appReader = AppSignatureReader()

    func readSignature(at url: URL) async throws -> SignatureInfo {
        // SecStaticCode works on Mach-O binaries the same way as .app bundles
        var result = try await appReader.readSignature(at: url)
        result.fileType = .machO
        // Mach-O binaries don't have provisioning profiles
        result.provisioningProfile = nil
        return result
    }
}
