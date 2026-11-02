# 地址搜索的 Xcode Cloud 对照

准备日期：2026-11-02。此文是接入配置与验收契约，**不代表已在云端运行或通过**。此前失败与本地证据见 [Apple 地点搜索记录](APPLE_PLACE_SEARCH_20261102.md)。

## 范围

- App Store Connect：RentVisit: Viewing Checklist，App ID `6828695680`，bundle ID `com.keeline.xunju.ios`。
- 开发团队 `N3Z6DDSQCJ`，通过现有 ASC 登录与 Xcode 的 Haichao Zhang 团队核对。团队配置落在 `ios/project.yml`，不手改或提交生成工程。
- 分支 `codex/ios-apple-place-search-20261102`，PR #118，保留草稿，不合入或发布。
- 2026-11-02 已用独立状态读取确认 Apple 网页会话认证成功，并成功复用会话查询实际额度：总量 1,500 compute minutes，已用 0，剩余 1,500（25 小时）；接口返回重置时间 `2026-11-03T10:13:41Z`。这是查询时的快照，启动前需重新核对，不得自动升级付费计划。

## 工作流配置

首次接入必须从 Xcode 的 **Integrate → Create Workflow** 完成产品与代码仓连接。2026-11-02 本轮公共 API 的 ciProducts 与网页会话 products 均返回空；网页会话的 SCM providers 也为空。网页认证已恢复，尚未完成代码仓连接。

CLI 网页登录选择的是 App Store Connect provider，不是签名用的 Developer Team ID。此账号 numeric provider 为 `128497972`，public provider 为 `b24fefbf-30af-43f3-8523-8f2e5c8f8c74`；`N3Z6DDSQCJ` 仅继续用于 `DEVELOPMENT_TEAM`。不要再将后者传给 `--public-provider-id`，也不要为 provider 选择错误清除登录缓存。

接入后使用以下最小配置；运行前读回核对，只有免费包含额度足够时才手动启动一次：

| 项目 | 值 |
| --- | --- |
| 名称 | RentVisit US Address Search |
| 项目 | `ios/Xunju.xcodeproj`（post-clone 生成） |
| Scheme | `XunjuLiveUSSearch` |
| 触发 | 手动；移除 push、PR、定时触发 |
| 操作 | 仅 Test，Debug；不加 Build、Archive、Analyze 或分发后置操作 |
| 目标 | 仅一个 iPhone 模拟器；选择服务实际提供的固定 Xcode / iOS 版本并记录 |
| 重试 | 关闭自动重复测试；失败保留证据 |
| 测试范围 | `XunjuUITests/LivePlaceSearchTests/testEnglishUSAddressSearchAcrossStatesAndPersist` |

此用例断言实际 App 为 en-US，依次查询纽约完整街道、California、Cupertino 街道，检查结果坐标落在对应地区，选择地址后重启并核对保存值。测试使用隔离业务数据，地点响应来自真实 Apple MapKit。没有新增产品入口、模拟搜索响应或更改 Mac 代理。

## 生成与环境记录

`ios/ci_scripts/ci_post_clone.sh` 仅在 Xcode Cloud 中运行：按 `.nvmrc` 准备 Node 24，`npm ci` 使用现有应用锁文件；下载官方 XcodeGen 2.45.4，验证固定 SHA-256 后，在临时工具目录运行仓库原有 `scripts/check-xcodegen.sh`。生成项目、密钥、本地配置均不提交；不需要把本机地图 Key 上传到云端。

Apple Cloud 要求 Swift Package 锁文件，不能依赖云端自动解版本。`ios/Package.resolved` 保存现有 ZIPFoundation 0.9.20 的解析结果；`check-xcodegen.sh` 在生成后复制到工程内的 `project.xcworkspace/xcshareddata/swiftpm/Package.resolved`，保持生成工程忽略规则与现有依赖版本。升级依赖时同步该锁文件。

`ios/ci_scripts/ci_pre_xcodebuild.sh` 仅在专用 scheme 的 `test-without-building` 阶段记录测试 worker 的提交、设备、runtime、UTC 时间，并向 Cloudflare trace 发起一次有超时的 HTTP 请求。输出只保留国家码与边缘机房码，不记录 IP、完整 trace 或代理变量。探针失败输出 `unknown`，不伪装为美国，也不吞掉随后 XCUITest 的失败。

Apple 的构建 worker 和测试 worker 是不同环境，且云端环境有自己的 HTTP 代理。因此该探针**仅证明测试 worker 的 HTTP 出口观测**，不能单独证明 MapKit 服务路由、物理设备位置或美国真实用户行为。云端不保证美国出口；不将地区语言设置或模拟 GPS 当美国网络证据。

## 已完成与待完成

- 本地 `check-xcodegen.sh` 通过：核心与中英文资源一致，XcodeGen 2.45.4 两次生成结果一致。
- 已将云脚本固定的同一个官方 XcodeGen ZIP 解包并用于本地生成检查，通过；源锁文件与生成工程内的锁文件逐字节一致，依赖仍为 ZIPFoundation 0.9.20。这没有执行云端 Node 安装或 post-clone 全流程。
- 已检查生成的共享 scheme：唯一 UI 方法白名单、串行执行、保留附件、没有 archive build。
- 两个 shell 脚本语法检查通过；隔离合成检查覆盖：测试阶段输出、构建阶段跳过、其他 scheme 跳过、本地跳过、探针失败为 unknown、本地拒绝 bootstrap；这些不是网络或云构建测试。
- 待完成：首次开通/代码仓授权、运行前配置与额度回读、云端 post-clone 构建、单个在线 UI 测试及 `.xcresult`/截图下载。未声明本轮应用测试通过，也未声明 PR 可合并或适合上线。

首次接入早期现场：专用方案及标准 Xunju 方案均曾停在 Review Workflow 的 Loading 状态，Edit Workflow / Next 不可用。账号设置显示 Admin 与 Certificates, Identifiers, & Profiles 权限；这些观测没有确定加载停滞的根因。

2026-11-02 重新进入后已能加载 Review Workflow，不能仅凭恢复先后将它归因于 CLI 登录。向导识别 `com.keeline.xunju.ios` 与 Haichao Zhang 团队，默认配置为 main 变更触发、Archive、Xcode 27.1 latest、无 TestFlight 或通知。已将本地向导中的名称改为 `RentVisit US Address Search`，并通过 Deactivate 确认将开关设为 0 后保存；因原生编辑器的部分控件无法可靠操作，计划在首次接入后用接口将配置收窄为上表，再读回并运行。**当前只是向导中的停用草案，尚未创建云端工作流，也没有运行 Archive。**

当前停在 Grant Access to Your Source Code：界面列出 `Hayden-Chang/rent_room` 和公共依赖 `weichsel/ZIPFoundation`。点击前者 Grant Access 的动作被自动审批拒绝，原因是可能向 Apple Xcode Cloud 授予私有仓库访问权限，缺少明确的权限范围授权；已向用户请求仅限本仓库的接入确认。没有绕过拒绝、授予所有仓库权限或触发构建。现场截图保存在本机 `/private/tmp/rent-room-apple-search-evidence/xcode-cloud-repository-access.png`。

每次真实运行保留 workflow ID、build run ID/URL、源码 SHA、源分支、Xcode/macOS/iOS 与设备、出口观测、实际方法数/通过/失败/跳过数、完整日志、`.xcresult` 与截图。查询未执行到的后续步骤必须标记未覆盖。

## 官方依据

- [Xcode Cloud get started：会员包含额度](https://developer.apple.com/xcode-cloud/get-started/)
- [首次工作流配置](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow)
- [自定义脚本的位置与运行阶段](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
- [环境变量与云端 HTTP 代理](https://developer.apple.com/documentation/xcode/environment-variable-reference)
- [Swift Package 锁文件要求](https://developer.apple.com/documentation/xcode/making-dependencies-available-to-xcode-cloud)
- [XcodeGen 2.45.4](https://github.com/yonaskolb/XcodeGen/releases/tag/2.45.4)
