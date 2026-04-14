import SwiftUI

@main
struct SignViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("SignViewer") {
            InstallerView()
        }
        .defaultSize(width: 480, height: 360)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var signatureWindows: [NSWindow] = []
    private var launchedViaURL = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Register URL handler before the app finishes launching
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if launchedViaURL {
            // Hide the installer window when launched via URL scheme
            DispatchQueue.main.async {
                for window in NSApp.windows where window.title.contains("SignViewer") {
                    if !window.title.contains("Signature Info") {
                        window.close()
                    }
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When clicking dock icon with no visible windows, show installer
        return true
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else { return }

        launchedViaURL = true
        DispatchQueue.main.async {
            self.openSignatureWindow(for: url)
        }
    }

    @MainActor
    private func openSignatureWindow(for url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "signviewer",
              components.host == "inspect",
              let pathItem = components.queryItems?.first(where: { $0.name == "path" }),
              let filePath = pathItem.value else { return }

        guard FileManager.default.fileExists(atPath: filePath) else { return }

        let fileURL = URL(fileURLWithPath: filePath)
        let viewModel = SignatureViewModel()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 550),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = fileURL.lastPathComponent + " — Signature Info"
        window.center()
        window.contentView = NSHostingView(
            rootView: SignatureWindowView(filePath: filePath, viewModel: viewModel)
        )
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        signatureWindows.append(window)

        // Hide installer window if visible
        DispatchQueue.main.async {
            for w in NSApp.windows where w !== window {
                if !w.title.contains("Signature Info") {
                    w.close()
                }
            }
        }
    }
}
