import Cocoa
import FinderSync

class FinderSyncExtension: FIFinderSync {
    override init() {
        super.init()
        // Monitor all volumes so the context menu appears everywhere
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems else { return nil }

        let menu = NSMenu(title: "SignViewer")
        let item = NSMenuItem(
            title: "Signing Info",
            action: #selector(viewSignatureInfo(_:)),
            keyEquivalent: ""
        )
        item.image = NSImage(systemSymbolName: "signature", accessibilityDescription: "签名信息")
        menu.addItem(item)
        return menu
    }

    @objc func viewSignatureInfo(_ sender: AnyObject?) {
        guard let items = FIFinderSyncController.default().selectedItemURLs(),
              let selectedURL = items.first else { return }

        let path = selectedURL.path
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "signviewer://inspect?path=\(encodedPath)") else { return }

        NSWorkspace.shared.open(url)
    }
}
