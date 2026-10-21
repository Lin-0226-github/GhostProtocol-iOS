# 指挥中心 v1.0.2 · 正式版

把 **全球灵异事件处理总部（GHOST PROTOCOL）** 封装成原生 iOS 应用。

## 本版修复

站点由 Tailwind v4 构建，大量使用了 iOS 16.4+ 才支持的 CSS 特性。WKWebView 遇到不认识的语法时不是降级渲染，而是**整条声明丢弃**，于是布局出现肉眼可见的破版。本版针对两处做了运行时兼容。

### 1. 渐变全部消失（本版新增）

```css
.bg-gradient-to-r{--tw-gradient-position:to right in oklab;background-image:linear-gradient(var(--tw-gradient-stops))}
```

`in oklab` 插值语法需要 Safari 16.4+。旧版 WebKit 解析失败后会丢弃整条 `background-image`，导致**全站 488 处渐变一起失效**——横幅两端渐隐变成实心色块、卡片光晕和按钮底色消失。

修复方式：注入样式把 `--tw-gradient-position` 的插值空间退回默认 sRGB，渐变本身保留，只是颜色过渡不走 oklab。

### 2. 卡片背景变成整块亮绿色、内容被遮挡

```css
.bg-primary\/\[0\.07\]{background-color:var(--primary)}                                   /* 纯色兜底 */
.bg-primary\/\[0\.07\]{background-color:color-mix(in oklab,var(--primary) 7%,transparent)} /* 正确值 */
```

`color-mix()` 需要 Safari 16.2+。不支持时第二条被丢弃，背景退化为 100% 不透明的主题绿，盖住标题与进度数字。

修复方式：运行时检测「类名声明了透明度、计算值却是不透明纯色」的元素，按类名里的 alpha 重写为 `rgba()`。宿主支持 `color-mix()` 时自动跳过，不重复干预。

### 3. 整页被放大、顶部导航消失

WKWebView 在布局完成前加载页面时 `bounds` 仍为 `.zero`，viewport 按 0 宽计算导致 `width=device-width` 失效。改为在 `viewDidLayoutSubviews` 中确认拿到真实宽度后再加载。

### 4. 字体被二次放大

注入 `-webkit-text-size-adjust: 100%`，避免窄视口下 WebKit 的自动字号放大干扰排版。

## 功能

- **原生外壳**：全屏 WKWebView，无浏览器地址栏与工具栏
- **桌面图标**：站点原始标志渲染的全套 iOS 图标，深色底 `#0E0F11`
- **启动屏**：纯深色启动画面，无白屏闪烁
- **下拉刷新**：原生刷新控件，主题色跟随站点绿色
- **返回手势**：左缘右滑返回；有历史记录时左上角浮出返回按钮
- **加载进度**：顶部 2pt 绿色进度条
- **失败兜底**：断网 / 超时 / DNS 失败时显示中文提示页，可一键重试
- **会话保持**：Cookie 与 localStorage 持久化，登录态不丢失
- **站内外分离**：站内链接留在 App，站外链接用内置 Safari 打开
- **原生弹窗**：网页 `alert` / `confirm` / `prompt` 走 iOS 原生弹窗
- **文件上传**：支持拍照、相册、麦克风输入
- **进程自愈**：Web 进程被系统回收后自动重载

## 安装

本包为 **未签名 IPA**，需要自行签名后才能安装到 iPhone：

1. 电脑安装 [Sideloadly](https://sideloadly.io/)
2. iPhone 连接电脑并信任
3. 将 IPA 拖入 Sideloadly，填入 Apple ID，点击 Start
4. 手机上：设置 → 通用 → VPN 与设备管理 → 信任开发者

> 免费 Apple ID 签名的证书 7 天过期，到期后重新签一次即可，应用数据不会丢失。
> 可直接覆盖旧版本安装，Bundle ID 相同（`top.lycl.ghostprotocol`），登录态保留。

## 技术规格

| 项目 | 值 |
| --- | --- |
| 版本 | 1.0.2 (Build 3) |
| Bundle ID | `top.lycl.ghostprotocol` |
| 最低系统 | iOS 14.0 |
| 架构 | arm64 |
| 体积 | 约 50 KB |

## 说明

本项目仅作网页容器封装，不修改、不代理、不存储站点任何内容。站点内容与可用性由 lycl.top 自行负责。
