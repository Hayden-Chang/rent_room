# 第六批批准后的业务接入（2026-10-20）

用户明确批准“三列影像、含照片/视频的问题编辑、分类/分组左滑与不涉及”，本批已接入实际页面。基准 main 经 GitHub Connector 再查仍为 `6a07ecd97fe639e594a8cc5690196921cbe5574e`；小程序源码不改动。独立组件审批及原始证据见 [MEDIA_COMPONENTS.md](MEDIA_COMPONENTS.md)。

## 实际行为

- `HouseMediaPage` 复用三列网格，原始顺序、照片/视频筛选、问题/检查项关联标签、独立备注和预览；备注保存后刷新并在重启后保留。归档隐藏添加与空备注“＋”。
- `IssueEditor` 复用已批准编辑组件，实际草稿载入旧标题、备注和影像。新增文件先暂存，保存时通过原始 `writeIssue` 将文字、顺序和关联一起提交；保存失败保留草稿及文件供重试，防重复写入。标题、文件存在/大小、归档与账号变化均校验。
- 取消有修改时先确认。放弃/移除只清理本次草稿新增的文件；原记录、当前磁盘记录或上次保存副本仍引用的文件均保留。引用核对失败时保留文件，不猜测回收。不扫描整个影像目录，也不声明已实现永久删除后的完整垃圾回收。
- 引用核对同时比较规范化目标，拒绝把已保存文件的符号别名当成草稿文件。清理先校验解析后的路径，再只移除自有文件名，不能借别名删除目标。
- `MediaPickerSheet` 共用 JPEG/MP4 转换，输出≤50MiB；取消任务或账号变化拒绝提交并清理未提交输出。问题编辑回调交给草稿，普通房源/检查项影像仍立即调用原 `addMedia`。
- 分类与分组复用已批准标题组件，连接原始备注、问题标记、拍摄目标、统计与折叠。二者共享打开的左滑栏；其他普通字段的统一协调尚未实现。
- 当前 main 停车类“不涉及”是底层“没有”的结果标签，再点一次由原始规则反选；恢复后原费用、备注和问题标记仍在。独立跳过按钮仅服务旧/自定义快照中 `skippable` 为真的分组，不给新清单擅自增加。

## 定向验证

均为共享 runner 的 development 阶段；没有跑全量UT、旧UI套件或最终PR head合并验证。有效通过合计 **19项UT、4条业务UI场景**，来自下表两轮，按实际diff复用，不宣称同一SHA单轮全跑。

| 运行 | 提交 | 结果 |
| --- | --- | --- |
| `xunju-ios-media-integration-20261020-01` | `e5aff8f13de5903729ab1a6ab708f7bbaf8d00ab` | 18UT全过；4UI中3过1失败。费用框实际在底栏后，测试仅用isHittable误判可点击，落到“总结”；层级明确显示summary与选中的总结标签，录屏18秒帧显示费用尚未滚入可见区 |
| `xunju-ios-media-alias-before-20261020-01` | `e1ce806` | 新增别名回归1UT按预期失败2条断言：错误接纳引用文件别名，且清理误删目标；仅操作UUID临时目录，原始结果保留 |
| `xunju-ios-media-integration-20261020-02` | `f054378` | 修复后8项草稿UT全过；2条修改的业务UI全过。测试先用真实滚动将控件完整移入内容区，再操作；未用坐标点击或handler替代 |

19项有效UT的影响映射：

- 新增 `IssueDraftTests` **8方法**：文字及顺序提交/重启、放弃和移除、保存失败/重试/不重复、空标题/缺文件/重复、归档及账号变化、当前和恢复副本引用/损坏保留、旧分组跳过/恢复保留答案备注标记和媒体、符号别名保护。均在02通过。
- 新增 `NativeMediaImportTests` **4方法**：真实JPEG、真实12秒MP4输出、账号变化/取消/无效源清理、只有显式标志加合法UUID才启用测试入口。01通过；`e5aff8f..f054378` 未改该源文件/测试/构建输入，结果等价。
- 受影响 `NativeStoreTests` **3方法**：`testConditionalGroupKeepsHiddenAnswersNotesAndProblemFlag`、`testIndependentIssueFlagFilteringAndCollapsedFormDoNotMutate`、`testManualIssueAndSummaryComparisonPersist`。
- 受影响 `MediaComponentTests` **3方法**：顺序/独行视频、空和连续视频、筛选不改备注关联及顺序；`MediaPathIsolationTests/testGuestMediaResolutionRejectsAnotherScopeSymlink` **1方法**。这7项01通过，后续未改规则、布局计算、类型定义、路径解析或相关测试，结果等价。

4条UI均为 `XunjuUITests/BusinessFlowTests/` 下精确方法：

| 方法 | 通过来源及结论 |
| --- | --- |
| `testHeadingSwipeNotesAbsenceAndRelaunchPreserveDetails` | 02：分类/分组真实左滑、首次点击先关旧栏、问题标记/备注、“不涉及”反选、重启后费用150与备注/标记保留 |
| `testIssueMediaSaveDiscardCaptionAndRelaunch` | 02：真实创建房源/问题、照片和视频导入处理、照片预览/完整视频文件显示、保存/图库关联与备注/筛选/重启、移除后放弃恢复、新问题放弃不出现、归档只读无增删保存 |
| `testManualIssueSaveResolveAndRelaunch` | 01：新编辑页面保存、解决和重启核对。后续仅改清理/引用检查及两个新用例使用的reveal helper；本用例无媒体且不调用helper，文字保存与布局未变，复用通过 |
| `testMediaEmptyStateAndSystemPickerCanCancel` | 01：普通启动不含夹具按钮，真实PhotosPicker呈现/取消、来源关闭后空态不变。后续未改来源UI及此用例；只读和取消流程不进入草稿清理，复用通过 |

测试照片/视频入口只在DEBUG并同时传入 `--business-test <合法UUID>` 与 `--media-import-fixture` 时显示。它把本地JPEG和H.264测试图案交给与真实相册相同的转换、文件写入和业务提交函数；未直接注入媒体元数据或模拟保存成功。普通Debug启动不变，Release忽略标志。它不证明已从系统相册真正选取文件或已通过相机验收。系统相册截图仍是载入状态，仅据此证明呈现与取消。

## 命令与原始证据

固定入口：`python3 /tmp/xunju-ios-20261019/run-review.py <plan.json> --validate-only`，通过后同入口去掉该参数。计划明确列出每个方法的来源与影响，调用当前项目 `scripts/run-xcodebuild.sh`、XcodeGen2.45.4，未提交生成工程或本机配置。

- 工作树：`rent_room/.worktrees/ios-parity-20261019`；Xcode26.6 / iOS26.5；UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`，截图1178×2556。
- `.xcresult`：`/Volumes/mac2/codex-builds/<运行ID>.xcresult`；构建结果同名 `.build.xcresult`。
- workspace专用缓存：`/Volumes/mac2/codex-builds/time-fragment-dd-shared-57d1cd671f68343408c29f9f-simulator`，名称来自共享基础设施，哈希绑定当前工作树。
- 计划/完整日志：`/tmp/xunju-ios-20261019/media-integration-plan-01.json`、`02.json`、`media-alias-before-plan-01.json` 及对应log。
- 持久留存：忽略目录 `artifacts/ios-media-integration-20261020/`，含所有轮次日志、原始附件、失败录屏/帧、receipt、收集脚本和provenance。02最终exitCode为0，runner退出并归还租约。
- 最终12张图直接复制xcresult原PNG，主agent逐张检查，未改图。映射见可视目录 `ios-media-integration/provenance.json`。

## 待完成边界

自动问题原位编辑、问题卡片内嵌影像、检查项44pt缩略图、全清单左滑协调、图库视频时长标签、永久删除/恢复副本的完整文件回收、真实系统选取/相机/文件分享仍待完成。原生微信SDK、StoreKit及服务端购买验证未完成；真实短信/Apple登录需正式配置和后端部署。本轮无新天地图请求、无真机安装、合并、生产部署或发布；PR #39保持Draft。
