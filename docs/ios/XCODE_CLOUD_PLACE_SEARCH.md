# 地址搜索的 Xcode Cloud 对照

准备日期：2026-11-02。此文是接入配置与验收契约，**不代表已在云端运行或通过**。此前失败与本地证据见 [Apple 地点搜索记录](APPLE_PLACE_SEARCH_20261102.md)。

## 范围

- App Store Connect：RentVisit: Viewing Checklist，App ID `6828695680`，bundle ID `com.keeline.xunju.ios`。
- 开发团队 `N3Z6DDSQCJ`，通过现有 ASC 登录与 Xcode 的 Haichao Zhang 团队核对。团队配置落在 `ios/project.yml`，不手改或提交生成工程。
- 分支 `codex/ios-apple-place-search-20261102`，PR #118，保留草稿，不合入或发布。
- Apple Developer Program 包含每月 25 compute hours；本账号实际套餐、已用/剩余额度需在首次接入后读回确认，不能把包含量当剩余量。不得自动升级付费计划。

## 工作流配置

首次接入必须从 Xcode 的 **Integrate → Create Workflow** 完成产品与代码仓连接。App Store Connect 当前显示入门页；公共 API 查询该 App 的 ciProducts 返回空。CLI API 登录可用，但单独的网页会话已过期；Chrome 中现有 App Store Connect 登录仍可用。

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

`ios/ci_scripts/ci_pre_xcodebuild.sh` 仅在专用 scheme 的 `test-without-building` 阶段记录测试 worker 的提交、设备、runtime、UTC 时间，并向 Cloudflare trace 发起一次有超时的 HTTP 请求。输出只保留国家码与边缘机房码，不记录 IP、完整 trace 或代理变量。探针失败输出 `unknown`，不伪装为美国，也不吞掉随后 XCUITest 的失败。

Apple 的构建 worker 和测试 worker 是不同环境，且云端环境有自己的 HTTP 代理。因此该探针**仅证明测试 worker 的 HTTP 出口观测**，不能单独证明 MapKit 服务路由、物理设备位置或美国真实用户行为。云端不保证美国出口；不将地区语言设置或模拟 GPS 当美国网络证据。

## 已完成与待完成

- 本地 `check-xcodegen.sh` 通过：核心与中英文资源一致，XcodeGen 2.45.4 两次生成结果一致。
- 已检查生成的共享 scheme：唯一 UI 方法白名单、串行执行、保留附件、没有 archive build。
- 两个 shell 脚本语法检查通过；隔离合成检查覆盖：测试阶段输出、构建阶段跳过、其他 scheme 跳过、本地跳过、探针失败为 unknown、本地拒绝 bootstrap；这些不是网络或云构建测试。
- 待完成：首次开通/代码仓授权、实际额度核对、云端 post-clone 构建、单个在线 UI 测试及 `.xcresult`/截图下载。未声明本轮应用测试通过，也未声明 PR 可合并或适合上线。

每次真实运行保留 workflow ID、build run ID/URL、源码 SHA、源分支、Xcode/macOS/iOS 与设备、出口观测、实际方法数/通过/失败/跳过数、完整日志、`.xcresult` 与截图。查询未执行到的后续步骤必须标记未覆盖。

## 官方依据

- [Xcode Cloud get started：会员包含额度](https://developer.apple.com/xcode-cloud/get-started/)
- [首次工作流配置](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow)
- [自定义脚本的位置与运行阶段](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
- [环境变量与云端 HTTP 代理](https://developer.apple.com/documentation/xcode/environment-variable-reference)
- [XcodeGen 2.45.4](https://github.com/yonaskolb/XcodeGen/releases/tag/2.45.4)
