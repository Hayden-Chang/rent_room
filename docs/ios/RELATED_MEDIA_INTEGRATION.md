# 第七批批准后的业务接入（2026-10-20）

用户明确回复“确认通过，继续业务接入”。[独立组件](RELATED_MEDIA_COMPONENTS.md)不重复索要批准。业务代码 `93d3da0064b1f7506f08d7a6f8a1605418b7d087`，测试与AX标识校准后 `d7ee2e96e35bb2beb00f68ef8239eb54540f464e`；main仍为实时核对的 `6a07ecd97fe639e594a8cc5690196921cbe5574e`。

## 已接入

- `IssuesPage` 使用已批准的 `ManualIssueCard`：真实问题标题、完整备注、解决状态、照片/视频及影像数。照片预览与原生视频播放不打开编辑器；详情仍使用既有问题草稿保存/放弃保护。
- 清单与自动问题共用 `InspectionFieldRow`，沿用原版answer/choose命令及独立问题标记。选择、输入、备注、拍摄和通勤/测速入口复用同一字段契约。父节点仅显示标题/备注/操作，不生成可写的子答案输入框。
- 普通字段、分类、分组按稳定fieldId筛选关联影像。前三项44pt缩略图和“+n”保留原顺序；全部图库支持实际照片/视频预览、类型筛选和备注持久化。空关联不增加分类/分组间距。
- 归档禁用修改，继续允许查看。读媒体使用既有安全路径解析；本轮未改变存储格式、数据身份边界或删除文件策略。

## 测试与历史失败

共享runner **development**，有效 **9项定向UT、8条业务UI通过**。共执行11次UI，保留首轮3次失败；不是全量测试或最终PR head门禁。

| 运行 | SHA | 结果 |
| --- | --- | --- |
| `xunju-ios-related-integration-20261020-01` | `93d3da0` | 9UT通过，8UI中5通过、3失败，退出65 |
| `xunju-ios-related-integration-20261020-02` | `d7ee2e9` | 仅重跑经诊断的3条UI，全部通过，退出0 |

首轮两条新视频断言错误要求初始存在Play/Pause按钮。实际截图与控件树显示本地视频已经载入，原生控件隐藏；校准为点击可见播放按钮，否则点击真实视频区域，再验证Pause，未改产品播放逻辑。另一条分组重启测试失败时搜索键盘仍显示，脚本直接开始找底部输入；第二轮补充键盘消失的明确条件断言后完整通过。未改变焦点实现，不能仅凭复验推断首次键盘未收起的完整根因。图片/录屏/日志全部保留。诊断时核对了Apple的 [FocusState](https://developer.apple.com/documentation/swiftui/focusstate/) 与 [滚动收键盘](https://developer.apple.com/documentation/swiftui/view/scrolldismisseskeyboard(_:)) 契约，没有因此添加未验证的焦点改动。

复用依据：`93d3da0..d7ee2e9` 仅增加预览/关闭AX标识与修改三个失败UI方法及其新增关闭helper；没有改输入、影像、业务存储、导航或已通过方法。9UT和首轮5条通过UI不调用新helper、也不依赖新预览标识，故证据等价。后续纯文档更新不改变验证源码。

### 精确选择

新增 `XunjuTests/RelatedMediaIntegrationTests/`：

- `testAutomaticAndChecklistShareOrderedFieldMediaNotesAndIndependentFlag`：同源视图、顺序、无关媒体隔离、独立取消标记不删答案/备注/文件、重开恢复。
- `testParentAnnotationsKeepMediaAndNeverBecomeEditableChildValues`：分类/分组独立关联、禁止父节点值写入、归档写保护。
- `testRelatedMediaCaptionWriteFailurePreservesOriginalAndRetryDoesNotDuplicate`：真实磁盘写失败、回滚、原文件保留和重试唯一保存。

受影响既有UT：`NativeStoreTests/testIndependentIssueFlagFilteringAndCollapsedFormDoNotMutate`、`testManualIssueAndSummaryComparisonPersist`；`IssueDraftTests/testSaveFailureRetainsDraftFilesAndCanRetryWithoutDuplication`；`BusinessIntegrationTests/testChoiceCommandRetainsMultipleValuesAndOtherDetailAcrossRelaunch`；`ComponentLogicTests/testChoiceCanClearAndSwitchWithoutCouplingProblemFlag`；`MediaComponentTests/testMixedAttachmentsPreserveOrderAndGiveVideosTheirOwnRow`。

UI精确选择（target均为XunjuUITests）：

- `BusinessFlowTests/testAutomaticIssueInlineEditingRelatedFilesAndRelaunch`：4项真实导入→清单/问题关联→两种预览/播放→全部图库顺序/第4项备注→重启和原位更改；02通过。
- `BusinessFlowTests/testIssueMediaSaveDiscardCaptionAndRelaunch`：原有完整草稿/图库/备注/放弃/重启/归档，新增问题卡片实际照片预览和视频播放且不打开编辑器；02通过。
- `BusinessFlowTests/testHeadingSwipeNotesAbsenceAndRelaunchPreserveDetails`：分类/分组左滑、备注、独立问题、不涉及反选、150费用重启保留；02通过。
- `BusinessFlowTests/testAutomaticNumericZeroAndArchiveReadOnly`：真实问题页输入0、重启、归档禁用；01通过。
- `BusinessFlowTests/testCreateAnswerSummaryAndRelaunchPersistence`、`testManualIssueSaveResolveAndRelaunch`：受影响清单输入/备注、问题状态；01通过。
- `UtilityBusinessTests/testRealGuidePlaceWorkplaceAndCommutePersistAfterRelaunch`、`SpeedBusinessTests/testMobileConsentAutofillsAndPersistsAfterRelaunch`：共享字段提取后的真实导航与保存；01通过。

### 原始结果

入口 `/tmp/xunju-ios-20261019/run-review.py`，计划 `related-integration-plan-01|02.json`（先validate-only）。项目包装脚本核对XcodeGen2.45.4确定性；project.yml未改，不提交生成工程。Xcode26.6 / iOS26.5，租约UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`。独立缓存为 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-57d1cd671f68343408c29f9f-simulator`，名称来自基础设施，哈希绑定本任务worktree。

结果 `/Volumes/mac2/codex-builds/xunju-ios-related-integration-20261020-01|02.xcresult`，构建各另存同名 `.build.xcresult`。两轮均已结束并归还本任务租约，其他项目槽位不操作。计划、完整日志、原始附件、三个失败录屏/最后一帧、receipt与收集脚本留在忽略目录 `artifacts/ios-related-integration-20261020/`。

9张PNG未改图，1178×2556，主agent逐张查看。来源SHA/测试/原附件/尺寸/SHA256见 `/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-related-integration/provenance.json`。

![实际问题卡片播放](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-related-integration/78-business-manual-card-video.png)

![全部关联影像与保存备注](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-related-integration/81-business-related-all-caption.png)

![重启后的自动问题](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-related-integration/82-business-automatic-issue-restored.png)

![归档保留0并禁止修改](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-related-integration/84-business-automatic-numeric-readonly.png)

导入使用双显式参数、UUID可丢弃目录与真实JPEG/H.264→原生导入/落盘路径；不是系统相册/相机取材验收。通勤与测速使用既有显式网络/传输fixture，没有新增天地图请求。真实短信、Apple/微信服务、StoreKit、真机媒体/分享、文件永久回收等仍待完成；未合并、部署或发布。
