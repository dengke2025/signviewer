# SignViewer Implementation Plan (v2 — Consensus Approved)

## Source Spec
`.omc/specs/deep-interview-signviewer.md`

## Requirements Summary
Build **SignViewer**, a macOS native app (SwiftUI, macOS 13+) consisting of:
1. **Host App** — standalone window with drag-and-drop support for viewing code signature details, registers custom URL scheme `signviewer://`
2. **Finder Sync Extension** — right-click context menu item "查看签名信息" that launches host app via URL scheme

Supported file types: `.app` bundles, Mach-O executables/dylibs, `.pkg` installers, `.dmg` disk images.

Information displayed: Bundle ID, Team ID, Certificate Name/ID, signing status, Entitlements, Provisioning Profile, full certificate chain.

## RALPLAN-DR Summary

### Principles
1. **Security-first data access** — Use Apple Security.framework APIs (`SecStaticCode`, `SecTrust`) as primary; fall back to CLI tools (`codesign`, `pkgutil`) only when APIs are insufficient
2. **Extension isolation** — Finder extension is a thin trigger that only passes a file path via URL scheme; all logic lives in host app
3. **Progressive disclosure** — Show summary (Bundle ID, Team ID, status) first; detailed tabs for Entitlements, Profile, Certificate chain
4. **Uniform file handling** — Single `SignatureReader` protocol with type-specific implementations, so adding file types later is trivial
5. **Simplest viable IPC** — URL scheme for extension→app communication; no XPC complexity unless bidirectional feedback is needed later

### Decision Drivers
1. **Finder extension sandbox constraints** — Cannot call `Process`/`codesign` from extension; must delegate to host app
2. **Host app lifecycle** — Extension must be able to launch the host app if not running; URL scheme solves this automatically
3. **File type diversity** — `.app`, Mach-O, `.pkg`, `.dmg` each need different reading strategies

### Viable Options

**Option A: URL Scheme (Chosen)**
- Finder extension calls `NSWorkspace.shared.open(signviewerURL)` with `signviewer://inspect?path=<encoded_path>`
- Host app registers URL scheme in Info.plist, handles incoming URL, reads signature, shows window
- Pros: 2 targets only (app + extension), auto-launches host app, zero IPC code, simple and reliable
- Cons: One-way communication (extension can't receive results back), no structured error reporting to extension

**Option B: XPC via registered Mach service**
- Host app registers a launchd Mach service; extension connects via `NSXPCConnection(machServiceName:)`
- Pros: Bidirectional, type-safe, Apple-recommended for complex IPC
- Cons: 3 targets, launchd plist management, host app must register service at launch, significantly more complex

**Option C: App Groups + shared container**
- Extension writes to shared UserDefaults; host app polls/observes
- Pros: Simple setup
- Cons: Latency, race conditions, unreliable

*Option B deferred:* XPC Mach service adds significant complexity for bidirectional communication that v1 doesn't need. The extension only needs to say "open this file" — URL scheme is sufficient. Can upgrade to Mach service later if the extension needs to display results inline.

*Option C invalidated:* Polling-based communication is unreliable and introduces unacceptable latency.

## Acceptance Criteria
- [ ] AC1: Finder右键.app → "查看签名信息" menu item appears
- [ ] AC2: Popup shows Bundle ID, Team ID, Cert Name, signing status (valid/expired/unsigned)
- [ ] AC3: Entitlements tab lists all entitlements with key-value display
- [ ] AC4: Provisioning Profile tab shows name, expiry, team, app ID
- [ ] AC5: Certificate Chain tab shows Root CA → Intermediate → Leaf with validity dates
- [ ] AC6: Supports Mach-O binaries and dylibs (display cert info, entitlements)
- [ ] AC7: Supports .pkg signature display via `pkgutil --check-signature`
- [ ] AC8: Supports .dmg signature display via `codesign -dvvv`
- [ ] AC9: Host app standalone: drag-and-drop file onto window triggers same info display
- [ ] AC10: Runs on macOS 13+ (Ventura)

## Implementation Steps

### Phase 1: Project Setup & Data Models
1. Create Xcode project `SignViewer` with SwiftUI App lifecycle
   - Target: macOS 13+, Swift
   - Register URL scheme `signviewer` in Info.plist (`CFBundleURLSchemes`)
   - File: `SignViewer.xcodeproj`
2. Define data models (needed by all subsequent phases)
   - File: `SignViewer/Models/SignatureInfo.swift`
     - `SignatureInfo`: bundleID, teamID, certName, certID, signStatus, signingDate, fileType, filePath
     - `EntitlementInfo`: key (String), value (String/Bool representation)
     - `ProvisioningProfileInfo`: name, expirationDate, teamID, appID
     - `CertificateInfo`: subject, issuer, validFrom, validTo, serialNumber
     - `CertificateChain`: [CertificateInfo] (ordered root→leaf)
     - `SigningStatus`: enum (valid, expired, unsigned, invalid)
     - `FileType`: enum (app, machO, pkg, dmg, unknown)
3. Add Finder Sync Extension target: `SignViewerFinder`
   - Enable Finder Sync capability
   - File: `SignViewerFinder/FinderSync.swift`

### Phase 2: Core Signature Reading
4. Create `SignatureReader` protocol
   - File: `SignViewer/Core/SignatureReader.swift`
   - Protocol: `func readSignature(at url: URL) async throws -> SignatureInfo`
5. Implement file type detection
   - File: `SignViewer/Core/FileTypeDetector.swift`
   - UTI-based detection: `.app` bundle, Mach-O (executable/dylib), `.pkg`, `.dmg`
   - CLI tools availability check: `FileManager.default.isExecutableFile(atPath: "/usr/bin/codesign")`
   - Returns `FileType` enum
6. Implement `AppSignatureReader` for .app bundles
   - File: `SignViewer/Core/Readers/AppSignatureReader.swift`
   - Uses `SecStaticCodeCreateWithPath` → `SecCodeCopySigningInformation` for:
     - Bundle ID (`kSecCodeInfoIdentifier`)
     - Team ID (`kSecCodeInfoTeamIdentifier`)
     - Certificate info (from `kSecCodeInfoCertificates`)
     - Entitlements (`kSecCodeInfoEntitlementsDict`)
   - Reads `embedded.mobileprovision` via `CMSDecoder` for provisioning profile
   - Extracts certificate chain via `SecTrust` from signing certificates
   - Validates signature via `SecStaticCodeCheckValidity` for status
7. Implement `MachOSignatureReader` for executables/dylibs
   - File: `SignViewer/Core/Readers/MachOSignatureReader.swift`
   - Same `SecStaticCode` approach as AppSignatureReader (Mach-O files are directly signable)
   - No provisioning profile (Mach-O binaries don't embed them)
8. Implement `PKGSignatureReader` for .pkg files
   - File: `SignViewer/Core/Readers/PKGSignatureReader.swift`
   - Uses `Process` to call `pkgutil --check-signature <path>`
   - Parses stdout for certificate subject, trust status
   - **Graceful degradation:** If `pkgutil` unavailable, return `SignatureInfo` with status `.invalid` and error message "Command Line Tools required for .pkg inspection"
9. Implement `DMGSignatureReader` for .dmg files
   - File: `SignViewer/Core/Readers/DMGSignatureReader.swift`
   - Uses `Process` to call `codesign -dvvv <path>` for signature details
   - Uses `spctl --assess --type open --context context:primary-signature <path>` for validation
   - **Graceful degradation:** Same pattern as PKGSignatureReader

### Phase 3: URL Scheme Handling
10. Implement URL scheme handler in host app
    - File: `SignViewer/App/SignViewerApp.swift`
    - Use `.onOpenURL { url in ... }` modifier
    - Parse `signviewer://inspect?path=<percent_encoded_path>`
    - Decode path, detect file type, invoke appropriate reader
    - Open/focus the signature detail window with results
11. Create `SignatureViewModel` to manage async reading
    - File: `SignViewer/ViewModels/SignatureViewModel.swift`
    - `@MainActor class SignatureViewModel: ObservableObject`
    - Properties: `signatureInfo`, `isLoading`, `error`
    - Method: `loadSignature(from url: URL) async`
    - Routes to correct reader via `FileTypeDetector`

### Phase 4: Finder Extension
12. Implement FinderSync extension
    - File: `SignViewerFinder/FinderSync.swift`
    - Override `menu(for:)` → return NSMenu with "查看签名信息" item
    - On menu action: get selected file URL from `FIFinderSyncController.default().selectedItemURLs()`
    - Percent-encode the file path
    - Call `NSWorkspace.shared.open(URL(string: "signviewer://inspect?path=\(encodedPath)")!)`
    - This automatically launches the host app if not running
    - Supported UTI: register for all file types (filtering happens in host app)

### Phase 5: Host App UI
13. Main window with drag-drop zone
    - File: `SignViewer/Views/ContentView.swift`
    - Central drop zone with icon and "拖拽文件到此处或点击浏览" text
    - `onDrop(of:)` accepting file URLs
    - "浏览" button → `NSOpenPanel` with supported file type filters
    - On file received: feed to `SignatureViewModel`
14. Signature detail view with tabs
    - File: `SignViewer/Views/SignatureDetailView.swift`
    - Tab 1 "概要": Bundle ID, Team ID, Cert Name, signing date, Status badge (green checkmark = valid, red X = invalid/expired, gray ? = unsigned)
    - Tab 2 "Entitlements": Scrollable list of entitlement key-value pairs, grouped by category
    - Tab 3 "Profile": Provisioning profile details (name, expiry, team, app ID), or "无 Provisioning Profile" placeholder
    - Tab 4 "证书链": Vertical chain visualization (indented list: Root CA → Intermediate → Leaf), each showing subject, issuer, validity period
15. Loading and error states
    - File: `SignViewer/Views/StatusViews.swift`
    - Loading spinner while reading signature
    - Error view for: unsigned files, permission denied, CLI tools missing, corrupted files
    - "CLI tools missing" error includes button to run `xcode-select --install`

### Phase 6: Integration & Polish
16. Wire up complete flow: Finder right-click → URL scheme → host app → read → display
17. Handle edge cases:
    - File doesn't exist (moved/deleted between right-click and app open)
    - File is not a supported type
    - Permission denied (SIP-protected binaries)
    - Provisioning profile absent (common for Mac apps)
18. App icon and Info.plist configuration
    - App category: Developer Tools
    - `LSUIElement`: false (app shows in Dock when running)
19. Window management
    - File: `SignViewer/App/WindowManager.swift`
    - Single-window mode: reuse existing window for new files
    - Window title shows current file name

## Risks and Mitigations
| Risk | Impact | Mitigation |
|------|--------|------------|
| Finder Sync Extension deprecated in future macOS | Extension stops working | Architecture is decoupled; host app works standalone. Can migrate to Action Extension. |
| `codesign`/`pkgutil` CLI unavailable | PKG/DMG reading fails | `FileTypeDetector` checks CLI availability upfront; readers return graceful error with "Install CLI Tools" button |
| Security.framework API changes | Compile errors on new macOS | Pin to stable APIs available since macOS 10.12+; all used APIs are mature |
| Provisioning Profile absent | Empty Profile tab | Show "无 Provisioning Profile" placeholder gracefully |
| URL scheme hijacking (another app registers same scheme) | Wrong app opens | Use unique scheme `signviewer`; verify bundle ID in URL handler |
| SIP-protected binaries | Permission denied reading signature | Catch security errors; show "系统完整性保护限制访问" message |

## Verification Steps
1. Build and run on macOS 13 — verify both targets compile
2. Right-click a signed .app in Finder → verify "查看签名信息" context menu appears
3. Click menu item → verify host app launches (if not running) and shows signature info
4. Verify popup shows correct Bundle ID, Team ID, cert info for a known app (e.g., Safari)
5. Drag a .app to main window → verify same info displays
6. Test unsigned app → verify "未签名" status badge (gray)
7. Test expired certificate → verify "已过期" status badge (red)
8. Test Mach-O binary (e.g., `/usr/bin/swift`) → verify cert info, no Profile tab content
9. Test .pkg file → verify pkgutil-based signature info
10. Test .dmg file → verify codesign-based signature info
11. Test entitlements display on sandboxed app (e.g., App Store app)
12. Test certificate chain: verify 3-level chain (Apple Root → WWDR → Developer)
13. Test with Xcode CLI tools uninstalled → verify graceful error for .pkg/.dmg
14. Test file that no longer exists → verify error message
15. Test right-click on unsupported file type → verify graceful handling

## ADR

### Decision
Use URL Scheme architecture (`signviewer://inspect?path=...`) with host app + Finder Sync Extension as two targets in one Xcode project.

### Drivers
- Finder extensions are sandboxed and cannot call external processes or Security.framework fully
- Extension must be able to launch host app if not running — URL scheme does this automatically
- v1 only needs one-way communication (file path from extension to app)
- Minimizing targets reduces build complexity for a developer self-use tool

### Alternatives Considered
1. **XPC via registered Mach service** — Deferred. Provides bidirectional type-safe IPC but adds launchd plist, 3rd target, and significant complexity. Not needed for v1's one-way "open this file" communication.
2. **App Groups + shared UserDefaults** — Rejected. Polling-based, unreliable, race conditions.
3. **Pure CLI tool** — Rejected per user preference for GUI.
4. **Standalone app only (no Finder extension)** — Rejected per user preference for Finder integration.

### Why Chosen
URL scheme is the simplest reliable mechanism for the extension's sole job: "tell the host app to open a file." It auto-launches the app, requires zero IPC infrastructure, and reduces the project to 2 targets. The one-way limitation is acceptable because the extension doesn't need to display results — the host app window does.

### Consequences
- One-way only: extension cannot show inline results or loading state (acceptable for v1)
- URL scheme could be hijacked by another app with same scheme (mitigated by unique name)
- Host app window appears on every Finder trigger (by design — this is the UI)

### Follow-ups
- Upgrade to XPC Mach service if v2 needs bidirectional extension↔app communication
- Consider Action Extension migration if Finder Sync is deprecated
- Evaluate notarization for broader distribution in v2
- Consider adding .ipa support in v2

## Revision Changelog
- **v2**: Replaced XPC Service architecture with URL scheme per Architect/Critic consensus
  - Fixed: Finder extension cannot connect to XPC Service in host app bundle (critical arch flaw)
  - Fixed: Moved data models to Phase 1 (before readers that depend on them)
  - Fixed: Added explicit CLI tools detection with graceful degradation
  - Fixed: Host app auto-launches via URL scheme (no more "must be running" issue)
  - Added: 3rd viable option (XPC Mach service) with proper deferred rationale
  - Reduced: 3 targets → 2 targets (removed XPC Service target)
