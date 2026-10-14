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
