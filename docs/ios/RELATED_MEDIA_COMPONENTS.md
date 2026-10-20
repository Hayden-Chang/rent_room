# 第七批：问题卡片与关联影像独立评审（2026-10-20）

状态 **REVIEW_READY，等待用户确认**。前六批均已批准，第六批已接入实际业务，19项定向UT/4条业务UI证据见 [MEDIA_INTEGRATION.md](MEDIA_INTEGRATION.md)，不重复请求批准。本页第七批尚未接入业务页面。

遵循 [ios-ui-component-review-gate](/Users/pc/.agents/skills/ios-ui-component-review-gate/SKILL.md) 的明确要求：

> Do not integrate it into the complete page or continue the downstream business flow before approval.

当前仅DEBUG且显式 `--component-review issue-cards|field-media` 进入独立宿主，使用本地写明测试图片的JPEG及既有12秒H.264测试图案。该分支不创建AppWorkspace、不读取用户房源/Keychain、不打开系统选择器或发请求。普通Debug/Release仍使用已批准的业务页面。未执行Release归档。

## 新组件与同源契约

基准：当前main `6a07ecd` 的 `pages/detail/index.wxml/.wxss`、`components/field-row/index.wxml/.wxss`。

| 范围 | 实现与验证 |
| --- | --- |
| 手动问题卡片 | 长标题14半粗、问题解决状态、完整多行备注、无影像卡片、含影像数量的详情入口。照片三列96pt/圆角8/间距8；视频独行190pt。照片预览、状态切换和详情回调互不误触；原生视频播放/暂停不触发打开问题 |
| 关联缩略图 | 44×44/圆角6/间距6，最多前三项，视频文字“▶ 视频”，额外“+n”显示全部。照片/视频预览及全部图库真实呈现；全部与缩略图保留同一顺序 |
| 自动问题内容 | 分类文字及已批准的选项/输入/备注组件组合；示例正常/有问题/没有底层值不变。实际输入、备注编辑及只读切换均验证。示例内容只在宿主内存变化，不证明房源保存或自动问题列表刷新 |
| 只读 | 解决、选项、输入禁用，仍允许影像预览及查看详情；保留已选值、原输入和备注，不通过切换状态清空数据 |

`RelatedMediaSurface.swift` 为可复用组件；`RelatedMediaReviewHost.swift` 是DEBUG独立组合，不调用store。尚未把卡片/缩略图/自动问题原位编辑接到 `IssuesPage`、`ChecklistPage`。图库已有预览/备注组件仅复用其显示和回调，不把回调当成完整业务验收。

## 定向测试与失败记录

均为共享runner的 **development** 阶段。有效 **2UT与2条独立UI场景通过**，来自下列SHA；合计4次UI执行，保留2次失败。没有运行全量UT、旧UI套件或最终PR head门禁。

| 运行ID后缀 | 提交 | 结果 |
| --- | --- | --- |
| `related-components-20261020-01` | `08965d8` | 2UT通过；卡片UI通过，缩略图UI停在尺寸精确相等断言：实际44.0×43.99999999999997pt。后续操作未执行，原录屏保留 |
| `related-components-20261020-02` | `4544eef` | 尺寸改为0.5pt容差后通过；照片/视频预览、全部图库及选项继续执行。输入后为“0150”，脚本错误假定中心点点击总把光标移到末尾并期待“1500”，场景在此失败，后续备注/只读未执行 |
| `related-components-20261020-03` | `c19baa653166e8d5c4c337563e73232e2ec367ea` | 完整关联影像UI通过：尺寸、两种预览、全部图库同顺序、选项、精确输入“0150”、备注保存及只读保留/禁用全部执行；修正宿主全部图库与缩略图顺序，并新增顺序断言 |

精确方法：

- `XunjuTests/UtilityComponentTests/testReviewRoutesRequireExplicitKnownDebugArgument`：新增路由仅显式参数识别，未知/缺失参数忽略。
- `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface`：原守卫兼容性。
- `XunjuUITests/RelatedMediaReviewTests/testManualIssuePhotosVideoResolveOpenAndReadOnly`：96高、8间距、三列同排、真实照片预览、原生Play/Pause、播放不误开问题、解决/详情回调、空卡片和只读。01通过，3张图。
- `XunjuUITests/RelatedMediaReviewTests/testRelatedThumbnailsMoreAndAutomaticIssueInlineEditing`：03完整通过，4张图。

复用依据：`08965d8..c19baa6` 只改第二条UI的尺寸/光标观测和顺序断言，以及宿主关联影像分支的数据顺序；卡片组件、卡片分支、第一条UI及其helper、两项UT/路由枚举、主题、工程及片源均未改。手动卡片流程不进入“全部关联影像”sheet，故复用其通过与3张图。第七批未改第六批业务源码及测试；新组件只由显式评审路由引用，普通业务的19UT/4UI证据仍等价。

两次失败之后在继续前核对官方编辑契约：[selectedTextRange](https://developer.apple.com/documentation/uikit/uitextinput/selectedtextrange) 将零长度范围定义为插入点，API可用于iOS3.2及以后；[系统选区交互](https://developer.apple.com/documentation/uikit/adopting-system-selection-ui-in-custom-text-views) 说明标准UITextField使用系统UI（文章讨论iOS17引入的系统交互）。两者适用于本次iOS26.5输入控件。具体光标位置和“0150”来自本轮实际录屏/断言，不能据此声称所有点击或系统版本都会前插。保留输入逻辑，用精确结果验证插入和只读不丢字符。

## 原始证据

完整运行名前缀 `xunju-ios-`，上述每轮结果为 `/Volumes/mac2/codex-builds/xunju-ios-related-components-20261020-<轮次>.xcresult`，构建另存同名 `.build.xcresult`。固定入口 `/tmp/xunju-ios-20261019/run-review.py`，先 `related-components-plan-<轮次>.json --validate-only` 再执行；每份计划含精确方法、来源和影响理由。

Xcode26.6 / iOS26.5 / XcodeGen2.45.4；UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`。workspace专用缓存仍为 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-57d1cd671f68343408c29f9f-simulator`（共享基础设施的旧名称，哈希绑定本任务）。03进程退出0，queue/locks/run-slots为空，租约已归还。

所有轮次计划、完整日志、原始附件、失败录屏/最后一帧、receipt和收集脚本已留在忽略目录 `artifacts/ios-related-components-20261020/`。7张PNG直接复制xcresult原图，1178×2556，未改图；主agent逐张检查。SHA/测试/原附件/尺寸/SHA256见下方目录的provenance.json。

| 状态 | 实际截图 |
| --- | --- |
| 手动问题含三图与视频、无影像卡片 | ![手动问题卡片](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-related-components/71-manual-issue-card-photos-video.png) |
| 原生视频播放 | ![视频播放](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-related-components/72-manual-issue-native-video.png) |
| 手动问题只读 | ![手动问题只读](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-related-components/73-manual-issue-card-readonly.png) |
| 关联缩略图与自动问题组合 | ![关联影像与自动问题](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-related-components/74-automatic-issue-related-thumbnails.png) |
| 关联视频预览 | ![关联视频预览](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-related-components/75-related-video-preview.png) |
| 全部关联影像同顺序 | ![全部关联影像](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-related-components/76-related-all-media.png) |
| 修改后只读保留 | ![自动问题只读](/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-related-components/77-automatic-issue-readonly.png) |

业务接入与重启/失败保护须在批准后验证。全清单统一左滑、图库时长、永久删除的文件回收、原生StoreKit/微信SDK、真实短信/Apple及真机/系统媒体/文件分享仍待完成。本批没有新增天地图请求、真机安装、后端部署、合并或发布。
