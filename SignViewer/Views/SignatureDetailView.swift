import SwiftUI

struct SignatureDetailView: View {
    let info: SignatureInfo

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                tabButton("Summary", systemImage: "info.circle", tag: 0)
                tabButton("Entitlements", systemImage: "lock.shield", tag: 1)
                tabButton("Profile", systemImage: "doc.badge.gearshape", tag: 2)
                tabButton("Certificate Chain", systemImage: "link", tag: 3)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case 0: summaryTab
                case 1: entitlementsTab
                case 2: profileTab
                case 3: certChainTab
                default: summaryTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func tabButton(_ title: String, systemImage: String, tag: Int) -> some View {
        Button(action: { selectedTab = tag }) {
            Label(title, systemImage: systemImage)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedTab == tag ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .foregroundColor(selectedTab == tag ? .accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Summary Tab

    private var summaryTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    statusIcon
                    VStack(alignment: .leading) {
                        Text(info.signStatus.rawValue)
                            .font(.title2.bold())
                        Text(info.filePath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(statusBackgroundColor))

                LazyVGrid(columns: [GridItem(.fixed(140), alignment: .trailing), GridItem(.flexible(), alignment: .leading)], spacing: 10) {
                    detailRow("File Type", info.fileType.rawValue)
                    detailRow("Bundle ID", info.bundleID ?? "N/A")
                    detailRow("Team ID", info.teamID ?? "N/A")
                    detailRow("Certificate", info.certName ?? "N/A")
                    detailRow("Serial Number", info.certID ?? "N/A")
                    if let date = info.signingDate {
                        detailRow("Signing Date", dateFormatter.string(from: date))
                    }
                }
                .padding()
            }
            .padding()
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch info.signStatus {
        case .valid:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36))
                .foregroundColor(.green)
        case .expired:
            Image(systemName: "xmark.seal.fill")
                .font(.system(size: 36))
                .foregroundColor(.red)
        case .unsigned:
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.gray)
        case .invalid:
            Image(systemName: "xmark.seal.fill")
                .font(.system(size: 36))
                .foregroundColor(.red)
        }
    }

    private var statusBackgroundColor: Color {
        switch info.signStatus {
        case .valid: return Color.green.opacity(0.1)
        case .expired, .invalid: return Color.red.opacity(0.1)
        case .unsigned: return Color.gray.opacity(0.1)
        }
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String) -> some View {
        Text(label)
            .font(.body)
            .foregroundColor(.secondary)
        Text(value)
            .font(.body.monospaced())
            .textSelection(.enabled)
    }

    // MARK: - Entitlements Tab

    private var entitlementsTab: some View {
        Group {
            if info.entitlements.isEmpty {
                emptyPlaceholder("No Entitlements", systemImage: "lock.open")
            } else {
                List(info.entitlements) { ent in
                    HStack(alignment: .top) {
                        Text(ent.key)
                            .font(.body.monospaced())
                            .foregroundColor(.primary)
                            .frame(minWidth: 200, alignment: .leading)
                        Spacer()
                        Text(ent.value)
                            .font(.body.monospaced())
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Provisioning Profile Tab

    private var profileTab: some View {
        Group {
            if let profile = info.provisioningProfile {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        LazyVGrid(columns: [GridItem(.fixed(140), alignment: .trailing), GridItem(.flexible(), alignment: .leading)], spacing: 10) {
                            detailRow("Name", profile.name)
                            detailRow("UUID", profile.uuid ?? "N/A")
                            detailRow("Team ID", profile.teamID ?? "N/A")
                            detailRow("App ID", profile.appID ?? "N/A")
                            if let creation = profile.creationDate {
                                detailRow("Created", dateFormatter.string(from: creation))
                            }
                            if let expiry = profile.expirationDate {
                                detailRow("Expires", dateFormatter.string(from: expiry))
                                detailRow("Status", expiry > Date() ? "Valid" : "Expired")
                            }
                        }
                        .padding()
                    }
                    .padding()
                }
            } else {
                emptyPlaceholder("No Provisioning Profile", systemImage: "doc.badge.gearshape")
            }
        }
    }

    // MARK: - Certificate Chain Tab

    private var certChainTab: some View {
        Group {
            if info.certificateChain.isEmpty {
                emptyPlaceholder("No Certificate Chain", systemImage: "link")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(info.certificateChain.enumerated()), id: \.element.id) { index, cert in
                            HStack(alignment: .top, spacing: 12) {
                                VStack {
                                    if index > 0 {
                                        Rectangle()
                                            .fill(Color.secondary.opacity(0.3))
                                            .frame(width: 2, height: 20)
                                    }
                                    Circle()
                                        .fill(index == 0 ? Color.blue : Color.secondary)
                                        .frame(width: 10, height: 10)
                                    if index < info.certificateChain.count - 1 {
                                        Rectangle()
                                            .fill(Color.secondary.opacity(0.3))
                                            .frame(width: 2, height: 40)
                                    }
                                }
                                .padding(.leading, CGFloat(index) * 20)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cert.subject)
                                        .font(.body.bold())
                                        .textSelection(.enabled)
                                    if cert.issuer != "Unknown" {
                                        Text("Issuer: \(cert.issuer)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if let from = cert.validFrom, let to = cert.validTo {
                                        Text("Valid: \(dateFormatter.string(from: from)) — \(dateFormatter.string(from: to))")
                                            .font(.caption)
                                            .foregroundColor(to < Date() ? .red : .secondary)
                                    }
                                    if let serial = cert.serialNumber {
                                        Text("Serial: \(serial)")
                                            .font(.caption.monospaced())
                                            .foregroundColor(.secondary)
                                            .textSelection(.enabled)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Helpers

    private func emptyPlaceholder(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text(text)
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }
}
