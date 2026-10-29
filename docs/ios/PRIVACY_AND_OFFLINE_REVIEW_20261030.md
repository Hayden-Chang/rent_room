# iOS 公开页面、隐私清单与免登录组件（2026-10-30）

## 范围与当前状态

用户要求先补公开页面和隐私清单，再移除 iOS 登录入口；已明确保留付费扩容，另做免登录购买，并保留仅由用户主动触发的地图、测速及反馈。核心记录应完全离线。

本批完成材料及独立组件，尚未接入生产 SettingsPage、AppWorkspace 或购买协调器。生产登录、启动时联网和账号目录行为尚未改变，不能以此文档作为离线版本已完成的证据。组件须按 `ios-ui-component-review-gate` 在实际 XCUITest 截图展示后取得用户批准，才能继续业务接入。

- iOS 草稿：[rent_room PR #92](https://github.com/Hayden-Chang/rent_room/pull/92)。
- 公开页面草稿：[support PR #14](https://github.com/Hayden-Chang/support/pull/14)，源码 `b9d7d234b5246b963683a6cc68a520dd19f03fa5`。
- 支持仓库沿用 TimeFragment 的静态 GitHub Pages 托管方式，新增看房搭子专属路径，不复用其他 App 的政策正文。
- 页面注明适用于免登录 iOS 版本，随该版本发布生效，不适用于微信小程序；目前未合并发布，不能将目标 URL 视作已上线。

## 公开页面

| 内容 | 目标 URL |
| --- | --- |
| 隐私政策（中英双语） | https://hayden-chang.github.io/support/privacy-policies/kanfangdazi/privacy-policy.html |
| 使用条款（中英双语） | https://hayden-chang.github.io/support/terms-of-service/kanfangdazi/terms-of-service.html |
| 支持与 FAQ（中英双语） | https://hayden-chang.github.io/support/kanfangdazi/ |

页面说明本机记录、系统备份与主动 ZIP 导出、权限、地图/路线/测速、反馈内容与保存、扩容交易、删除及联系渠道。操作方与公开联系邮箱沿用 support 仓库现有资料。政策和条款均保留 Markdown 正文，便于后续与 HTML 同步审查。页面不加载脚本、统计或第三方资源；访问第三方外链才离开页面。

源码 `2eb9eca` 的三个页面共 24 个链接检查通过：站内目标文件存在、外链均为 HTTPS 或 mailto。隐私/条款 Markdown 正文与 HTML 一致，无 script、iframe、form、外部样式或图片加载。通过本地浏览器查看三个页面并点击导航与 FAQ。`b9d7d23` 只在 HTML 标签及 CSS 规则间加入换行，去掉空白后的源码完全相同，复用内容与视觉证据。该结果不证明公网部署，也未覆盖所有手机宽度。原始输出及预览图位于 `/private/tmp/xunju-offline-privacy-20261030/`。

## 隐私清单的源码依据

`ios/Xunju/Resources/PrivacyInfo.xcprivacy` 由 XcodeGen 的 `Xunju` 源目录自动纳入 App 资源，无须提交生成工程。

| 项目 | 声明及依据 |
| --- | --- |
| 跟踪 | `NSPrivacyTracking = false`，跟踪域名为空；当前没有广告/跨 App 跟踪 SDK |
| 系统运行时间 | `NSPrivacyAccessedAPICategorySystemBootTime` / `35F9.1`；`NativeSpeedTest.swift` 测量持续时间，`MPChecklist.swift` 计算手势时间间隔 |
| 客户支持 | `CustomerSupport`，App 功能，不跟踪、不关联购买身份；用户主动提交评价及自由文本，后端保存正文、随机请求编号与时间 |
| 购买历史与标识 | `PurchaseHistory`、`UserID`，App 功能，不跟踪；交易与购买标识用于持久容量账本，因此标记关联身份，免登录并不代表不存在购买标识 |
| 精确位置 | `PreciseLocation`，App 功能，不跟踪、不关联购买身份；用户主动地图/路线请求可向服务方发送坐标 |
| ZIPFoundation 0.9.20 | SDK 自带 `PrivacyInfo.xcprivacy`，声明 FileTimestamp / `0A2A.1`；随其资源 Bundle 打包，不把 SDK 的包装库理由复制到 App 清单 |

直接源码扫描未发现 `UserDefaults` / `@AppStorage`、磁盘空间或文件时间戳读取。媒体代码读取 `fileSizeKey` 和 `isRegularFileKey`。新增 API 或依赖时须重新检查；本次扫描不代替 Apple 对最终提交包的验证。

系统运行时间原因依据 [Apple required-reason API 文档](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)。上述收集类型针对目标免登录版本；完整接入后须按实际传输与保留情况复核，包括购买标识、地图服务及反馈的关联性。App Store Connect 的 App Privacy 标签需单独填写，本文件不会同步后台标签。

## 组件验收边界

- `LocalSettingsSurface` 顶部保留容量入口，移除头像、昵称、登录和退出登录控件；保留其他设置，增加隐私、条款、帮助入口。
- `AccountFreeCapacitySurface` 复用容量卡片，显示免 App 登录购买/恢复文案及法律链接。价格由调用者提供，不能在生产中回退到夹具价。
- `LocalSettingsReviewHost` 只在 DEBUG 且参数 `--local-settings-review settings|capacity` 完整匹配时启用。它不启动 workspace、Keychain、网络或 StoreKit。
- 测试点击购买仅驱动“等待购买结果”，点击恢复仅驱动网络错误；这些证据只证明呈现与交互，不证明实际交易、退款、容量到账或数据持久化。

## 后续业务接入的验收条件

1. 用户批准组件截图后接入真实页面；普通启动及切回前台不自动请求容量策略/购买服务，核心新增、修改、媒体及导入导出离线可用。
2. 保留升级前当前本机记录及媒体，不因移除登录跳到空游客目录；购买身份与本机数据目录分离，不自动合并其他账号目录。
3. 实现免 App 登录的交易验证、重复到账保护、离线容量缓存、失败后重试、恢复和退款保留房源。当前服务端实现仍是 [model_server Draft PR #87](https://github.com/Hayden-Chang/model_server/pull/87)，未部署；不能仅隐藏登录或伪造 session 来声称完成免登录购买。
4. 现有商品是消耗型扩容，iOS 最低版本为 17。已完成消耗型交易在旧系统上的恢复不能假设与 iOS 18+ 历史 API 相同，需要在实现中明确持久恢复路径并验证。
5. 上线前合并并检查三个公网 URL、复核政策与最终代码、填写 App Privacy，完成真实沙箱购买/恢复及发布要求。本批没有合并、部署、真机安装或提交审核。

## 执行记录

首次 run `xunju-privacy-review-20261030-01` 在源码 `66917f6` 上编译通过，实际 App Bundle 同时包含 App 清单及 ZIPFoundation 清单。编译后等候测试槽位时，本任务新增此文档，runner 因工作区快照变化拒绝继续，退出 2，未执行测试。保留 `/Volumes/mac2/codex-builds/xunju-privacy-review-20261030-01.build.xcresult` 及 `/private/tmp/xunju-offline-privacy-20261030/run-01.log`，不计作通过或失败的测试用例。提交文档后使用新 run ID，在冻结工作区上复验相同的 3 项单测及 2 项 UI 测试。
