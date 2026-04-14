# SignViewer

macOS 原生代码签名查看工具。通过 Finder 右键菜单或拖拽文件，快速查看应用程序的数字签名信息。

## 功能

- **Finder 集成** — 右键点击文件，选择「查看签名信息」即可查看
- **拖拽支持** — 将文件拖拽到主窗口，或点击「浏览」按钮选择文件
- **四个信息维度：**
  - 概要：Bundle ID、Team ID、证书名称、签名状态
  - Entitlements：沙盒、Hardened Runtime 等权限列表
  - Provisioning Profile：名称、过期时间、App ID
  - 证书链：完整证书链（Root CA → 中间证书 → 开发者证书）

### 支持的文件类型

| 类型 | 读取方式 |
|------|---------|
| `.app` 应用程序 | Security.framework (`SecStaticCode`) |
| Mach-O 可执行文件 / dylib | Security.framework (`SecStaticCode`) |
| `.pkg` 安装包 | `pkgutil --check-signature` |
| `.dmg` 磁盘镜像 | `codesign -dvvv` / `spctl --assess` |

## 系统要求

- macOS 13.0 (Ventura) 或更高版本
- Xcode 15+ (编译)
- Xcode Command Line Tools (查看 `.pkg` / `.dmg` 签名需要)

## 编译与运行

```bash
# 安装 xcodegen（如未安装）
brew install xcodegen

# 生成 Xcode 项目
xcodegen generate

# 命令行编译
xcodebuild -scheme SignViewer -configuration Debug build

# 或在 Xcode 中打开
open SignViewer.xcodeproj
```

编译产物位于 `build/Debug/SignViewer.app`。

## 启用 Finder 扩展

1. 打开 **系统设置 → 隐私与安全性 → 扩展 → Finder 扩展**
2. 勾选 **SignViewerFinder**
3. 在 Finder 中右键任意文件，即可看到「查看签名信息」菜单项

> 注意：Finder 扩展需要有效的开发者签名才能被系统加载。开发阶段可以直接使用主应用的拖拽功能。

## URL Scheme

SignViewer 注册了 `signviewer://` URL scheme，可通过命令行触发：

```bash
open "signviewer://inspect?path=%2FApplications%2FSafari.app"
```

## 架构

```
┌─────────────────────┐     URL Scheme      ┌──────────────────────┐
│  Finder Extension    │ ──────────────────> │     Host App         │
│  (sandboxed)         │  signviewer://      │  (non-sandboxed)     │
│                      │  inspect?path=...   │                      │
│  右键菜单触发         │                     │  Security.framework  │
│  NSWorkspace.open()  │                     │  codesign / pkgutil  │
└─────────────────────┘                      └──────────────────────┘
```

- **Finder Extension** — 仅负责添加右键菜单，通过 URL scheme 将文件路径传递给主应用
- **Host App** — 负责所有签名信息读取和展示，不受沙盒限制

## 项目结构

```
signviewer/
├── project.yml                     # XcodeGen 项目配置
├── SignViewer/
│   ├── App/SignViewerApp.swift     # 应用入口 + URL scheme 处理
│   ├── Models/SignatureInfo.swift  # 数据模型
│   ├── Core/
│   │   ├── SignatureReader.swift   # 读取协议
│   │   ├── FileTypeDetector.swift  # 文件类型检测
│   │   └── Readers/               # 各类型签名读取器
│   ├── ViewModels/                 # 视图模型
│   └── Views/                      # SwiftUI 视图
└── SignViewerFinder/               # Finder Sync Extension
```

## 许可证

MIT
