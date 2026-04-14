# SignViewer

A macOS native tool for viewing code signature information of applications, binaries, and packages. Works as a Finder extension — right-click any file to inspect its signing details.

Inspired by [WhatsYourSign](https://objective-see.org/products/whatsyoursign.html).

## Features

- **Finder Integration** — Right-click any file, select "Signing Info" to view details
- **One-Click Install** — Simple installer copies to /Applications and enables the Finder extension
- **Four information tabs:**
  - **Summary** — Bundle ID, Team ID, Certificate Name, Signing Status
  - **Entitlements** — Sandbox, Hardened Runtime, and other permissions
  - **Profile** — Provisioning Profile name, expiration, App ID
  - **Certificate Chain** — Full chain from Root CA to leaf certificate

### Supported File Types

| Type | Method |
|------|--------|
| `.app` bundles | Security.framework (`SecStaticCode`) |
| Mach-O executables / dylib | Security.framework (`SecStaticCode`) |
| `.pkg` installer packages | `pkgutil --check-signature` |
| `.dmg` disk images | `codesign -dvvv` / `spctl --assess` |

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ (to build)
- Xcode Command Line Tools (for `.pkg` / `.dmg` signature inspection)

## Build

```bash
# Install xcodegen if needed
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Build from command line
xcodebuild -scheme SignViewer -configuration Release build

# Or open in Xcode
open SignViewer.xcodeproj
```

## Install

1. Open `SignViewer.app`
2. Click **Install**
3. Finder restarts automatically
4. Right-click any file in Finder → **Signing Info**

To uninstall, open SignViewer.app again and click **Uninstall**.

## Architecture

```
┌─────────────────────┐     URL Scheme      ┌──────────────────────┐
│  Finder Extension    │ ──────────────────> │     Host App         │
│  (sandboxed)         │  signviewer://      │  (non-sandboxed)     │
│                      │  inspect?path=...   │                      │
│  Right-click menu    │                     │  Security.framework  │
│  NSWorkspace.open()  │                     │  codesign / pkgutil  │
└─────────────────────┘                      └──────────────────────┘
```

- **Finder Extension** — Adds the right-click menu item, passes file path to host app via URL scheme
- **Host App** — Reads all signature info and displays results. Runs as `LSUIElement` (no Dock icon) when triggered from Finder

## Project Structure

```
signviewer/
├── project.yml                     # XcodeGen project config
├── SignViewer/
│   ├── App/SignViewerApp.swift     # Entry point + URL scheme handler
│   ├── Models/SignatureInfo.swift  # Data models
│   ├── Core/
│   │   ├── SignatureReader.swift   # Reader protocol
│   │   ├── FileTypeDetector.swift  # File type detection (UTI + Mach-O magic)
│   │   └── Readers/               # Per-type signature readers
│   ├── ViewModels/                 # View model
│   └── Views/
│       ├── InstallerView.swift     # Install / Uninstall UI
│       ├── SignatureDetailView.swift # 4-tab signature display
│       └── SignatureWindowView.swift # Window wrapper
└── SignViewerFinder/               # Finder Sync Extension
    └── FinderSync.swift
```

## License

MIT
