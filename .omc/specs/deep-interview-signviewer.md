# Deep Interview Spec: SignViewer - macOS Code Signature Viewer

## Metadata
- Interview ID: signviewer-20260414
- Rounds: 6
- Final Ambiguity Score: 14.5%
- Type: greenfield
- Generated: 2026-04-14
- Threshold: 20%
- Status: PASSED

## Clarity Breakdown
| Dimension | Score | Weight | Weighted |
|-----------|-------|--------|----------|
| Goal Clarity | 0.90 | 0.40 | 0.36 |
| Constraint Clarity | 0.85 | 0.30 | 0.255 |
| Success Criteria | 0.80 | 0.30 | 0.24 |
| **Total Clarity** | | | **0.855** |
| **Ambiguity** | | | **14.5%** |

## Goal
构建一个macOS原生应用 **SignViewer**，由主应用 + Finder扩展组成。用户在Finder中右键点击程序文件，通过扩展触发查看该文件的代码签名详情（Bundle ID、Team ID、Certificate、Entitlements、Provisioning Profile、证书链等），信息在弹窗中展示。主应用负责实际的签名信息读取，Finder扩展通过XPC与主应用通信。

## Constraints
- **技术栈:** SwiftUI + macOS 13+ (Ventura)
- **架构:** 主应用(host app) + Finder Sync Extension，通过XPC通信
- **签名读取:** 使用Security.framework API + codesign命令行工具（主应用中调用）
- **Sandbox:** Finder扩展运行在sandbox中，签名读取逻辑在主应用/XPC服务中完成
- **语言:** Swift

## Non-Goals
- 不做iOS .ipa文件支持（首版）
- 不做签名修改/重签名功能
- 不做App Store分发（首版，开发者自用工具）
- 不做代码签名验证的自动化/批量功能

## Acceptance Criteria
- [ ] Finder中右键.app文件，出现"查看签名信息"菜单项
- [ ] 点击后弹窗展示：Bundle ID, Team ID, Certificate Name/ID, 签名状态(有效/过期/无签名)
- [ ] 弹窗展示Entitlements列表（sandbox, hardened runtime等权限）
- [ ] 弹窗展示Provisioning Profile信息（过期时间等）
- [ ] 弹窗展示完整证书链（Root CA → 中间证书 → 开发者证书）
- [ ] 支持.app应用程序包
- [ ] 支持Mach-O可执行文件和dylib
- [ ] 支持.pkg和.dmg安装包的签名查看
- [ ] 主应用可独立运行，支持拖拽文件查看签名
- [ ] macOS 13+正常运行

## Assumptions Exposed & Resolved
| Assumption | Challenge | Resolution |
|------------|-----------|------------|
| 需要独立窗口应用 | Finder右键扩展是否就够了？ | 选择Finder扩展+主应用组合，兼顾便捷和能力 |
| Finder扩展能直接读取签名 | Sandbox限制下无法调codesign | 主应用+XPC架构解决sandbox限制 |
| 只需要基础签名信息 | 是否需要更多细节？ | 全部信息都要：基础+entitlements+profile+证书链 |

## Technical Context
- **签名读取方式:** `SecStaticCode` API + `codesign -dvvv` / `codesign --display --entitlements` 命令
- **PKG签名:** `pkgutil --check-signature` 或 Security.framework
- **DMG签名:** `codesign -dvvv` 或 `spctl --assess`
- **Provisioning Profile:** 解析embedded.mobileprovision (CMS解码)
- **证书链:** SecTrust API获取证书链信息
- **XPC通信:** NSXPCConnection在Finder扩展和主应用间传递文件路径和签名结果

## Ontology (Key Entities)

| Entity | Type | Fields | Relationships |
|--------|------|--------|---------------|
| App (SignViewer) | core domain | mainWindow, dragDropZone | hosts FinderExtension, XPCService |
| SignatureInfo | core domain | bundleID, teamID, certName, certID, signStatus, signingDate | belongs to target file |
| Entitlements | supporting | key-value pairs, sandbox, hardenedRuntime, networkAccess | part of SignatureInfo |
| ProvisioningProfile | supporting | name, expirationDate, teamID, appID, devices | part of SignatureInfo |
| CertificateChain | supporting | rootCA, intermediates, leafCert, validityPeriod | part of SignatureInfo |
| FinderExtension | core domain | contextMenuItem, selectedFile | communicates via XPCService |
| XPCService | core domain | connection, request, response | bridges FinderExtension ↔ App |

## Ontology Convergence

| Round | Entity Count | New | Changed | Stable | Stability Ratio |
|-------|-------------|-----|---------|--------|----------------|
| 1 | 2 | 2 | - | - | N/A |
| 2 | 5 | 3 | 0 | 2 | 40% |
| 3 | 5 | 0 | 0 | 5 | 100% |
| 4 | 6 | 1 | 0 | 5 | 83% |
| 5 | 6 | 0 | 0 | 6 | 100% |
| 6 | 7 | 1 | 0 | 6 | 86% |

## Interview Transcript
<details>
<summary>Full Q&A (6 rounds)</summary>

### Round 1
**Q:** 这个工具的界面形式是什么？
**A:** macOS原生GUI应用
**Ambiguity:** 71.5% (Goal: 0.45, Constraints: 0.20, Criteria: 0.15)

### Round 2
**Q:** 具体需要展示哪些签名信息？
**A:** 全部：基础信息 + Entitlements + Provisioning Profile + 证书链
**Ambiguity:** 49.5% (Goal: 0.70, Constraints: 0.20, Criteria: 0.55)

### Round 3
**Q:** 技术栈和系统要求是什么？
**A:** SwiftUI + macOS 13+
**Ambiguity:** 36.0% (Goal: 0.70, Constraints: 0.65, Criteria: 0.55)

### Round 4 (Contrarian Mode)
**Q:** 用户如何选择要查看的程序？你是否真的需要一个独立的窗口应用，还是其实一个Finder右键扩展就够了？
**A:** Finder扩展 + 简单弹窗
**Ambiguity:** 30.0% (Goal: 0.85, Constraints: 0.60, Criteria: 0.60)

### Round 5
**Q:** 需要支持查看哪些类型的文件的签名信息？
**A:** .app + 可执行文件/dylib + .pkg/.dmg
**Ambiguity:** 20.5% (Goal: 0.90, Constraints: 0.65, Criteria: 0.80)

### Round 6 (Simplifier Mode)
**Q:** Finder扩展运行在sandbox中，可能无法直接调用codesign命令。你接受哪种方案？
**A:** 主应用 + Finder扩展，通过XPC通信
**Ambiguity:** 14.5% (Goal: 0.90, Constraints: 0.85, Criteria: 0.80)

</details>
