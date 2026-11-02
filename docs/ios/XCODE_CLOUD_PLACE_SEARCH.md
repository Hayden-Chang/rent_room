# 地址搜索的 Xcode Cloud 对照

更新日期：2026-11-02。已完成接入并运行首轮云任务；**首轮在准备脚本失败，未执行 App 测试**。此前失败与本地证据见 [Apple 地点搜索记录](APPLE_PLACE_SEARCH_20261102.md)。

## 范围

- App Store Connect：RentVisit: Viewing Checklist，App ID `6828695680`，bundle ID `com.keeline.xunju.ios`。
- 开发团队 `N3Z6DDSQCJ`，通过现有 ASC 登录与 Xcode 的 Haichao Zhang 团队核对。团队配置落在 `ios/project.yml`，不手改或提交生成工程。
- 分支 `codex/ios-apple-place-search-20261102`，PR #118，保留草稿，不合入或发布。
- 2026-11-02 已用独立状态读取确认 Apple 网页会话认证成功，并成功复用会话查询实际额度：总量 1,500 compute minutes，已用 0，剩余 1,500（25 小时）；接口返回重置时间 `2026-11-03T10:13:41Z`。这是查询时的快照，启动前需重新核对，不得自动升级付费计划。

## 工作流配置

已从 Xcode 的 **Integrate → Create Workflow** 完成产品与代码仓连接。用户授权且界面确认 `Hayden-Chang/rent_room` 绿勾；没有为公共依赖 `weichsel/ZIPFoundation` 增加授权。按向导警告继续完成配置，是否能拉取该依赖仍以实际构建为准。

产品 ID `3740E3EE-CB27-4313-A049-ABEF35969C20`，工作流 ID `DCDCE178-FFAF-4B52-867B-25FD95D17C62`，SCM 仓库 ID `208a0356-45ff-41f9-a3fd-3668f85d1ad6`。先在停用状态通过 API 收窄配置，回读确认后启用并手动运行。

CLI 网页登录选择的是 App Store Connect provider，不是签名用的 Developer Team ID。此账号 numeric provider 为 `128497972`，public provider 为 `b24fefbf-30af-43f3-8523-8f2e5c8f8c74`；`N3Z6DDSQCJ` 仅继续用于 `DEVELOPMENT_TEAM`。不要再将后者传给 `--public-provider-id`，也不要为 provider 选择错误清除登录缓存。

已回读确认以下最小配置；运行前额度仍为剩余 1,500 分钟，未升级套餐：

| 项目 | 值 |
| --- | --- |
| 名称 | RentVisit US Address Search |
| 项目 | `ios/Xunju.xcodeproj`（post-clone 生成） |
| Scheme | `XunjuLiveUSSearch` |
| 触发 | 手动，仅 `codex/ios-apple-place-search-20261102`；无 push、PR、定时触发 |
| 操作 | 仅 Test，Debug；不加 Build、Archive、Analyze 或分发后置操作 |
| 目标 | iPhone 16 / iOS 26.5，Xcode 26.6 (17F113)，macOS Tahoe 26.5.1 (25F80) |
| 重试 | 关闭自动重复测试；失败保留证据 |
| 测试范围 | `XunjuUITests/LivePlaceSearchTests/testEnglishUSAddressSearchAcrossStatesAndPersist` |

此用例断言实际 App 为 en-US，依次查询纽约完整街道、California、Cupertino 街道，检查结果坐标落在对应地区，选择地址后重启并核对保存值。测试使用隔离业务数据，地点响应来自真实 Apple MapKit。没有新增产品入口、模拟搜索响应或更改 Mac 代理。

## 生成与环境记录

`ios/ci_scripts/ci_post_clone.sh` 仅在 Xcode Cloud 中运行：校验 `.nvmrc` 的主版本后，将官方 Node 24.22.2 对应 arm64/x64 预编译包下载到临时目录并验证固定 SHA-256，避免依赖云端 Homebrew 源码编译；`npm ci` 使用现有应用锁文件；下载官方 XcodeGen 2.45.4，验证固定 SHA-256 后，在临时工具目录运行仓库原有 `scripts/check-xcodegen.sh`。生成项目、密钥、本地配置均不提交；不需要把本机地图 Key 上传到云端。

Apple Cloud 要求 Swift Package 锁文件，不能依赖云端自动解版本。`ios/Package.resolved` 保存现有 ZIPFoundation 0.9.20 的解析结果；`check-xcodegen.sh` 在生成后复制到工程内的 `project.xcworkspace/xcshareddata/swiftpm/Package.resolved`，保持生成工程忽略规则与现有依赖版本。升级依赖时同步该锁文件。

`ios/ci_scripts/ci_pre_xcodebuild.sh` 仅在专用 scheme 的 `test-without-building` 阶段记录测试 worker 的提交、设备、runtime、UTC 时间，并向 Cloudflare trace 发起一次有超时的 HTTP 请求。输出只保留国家码与边缘机房码，不记录 IP、完整 trace 或代理变量。探针失败输出 `unknown`，不伪装为美国，也不吞掉随后 XCUITest 的失败。

Apple 的构建 worker 和测试 worker 是不同环境，且云端环境有自己的 HTTP 代理。因此该探针**仅证明测试 worker 的 HTTP 出口观测**，不能单独证明 MapKit 服务路由、物理设备位置或美国真实用户行为。云端不保证美国出口；不将地区语言设置或模拟 GPS 当美国网络证据。

## 运行记录与待完成

首轮 run `a651ec1a-bae2-4d28-a2f6-8b18aaf1cdb9`，build #1，手动触发，源码 `8e11afc5e58b63308f31ad359f7ba66a9458720f`。开始 `2026-11-02T10:28:13.919Z`，结束 `10:30:49.156Z`，结果 FAILED。

失败发生在 `ci_post_clone.sh` 安装 Node：云端 Intel x86_64 主机的 Homebrew 没有对应新包的 bottle，改为源码编译依赖 `pkgconf` 后报 `C compiler cannot create executables`。未生成工程、未编译 App、未启动模拟器测试，没有美国出口观测或 `.xcresult`；这不是地址搜索断言失败。保留日志：本机 `/private/tmp/rent-room-apple-search-evidence/cloud-run-1/ci_post_clone.log` 及同目录原始 LOG_BUNDLE。

已将 bootstrap 改为官方 Node 24.22.2 二进制、按 CPU 选择并固定校验值，临时目录退出清理；本地 arm64 在隔离任务 worktree 执行完整脚本通过，包括真实工具下载/校验、npm ci、资源一致性、XcodeGen 两次确定性生成。日志 `/private/tmp/rent-room-apple-search-evidence/cloud-bootstrap-local-arm64.log`。没有安装或修改宿主共享 Node/Homebrew；这仍不是云端 x64 成功证据。

其他已有准备验证：共享 scheme 唯一 UI 方法白名单、串行执行、保留附件、无 archive build；两个 shell 脚本语法通过；测试阶段探针的阶段/scheme/local/失败分支检查通过。上述脚本检查不等同于真实网络测试。

下一轮只验证 bootstrap 修复及原定单个在线 UI 测试，不扩大测试范围、不自动重试失败测试。待完成：云端构建、真实方法执行、出口观测与 `.xcresult`/截图下载。PR 仍为草稿，未合入或发布，不能据此批准美国市场上线。

每次真实运行保留 workflow ID、build run ID/URL、源码 SHA、源分支、Xcode/macOS/iOS 与设备、出口观测、实际方法数/通过/失败/跳过数、完整日志、`.xcresult` 与截图。查询未执行到的后续步骤必须标记未覆盖。

## 官方依据

- [Xcode Cloud get started：会员包含额度](https://developer.apple.com/xcode-cloud/get-started/)
- [首次工作流配置](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow)
- [自定义脚本的位置与运行阶段](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
- [环境变量与云端 HTTP 代理](https://developer.apple.com/documentation/xcode/environment-variable-reference)
- [Swift Package 锁文件要求](https://developer.apple.com/documentation/xcode/making-dependencies-available-to-xcode-cloud)
- [XcodeGen 2.45.4](https://github.com/yonaskolb/XcodeGen/releases/tag/2.45.4)
- [Node 24.22.2 官方校验清单](https://nodejs.org/dist/v24.22.2/SHASUMS256.txt)
