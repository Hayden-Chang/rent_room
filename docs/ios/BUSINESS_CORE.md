# iOS 业务核心与第二批组件

## 当前状态

第一批组件已由用户明确批准：“确认通过，继续完整业务开发”。原生端现在通过 JavaScriptCore 复用最新 main 小程序的原始 `model.js`、`source-model.js`、`store.js`、`capacity.js`、`issues.js` 等纯业务模块，UI 继续使用 SwiftUI。不另写第二套清单规则；302字段及动态进度、分组、问题和比较契约保持同源。

`ios/Core/bridge.js` 是原生适配入口；`ios/scripts/build-core.mjs` 用固定版本 esbuild 生成带9个来源文件 SHA-256 的 `Resources/XunjuCore.js`。构建包装脚本检查生成结果是否过期。先在 `apps/wechat` 执行 `npm ci --ignore-scripts`，然后用 `node ios/scripts/build-core.mjs` 更新；不要手改生成文件。工程真源仍为 XcodeGen。

已接入可调用、可持久化的业务 API：新建/重命名、答案/备注/问题标记、条件分组、动态费用、归档/还原/删除、意向/总结、手动问题、影像元数据、2至3房源比较和导入原子提交。仍需完整页面操作验证；有业务 API 不等于已完成相机、地图、ZIP 或用户流程。

本机保存使用原子替换并保留上一完整版本。损坏状态阻止写入，恢复时保留损坏原件。需持久保存的新增/归档/删除失败会回滚；普通输入保存失败仍保留本次会话的输入，等待重试。

游客记录使用独立目录、归属标记、认领 journal 和已提交批次号。首次登录保留记录与媒体原件，冲突编号生成副本，重试不重复；合并后允许保留超额已有记录，但不发放额外容量。退出后的新游客不能看见已归属账号的记录。媒体使用沙盒内相对路径，认领时复制到目标账号目录。

## 第二批组件：REVIEW_READY

已展示并等待用户确认的范围：文字/数字输入、长选项、“其他”附加内容、多选、左滑操作，以及总结三种意向与备注。独立 DEBUG 宿主仍使用可丢弃 fixture，不写房源或认证状态。本批尚未集成完整页面；日期选择器和其余页面不在本批批准范围。

- 总结证据 SHA `291d78a`，XCUITest `AnswerReviewTests/testDecisionCanClearAndNoteKeepsInput`。
- 输入证据 SHA `940a940`，XCUITest `AnswerReviewTests/testTextNumbersOtherAndMultipleChoices`。
- 设备：iPhone16 / iOS26.5，UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`，1178×2556。
- 结果：`/Volumes/mac2/codex-builds/xunju-ios-answers-20261019-01.xcresult` 与 `...-02.xcresult`。
- 图片：`ios-review/08-inputs-other-multiple.png`、`09-input-swipe.png`、`10-summary-note.png`，绝对根路径为 `/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/`。
- 主 agent 已检查原图并展示：44pt控件、原色/圆角、长选项换行、多选同时选中、“其他”输入切换后保留、左滑三个操作；总结截图包含原生键盘输入状态。

首轮输入用例错误假设点击后光标在末尾；实际在开头插入数字，已有数字未丢失。修正断言接受两种合法光标位置，只重跑该失败方法；原失败 bundle 保留。总结用例首轮通过且生产组件未变，复用原证据。后续认证、存储与认领代码不被这两个 fixture 宿主调用，也未改布局、颜色、资产、字体或宿主数据，可复用这些截图；不能把截图标为来自后续 SHA。

## 本轮定向测试

| 实施边界 | 精确测试层 | 结果与证据 |
| --- | --- | --- |
| 同源302字段、数字0、持久化、容量/归档、隐藏答案、独立问题标记、OR筛选、手动问题、比较/总结、导入、损坏恢复、保存失败保护 | `XunjuTests/NativeStoreTests` 的8个新增方法 | 首轮8通过；认领引擎新增后重验8通过，`xunju-ios-scopes-20261019-01.xcresult` |
| 游客认领、空游客、账号隔离、媒体原件、失败journal恢复、冲突编号、超容量保留、非法路径 | `XunjuTests/IdentityScopeTests` 的6个新增方法 | 6通过，同上；合计14UT、0失败 |
| 手机验证码协议、服务错误/不假成功、非法手机号不发请求、账号/容量校验、Apple挑战与token传服务端、Bearer撤销 | `XunjuTests/AuthenticationAPITests` 的3个新增方法 | 3通过，`xunju-ios-auth-20261019-02.xcresult`；使用模拟传输，不调用线上 |
| 新增输入与总结原生交互 | `XunjuUITests/AnswerReviewTests` 的2个新增方法 | 2通过，见上述两个bundle，输入用例保留过一次测量假设失败 |

所有原生测试通过共享 Simulator Management runner，计划/日志在 `/tmp/xunju-ios-20261019/`，receipt 在 `/tmp/todo-ios-sim-pool/run-receipts/`；所有 DerivedData/xcresult 在 `/Volumes/mac2/codex-builds/`。构建曾因Swift不允许在泛型函数中声明局部类型而失败，修正后3UT通过；未把编译失败计为产品回归或单测通过。

这是开发阶段增量证据，尚非完整应用的最终 PR head 验证或合并许可。

## 认证服务与真实配置

iOS 已有短信与 Apple 的网络协议客户端以及仅本机 Keychain 会话存储。Keychain 内容不写入业务 state 或房源 ZIP；账号目录只接受服务端返回的64位十六进制身份。

配套后端 [model_server Draft PR #87](https://github.com/Hayden-Chang/model_server/pull/87)，源码 `4ccee7d529780afbee63488adbe64645c84809db`：同一会话/容量库新增短信挑战、验证码限流/过期/尝试次数/单次使用、Apple签名及nonce验证、当前会话撤销和旧微信会话迁移。新增及受影响的33项测试通过。主 agent 已读取实际远程patch并对照本地源码和测试单独审查。未合并、未部署、未发送真实短信或完成Apple真机授权。

正式接入仍需短信供应商签名/模板、RAM凭证、稳定身份密钥和正式 Bundle ID / Sign in with Apple 能力。默认新登录关闭；客户端不会将手机号或Apple user identifier直接视为可信账号。微信原生 SDK、真实短信/Apple授权、会话到页面的完整生命周期、StoreKit扩容仍待接入与验收。

## 剩余工作

完整房源/清单/对比/设置页面、影像拍摄/预览/编辑、问题编辑、ZIP页面接入、上班地点/通勤/测速、引导、账号状态切换和StoreKit均需继续实现与原生操作验收。普通启动暂仍显示准备页；本轮不能称为 iOS 全功能交付，也不能发布。


## ZIP 核心：双向兼容已验证

固定依赖 ZIPFoundation 0.9.20，声明在 `ios/project.yml`，许可证随原生资源保留。归档任务在独立 actor 中运行，每块256 KiB；manifest上限32 MiB，媒体总量没有50 MiB的人工上限。只读预览验证文件头/中央目录、重复路径、压缩方式、加密、文件类型、大小/CRC元数据，仅读取manifest，不展开未选择的媒体。确认导入时二次读取并校验文件指纹，只解出选中的媒体到随机私有文件名；schema和规则继续通过原小程序的 `prepareImport` 验证。

导入前后核对账号scope与状态revision，存储失败/容量不足/文件损坏/取消或账号切换均不提交；暂存媒体随失败清理。允许按净增容量覆盖选中房源，保留本机全局设置。导出只含房源与其影像，不带账号归属、Keychain或全局设置；不修改原始房源/媒体。文件选择、分享与进度UI尚未接入，不能据此声明完整备份操作验收。

`xunju-ios-backup-scopes-20261019-05.xcresult`：21UT通过，0失败（11项新备份、6项受影响的认领、4项路径隔离/规范化）。首次引入时的两次编译失败保留：缺少try、Swift6对第三方Entry捕获的隔离诊断；之后仅读取可发送的size/CRC标量。未以编译失败作为回归证明。

双向实证：

- `ios/scripts/create-wechat-backup-fixture.mjs` 直接调用未修改的小程序 `writeBackup`，生成真实协议fixture `XunjuTests/Fixtures/wechat-backup.zip`。iOS实际导入并验证中文标题、租金备注、手动问题及影像的issueId、备注和原始字节。
- 原生XCTest实际生成并作为附件保留 `native-cross-platform.zip`。从上述05结果bundle导出后，使用 `ios/scripts/verify-native-backup.mjs` 调用未修改的小程序 `readBackup` 两遍（预览/带sink校验）。房源字段、数字0、总结、媒体关联、800000个媒体字节的SHA256及CRC均通过。
- 另有52 MiB总媒体的真实写入/预览测试，证明没有误加50 MiB总体积限制。未以此代表真机峰值内存或超4 GiB场景已验收。

## 路径回归与保留证据

独立审查发现初版目录解析允许整个media目录通过符号链接指向其他scope。新增3项精确回归，在 `xunju-ios-path-regression-20261019-before.xcresult` 均因错误接受跨scope读取/导出/暂存而失败；数据全部为本测试创建的临时目录。统一通过 `LocalMediaFiles` 校验规范目录后，同3项在05全部通过。

首次收紧后正常新目录被误拒绝：已有目录测试通过，精确首次创建测试在 `xunju-ios-url-regression-20261019-before-create.xcresult` 复现失败；日志显示预创建URL无尾斜杠、创建后解析URL有尾斜杠，但规范path相同。改为比较规范path后，正常创建、认领、ZIP流程及隔离回归共21项同时通过。04的正常路径失败、诊断先仅覆盖已有目录的通过结果及全部修正前证据均保留。

本轮累计新增iOS业务UT为32个（核心8、认领6、认证3、备份11、路径4），另有2个新增UI方法；均为分边界开发验证，不声称一次最终head全量运行。日志、计划、receipt和源码文件哈希副本在本worktree忽略目录 `artifacts/ios-business-20261019/`，原生结果bundle仍以 `/Volumes/mac2/codex-builds/` 下绝对路径为准。
