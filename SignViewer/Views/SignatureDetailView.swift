import SwiftUI

struct SignatureDetailView: View {
    let info: SignatureInfo

    var body: some View {
        TabView {
            summaryTab
                .tabItem { Label("概要", systemImage: "info.circle") }

            entitlementsTab
                .tabItem { Label("Entitlements", systemImage: "lock.shield") }

            profileTab
                .tabItem { Label("Profile", systemImage: "doc.badge.gearshape") }

            certChainTab
                .tabItem { Label("证书链", systemImage: "link") }
        }
        .padding()
    }

    // MARK: - Summary Tab

    private var summaryTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Status header
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

                // Details grid
                LazyVGrid(columns: [GridItem(.fixed(140), alignment: .trailing), GridItem(.flexible(), alignment: .leading)], spacing: 10) {
                    detailRow("文件类型", info.fileType.rawValue)
                    detailRow("Bundle ID", info.bundleID ?? "N/A")
                    detailRow("Team ID", info.teamID ?? "N/A")
                    detailRow("证书名称", info.certName ?? "N/A")
                    detailRow("证书序列号", info.certID ?? "N/A")
                    if let date = info.signingDate {
                        detailRow("签名日期", dateFormatter.string(from: date))
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
                emptyPlaceholder("无 Entitlements", systemImage: "lock.open")
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
                            detailRow("名称", profile.name)
                            detailRow("UUID", profile.uuid ?? "N/A")
                            detailRow("Team ID", profile.teamID ?? "N/A")
                            detailRow("App ID", profile.appID ?? "N/A")
                            if let creation = profile.creationDate {
                                detailRow("创建日期", dateFormatter.string(from: creation))
                            }
                            if let expiry = profile.expirationDate {
                                detailRow("过期日期", dateFormatter.string(from: expiry))
                                detailRow("状态", expiry > Date() ? "有效" : "已过期")
                            }
                        }
                        .padding()
                    }
                    .padding()
                }
            } else {
                emptyPlaceholder("无 Provisioning Profile", systemImage: "doc.badge.gearshape")
            }
        }
    }

    // MARK: - Certificate Chain Tab

    private var certChainTab: some View {
        Group {
            if info.certificateChain.isEmpty {
                emptyPlaceholder("无证书链信息", systemImage: "link")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(info.certificateChain.enumerated()), id: \.element.id) { index, cert in
                            HStack(alignment: .top, spacing: 12) {
                                // Indentation and chain connector
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
                                        Text("签发者: \(cert.issuer)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if let from = cert.validFrom, let to = cert.validTo {
                                        Text("有效期: \(dateFormatter.string(from: from)) ~ \(dateFormatter.string(from: to))")
                                            .font(.caption)
                                            .foregroundColor(to < Date() ? .red : .secondary)
                                    }
                                    if let serial = cert.serialNumber {
                                        Text("序列号: \(serial)")
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
