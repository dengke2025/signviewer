import Foundation

protocol SignatureReader {
    func readSignature(at url: URL) async throws -> SignatureInfo
}
