import Foundation
import SwiftUI

@MainActor
class SignatureViewModel: ObservableObject {
    @Published var signatureInfo: SignatureInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentFilePath: String?

    private let readers: [FileType: SignatureReader] = [
        .app: AppSignatureReader(),
        .machO: MachOSignatureReader(),
        .pkg: PKGSignatureReader(),
        .dmg: DMGSignatureReader()
    ]

    func loadSignature(from url: URL) async {
        isLoading = true
        errorMessage = nil
        signatureInfo = nil
        currentFilePath = url.lastPathComponent

        let fileType = FileTypeDetector.detect(url: url)

        guard fileType != .unknown else {
            errorMessage = "Unsupported file type: \(url.pathExtension)"
            isLoading = false
            return
        }

        guard let reader = readers[fileType] else {
            errorMessage = "No reader available for: \(fileType.rawValue)"
            isLoading = false
            return
        }

        do {
            let info = try await reader.readSignature(at: url)
            signatureInfo = info
            if let err = info.errorMessage {
                errorMessage = err
            }
        } catch {
            errorMessage = "Failed to read signature: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
