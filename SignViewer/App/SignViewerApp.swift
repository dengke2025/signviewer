import SwiftUI

@main
struct SignViewerApp: App {
    @StateObject private var viewModel = SignatureViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .onOpenURL { url in
                    handleURL(url)
                }
        }
        .defaultSize(width: 700, height: 550)
    }

    private func handleURL(_ url: URL) {
        // Handle signviewer://inspect?path=<encoded_path>
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "signviewer",
              components.host == "inspect",
              let pathItem = components.queryItems?.first(where: { $0.name == "path" }),
              let filePath = pathItem.value else {
            return
        }

        let fileURL = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: filePath) else {
            Task { @MainActor in
                viewModel.errorMessage = "文件不存在: \(filePath)"
            }
            return
        }

        Task {
            await viewModel.loadSignature(from: fileURL)
        }
    }
}
