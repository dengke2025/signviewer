import Foundation

enum SigningStatus: String, Codable {
    case valid = "Valid"
    case expired = "Expired"
    case unsigned = "Unsigned"
    case invalid = "Invalid"
}

enum FileType: String, Codable {
    case app = "Application Bundle"
    case machO = "Mach-O Binary"
    case pkg = "Installer Package"
    case dmg = "Disk Image"
    case unknown = "Unknown"
}

struct SignatureInfo: Codable, Identifiable {
    let id = UUID()
    var filePath: String
    var fileType: FileType
    var bundleID: String?
    var teamID: String?
    var certName: String?
    var certID: String?
    var signStatus: SigningStatus
    var signingDate: Date?
    var entitlements: [EntitlementInfo]
    var provisioningProfile: ProvisioningProfileInfo?
    var certificateChain: [CertificateInfo]
    var errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case filePath, fileType, bundleID, teamID, certName, certID
        case signStatus, signingDate, entitlements, provisioningProfile
        case certificateChain, errorMessage
    }
}

struct EntitlementInfo: Codable, Identifiable, Hashable {
    let id = UUID()
    var key: String
    var value: String

    enum CodingKeys: String, CodingKey {
        case key, value
    }
}

struct ProvisioningProfileInfo: Codable {
    var name: String
    var expirationDate: Date?
    var teamID: String?
    var appID: String?
    var creationDate: Date?
    var uuid: String?
}

struct CertificateInfo: Codable, Identifiable, Hashable {
    let id = UUID()
    var subject: String
    var issuer: String
    var validFrom: Date?
    var validTo: Date?
    var serialNumber: String?

    enum CodingKeys: String, CodingKey {
        case subject, issuer, validFrom, validTo, serialNumber
    }
}
