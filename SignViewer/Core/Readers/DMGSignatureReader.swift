import Foundation

struct DMGSignatureReader: SignatureReader {
    func readSignature(at url: URL) async throws -> SignatureInfo {
        var info = SignatureInfo(
            filePath: url.path,
            fileType: .dmg,
            signStatus: .unsigned,
            entitlements: [],
            certificateChain: []
        )

        guard FileTypeDetector.hasCommandLineTools else {
            info.errorMessage = "Xcode Command Line Tools required to inspect .dmg signatures. Run: xcode-select --install"
            return info
        }

        // Use codesign to get signature details
        let codesignOutput = try await runProcess("/usr/bin/codesign", arguments: ["-dvvv", url.path])
        parseCodesignOutput(codesignOutput, into: &info)

        // Use spctl to assess validity
        let spctlOutput = try await runProcess("/usr/sbin/spctl", arguments: [
            "--assess", "--type", "open", "--context", "context:primary-signature", "-v", url.path
        ])
        if spctlOutput.contains("accepted") {
            info.signStatus = .valid
        } else if spctlOutput.contains("rejected") {
            info.signStatus = .invalid
        }

        return info
    }

    private func parseCodesignOutput(_ output: String, into info: inout SignatureInfo) {
        let lines = output.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Identifier=") {
                info.bundleID = String(trimmed.dropFirst("Identifier=".count))
            } else if trimmed.hasPrefix("TeamIdentifier=") {
                let value = String(trimmed.dropFirst("TeamIdentifier=".count))
                if value != "not set" {
                    info.teamID = value
                }
            } else if trimmed.hasPrefix("Authority=") {
                let certSubject = String(trimmed.dropFirst("Authority=".count))
                info.certificateChain.append(CertificateInfo(
                    subject: certSubject,
                    issuer: "Unknown"
                ))
                if info.certName == nil {
                    info.certName = certSubject
                }
            } else if trimmed.hasPrefix("Timestamp=") {
                let dateStr = String(trimmed.dropFirst("Timestamp=".count))
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "MMM d, yyyy 'at' h:mm:ss a"
                info.signingDate = formatter.date(from: dateStr)
            }
        }

        if !info.certificateChain.isEmpty {
            info.signStatus = .valid
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
