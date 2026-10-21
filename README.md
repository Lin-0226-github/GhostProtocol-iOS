# 指挥中心 · iOS 客户端

把 **https://lycl.top/**（全球灵异事件处理总部 · GHOST PROTOCOL）包装成一个原生 iOS App。

**当前版本：v1.0.0** ｜ [下载正式版 IPA](https://github.com/Lin-0226-github/GhostProtocol-iOS/releases/latest)

> 需要先说明一点：IPA 是 iOS 原生安装包，**只能在 macOS + Xcode 上编译并用 Apple 证书签名**，任何 Linux / Windows 环境都做不出来。
> 所以这套工程的设计是：**推送到 GitHub → 由 GitHub 的 macOS 机器自动编译 → 下载 IPA**。你不需要有 Mac。
>
> 发新版本只需推送一个 tag（如 `v1.0.1`），`Release IPA` 流水线会自动编译并创建 Release。

---

## 这个 App 做了什么

| 能力 | 说明 |
| --- | --- |
| 桌面图标 | 用站点原始 SVG 标志渲染的全套 iOS 图标（含 1024 App Store 尺寸），深色底 `#0E0F11` |
| 启动屏 | 纯深色启动画面，无白屏闪烁 |
| 全屏 WebView | 顶部状态栏融合深色背景，不使用系统浏览器栏 |
| 下拉刷新 | 原生下拉刷新控件，主题色跟随站点绿色 |
| 返回手势 | 从屏幕左缘右滑返回上一页；有历史记录时左上角浮出返回按钮 |
| 加载进度 | 顶部 2pt 绿色进度条 |
| 失败兜底 | 断网 / 超时 / DNS 失败时显示中文提示页，可一键重试 |
| 会话保持 | Cookie + localStorage 持久化，登录态不丢 |
| 站内站外分离 | lycl.top 站内链接在 App 内打开，站外链接用内置 Safari 打开 |
| 原生弹窗 | 网页 `alert` / `confirm` / `prompt` 走 iOS 原生弹窗 |
| 文件上传 | 支持拍照、相册、麦克风（已在 Info.plist 声明权限文案） |
| 进程自愈 | Web 进程被系统回收后自动重载页面 |

---

## 第一步：把工程推到 GitHub

新建一个空仓库（建议 **Public**，私有仓库会消耗 Actions 分钟数，macOS 机器按 10 倍计费），然后在本目录执行：

```bash
git init
git add .
git commit -m "feat: lycl.top iOS wrapper"
git branch -M main
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```

> 也可以直接用网页版 GitHub：新建仓库 → 「uploading an existing file」→ 把本文件夹内容拖进去。
> 注意 `.github` 和 `.gitignore` 是隐藏目录/文件，网页上传可能漏掉，用 `git push` 最稳。

## 第二步：让它自动编译

推送完成后：

1. 打开仓库页面 → 顶部 **Actions** 标签
2. 左侧选 **Build IPA (unsigned)**
3. 右侧点 **Run workflow** → 绿色按钮 **Run workflow**
4. 等约 3–6 分钟（首次要装 XcodeGen，会久一点）

编译成功后，进入这次运行的页面，拉到底部 **Artifacts**，下载 `GhostProtocol-unsigned-ipa`。

下载得到的是一个 `.zip`，**解压后里面才是 `GhostProtocol-unsigned.ipa`**。

## 第三步：装到 iPhone

这个 IPA 是**未签名**的，iOS 默认拒绝安装。挑一条适合你的路：

### 方案 A：Sideloadly 自签（免费，推荐）

需要一台电脑（Windows 或 Mac 都行）+ 数据线。

1. 电脑上装 [Sideloadly](https://sideloadly.io/)
2. iPhone 用数据线连电脑，手机上点「信任此电脑」
3. 把 `GhostProtocol-unsigned.ipa` 拖进 Sideloadly，`Apple ID` 填你的 Apple ID，点 **Start**
4. 输入 Apple ID 密码（用于生成免费开发证书，只在本地传输）
5. 手机桌面出现「指挥中心」后，首次打开会提示不受信任：
   **设置 → 通用 → VPN 与设备管理 → 开发者 App → 信任**
6. 打开即用

> ⚠️ 免费 Apple ID 签名的证书 **7 天过期**，到期后 App 打不开，重新用 Sideloadly 走一次即可（数据不会丢）。
> 想自动续签可以装 [AltStore](https://altstore.io/)，连同一 Wi-Fi 就能后台刷新。
> 你的设备是 iOS 15.5，**不需要**开启「开发者模式」（那是 iOS 16+ 的要求）。

### 方案 B：付费开发者账号（$99/年，永久不掉签）

有 Apple Developer Program 账号的话，用本仓库的第二个流水线 **Build IPA (signed)**：

1. 在 [Apple 开发者后台](https://developer.apple.com/account/resources/certificates) 创建证书（Apple Distribution 或 Apple Development），导出 `.p12`
2. 创建 App ID（Bundle ID 填 `top.lycl.ghostprotocol`）和描述文件（**Ad Hoc** 类型，把 iPhone 的 UDID 加进去）
3. 把 `.p12` 和 `.mobileprovision` 转成 base64：
   ```bash
   base64 -i certificate.p12 | pbcopy          # macOS
   base64 -w 0 certificate.p12 > cert.txt      # Linux / WSL
   ```
4. 仓库 **Settings → Secrets and variables → Actions** 添加：
   | 名称 | 内容 |
   | --- | --- |
   | `BUILD_CERTIFICATE_BASE64` | `.p12` 的 base64 |
   | `P12_PASSWORD` | 导出 `.p12` 时设的密码 |
   | `KEYCHAIN_PASSWORD` | 随便填一个临时密码 |
   | `PROVISIONING_PROFILE_BASE64` | `.mobileprovision` 的 base64 |
   | `TEAM_ID` | 开发者团队 ID（10 位） |
5. 跑 **Build IPA (signed)**，导出方式选 `ad-hoc`，得到已签名 IPA，用爱思助手 / Apple Configurator 直接装

### 方案 C：不折腾签名（0 成本）

这个站本身就是 PWA。用 **Safari** 打开 `lycl.top` → 分享按钮 → **添加到主屏幕**。
图标、全屏、独立窗口都有，只是图标会是网页截图（站点引用的是 SVG 图标，iOS 不认），且没有下拉刷新和返回按钮。

---

## 工程结构

```
GhostProtocol/
├── project.yml                       # XcodeGen 配置（生成 .xcodeproj）
├── App/
│   ├── AppDelegate.swift             # 入口
│   ├── WebViewController.swift       # WebView 壳主体
│   ├── ErrorView.swift               # 加载失败页
│   └── Assets.xcassets/              # AppIcon + 启动屏底色
├── Supporting/
│   └── Info.plist                    # 权限、方向、ATS、启动屏
└── .github/workflows/
    ├── build-unsigned.yml            # 未签名 IPA（不需要账号）
    └── build-signed.yml              # 证书签名 IPA（需要开发者账号）
```

`.xcodeproj` 不提交到仓库，每次构建由 XcodeGen 现生成。想在 Mac 上本地打开：

```bash
brew install xcodegen
xcodegen generate
open GhostProtocol.xcodeproj
```

---

## 想改成自己的站点？

| 要改什么 | 改哪里 |
| --- | --- |
| 网址 | `App/WebViewController.swift` 里的 `Site.home` |
| 站内白名单域名 | 同文件 `Site.hosts` |
| App 桌面名称 | `Supporting/Info.plist` 的 `CFBundleDisplayName` |
| Bundle ID | `project.yml` 的 `PRODUCT_BUNDLE_IDENTIFIER`（签名版还要同步改 `BUNDLE_ID` 变量） |
| 图标 | 替换 `App/Assets.xcassets/AppIcon.appiconset/` 下所有 PNG（保持文件名不变） |
| 版本号 | `project.yml` 的 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` |

---

## 常见问题

**Q：Actions 里报 `xcodegen: command not found`？**
Homebrew 安装偶发失败，重新跑一次 workflow 即可；如果持续失败，检查 `macos-14` runner 的镜像状态。

**Q：构建成功但装不上，提示「无法安装此 App」？**
说明还是未签名包。必须走方案 A 或 B 签名。

**Q：Sideloadly 报 `Provision.cpp:150` / `Failed to sign`？**
换一个 Apple ID 试试，或先在 iPhone 上登录一次该 Apple ID（设置 → App Store）。

**Q：私有仓库跑 Actions 会不会很贵？**
macOS runner 按 10 倍分钟计费。一次构建约 5 分钟 = 计 50 分钟。免费额度 2000 分钟/月，够跑 40 次。公开仓库则完全免费。

**Q：能上架 App Store 吗？**
纯 WebView 壳会被 App Store 审核 4.2 条款（Minimum Functionality）拒绝，这套方案只适合自用 / 内部分发。

---

## 免责声明

本项目仅做网页容器封装，不修改、不代理、不存储站点任何内容。站点内容与可用性由 lycl.top 自行负责。
