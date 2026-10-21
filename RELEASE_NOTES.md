# 指挥中心 v1.0.3 · 正式版

把 **全球灵异事件处理总部（GHOST PROTOCOL）** 封装成原生 iOS 应用。

## 本版更新

### 1. 边框、文字颜色过亮（本版新增）

`border-primary/40`、`text-muted-foreground/70` 和背景色是同一套机制：

```css
.border-primary\/40{border-color:var(--primary)}                                  /* 纯色兜底 */
.border-primary\/40{border-color:color-mix(in oklab,var(--primary) 40%,transparent)} /* 正确值 */
```

`color-mix()` 不受支持时退回纯色，边框从 40% 变成 100% 纯绿，看起来比正常情况亮一档。

兼容层原本只修复 `bg-*`，本版扩展到三类：
- `bg-*` → `backgroundColor`
- `text-*` → `color`
- `border-*` → `borderColor`

### 2. 新增摇一摇诊断

仍然有错位的元素时，**摇一摇手机**会把当前页面告警横幅及其 8 层祖先元素的实际样式打在屏幕上（背景色、宽度、内边距、定位、溢出等），点击任意位置关闭。用于在缺少 Safari 检查器的情况下定位剩余的 CSS 兼容问题。

### 3. 历史修复

- **全站渐变消失**：`linear-gradient(to right in oklab, ...)` 需要 Safari 16.4+，旧引擎整条丢弃，488 处渐变失效。已把插值空间退回 sRGB。
- **卡片背景变整块亮绿**：`color-mix()` 退化导致 7% 淡绿变 100% 不透明。已按类名声明的 alpha 重写为 `rgba()`。
- **整页被放大、顶部导航消失**：WKWebView 在布局完成前加载，viewport 按 0 宽计算。已改为拿到真实宽度后再加载。
- **字体二次放大**：注入 `-webkit-text-size-adjust: 100%`。

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
| 版本 | 1.0.3 (Build 4) |
| Bundle ID | `top.lycl.ghostprotocol` |
| 最低系统 | iOS 14.0 |
| 架构 | arm64 |
| 体积 | 约 50 KB |

## 说明

本项目仅作网页容器封装，不修改、不代理、不存储站点任何内容。站点内容与可用性由 lycl.top 自行负责。
