# 第六批 iOS 独立组件评审（2026-10-20）

本批状态为 **APPROVED**。用户于2026-10-20明确回复“确认通过，继续业务接入”。前六批批准均有效，不重复索要。最新远程 main 经 Connector 再查仍为 `6a07ecd97fe639e594a8cc5690196921cbe5574e`。小程序源码未修改。

遵循 [ios-ui-component-review-gate](/Users/pc/.agents/skills/ios-ui-component-review-gate/SKILL.md) 的组件先评审、批准后接入要求。独立评审阶段尚未接入业务；批准后的实际接入与验证见 [MEDIA_INTEGRATION.md](MEDIA_INTEGRATION.md)。DEBUG 下仅显式 `--component-review media|issue-media|headings` 进入独立宿主，不读写房源、不打开相册或相机、不发网络请求。

## 对齐范围

| 组件 | 同源尺寸及交互 |
| --- | --- |
| 影像网格 | 三列、缩略图高114pt/圆角12、横间距8/行间距16；关联标签覆盖缩略图底部；备注独立按钮、最小高44、文字13、空备注居中“＋”22；筛选高36 |
| 问题编辑 | 标题48pt/必填/输入限200、备注至少160pt/选填；照片三列104pt/间距10，移除44；视频独占一行190pt、系统原生控件；底栏取消与保存宽度1:2 |
| 问题状态 | 空标题红框校验、保存失败保留草稿、放弃/继续编辑原生确认；选取和保存期间禁用编辑/退出/重复提交，显示对应等待指示；归档隐藏增删与保存，仅保留返回和预览 |
| 分类/分组 | 分类头56pt、分组48pt、标题14半粗、分类统计12及红色问题数；分组选项13半粗、最小44，跳过12常规；跳过隐藏选项/明细但保留值；备注不限两行 |
| 左滑 | 132pt操作栏，每项44pt，复用原标记/备注/拍摄PNG；分类与分组共享当前打开项；打开别行关闭旧栏，标题首次点击先收起操作；只读可折叠和看备注 |

基准文件：`apps/wechat/src/pages/detail/index.wxss` 最终覆盖规则、`pages/issue/index.wxml/.wxss`、`components/field-row/index.wxml/.wxss/.js` 及 `lib/model.js`。原始分组结果值仍为“正常/有问题/没有”，界面显示“是/否/没有”。

宿主使用3张写明“测试图片”的本地JPEG和静音H.264测试图案；图片和视频不是用户记录。视频夹具最终长12秒、160×90/10fps、64580字节，来源命令为 `ffmpeg -f lavfi -i testsrc2=size=160x90:rate=10:duration=12 -c:v libx264 -pix_fmt yuv420p -preset slow -crf 30 -movflags +faststart`。编码内容仅在 `#if DEBUG` 源码内；未执行Release归档或发布。

## 精确验证与失败保留

全部为共享 runner 的 **development** 验证，不是最终PR head合并验证。没有运行全量单测或原有UI套件。有效证据合计为 **6项定向UT与4条独立UI场景通过**，来源提交不同，详见下表；不把历史失败算作通过。

结果根为 `/Volumes/mac2/codex-builds/`，每轮 `.xcresult` 完整名为 `xunju-ios-media-components-20261020-<轮次>.xcresult`，构建另存同名 `.build.xcresult`。

| 轮次 | 提交 | 执行结果及诊断 |
| --- | --- | --- |
| 01 | `4773201` | 6UT通过；4UI中1通过、3失败。网格视觉间距正确，但裁剪图片的AX/交互边界越界；标题左滑未展开；视频控件隐藏，测试未到原生播放动作 |
| 02 | `1fbd3e8` | 4UI中1通过、3失败。忽略子AX元素后未补按钮角色，实际115×114边界正确但类型为Other；截图同时发现“不涉及”被横排压为空白；标题手势优先级尝试未形成有效完整流程 |
| 03 | `3ea044b` | 网格与标题2UI通过；视频1UI失败。2秒短片已到末尾，AX为“已播放2秒、剩余0秒”，测试仍等待暂停。保存日志、层级及录屏末帧 |
| 04 | `b404be8` | 编辑校验/放弃/带影像等待态1UI通过；视频1UI失败。12秒片源正常，录屏确认中央首点已开始播放，脚本却等待“播放”而非“暂停” |
| 05 | `2f5bbee` | 2UI全通过：按实际状态操作原生Play/Pause，随后移除视频/照片、只读；分类/分组独立标记、互斥操作栏、跳过/折叠/只读完整流程 |
| 06 | `facf02c` | 1UI通过：修正plain移除按钮重复变淡，复验校验、文字保留、原生放弃确认、带影像保存/选取等待态及恢复可操作 |

最终通过的4条UI选择器：

- `XunjuUITests/MediaComponentReviewTests/testGalleryThreeColumnsFilterPreviewCaptionAndEmpty`：`3ea044b`，实际3列/114高/8间距，照片预览、备注保存、两类筛选、空态与添加回调。
- `XunjuUITests/MediaComponentReviewTests/testCategoryGroupSwipeSkipFoldAndReadOnlyPreserveSelection`：`2f5bbee`，跳过/折叠不删原值，真实左滑，分类/分组独立标记，备注回调与只读。
- `XunjuUITests/MediaComponentReviewTests/testIssuePhotosInlineVideoRemovalAndReadOnly`：`2f5bbee`，104照片/190视频、实际原生播放/暂停、预览、移除、只读输入/单返回栏。
- `XunjuUITests/MediaComponentReviewTests/testIssueValidationSaveFailureAndDiscardRetainDraft`：`facf02c`，1:2底栏、标题校验、保存失败保留文字、放弃/继续编辑、保存与选取禁用/等待/恢复。

6UT均来源 `4773201`：

- `XunjuTests/MediaComponentTests/testMixedAttachmentsPreserveOrderAndGiveVideosTheirOwnRow`
- `XunjuTests/MediaComponentTests/testEmptyAndConsecutiveVideosDoNotCreateEmptyRows`
- `XunjuTests/MediaComponentTests/testGalleryFiltersDoNotChangeCaptionsRelationsOrOrder`
- `XunjuTests/UtilityComponentTests/testReviewRoutesRequireExplicitKnownDebugArgument`
- `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface`
- `XunjuTests/ComponentLogicTests/testChoiceCanClearAndSwitchWithoutCouplingProblemFlag`

命令、计划、每轮完整日志、原始附件、失败录屏/帧、runner receipt与SHA256均复制到本worktree忽略目录 `artifacts/ios-media-components-20261020/`；scratch为 `/tmp/xunju-ios-20261019/`。每轮先 `run-review.py <plan> --validate-only`，通过后同一入口执行精确选择器；runner调本项目 `scripts/run-xcodebuild.sh`，固定XcodeGen2.45.4。`.xcodeproj`、本机配置、运行附件未提交。

Xcode26.6 / iOS26.5，独占UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`，逻辑393×852，所有截图1178×2556。专用workspace缓存为 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-57d1cd671f68343408c29f9f-simulator`；名称来自共享基础设施，workspace哈希专属于当前worktree。06结束后本任务进程退出0，queue/locks/run-slots均为空，租约已释放。

## 复用依据

独立评审阶段组件代码冻结于 `facf02c24b7adaf8acf4f723ffca6f489a5dac86`，之后本批只有文档变化。

- UT：`4773201..facf02c` 的上述UT文件、`ReviewSurface.parse`、`InspectionSelection`、工程配置、主题和资源均未改变；`MediaTile`、`MediaFilter`、`IssueMediaRows`定义未改变，复用6项通过。
- 网格：`3ea044b..facf02c` 未改变网格/备注编辑组件、图片生成、缩略图/筛选元数据及用例。视频夹具时长改变，但该场景只预览照片，视频仅展示相同图标及元数据，不加载视频帧；其他改动为问题编辑和标题，故复用其2张截图及通过结果。
- 视频/只读：`2f5bbee..facf02c` 只移除busy期间plain按钮重复透明度，并清除宿主问题编辑中旧错误/事件。该用例从空草稿添加影像，错误/事件原本为空，全程busy为false；片源/播放器/测试均未改变，复用其3张截图及结果。
- 标题：`2f5bbee..facf02c` 的标题组件、状态、测试与图片均未改变，问题编辑分支的变化不影响本路由，复用5张截图及结果。

Apple依据：`.ignore`总是创建无初始属性的新AX元素，需补标签和按钮角色，见 [AccessibilityChildBehavior.ignore](https://developer.apple.com/documentation/swiftui/accessibilitychildbehavior/ignore)。标题采用 `PrimitiveButtonStyle` 的 `configuration.trigger()` 将点击与横滑组合，见 [Apple示例](https://developer.apple.com/documentation/swiftui/primitivebuttonstyleconfiguration/role)。播放器使用系统控件，未在屏幕显示期间反复设置 `showsPlaybackControls`，见 [AVKit说明](https://developer.apple.com/documentation/avkit/avplayerviewcontroller/showsplaybackcontrols)。失败与修正是本次观察，不归因为已确认的系统缺陷。

## 独立评审的证据边界与后续接入

本页记录的独立组件证据只证明真实SwiftUI/AVKit渲染和回调。标题校验与保存错误由宿主构造；添加/移除仅改变临时夹具数组，不证明正式问题持久化、文件回收、相册导入或相机拍摄。

批准后已接入三列网格与关联/备注、正式问题媒体草稿/保存/放弃清理及分类/分组原始桥接；业务重启与失败保护验证见 [MEDIA_INTEGRATION.md](MEDIA_INTEGRATION.md)。普通字段与标题的统一手势协调仍待补齐。自动问题行内编辑、媒体关联缩略图、永久删除的物理文件/恢复副本回收、原生StoreKit及微信SDK等仍未完成。真实短信/Apple登录仍需正式配置与服务部署；当前任务、PR均不因此宣称完整交付。

本批没有真实相册/相机/文件分享验收，没有新天地图探测，没有真机安装、合并、生产部署或发布。前五批业务接入和局限见 [UTILITIES.md](UTILITIES.md)。

## 15张实际附件

下方均直接复制 `.xcresult` 导出的PNG，未改图。主agent已逐张检查；原始附件名、测试、提交、尺寸、SHA256映射见本机 `ios-media-components/provenance.json` 及忽略证据目录的同名文件。

| 状态 | 来源 | 截图 |
| --- | --- | --- |
| 48-gallery-three-columns | `3ea044b` | ![48-gallery-three-columns](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-components/48-gallery-three-columns.png) |
| 49-gallery-empty | `3ea044b` | ![49-gallery-empty](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-components/49-gallery-empty.png) |
| 50-issue-title-validation | `facf02c` | ![50-issue-title-validation](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-components/50-issue-title-validation.png) |
| 51-issue-save-failure | `facf02c` | ![51-issue-save-failure](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-components/51-issue-save-failure.png) |
| 52-issue-discard-confirmation | `facf02c` | ![52-issue-discard-confirmation](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-components/52-issue-discard-confirmation.png) |
| 53-issue-photo-row | `2f5bbee` | ![53-issue-photo-row](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-components/53-issue-photo-row.png) |
| 54-issue-inline-video | `2f5bbee` | ![54-issue-inline-video](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-components/54-issue-inline-video.png) |
| 55-issue-readonly | `2f5bbee` | ![55-issue-readonly](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-components/55-issue-readonly.png) |
| 56-heading-progress-and-choices | `2f5bbee` | ![56-heading-progress-and-choices](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-components/56-heading-progress-and-choices.png) |
| 57-heading-swipe-and-flag | `2f5bbee` | ![57-heading-swipe-and-flag](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-components/57-heading-swipe-and-flag.png) |
| 58-heading-readonly | `2f5bbee` | ![58-heading-readonly](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-components/58-heading-readonly.png) |
| 59-heading-skipped | `2f5bbee` | ![59-heading-skipped](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-components/59-heading-skipped.png) |
| 60-issue-saving | `facf02c` | ![60-issue-saving](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-components/60-issue-saving.png) |
| 61-group-swipe | `2f5bbee` | ![61-group-swipe](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-components/61-group-swipe.png) |
| 62-issue-selecting | `facf02c` | ![62-issue-selecting](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-components/62-issue-selecting.png) |
