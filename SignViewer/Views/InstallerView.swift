import SwiftUI

struct InstallerView: View {
    @State private var installState: InstallState = .ready
    @State private var isInstalled = false

    enum InstallState {
        case ready
        case installing
        case success
        case error(String)
    }

    var body: some View {
        VStack(spacing: 24) {
            // Show in Dock when installer is visible
            EmptyView().onAppear {
                NSApp.setActivationPolicy(.regular)
            }.onDisappear {
                NSApp.setActivationPolicy(.accessory)
            }

            // App icon area
            Image(systemName: "signature")
                .font(.system(size: 72))
                .foregroundColor(.accentColor)

            Text("SignViewer")
                .font(.largeTitle.bold())

            Text("A Finder extension for viewing code signature info")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Divider()
                .padding(.horizontal, 40)

            switch installState {
            case .ready:
                if isInstalled {
                    installedView
                } else {
                    readyView
                }
            case .installing:
                ProgressView("Installing...")
                    .padding()
            case .success:
                successView
            case .error(let msg):
                errorView(msg)
            }

            Spacer()

            Text("After installation, right-click any file in Finder to view its signature")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            checkInstalled()
        }
    }

    private var readyView: some View {
        VStack(spacing: 12) {
            Button(action: install) {
                Label("Install", systemImage: "arrow.down.circle.fill")
                    .font(.title3)
                    .frame(width: 200, height: 44)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Installs SignViewer to /Applications and enables the Finder extension")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var installedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.green)

            Text("Installed")
                .font(.title3.bold())

            HStack(spacing: 16) {
                Button("Reinstall") {
                    install()
                }
                Button("Uninstall") {
                    uninstall()
                }
                .foregroundColor(.red)
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.green)

            Text("Installation Successful!")
                .font(.title3.bold())

            Text("Finder has been restarted. You can now right-click any file to view its signature.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.orange)

            Text("Installation Failed")
                .font(.title3.bold())

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                installState = .ready
            }
        }
    }

    private func checkInstalled() {
        let installedPath = "/Applications/SignViewer.app"
        isInstalled = FileManager.default.fileExists(atPath: installedPath)
    }

    private func install() {
        installState = .installing

        DispatchQueue.global(qos: .userInitiated).async {
            let result = performInstall()
            DispatchQueue.main.async {
                switch result {
                case .success:
                    installState = .success
                    isInstalled = true
                case .failure(let error):
                    installState = .error(error.localizedDescription)
                }
            }
        }
    }

    private func performInstall() -> Result<Void, Error> {
        let fm = FileManager.default
        let source = Bundle.main.bundlePath
        let dest = "/Applications/SignViewer.app"

        do {
            if fm.fileExists(atPath: dest) {
                try fm.removeItem(atPath: dest)
            }

            try fm.copyItem(atPath: source, toPath: dest)

            let pluginkit = Process()
            pluginkit.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            pluginkit.arguments = ["-e", "use", "-i", "com.signviewer.app.finder"]
            try pluginkit.run()
            pluginkit.waitUntilExit()

            let killall = Process()
            killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killall.arguments = ["Finder"]
            try killall.run()
            killall.waitUntilExit()

            return .success(())
        } catch {
            return .failure(error)
        }
    }

    private func uninstall() {
        installState = .installing

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let dest = "/Applications/SignViewer.app"

            do {
                let pluginkit = Process()
                pluginkit.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
                pluginkit.arguments = ["-e", "ignore", "-i", "com.signviewer.app.finder"]
                try pluginkit.run()
                pluginkit.waitUntilExit()

                if fm.fileExists(atPath: dest) {
                    try fm.removeItem(atPath: dest)
                }

                let killall = Process()
                killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
                killall.arguments = ["Finder"]
                try killall.run()
                killall.waitUntilExit()

                DispatchQueue.main.async {
                    installState = .ready
                    isInstalled = false
                }
            } catch {
                DispatchQueue.main.async {
                    installState = .error(error.localizedDescription)
                }
            }
        }
    }
}
