# 新建与编辑问题（2026-10-14）

手动问题由标题弹窗改为独立表单。标题必填（去除首尾空白，最多200字），备注选填（最多10000字），影像选填（照片/视频，拍摄或相册，一次最多9个，沿用单文件50MB和视频60秒限制）。列表可重新打开编辑，保留待跟进/已解决状态。归档问题只读。

问题保存 `note`，附件仍在房源 `media` 中，以 `issueId` 关联；不借用检查项的 `fieldId`。房源影像显示所属问题，长按该影像进入所属问题编辑。ZIP完整备份包含问题备注、关联和媒体字节；Excel仍仅交换检查项，未新增手动问题Excel格式。旧的只有标题的问题可正常打开。

选取影像先复制至本机草稿，不写入房源。取消/返回后清理本页新选文件；已保存附件从问题中移除时不立即删除物理文件，以保留上一版恢复能力。保存使用必须落盘的事务；失败回滚房源状态，页面保留标题、备注和影像供重试。返回保护使用微信 `enableAlertBeforeUnload`，页内取消另有确认；系统终止小程序不保证保留未保存草稿。

## 验证证据

源码候选：`9ddb4c2e0376a082abb61c6111241ab9884e5daf`，基线：`750fe4b9c33af85291c3b7f7fc34a3eccf37bd0b`。基线新增测速页面，本次同步时同时保留两个页面注册和导入；同步后重建并重跑下面的最终组合。文档提交不改变业务代码和测试，复用此候选的证据。

Node为24.19.0。以下命令在 `apps/wechat` 执行：

```sh
node scripts/build.mjs
node scripts/check.mjs
node node_modules/vitest/vitest.mjs run tests/issue-editor.test.js tests/platform.test.js tests/files.test.js tests/runtime.test.js tests/media-caption.test.js tests/detail-navigation.test.js tests/speed-test-page.test.js
node node_modules/vitest/vitest.mjs run tests/model.test.js -t 'durable store and migrations'
```

- 新增问题表单/数据：17项，覆盖必填和长度、只写标题、旧问题编辑、归档、取消和回退保护调用、权限拒绝、部分文件复制失败、选择中返回、失败重试、防重复提交、真实字节ZIP恢复与关联。构建包在VM中调用页面处理函数；不是触摸或真实渲染证据。
- 平台与文件：媒体复制和导入导出直接受本次影响。运行现有 `platform`、`files` 文件。
- 详情页消费者：`runtime`、`media-caption`、`detail-navigation`；同步主线后增加 `speed-test-page` 验证共用详情页测速入口。
- store增加可选事务模式：只选 `model` 中 `durable store and migrations` 8项，另12项跳过。
- 最终共68项通过，未运行全量套件。日志：`apps/wechat/artifacts/issue-final.log`、`issue-store-final.log`。
- 官方wcc编译11个模板，wcsc编译9个样式，9页面，总构建1252632字节。产物检查通过，无测试页加入发布包。
- 早期新增测试有一次测试文件括号遗漏，解析失败且没有执行用例；修正测试语法后17项通过。不是产品失败或修复前回归证据。本次是新功能。

## 尚未完成的界面与手机验收

新增最小UI脚本 `apps/wechat/tests/e2e/issue-editor.cjs` 通过页面元素点击/输入验证空标题、新建、编辑回显和落盘，并截图。房源fixture由SDK准备，不把前置准备当作用户流程。

```sh
WECHAT_NODE=/本机/Node24/node python3 scripts/wechat-pool/pool.py --root /Volumes/mac2/codex-builds/wechat-instance-pool run --project "$PWD/apps/wechat/dist" --experimental --wait 30 --timeout 100 -- /本机/Node24/node "$PWD/apps/wechat/tests/e2e/issue-editor.cjs"
```

2026-10-14本次实际调用等待后失败：`No free slot; active/orphan instances were not stopped`。三个槽位为busy-or-quarantined。receipt为 `d7adf99fb5034c78be47805d57f5ffbd`；摘要日志 `apps/wechat/artifacts/issue-pool-attempt.log`。回调未启动，无UI通过/截图证据；没有接管、清理或重启别的任务实例。

真机待验证：系统返回/侧滑确认，软键盘与底部保存按钮，拍照/视频/相册、权限拒绝、保存后重开预览、ZIP恢复。预览码由统一CI租约入口生成，不能代替上述验证。PR保持草稿，UI未经用户确认不得合入或发布。

## 2026-10-14 追加：问题下方直接预览

按手机验收反馈，问题列表在标题/完整备注下方直接显示全部关联附件：照片缩略图点击打开该问题的媒体预览，视频为内嵌原生播放器（不自动播放）。新建/编辑页的视频也改为内嵌播放器。预览区阻止点击冒泡，避免打开问题编辑；归档问题保留只读预览。没有改变媒体文件、关联、存储或ZIP格式。

新增2项回归在旧版本失败：列表无媒体数组、模板无直接预览区域。最初从仓库根运行导致路径错误的记录为 `issue-preview-wrong-cwd.log`，不算回归证据；在正确应用目录运行的行为失败证据为 `issue-preview-before.log`。

修改后重建，`issue-editor`、`detail-navigation`、`media-caption`、`runtime` 共35项通过，日志 `issue-inline-preview.log`；覆盖全部附件归属、点击选中项、无跨问题串图、归档可预览及模板的事件绑定。官方wcc 11模板、wcsc 9样式通过，9页面、1254071字节。上一轮其余测试的对应数据/平台/store/测速源码与测试未改，复用原有证据，不重跑无影响项。测试是VM/模板检查，不能替代实际视频解码和点击操作。

再次检查实例池，3槽仍busy-or-quarantined；本次未重试同一不可用入口。真实照片显示、内嵌视频播放/全屏、预览区域点击与软键盘仍需手机验收。保持草稿PR。

## 2026-10-14 追加：右下角新建问题按钮

用户已明确确认前一版问题表单及下方图片/视频预览“没问题”。本次仅将问题页标题行的新建入口移至右下角，沿用新建影像的52px圆形按钮、阴影、安全区间距，并使用现有紫色加号图标；归档房源仍隐藏新建入口。UI脚本同步使用稳定的 `.add-issue-button` 选择器。

在 `05be493` 上修改详情WXML/WXSS和UI脚本后，重新运行上述 build/check，以及 `issue-editor`、`detail-navigation`、`media-caption`、`runtime` 四个测试文件：35项通过，日志 `apps/wechat/artifacts/issue-floating-button.log`；官方wcc 11模板、wcsc 9样式通过，9页面、1254246字节。业务处理、媒体、存储和数据格式未修改，其余测试复用上一候选证据。此次低影响布局调整没有新增镜像实现的测试。

共享实例池维护通知要求暂缓GUI/SDK测试，本次未使用旧runner启动实例；没有新增实际截图或触摸通过证据。按钮位置待扫码查看，前一版已确认的范围不重复请求批准。保持草稿PR，未合入或发布。

## 2026-10-14 最终验收与主线整合

用户查看 `15e8a34` 对应预览后明确反馈「看了，没问题，合入吧」，确认本次右下角按钮并授权合入。此前表单和直接预览也已确认；这记录为用户验收，不声称新增GUI自动化或Android通过证据。按当前明确授权继续合入，保留工具池维护导致UI脚本未执行的证据限制。

合入前主线前进至 `a7a08b631a1d5fc34bb82dcf2962179f7dc83210`（清单整行左滑、快速短甩及备注键盘避让）。仅详情WXSS尾部追加样式发生文本冲突，解决方式是同时保留问题预览样式和主线note-sheet样式。详情JS/WXML自动组合经审查保留两边逻辑，独立问题页、问题数据规则和已批准的新建按钮行为不变。

组合后从 apps/wechat 重新构建并运行官方检查：9页面、1257678字节，wcc 11模板/wcsc 9样式通过。增量Vitest选择 issue-editor、platform、files、runtime、media-caption、detail-navigation、speed-test-page，以及交叉边界 note-keyboard、field-row-swipe、field-row-events、field-row-swipe-scope，共128项通过；另 model 的 durable store and migrations 8项通过、12项未选。共136项通过，未跑全量。日志为 `artifacts/issue-merge-final.log` 与 `artifacts/issue-merge-store.log`。

本次增加选择的理由：主线更改同一详情页的滚动关闭与备注键盘状态，组件手势事件路由会影响问题列表中的field-row；测试覆盖这些直接消费者，保证组合没有丢失主线行为。新建/编辑/预览的GUI脚本仍因实例池维护未执行，不把VM测试或用户验收记成自动化成功。主 agent 最终审查无阻断发现，用户已确认范围不重复索要批准；仅合入代码，不上传正式版。
