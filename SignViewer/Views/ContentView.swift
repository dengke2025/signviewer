import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var viewModel: SignatureViewModel

    @State private var isDragOver = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let info = viewModel.signatureInfo {
                SignatureDetailView(info: info)
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else {
                dropZoneView
            }
        }
        .frame(minWidth: 600, minHeight: 450)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("浏览...") {
                    openFilePicker()
                }
            }
            if viewModel.signatureInfo != nil {
                ToolbarItem(placement: .automatic) {
                    Button("清除") {
                        viewModel.signatureInfo = nil
                        viewModel.errorMessage = nil
                        viewModel.currentFilePath = nil
                    }
                }
            }
        }
        .navigationTitle(viewModel.currentFilePath ?? "SignViewer")
    }

    private var dropZoneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "signature")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("拖拽文件到此处")
                .font(.title2)
                .foregroundColor(.primary)

            Text("支持 .app, .pkg, .dmg, 可执行文件, dylib")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("或点击工具栏\"浏览\"按钮选择文件")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isDragOver ? Color.accentColor : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                .padding(20)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在读取签名信息...")
                .foregroundColor(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if message.contains("Command Line Tools") || message.contains("xcode-select") {
                Button("安装 Command Line Tools") {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
                    process.arguments = ["--install"]
                    try? process.run()
                }
                .buttonStyle(.borderedProminent)
            }

            Button("返回") {
                viewModel.errorMessage = nil
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in
                await viewModel.loadSignature(from: url)
            }
        }
        return true
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "选择要查看签名的文件"
        panel.allowedContentTypes = [
            .application,
            .package,
            .diskImage,
            .unixExecutable,
            UTType(filenameExtension: "dylib") ?? .data,
            UTType(filenameExtension: "pkg") ?? .data
        ]

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await viewModel.loadSignature(from: url)
            }
        }
    }
}
