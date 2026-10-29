# 设置中的手动检查更新

本阶段为独立 SwiftUI 组件评审。入口是 Debug 显式参数 `--component-review app-update`，Release 不编译评审宿主。尚未替换完整设置页中的版本行、发起商店查询或增加自动检查。

## 评审范围

- 与设置页一致的白色圆角卡片，包含安装包版本和“检查更新”两行。
- 版本读取 `CFBundleShortVersionString`；缺失时显示“未知版本”，不使用 build number 或虚构的默认版本。
- 检查中显示进度并禁止重复点击；结果区分最新版本、新版、商店无结果、网络失败、系统要求和商店信息不可用。
- 新版系统弹窗提供“去更新”和“稍后”；稍后关闭弹窗且不触发跳转；打开商店失败在原行提示并允许重试。
- 组件只处理呈现与回调，宿主以显式按钮交付测试响应，便于稳定捕获检查中。此等待由测试控制，不表示真实请求耗时。商店跳转回调在宿主中返回失败，不打开任意测试 App。

## 验证映射

| 变更边界 | 精确选择器 | 类型 / 原因 |
| --- | --- | --- |
| 安装包版本 | `XunjuTests/AppUpdateComponentTests/testDisplayedVersionUsesInstalledMarketingVersionInsteadOfBuildNumber` | 新增；独立 Bundle 验证 marketing version 与 build number 不混用 |
| 版本缺失 | `XunjuTests/AppUpdateComponentTests/testMissingOrBlankVersionDoesNotInventAReleaseNumber` | 新增；缺失、仅 build number、空白值 |
| 评审入口 | `XunjuTests/AppUpdateComponentTests/testUpdateReviewRequiresExplicitRoute` | 新增；普通启动或不完整参数不进入评审 |
| 既有评审路由 | `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface` | 受影响既有；新增路由不改变原解析契约 |
| 检查中、新版、稍后、跳转回调与失败 | `XunjuUITests/AppUpdateComponentUITests/testCheckingNewVersionLaterAndStoreHandoffFailure` | 新增；最高风险，真实点击与系统弹窗；附件 01–05 |
| 最新、无结果、失败与重试 | `XunjuUITests/AppUpdateComponentUITests/testCurrentUnavailableAndNetworkFailureCanRetry` | 新增；错误结果不能误报最新；附件 06–08 |
| 系统要求、商店不可用 | `XunjuUITests/AppUpdateComponentUITests/testSystemRequirementAndMissingStorefrontDoNotOfferUpdate` | 新增；不提示不可执行的更新；附件 09–10 |

最终候选复用同一映射，4 项定向单测和 3 项 UI，未运行全量测试。测试结果、截图与证据 SHA 在完成后补录。

### 开发失败与修正

首个有效测试批次 `rent-room-check-update-20261030-04` 在提交 `1f04717151abf169847e8c6a898eef517ef594f1` 上完成：4 UT 通过，3 UI 均在入口断言失败。导出的无障碍层级显示 `settings.checkUpdate` 位于 `Other` 容器，其内部真实 `Button` 无该标识；录屏确认卡片已实际呈现。移除 Button 上多余的 `.accessibilityElement(children: .ignore)`，让标签、值与标识直接属于原生按钮；保留原测试选择器与真实点击断言，重跑同一组用例。

此前 `-02` 在依赖准备阶段因缺少 esbuild 停止；按 lockfile 安装后，`-03` 被全局 Git HTTPS→SSH 改写阻塞，于依赖下载阶段主动终止。`-04` 仅通过进程环境覆盖下载协议，未改变全局配置。上述准备失败不计为业务测试。

## 接入前置条件

用户确认组件效果后，将卡片接到 `SettingsPage`，接入 Apple Lookup、数字分段版本比较、当前 storefront 和系统兼容性判断。只做手动检查，不引入 time_fragment 的自动检查及提醒冷却。

当前主线 Bundle ID 为 `com.keeline.xunju.ios`。2026-10-30 使用现有 App Store Connect 凭据按此 ID 查询无匹配记录；此结果不能证明其他账号没有该 App。正式 App ID 和 Bundle ID 需核对后用于商店查询和跳转，不能沿用 time_fragment 的标识。当前组件证据不能证明真实商店查询、地区可用性、上架版本或商店打开成功。
