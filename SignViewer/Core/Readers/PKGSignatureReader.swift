import Foundation

struct PKGSignatureReader: SignatureReader {
    func readSignature(at url: URL) async throws -> SignatureInfo {
        var info = SignatureInfo(
            filePath: url.path,
            fileType: .pkg,
            signStatus: .unsigned,
            entitlements: [],
            certificateChain: []
        )

        guard FileTypeDetector.hasCommandLineTools else {
            info.errorMessage = "Xcode Command Line Tools required to inspect .pkg signatures. Run: xcode-select --install"
            return info
        }

        let output = try await runProcess("/usr/sbin/pkgutil", arguments: ["--check-signature", url.path])
        parsePKGOutput(output, into: &info)
        return info
    }

    private func parsePKGOutput(_ output: String, into info: inout SignatureInfo) {
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("signed by") || trimmed.contains("Status: signed") {
                info.signStatus = .valid
            } else if trimmed.contains("unsigned") || trimmed.contains("Status: no signature") {
                info.signStatus = .unsigned
                return
            } else if trimmed.contains("invalid") || trimmed.contains("expired") {
                info.signStatus = .invalid
            }

            // Parse certificate chain entries (numbered lines like "1. ...")
            if let range = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                let certSubject = String(trimmed[range.upperBound...])
                info.certificateChain.append(CertificateInfo(
                    subject: certSubject,
                    issuer: "Unknown"
                ))
            }
        }

        if let firstCert = info.certificateChain.first {
            info.certName = firstCert.subject
        }
    }

    private func runProcess(_ path: String, arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
