# 添加影像来源菜单对齐

## 当前验收状态：未通过，待重新对照

2026-10-21 用户在真机更新后明确反馈来源弹层“这个界面不一样”。撤回此前“已对齐”的结论：现有底部菜单仅证明通用组件已接入，功能测试通过不能证明它与微信面板外观相同。后文保留已执行的实现和测试记录，不再作为视觉验收通过依据。

重新读取远程 main `f66f50c20cdcbacbbe8f55b6ebc99a563a3d949d`：此入口仍直接调用 `wx.chooseMedia`，没有对应 WXML/WXSS 自定义来源弹层。当前缺少同一手机上的小程序原生面板截图；不能由 iOS 自身截图或桌面开发者工具外观推定微信 iPhone 面板的文案、顺序、字号、圆角、安全区和间距。取得该对照后再修改组件并展示实测效果。

## 微信开发者工具实际检查（2026-10-21）

按用户要求，将上述 main 的小程序源码导出到本任务忽略目录后独立构建，通过固定三槽池领用 slot 1，使用 Stable 2.01.2510290、基础库 3.17.3 打开测试项目。只创建可丢弃的“影像来源对照”房源，未使用用户业务数据；未模拟 `chooseMedia` 返回结果。

自动化 SDK 查询 `.camera-button` 超时后，改用原生 UI 自动化实际点击清单页的“拍照或录视频”按钮。开发者工具弹出的是 **macOS 原生 Open 文件窗口**，没有展示 iPhone 微信的来源选择弹层。随后实际点击 Cancel，回到清单页，未选择或导入文件。

- SDK 截图 `native-picker-open.png` 只包含背后的清单页面，不能作为手机弹层或 macOS 文件窗口的截图证据。macOS 窗口已通过原生 UI 截图和控件树核对；其中含本机目录信息，不纳入仓库或公开 PR。
- 本次仅证实当前桌面工具的实际行为，以及此入口调用微信原生媒体选择能力。没有获取手机微信面板的视觉基准，也没有修改、重新验收或部署 iOS 菜单。
- 运行编号 `2d7e6564c4264301868c24ebc5fcfb26`；原始日志、截图与 receipt 在 `/Volumes/mac2/codex-builds/wechat-instance-pool/runs/2d7e6564c4264301868c24ebc5fcfb26/`。构建与检查脚本在 `artifacts/wechat-media-reference-20261021/`，均为忽略的本机证据。
- receipt 的 `sourceHead=624c618` 是承载导出源码的任务工作树 HEAD；实际导出的小程序版本为 `f66f50c`，见检查记录 `inspection.json` 的 `source`。不得把两者混用。
- 回调正常退出；池已清理测试数据、关闭测试项目并归还为 idle，常驻开发者工具保留。receipt 的 `passed` 仅表示本次检查流程正常结束，不表示手机 UI 对齐通过。

## 此前实现范围

2026-10-21，用户反馈“添加影像的界面和小程序不一致”。范围是清单、影像页、问题编辑三个业务入口的来源选择层；不改登录、媒体存储或导入规则。

## 差异与修复

小程序 `apps/wechat/src/lib/platform.js` 使用 `chooseMedia`，来源为相册和相机。iOS 虽已有 `MPSourceSheet` / `MPActionMenu` 组件，但业务仍通过旧 `MediaPickerSheet` 显示独立导航页，包含“添加影像”标题、彩色按钮、大小说明及大片留白。

- 三个业务入口均改为透明全屏承载的底部菜单，复用现有组件：两行来源选项、独立取消行、原页面遮罩。点击取消或遮罩收起。
- 来源行使用54 pt行高，取消行与来源组间隔8 pt；不再显示旧标题页和常驻50 MiB说明。大小校验保留在导入逻辑中。
- 系统相册继续使用 PhotosPicker；拍照/录像继续使用 UIImagePickerController。保存等待禁止重复操作，读取/保存失败使用提示弹窗。
- `persist`、图片/视频处理、草稿暂存、账号作用域检查、失败文件清理均未修改。问题编辑打开/关闭来源菜单仍保留草稿。
- 新增 `media.source` 和 `media.add` 无障碍标识，区分模态菜单、影像页与仍留在层级中的清单入口。

本次是已批准菜单样式的业务接入。组件批准不等于整个 App 或所有系统界面的像素验收。系统相册/相机仍是 iOS 系统界面；小程序一次可选9个，而 iOS 当前仍单选，未以此次视觉修复宣称该功能差异已消除。

## 验证经过

工作树 `/Volumes/mac2/projects/git_repo/run_self/rent_room/.worktrees/ios-parity-20261019`，分支 `codex/ios-parity-20261019`。使用 XcodeGen2.45.4、仓库 `scripts/run-xcodebuild.sh` 与共享 Simulator Management runner。模拟器为 iPhone16 / iOS26.5，UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`。测试使用每次独立、可丢弃的测试记录。

| 运行 | 源码与结果 |
| --- | --- |
| `xunju-media-source-20261021-red-01` | 在 `301a947` 原生产源码上加入回归，1 UI按预期失败：导航栏“添加影像”仍存在，截图为旧整页 Sheet。 |
| `xunju-media-source-20261021-green-01` | `4768d07`：4个媒体导入UT通过，问题影像保存/放弃/备注/重启UI通过；另2 UI失败，分别是同名入口选择器冲突、把文字框19.33 pt误当54 pt行高。实际截图已显示新菜单。 |
| `xunju-media-source-20261021-green-02` | `b2b3fff`：三入口菜单及行距断言通过；系统相册取消误选底层菜单“取消”，另一个用例错误预期模拟器无相机，实际已打开系统相机。2 UI失败，原始记录保留。 |

green-02 后对照实际控件树和 Apple 文档修正测试：系统相册使用 `navigationBars["照片"].buttons["Cancel"]`，等待其消失后检查来源按钮可点击；相机检查实际打开的 `DismissImagePickerButton`，或验证不可用提示。未增加固定等待，未修改业务逻辑来迎合断言，也未隐藏失败。

依据（2026-10-21查阅，页面未给出明确更新时间）：[isHittable](https://developer.apple.com/documentation/xcuiautomation/xcuielement/ishittable) 区分控件存在与可点击；[XCUIElementQuery](https://developer.apple.com/documentation/xcuiautomation/xcuielementquery) 支持按父级缩小查询；[UIImagePickerController](https://developer.apple.com/documentation/uikit/uiimagepickercontroller) 要求查询运行时来源能力，不能假定所有模拟器都无相机。

测试计划、命令数组、日志及导出的原始截图保存在 `artifacts/ios-media-source-20261021/`（忽略，不提交）。各运行 `.xcresult` 位于 `/Volumes/mac2/codex-builds/<run-id>.xcresult`；runner receipt 位于 `/tmp/todo-ios-sim-pool/run-receipts/<run-id>.json`。源码生产改动为 `4768d07`、`a070357`（仅新增无障碍标识）；之后至 `32f8418` 只调整两条UI测试。4 UT及问题影像UI的代码与业务路径未再变化，可沿用 green-01 通过证据；不称最终 head 一次运行全部通过。

## 最后结果与证据等价

`xunju-media-source-20261021-green-03` 在 `32f8418e6acb82006c4e588201f22115fa1ede2d` 上2 UI全部通过，0失败、0跳过，runner退出0且租约/slot已释放。实际执行 `testMediaEmptyStateAndSystemPickerCanCancel` 与 `testMediaSourceMenuMatchesMiniProgramFromAllEntryPoints`，合计72.968秒测试方法时间。最终运行验证了真实系统相册取消，以及本次模拟器实际打开相机后的关闭返回；不可用相机的错误分支本轮未触发。

去重4 UT、3 UI均有通过证据（green-01与green-03增量合计）。未运行无关全套或最终PR head合并门禁。`4768d07..32f8418` 生产差异仅两处无障碍标识/容器，不改变存储、导入或草稿路径；因此复用4 UT及问题影像保存UI。之后的文档提交与该源码、测试完全等价。

人工查看三入口原始截图，确认无旧标题页、大段留白及彩色来源按钮，菜单位于底部且原页面保留遮罩。真实截图索引：`/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/ios-media-source/index.html`，原图映射见同目录 `evidence.json`。这些是模拟器截图，不冒充真机画面。没有操作真机相册中的用户影像或进行实际拍摄。

主 agent 已审查相对 `301a947` 的生产增量、测试与上述证据：仅三入口呈现和共用来源层，未改小程序、导入持久化、账号规则或工程配置。PR39继续Draft，不合并、不发布。
