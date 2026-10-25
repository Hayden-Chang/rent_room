# iOS 地点和通勤查询修复（2026-10-22）

现有小程序 Key 可以继续使用，无需新增服务端 Key。iOS 已配置 Key 时复用小程序的地点、附近位置和路线解析，通过真实 WebKit 浏览器环境调用天地图；原生地图仍由 MapKit 渲染。未配置 Key 时保留原系统地点查询路径。已有地址重进收起、搜索焦点立即展开、选点/手填收起与相机保留行为不变。

## 根因与修复

1. 同一 Key 在真实 iOS URLSession 请求中返回 HTTP 403、`301012 权限类型错误`；真实 WKWebView 请求返回 HTTP 200、`resultCode=0`。Key 来源与当前小程序预览包一致，没有泄露或替换 Key。使用默认 WebKit 请求，不伪造 User-Agent；非持久数据存储、不携带 cookie，仍只允许天地图指定 HTTPS GET 路径。天地图官方说明要求区分浏览器与服务端应用类型，见[福建省自然资源厅说明](https://zrzyt.fujian.gov.cn/zwgk/xwdt/zrzyyw/202610/t20261009_7222216.htm)。此处现网证据为本应用的两种真实请求结果，不由本地文件名推断控制台配置。
2. iOS 18 的路线已解析完成，但传入参数数组的 Swift block 在完成回调时触发 TypeError；原 continuation 不结束。显式用 JSValue 包装回调后，同一个挂起响应回归用例通过。只保留 Promise 生命周期并不能修好此问题；该失败记录也保留。
3. 原查询没有取消与整体截止处理。现在取消立即抛出 CancellationError，查询整体最多等待15秒；浏览器单次请求沿用8/12秒上限并用 AbortController 结束。成功、失败、取消和超时只能结束一次；晚到的结果不会改写记录。
4. 旧系统地点搜索在不同系统版本返回不同结果：iOS18 的公开地标诊断曾返回不相关的 Tesla POI，iOS26 返回正确的英文地标；前轮也出现查询失败提示。不能把只匹配中文名称的诊断断言视为全部故障的根因。已配置的业务页现在使用小程序的既有天地图解析和 GCJ-02 存储边界，来源文案同步为“天地图”；没有宣称修复 Apple 服务本身。

小程序源码、现有 Key 文件、服务端与存储 schema 未修改。没有新增私有服务端凭据或代理部署。测试期间的阶段日志、原始 SDK/地理编码探针没有进入生产代码；长期覆盖保留为桥接单测、实际提供方断言和扩展的在线业务 UI 用例。

## 修改前失败与开发验证

- `xunju-query-diagnosis-20261022-red-02`：iOS26 上取消用例等待超时，证明原调用没有取消完成处理；其公开 SDK 诊断因中文名称判断失败，附件实际包含正确英文地标，该断言失败不计为 SDK 请求失败。
- `xunju-query-ios18-20261022-red-01`、`xunju-bridge-ios18-20261022-diagnostic-03`：原路线响应已返回/编码，但挂起回归用例未完成；在线业务未获得目标地标。另有原业务用例停在引导后的键盘焦点前提，不能计为通勤产品失败。
- `xunju-bridge-ios18-20261022-fix-01`：取消通过，路线回调仍失败。`...stages-01` 确认 JS 已到 query-ready，随后回调 TypeError；同轮 `testLiveNativeRouteProviderReturnsUsablePublicRoute` 真实返回403/301012。
- `xunju-bridge-ios18-20261022-fix-02`：显式回调转换后，挂起响应和取消2UT通过。
- `xunju-browser-map-ios26-20261022-diagnostic-01`：同一 Key 在实际 WebKit 中返回路线，1项真实提供方验证通过。最初的 iOS18 浏览器诊断未开始执行，因兼容设备正被其他任务租用而主动取消排队；不计为通过或产品失败。
- `xunju-map-query-20261022-green-01`：实际设备为iOS18.3.1，8UT和原业务UI通过；在线UI已完成真实搜索、选点、公交17分钟填回。后续测试用“驾车”筛选，而真实字段标签为“开车通勤时间（分钟）”，因此未到达驾车查询。失败快照明确显示搜索值“驾车”；修正两个筛选入口为“开车”，并校验实际搜索值，没有修改产品字段或放宽路线断言。
- 小程序在线对照任务 `3882e81b7c7a416380f853233b351e17` 因三个开发工具实例均被异常隔离、没有空闲槽而未执行；未重置或抢占实例。用户确认小程序地址和两类通勤正常，此观察与现有 Key 的 WebKit 实测一致，不把该排队任务说成小程序验证通过。

诊断的 `.xcresult` 都保留在 `/Volumes/mac2/codex-builds/`，计划、日志和已导出附件在 `/private/tmp/rent-room-map-collapse-20261022/`。两次启动脚本参数错误在执行测试前被 runner 拒绝，不计为产品失败或测试通过。

## 最终验证

冻结源代码 `39d808a8d74e370ac317691102a215ccf503f829`，工作树干净。`final-pr-head` 计划为11UT/3UI，**14通过、0失败、0跳过**，没有运行全量 suite。全部使用仓库包装脚本、XcodeGen2.45.4与共享 runner。

- Run ID：`xunju-map-query-20261022-final-01`；runner PID22962，slot1，测试子进程23121，退出0，租约已释放。
- iPhone14 Pro / iOS18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`。官方 `--config` 仅将设备名称前缀限制为兼容设备，仍使用同一池根、锁和并发上限，没有手工租约。
- 结果 `/Volumes/mac2/codex-builds/xunju-map-query-20261022-final-01.xcresult`；receipt `/tmp/todo-ios-sim-pool/run-receipts/xunju-map-query-20261022-final-01.json`。
- 计划、命令、日志、summary和执行凭据分别为 `/private/tmp/rent-room-map-collapse-20261022/ios-map-query-final-01-{plan.json,command.sh,log,summary.json,execution.json}`。
- 实际缓存 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-ccf0d0815539d3e202f08802-simulator`，无生成的xcodeproj进入diff。

### 单测影响映射

- `XunjuTests/MapCoreTests/testSuspendedRouteResponseCompletesJavaScriptBridge`：iOS 18 callback conversion regression
- `XunjuTests/MapCoreTests/testCancellingPendingRouteQueryCompletesBeforeTransportReturns`：Cancellation must not wait for provider callbacks
- `XunjuTests/MapCoreTests/testStalledRouteDeadlineCompletesAndLateReplyCannotChangeRecords`：Stalled provider has a bounded whole-query deadline
- `XunjuTests/MapCoreTests/testNegativeRouteTimeAndMissingKeyNeverProduceAResult`：Error replies still settle the bridge without saving invented results
- `XunjuTests/MapCoreTests/testTransportRejectsUntrustedDomainsAndUnsupportedMethodsBeforeSending`：Retain map origin/method boundary
- `XunjuTests/UtilityFlowTests/testConfiguredPlaceSearchUsesMiniProgramParserAndPreservesSavedCoordinate`：Configured browser provider bypasses unavailable system search and preserves GCJ-02 storage
- `XunjuTests/UtilityFlowTests/testCancelledPlaceResponseDoesNotRestoreCandidatesOrChangeRecords`：Keep keyless SDK cancellation behavior
- `XunjuTests/UtilityFlowTests/testRouteConfirmationPersistsAndRejectsChangedValueAndEndpoints`：Verify route save and stale endpoint/value guards
- `XunjuTests/MapCoreTests/testLiveNativeRouteProviderReturnsUsablePublicRoute`：Same public-route assertion failed with 403/301012 before the provider transport fix
- `XunjuTests/MapCoreTests/testPlaceSearchUsesCanonicalParsingAndCoordinateBoundaryWithoutMutation`：Canonical places parser now feeds the actual iOS picker
- `XunjuTests/MapCoreTests/testRouteQueryAndConfirmedWriteRetainNotesAndRejectChangedEndpointsOrValue`：Async route parsing must retain notes and reject stale confirmed writes

### UI风险排序与实际结果

1. 原失败在线入口：`UtilityBusinessTests/testLiveSystemPlaceSearchSelectionAndRelaunch`，沿用原方法名，扩展到真实地点搜索、公交/开车路线、填回及磁盘重启。普通业务UI、UUID隔离记录、没有 `--utility-network-fixture`，没有物理/GPS位置。实际公开选点为人民广场附近与东方明珠；公交17分钟、开车7分钟，两者确认填回，重启后逐项核对仍分别为17与7。单测另记录实际天地图HTTP200/resultCode0/3组结果，不能用该HTTP状态代替本条语义验证。
2. 用户已批准的交互：`UtilityBusinessTests/testHouseMapReentryFocusAndAddressPersistAfterRelaunch`，重进、空搜索聚焦、手填坐标失效、保留地图及重启保持收起。
3. 原串联业务：`UtilityBusinessTests/testRealGuidePlaceWorkplaceAndCommutePersistAfterRelaunch`，引导、选点、上班地点、通勤填回重启、归档只读；此条使用显式网络夹具，真实导航和磁盘保存。与在线条目分开标注。

三条UI分别49.770、103.377、72.630秒，均为方法执行时间，不能当成真实网络延迟或runner墙钟。上述3项覆盖本轮最高风险，未增加更多最终UI方法。原组件平移/完整相机恢复沿用既有记录；本轮组件只增加正确的地点来源文本，不改相机逻辑，正式页面的重进/手填边界已重验。

### 原始图像与主agent审查

19张原始1178×2556 PNG导出到 `/private/tmp/rent-room-map-collapse-20261022/ios-map-query-final-01-attachments/`。显示副本在 `/Users/pc/.codex/visualizations/2026/10/22/01a1613d-4a43-7142-9c62-95a0f560db41/map-query/`，`provenance.json`逐张记录测试、设备、原始路径、尺寸和SHA256，复制前后字节完全一致。

主agent查看实际搜索结果、选中收起、公交路径及17分钟卡片、开车路径及7分钟卡片、重启后开车字段7的截图。`live-map-05-both-commutes-persisted.png`画面只显示最后筛选的开车字段；两项重启断言由UI执行记录证明，不声称一张图同时展示两项。主agent检查本轮完整diff的域名/方法限制、回调生命周期、取消与晚到结果、坐标往返、确认保护、来源文案和测试夹具边界，没有发现待修项。

没有真机安装、合并或发布；PR仍基于未合并的#39，保持Draft。验证之后仅补充本文档与地图历史记录的当前状态链接，不改变可执行代码、资源、生成输入、测试或选择计划，可复用39d808a的证据。
