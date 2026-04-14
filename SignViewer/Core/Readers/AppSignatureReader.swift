import Foundation
import Security

struct AppSignatureReader: SignatureReader {
    func readSignature(at url: URL) async throws -> SignatureInfo {
        var info = SignatureInfo(
            filePath: url.path,
            fileType: .app,
            signStatus: .unsigned,
            entitlements: [],
            certificateChain: []
        )

        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        guard createStatus == errSecSuccess, let code = staticCode else {
            info.signStatus = .unsigned
            info.errorMessage = "无法读取签名信息: \(createStatus)"
            return info
        }

        // Validate signature
        let validityStatus = SecStaticCodeCheckValidity(code, [], nil)
        switch validityStatus {
        case errSecSuccess:
            info.signStatus = .valid
        case errSecCSUnsigned:
            info.signStatus = .unsigned
            return info
        default:
            info.signStatus = .invalid
        }

        // Get signing information
        var cfInfo: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation | kSecCSRequirementInformation),
            &cfInfo
        )
        guard infoStatus == errSecSuccess, let signingInfo = cfInfo as? [String: Any] else {
            return info
        }

        // Bundle ID
        info.bundleID = signingInfo[kSecCodeInfoIdentifier as String] as? String

        // Team ID
        info.teamID = signingInfo[kSecCodeInfoTeamIdentifier as String] as? String

        // Entitlements
        if let entDict = signingInfo[kSecCodeInfoEntitlementsDict as String] as? [String: Any] {
            info.entitlements = entDict.map { key, value in
                EntitlementInfo(key: key, value: "\(value)")
            }.sorted { $0.key < $1.key }
        }

        // Certificates
        if let certs = signingInfo[kSecCodeInfoCertificates as String] as? [SecCertificate] {
            info.certificateChain = certs.enumerated().map { _, cert in
                certificateInfo(from: cert)
            }
            // First cert is the signing cert (leaf)
            if let leafCert = certs.first {
                info.certName = SecCertificateCopySubjectSummary(leafCert) as? String
                info.certID = serialNumber(of: leafCert)
            }
            // Check expiry of leaf cert
            if let leaf = info.certificateChain.first, let validTo = leaf.validTo, validTo < Date() {
                info.signStatus = .expired
            }
        }

        // Signing date
        if let timestamp = signingInfo[kSecCodeInfoTimestamp as String] as? Date {
            info.signingDate = timestamp
        }

        // Provisioning profile
        info.provisioningProfile = readProvisioningProfile(bundleURL: url)

        return info
    }

    private func certificateInfo(from cert: SecCertificate) -> CertificateInfo {
        let subject = (SecCertificateCopySubjectSummary(cert) as? String) ?? "Unknown"

        var info = CertificateInfo(subject: subject, issuer: "Unknown")
        info.serialNumber = serialNumber(of: cert)

        // Get validity dates from certificate data
        if let values = certificateValues(cert) {
            info.validFrom = values.notBefore
            info.validTo = values.notAfter
            if let issuerName = values.issuer {
                info.issuer = issuerName
            }
        }

        return info
    }

    private func serialNumber(of cert: SecCertificate) -> String? {
        var error: Unmanaged<CFError>?
        guard let serial = SecCertificateCopySerialNumberData(cert, &error) else { return nil }
        return (serial as Data).map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    private struct CertValues {
        var notBefore: Date?
        var notAfter: Date?
        var issuer: String?
    }

    private func certificateValues(_ cert: SecCertificate) -> CertValues? {
        let keys = [
            kSecOIDX509V1ValidityNotBefore,
            kSecOIDX509V1ValidityNotAfter,
            kSecOIDX509V1IssuerName
        ] as CFArray
        guard let valuesDict = SecCertificateCopyValues(cert, keys, nil) as? [String: Any] else {
            return nil
        }
        var result = CertValues()
        for (_, val) in valuesDict {
            guard let entry = val as? [String: Any],
                  let label = entry[kSecPropertyKeyLabel as String] as? String,
                  let value = entry[kSecPropertyKeyValue as String] else { continue }
            let notBeforeKey = kSecOIDX509V1ValidityNotBefore as String
            let notAfterKey = kSecOIDX509V1ValidityNotAfter as String
            let issuerKey = kSecOIDX509V1IssuerName as String
            if label == notBeforeKey {
                result.notBefore = value as? Date ?? (value as? NSNumber).flatMap { Date(timeIntervalSinceReferenceDate: $0.doubleValue) }
            } else if label == notAfterKey {
                result.notAfter = value as? Date ?? (value as? NSNumber).flatMap { Date(timeIntervalSinceReferenceDate: $0.doubleValue) }
            } else if label == issuerKey {
                if let issuerEntries = value as? [[String: Any]] {
                    let cn = issuerEntries.first { ($0[kSecPropertyKeyLabel as String] as? String) == "2.5.4.3" }
                    result.issuer = cn?[kSecPropertyKeyValue as String] as? String
                }
            }
        }
        return result
    }

    private func readProvisioningProfile(bundleURL: URL) -> ProvisioningProfileInfo? {
        let profileURL = bundleURL.appendingPathComponent("Contents/embedded.provisionprofile")
        let mobileProfileURL = bundleURL.appendingPathComponent("embedded.mobileprovision")

        let url: URL
        if FileManager.default.fileExists(atPath: profileURL.path) {
            url = profileURL
        } else if FileManager.default.fileExists(atPath: mobileProfileURL.path) {
            url = mobileProfileURL
        } else {
            return nil
        }

        guard let data = try? Data(contentsOf: url) else { return nil }
        return parseProvisioningProfile(data: data)
    }

    private func parseProvisioningProfile(data: Data) -> ProvisioningProfileInfo? {
        // CMS decode to extract the plist
        var decoder: CMSDecoder?
        CMSDecoderCreate(&decoder)
        guard let cms = decoder else { return nil }

        data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            CMSDecoderUpdateMessage(cms, baseAddress, data.count)
        }
        CMSDecoderFinalizeMessage(cms)

        var content: CFData?
        CMSDecoderCopyContent(cms, &content)
        guard let plistData = content as Data?,
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }

        return ProvisioningProfileInfo(
            name: plist["Name"] as? String ?? "Unknown",
            expirationDate: plist["ExpirationDate"] as? Date,
            teamID: (plist["TeamIdentifier"] as? [String])?.first,
            appID: (plist["Entitlements"] as? [String: Any])?["application-identifier"] as? String,
            creationDate: plist["CreationDate"] as? Date,
            uuid: plist["UUID"] as? String
        )
    }
}
