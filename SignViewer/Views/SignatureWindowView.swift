import SwiftUI

struct SignatureWindowView: View {
    let filePath: String
    @ObservedObject var viewModel: SignatureViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Reading signature info...")
                        .foregroundColor(.secondary)
                }
            } else if let info = viewModel.signatureInfo {
                SignatureDetailView(info: info)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            } else {
                ProgressView()
            }
        }
        .frame(minWidth: 600, minHeight: 450)
        .navigationTitle(URL(fileURLWithPath: filePath).lastPathComponent)
        .task {
            await viewModel.loadSignature(from: URL(fileURLWithPath: filePath))
        }
    }
}
