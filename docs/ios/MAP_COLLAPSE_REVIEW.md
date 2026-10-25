# 地图自动收起修复与评审（2026-10-22）

当前：组件已获用户批准，正式房源/上班地址接入完成。后续地点在线查询与通勤回调/授权问题也已修复；iOS18最终11UT/3UI全部通过，见[查询修复与真实路线证据](MAP_QUERY_RELIABILITY.md)。

下面保留地图独立修复阶段的历史记录；其中查询服务未改或仍失败等描述对应当时提交，当前查询状态以上方链接为准。

## 用户批准后的正式页面接入

用户在本会话明确回复“没问题”，本轮组件状态为 `APPROVED`。随后接入 `LocationPages.swift`：PlacePicker传入真实外部address；HousePlaceField读取房源地址，WorkplacePage使用手填text。没有改布局、查询服务、GCJ-02存储格式或工程配置。未合并、真机安装或发布。

真实页面回归补充发现：选点后的地图若从未发生相机回调，手填导致坐标失效时，原组件会移除MapKit、变成占位区。组件现在在获得有效位置后保留地图实例和position，尚无MapCamera回调也能再次展开原视野；不将失效坐标写回房源。既有原生平移后的完整相机恢复规则保持不变。

### 本轮失败与修正边界

- 测试提交1571252、旧页面red-01构建成功，停在脚本假设“文字从末尾追加”；实际光标在开头，尚未到达地图断言。这是测试前提问题，不记为产品复现。
- d314904修正文字观察后，旧页面red-02失败于手填后的再次展开。导出截图虽名为manual-collapsed，实际清楚显示“收起地图”和展开的占位区，因此不能把原生Map节点消失当作已经收起。正式接入后增加开关文案断言。
- 509e747的green-01：4 UT通过；4 UI中仅模拟系统定位通过，3失败。上班地址失败证明首个相机回调前的实例丢失；房源用例在引导结束后的清单搜索输入未获得焦点，尚未到地图步骤，改用用户实际的基本信息标题入口。补充在线SDK用例失败，UI快照显示“地点查询失败，请重试或手动填写地址”；没有返回公开地标。保留此失败，不将固定网络数据通过称为在线查询通过。
- 288c1e3修复相机实例边界，并按实际基本信息入口验证；以下为重新计算的定向测试记录。所有原失败xcresult、日志和附件均保留，未覆盖或终止。

### 影响映射与证据

UT为UtilityFlowTests下4个精确方法：testUsingPlaceDismissesCandidatesUntilAnotherSearch（选择取消候选与显式重搜）、testHouseSelectionRoundTripKeepsCandidatesDismissed（房源坐标读回）、testPlaceSelectionPersistsCanonicalAddressAndWorkplaceWithoutChangingAnswers（房源/上班保存重载且不改答案）、testClearingOrInvalidatingLocationRemovesDisplayedPointAndOldCandidates（清空/失效坐标及旧候选）。未运行全量UT。

开发阶段UI按影响选择真实房源/上班页面、连续模拟定位和相机组件。补充在线SDK失败独立保留，查询提供方和客户端代码本次未修改，不作为离线交互门禁；没有声称SDK现网查询通过。

最终PR-head按上限选择3个精确UI：UtilityBusinessTests/testHouseMapReentryFocusAndAddressPersistAfterRelaunch（实际基本信息重进、空搜索焦点、手填、磁盘重启），UtilityBusinessTests/testManualWorkplaceSaveAndClearSurviveRelaunch（坐标失效、地图实例保留、纯文字地址重启与焦点、清空重启），UtilityReviewTests/testPlaceMapExpandsForSearchAndCollapsesAfterUseOrManualAddress（已批准的原生平移、搜索、手填和完整相机恢复）。模拟定位为开发阶段额外影响覆盖；权限/设置和只读组件沿用前轮证据，变更仅在坐标失效前后保留Map实例，不改变固定有效center、readonly或权限分支。

### 第二轮诊断与官方资料

288c1e3的green-02：4 UT通过；连续模拟定位与相机组件2 UI通过，2页面UI失败。上班地址在第一次点击展开行后仍显示“展开地图”，录像及合成触点确认点击位于整行中部（196.5,339.33）；在按钮label的可见frame内补充contentShape(Rectangle())。原房源串联用例已通过重进收起、空输入焦点与手填收起，随后通勤等待超时；失败录像显示起终点标记与地址均在，状态仍为“查询中…”，不能声称通勤通过。保留该原用例，新增独立房源地图回归，不依赖路线查询即可完成地图交互及磁盘重启验证。

按research-after-two-failed-attempts在下一轮编辑前核对Apple资料（2026-10-22访问）：[WWDC23 MapKit for SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10043/)说明默认相机回调在地图交互结束时触发、position独立表示相机位置；[contentShape](https://developer.apple.com/documentation/swiftui/view/contentshape(_:eofill:))定义命中形状；[waitForExistence](https://developer.apple.com/documentation/xcuiautomation/xcuielement/waitforexistence(timeout:))用于等待可访问性节点出现。本次API均已在iOS18.3.1可用；应用到35a49ff的最小差异为整行命中区，测试在真实Map节点上使用条件等待，不加固定sleep、不放宽坐标或地址断言。

### 最终验证结果

冻结源码 `35a49ffcfd3da3163921fd74abc0868fd2656ef4`，`final-pr-head`计划 **4 UT / 3 UI，7通过、0失败、0跳过**，一次完整通过。本轮没有运行全量suite。房源独立方法49.548秒、上班地址33.953秒、相机组件25.575秒；只表示方法执行时间，包含构建与启动收尾的runner墙钟不与其混算。

- 计划 `/private/tmp/rent-room-map-collapse-20261022/ios-business-green-03-plan.json`，完整原始命令 `ios-business-green-03-command.sh`、日志 `ios-business-green-03.log`、summary `ios-business-green-03-summary.json`均在同目录。
- 结果包 `/Volumes/mac2/codex-builds/xunju-map-business-20261022-green-03.xcresult`；共享runner PID3332、slot1，测试子进程3508，退出码0。真实执行凭据 `ios-business-green-03-execution.json`；receipt `/tmp/todo-ios-sim-pool/run-receipts/xunju-map-business-20261022-green-03.json`；完成后本run的owner/lease均已释放。
- iPhone14 Pro / iOS18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`；仓库包装脚本与XcodeGen2.45.4。缓存 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-ccf0d0815539d3e202f08802-simulator`，没有生成工程进入diff。
- 原始19张1178×2556附件与manifest在 `/private/tmp/rent-room-map-collapse-20261022/ios-business-green-03-attachments/`。显示副本在 `/Users/pc/.codex/visualizations/2026/10/22/01a1613d-4a43-7142-9c62-95a0f560db41/map-collapse/ios-business/`，provenance.json记录源码、测试、设备、尺寸、SHA256和原始路径；复制前后字节一致。
- 主agent查看房源重进、纯文字地址重启、手填后原地图恢复、上班地址与焦点截图，以及组件相机恢复截图。组件本批中心31.2304,121.4900、距离2483米，展开/搜索/手填恢复断言通过。纯文字地址重启会预填搜索并显示候选，地图仍收起；未改搜索结果列表。
- 真实房源焦点截图中的地图被键盘及清单布局遮挡，但真实Map节点和展开状态断言已通过，不声称聚焦时地图全部可见。上班重启截图拍在导航转场中，不作稳定外观样例；可交付的稳定样例使用house-map-01-reentered-collapsed及house-map-04-retained-camera等原始图片。
- 页面使用UUID隔离NativeStore、真实页面导航和磁盘重启；POI与地点网络为显式固定数据，MapKit渲染、原生操作和业务保存是真实实现。补充在线地标查询失败及串联通勤超时仍未解决，不把本轮地图交互通过说成这些服务通过或整个父PR可发布。
- 本源码之后仅追加本文档；生产、测试、资源、工程配置与运行输入不变，复用35a49ff的本地证据。主agent已检查最终6文件diff，无存储、查询服务或生成工程修改。PR #42保持Draft，父分支为未合并的#39；没有远程CI状态或workflow结果可宣称通过。没有合并、真机安装或发布。


本节以下为组件批准前的历史评审记录；其中“等待批准/正式接入尚未完成”描述对应历史提交，当前状态以本节为准。

## 批准前的组件评审（历史）

本次仅评审原生地点组件：已有地址、坐标或预填地址重新显示时保持收起；搜索框获得焦点、输入或清空时自动展开地图；点击“使用”或搜索结果、外部手填地址变化时收起地图，保留搜索结果和“展开地图”入口。再次展开恢复完整 MapCamera（中心、距离、方向和倾角），不主动请求 GPS。隐藏地图不参与点击或无障碍导航；只读地图仍可查看。

## 范围和接入边界

- 基于尚未合并的 iOS 开发分支 `codex/ios-parity-20261019`，父提交 `4cabe5fb8ef5f87704cce947fc59ce91e0b01327`；本次子分支 `codex/ios-map-auto-collapse-20261022`。
- `PlacePickerSurface` 已实现交互，Debug 显式地点评审宿主使用同一组件和外部地址参数。正式 `LocationPages.swift` 尚未传入外部手填地址；须经本次视觉批准后再接入房源/上班地址变化，并验证手填失效坐标时仍保留当前视野。
- 评审宿主候选地点为固定夹具；地图为真实 MapKit，平移使用原生手势。宿主选点不写房源，不代表业务保存或物理 GPS 已验收。
- `reviewCameraChanged` 仅在 Debug 编译，普通业务调用为 nil；用于读回真实相机距离，不改变相机决策。

## 本轮同步：重进保持收起，聚焦立即展开

源码证据提交 `fc6692f6ebc84254baa0b5100cd38e90fa851a66`。`PlacePickerSurface` 初次显示根据地址、中心和预填query初始化收起，空白地点与只读地图仍可显示；通过FocusState显式展开，绑定忽略未变化的文字。对PlaceSearch.start稍后预填的纯文字地址，在用户尚未操作时仍保持收起，用户已聚焦/输入/手动展开后的异步预填不会替其收起。

共用组件由既有HousePlaceField/WorkplacePage调用，本轮没有改LocationPages、PlaceSearch、房源存储或工程配置。Debug宿主保留地址与中心，使用独立id重建同一生产组件，新增挂载代次与查询写入计数；全部只在DEBUG编译。重进证据是组件重新挂载，不代表真实房源导航、磁盘保存与重新打开的完整业务E2E。正式手填字段的外部address参数接入仍遵守上面的批准边界。

### 修改前与诊断

- `d398720`只增加测试/宿主，生产组件仍为旧版。red-01：iPhone14 Pro/iOS18.3.1，2方法1失败/1通过，失败为 `Reentering a saved address must keep the map collapsed`。空搜索首次聚焦旧版已可展开，没有把这个通过场景说成焦点不展开的失败。
- 随后`067636f`只增加查询写入计数，仍不改生产组件。focus-red-02：iPhone16/iOS26.5，单方法失败，焦点没有输入文字却写回查询2次（0→2），失败为 `Focus must not resubmit an unchanged search query`。因此新版本使用显式焦点并跳过相同值写回，使展开不再依赖该副作用。
- 两次原始结果分别为 `/Volumes/mac2/codex-builds/xunju-map-focus-reentry-20261022-red-01.xcresult` 和 `xunju-map-focus-reentry-20261022-focus-red-02.xcresult`；日志及summary在 `/private/tmp/rent-room-map-collapse-20261022/ios-focus-*`。未强停或覆盖失败结果。

### 修复后结果

共享runner最终计划0 UT/3 UI，三个精确方法一次完整通过（0失败/0跳过），未运行全量suite。未增加镜像组件状态的UT；本轮只改SwiftUI本地交互，沿用真实UI验证。

| 精确方法 | 本轮证据 |
| --- | --- |
| `XunjuUITests/UtilityReviewTests/testPlaceMapExpandsForSearchAndCollapsesAfterUseOrManualAddress` | 选点后保持地址，id重建后挂载计数变1且地图仍隐藏；后续原生平移、选点/搜索/手填收起与中心/距离恢复均通过，9张图 |
| `XunjuUITests/UtilityReviewTests/testPlaceSearchSelectionAndPermissionFallback` | 空query只点击搜索框，键盘出现、地图展开、query仍为空且写入计数保持0；搜索选点及权限/设置入口通过，5张图 |
| `XunjuUITests/UtilityReviewTests/testReadOnlyMapHidesEditingAndLocationActions` | 从初始收起状态切到只读，地图显示且编辑/定位入口隐藏，通过，1张图 |

- 设备：iPhone14 Pro / iOS18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`，1178×2556截图。
- runner PID92002、slot1，UI子进程92420，退出码0，完成后本任务owner/lease已释放。缓存 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-ccf0d0815539d3e202f08802-simulator`；仓库包装脚本与XcodeGen2.45.4，未提交生成工程。
- 计划 `/private/tmp/rent-room-map-collapse-20261022/ios-focus-reentry-green-plan.json`，日志同目录 `ios-focus-reentry-green.log`，runner receipt `/tmp/todo-ios-sim-pool/run-receipts/xunju-map-focus-reentry-20261022-green-01.json`。
- 结果包 `/Volumes/mac2/codex-builds/xunju-map-focus-reentry-20261022-green-01.xcresult`；原始15张附件及manifest在 `/private/tmp/rent-room-map-collapse-20261022/ios-focus-reentry-attachments/`。
- 显示副本 `/Users/pc/.codex/visualizations/2026/10/22/01a1613d-4a43-7142-9c62-95a0f560db41/map-collapse/ios-focus-reentry/`，provenance.json逐图记录原始路径、测试、尺寸和SHA256，复制前后字节一致。
- 主agent已查看重进前后、空输入焦点和键盘、视野恢复与只读原始截图；重进后只剩“展开地图”，焦点态搜索框仍显示占位词且地图与键盘同时可见。本轮POI/权限仍为固定夹具，真实MapKit和原生操作，未做物理设备或真实业务保存验证。

当前 `REVIEW_READY`，等用户视觉批准；未合并、真机安装或发布。证据源码之后仅追加本文档，生产、宿主、UI测试与构建配置相同，复用fc6692f结果，不将文档提交称为新测试来源。

## 前轮搜索展开修订与证据

按用户最新反馈，只有用户编辑/清空搜索框才主动展开；选择结果后程序清空搜索词继续保持收起，外部手填地址变化仍收起。未改正式页面或业务模型。

- 回归提交 `fb918856f28af29ffa5ded1eb7168bb2a6f10fba` 在旧组件上构建成功，1方法1失败，唯一失败为 `Search input must expand the map`。设备为 runner 分配的 iPhone 14 Pro / iOS18.3.1，UDID `8F178971-C203-4690-A83B-253046EACBB1`；失败诊断耗时较长，最终正常返回65，没有强停进程。结果包 `/Volumes/mac2/codex-builds/xunju-map-search-expand-20261022-red-01.xcresult`。
- 修订证据提交 `b196433c766e4f0298da2eb6fd4942cefc9e70b5`，工作树干净，`final-pr-head` 计划0 UT / 3 UI，三个方法一次完整通过。未运行全量suite；状态只在SwiftUI组件中，未增加镜像实现的独立UT。
- 本轮通过设备由共享runner分配：iPhone16 / iOS26.5，UDID `759E28A9-21EB-4AA1-9F4F-EF1850989C56`。runner PID56146，slot3；构建子进程57688，UI子进程58752。排队累计219.261秒。正常结束后本任务slot/lease已释放，receipt退出码0。沿用本worktree独立缓存 `time-fragment-dd-shared-ccf0d0815539d3e202f08802-simulator`。

| 精确方法 | 覆盖与结果 |
| --- | --- |
| `XunjuUITests/UtilityReviewTests/testPlaceMapExpandsForSearchAndCollapsesAfterUseOrManualAddress` | 原生平移后选点收起、手动展开、再次收起后输入搜索自动展开、提交搜索仍展开、手填收起与再次恢复；中心和相机距离比较通过，7张状态图 |
| `XunjuUITests/UtilityReviewTests/testPlaceSearchSelectionAndPermissionFallback` | 搜索结果可选、选择后程序清空词不展开、定位权限提示和设置回调通过，3张图 |
| `XunjuUITests/UtilityReviewTests/testReadOnlyMapHidesEditingAndLocationActions` | 只读地图可见且无编辑/定位入口，通过，1张图 |

主agent已检查导出的原始截图：收起后仅剩“展开地图”入口；搜索态显示“收起地图”和实际MapKit；手填后地图隐藏，恢复视野一致。该夹具的平移中心 `31.2304,121.4857`，相机距离2483米，在选点、搜索、手填展开后保持一致。

输入时键盘会遮住下方地图：`map-04-typing-expanded` 可见“收起地图”入口，`map-05-search-expanded` 是按搜索收键盘后可见的实际地图。未改搜索结果列表高度或增加自动滚动，也未声称输入时地图始终可见。POI与权限事件仍为固定组件夹具；没有物理GPS、真实业务保存或手机中文输入法验证。

原始证据与可读副本：

- 计划：`/private/tmp/rent-room-map-collapse-20261022/ios-search-expand-{red,green}-plan.json`；日志及summary在同目录同前缀。
- 通过结果包：`/Volumes/mac2/codex-builds/xunju-map-search-expand-20261022-green-01.xcresult`（3通过/0失败）。
- 11张原始附件及manifest：`/private/tmp/rent-room-map-collapse-20261022/ios-search-expand-attachments/`；1178×2556像素。
- 显示副本：`/Users/pc/.codex/visualizations/2026/10/22/01a1613d-4a43-7142-9c62-95a0f560db41/map-collapse/search-expand/`；`provenance.json`逐图记录原始文件、测试、尺寸和SHA256，复制前后字节一致。
- 本轮源码之后仅追加本文档，组件、测试、宿主及构建配置没有变化，复用b196433截图与本地通过结果；不把文档提交称为新测试来源。

当前门禁为 `REVIEW_READY`，等待用户明确批准组件交互后接入正式手填地址页面。小程序本轮46项与编译通过，但共享工具健康检查失败，最新搜索展开尚无开发者工具截图；详见PR #41。

## 首轮自动化证据（搜索输入收起，已按用户反馈修订）

共享 runner `/Volumes/mac2/projects/git_repo/run_self/Simulator Management/bin/sim-test-run.mjs`，实时配置 `config/runner.json`。本批使用 iPhone 16 / iOS 26.5，UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`。构建均经项目 `scripts/run-xcodebuild.sh` 和固定 XcodeGen 2.45.4；未改工程配置或提交生成工程。

| 源码边界 | 精确方法 | 结果 |
| --- | --- | --- |
| 选点、搜索、手填地址及相机保留 | `XunjuUITests/UtilityReviewTests/testPlaceMapCollapsesAfterUseAndSearch` | `e9320c4` 通过；平移后比较中心及相机距离，并保存7张状态图 |
| 只读地图 | `XunjuUITests/UtilityReviewTests/testReadOnlyMapHidesEditingAndLocationActions` | `e9320c4` 通过 |
| 搜索选择、定位权限及设置入口 | `XunjuUITests/UtilityReviewTests/testPlaceSearchSelectionAndPermissionFallback` | `7321c0a` 单方法重跑通过 |

不选择独立 UT：本次状态和相机仅存在于 SwiftUI 组件内，未修改业务模型或查询服务；通过上述真实 UI 方法验证交互边界。未运行全部 UT/UI suite。

- 修复前 `4fea0d6` 新增 UI 回归在“Using a place must collapse the map”断言失败（构建成功，1方法1失败）。首次尝试因本机 Git URL 重写导致公开 Swift Package SSH 拉取失败，改为仅进程内 HTTPS 配置后取得上述有效失败。
- `c2090a8` 初轮3 UI通过，但主 agent 查看截图发现恢复 region 会改变缩放，未将其视为视觉通过。改为 MapCamera 并固定原生地图内部高度。
- `e9320c4` 批次2通过1失败。唯一失败是定位按钮边缘点击未触发权限提示；检查录屏和合成触点后，把可见 padding 移到按钮 label 内，使整个可见按钮响应。`7321c0a` 只改该命中边界，未改相机、收起状态、只读或测试夹具；复用2项通过结果，精确重跑失败方法。没有把不同尝试说成一次完整全绿。

原始证据：

- 计划及日志：`/private/tmp/rent-room-map-collapse-20261022/ios-*-plan*.json`、`ios-*.log`。
- 修复前：`/Volumes/mac2/codex-builds/xunju-map-collapse-20261022-red-02.xcresult`。
- 最后完整批次：`/Volumes/mac2/codex-builds/xunju-map-collapse-20261022-green-02.xcresult`。
- 单方法修复：`/Volumes/mac2/codex-builds/xunju-map-collapse-20261022-permission-03.xcresult`。
- 原始截图：`/private/tmp/rent-room-map-collapse-20261022/ios-attachments-02/`、`ios-attachments-03/`；截图1178×2556。
- 构建缓存由 runner 按本任务 worktree 分配：`/Volumes/mac2/codex-builds/time-fragment-dd-shared-357a8997fd7cb49447f18397-simulator`。实际执行 slot/lease 在执行时已核实，完成后释放。

当前为待用户批准的组件评审，未合并、真机安装或发布。手机中文输入、真实 GPS，以及房源/上班地址正式页面的保存与重启属于批准后接入验证。
