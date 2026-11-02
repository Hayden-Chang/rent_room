# 地址搜索的 Xcode Cloud 对照

更新日期：2026-11-02。已完成接入并取得第二轮真实 UI 结果；**纽约地址通过，California 在等待窗口内未完成，整条流程失败**。此前失败与本地证据见 [Apple 地点搜索记录](APPLE_PLACE_SEARCH_20261102.md)。

## 范围

- App Store Connect：RentVisit: Viewing Checklist，App ID `6828695680`，bundle ID `com.keeline.xunju.ios`。
- 开发团队 `N3Z6DDSQCJ`，通过现有 ASC 登录与 Xcode 的 Haichao Zhang 团队核对。团队配置落在 `ios/project.yml`，不手改或提交生成工程。
- 分支 `codex/ios-apple-place-search-20261102`，PR #118，保留草稿，不合入或发布。
- 2026-11-02 已用独立状态读取确认 Apple 网页会话认证成功，并成功复用会话查询实际额度：总量 1,500 compute minutes，已用 0，剩余 1,500（25 小时）；接口返回重置时间 `2026-11-03T10:13:41Z`。这是查询时的快照，启动前需重新核对，不得自动升级付费计划。

## 工作流配置

已从 Xcode 的 **Integrate → Create Workflow** 完成产品与代码仓连接。用户授权且界面确认 `Hayden-Chang/rent_room` 绿勾；没有为公共依赖 `weichsel/ZIPFoundation` 增加授权。按向导警告继续完成配置，第二轮已成功拉取并编译 ZIPFoundation 0.9.20，证实无需增加该公共仓库的授权。

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

已将 bootstrap 改为官方 Node 24.22.2 二进制、按 CPU 选择并固定校验值，临时目录退出清理；本地 arm64 在隔离任务 worktree 执行完整脚本通过，包括真实工具下载/校验、npm ci、资源一致性、XcodeGen 两次确定性生成。日志 `/private/tmp/rent-room-apple-search-evidence/cloud-bootstrap-local-arm64.log`。没有安装或修改宿主共享 Node/Homebrew；随后第二轮云端同一脚本也通过；首轮 Intel 环境故障证据保留，不把不同 worker 当同机器复测。

其他已有准备验证：共享 scheme 唯一 UI 方法白名单、串行执行、保留附件、无 archive build；两个 shell 脚本语法通过；测试阶段探针的阶段/scheme/local/失败分支检查通过。上述脚本检查不等同于真实网络测试。

第二轮 run `e1e8d5ab-899a-4d9f-b6d1-8544597fc869`，build #2，源码 `b54661d1f028266dc0ed20df00a480e7ce07e4e4`，同一个手动单方法工作流，无测试重试。post-clone、公共依赖解析、`TEST BUILD SUCCEEDED` 均确认。真实 XCUITest：**1 执行 / 0 通过 / 1 失败 / 0 跳过**；iPhone 16 / iOS 26.5 (23F77) / arm64，方法耗时约 43.89 秒。

- 测试 worker 在 `2026-11-02T10:38:05Z` 的 HTTP 出口观测为 `US`，边缘机房 `PHX`。这仍不等同于物理美国设备或所有 MapKit 请求路由证明。
- en-US 语言断言通过；纽约 `350 Fifth Avenue` 返回 `40.7482378,-73.9850579`，坐标断言和选中回填成功。[纽约结果截图](evidence/apple-place-search-20261102/cloud26-new-york-result.png)。
- California 输入正确；18 秒内没有结果按钮，失败时 UI 仍显示 `Searching for location…`。**测试的 `no result` 是等待超时诊断，不能解释为服务明确返回空集或不支持 California。** [等待超时截图](evidence/apple-place-search-20261102/cloud26-california-still-searching.png) 来自原始测试录像末帧，未改变内容。
- 系统日志在 California 提交后记录缺少 `siri_kg` 归属信息，并向 geod 请求下载 Apple 域名下的 Wikipedia logo；随后有连接 stall 和取消记录。可作为 SDK/云网络收尾问题的线索，尚未证明这些素材请求就是根因。当前包装的 12 秒逻辑仅调用 SDK cancel，并不独立结束等待；仍需针对无回调/超时行为建立回归证据后修复，不能单纯延长 UI 等待来称通过。
- Cupertino 与重启持久化未执行。没有获得完整美国地址路径的通过证据，不批准上线。

完整日志、`test-results.xcresult.zip`、解包后的 `.xcresult`、36 个附件、原始录像、诊断日志与 `receipt.json` 保留于本机 `/private/tmp/rent-room-apple-search-evidence/cloud-run-2-final/`。`test-summary.json` 由实际 xcresult 导出。第二轮失败保留，未重复跑同一测试追求绿灯。结束后独立网页接口回读 `disabled: true`；额度已用 7 分钟、剩余 1,493 分钟，无付费升级。PR 仍为草稿，未合入或发布。

每次真实运行保留 workflow ID、build run ID/URL、源码 SHA、源分支、Xcode/macOS/iOS 与设备、出口观测、实际方法数/通过/失败/跳过数、完整日志、`.xcresult` 与截图。查询未执行到的后续步骤必须标记未覆盖。

## 官方依据

- [Xcode Cloud get started：会员包含额度](https://developer.apple.com/xcode-cloud/get-started/)
- [首次工作流配置](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow)
- [自定义脚本的位置与运行阶段](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
- [环境变量与云端 HTTP 代理](https://developer.apple.com/documentation/xcode/environment-variable-reference)
- [Swift Package 锁文件要求](https://developer.apple.com/documentation/xcode/making-dependencies-available-to-xcode-cloud)
- [XcodeGen 2.45.4](https://github.com/yonaskolb/XcodeGen/releases/tag/2.45.4)
- [Node 24.22.2 官方校验清单](https://nodejs.org/dist/v24.22.2/SHASUMS256.txt)
