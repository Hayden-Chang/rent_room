# ZIP 房源导入导出

2026-10-15。变更需通过 PR 和实际 UI 审批；本文件描述实现契约，验证结果与最终 SHA 以 PR 为准。

## 用户规则

- 导入只接受本应用当前导出的 ZIP。导出只生成 ZIP；取消 Excel/JSON 入口和模板，不转换旧文件。
- 多套房源进入多选列表，支持全选、取消全选、单套选择；归档房源带标记并可选择。没有选中房源时禁止确认。
- 点击导出先生成 ZIP，按钮变为“发送 ZIP”；再次点击时同步调用微信分享，避免异步生成过程丢失用户点击上下文。取消或发送失败保留当前 ZIP，可直接重试发送；更改选择、离开页面或发送成功后清理，原生分享未结束时延后删除。
- ZIP 包含所选房源的完整检查记录、分组状态、模板快照、自定义项、备注、问题及照片/视频。个人设置与上班地点不迁移。
- 首次导入保留房源 ID 和名称；相同 ID 才视为重复。重复项必须逐套选择覆盖或新增副本，同名不同 ID 独立处理。
- 覆盖整套记录，不合并旧字段，确认前展示目标名称；新增副本使用新 ID 和“（副本）”名称后缀。
- 本次所选房源一次保存，全部成功才生效。文件写入、完整性校验、空间不足、取消或状态保存失败时保留原记录，并清理本次新文件。
- 保存前完成文件准备；旧附件在当前状态或上一份自动恢复仍引用时保留。后续成功导入轮换恢复副本后，可清理已无引用的旧附件。

## 文件边界

`files.js` 使用 fflate 流式 ZIP。`platform.js` 从微信 fd 按 256 KiB 读取并分块写入，预览只解码清单，确认后仅提取所选附件；未选择的媒体使用丢弃 decoder，避免 fflate 将未启动的流全部缓存。

ZIP 清单包含 `format: xunju-backup`、`archiveVersion: 1`、状态版本 2、导出时间、房源及每个附件的大小和 CRC32。导入校验路径、重复条目、引用完整性、所选附件大小/CRC32及 ZIP 结束记录。确认前后清单不一致时拒绝保存。

取消此前 50 MiB 文件/媒体总量和 100 MiB 解压总量门槛。现有拍摄/相册入口的单个影像限制保持原行为。最多 200 套房源及 32 MiB 清单元数据校验仍有效；媒体总量由微信/设备资源决定，不承诺无限大小。空间不足应提示原因；未完成的 ZIP 立即清理，已完成的文件按上述发送/页面生命周期清理。

## 自动测试选择

从 `apps/wechat` 执行，Node.js 24：

```sh
npm run build
npm test -- tests/files.test.js tests/platform.test.js tests/transfer.test.js tests/transfer-page.test.js tests/model.test.js tests/runtime.test.js tests/media-caption.test.js tests/issue-editor.test.js tests/all-node-swipe.test.js tests/broadband-installation.test.js
npm run check
npm run package
```

| 生产边界 | 选择依据 |
| --- | --- |
| 流式编解码、媒体和清单 | files：真实字节、超过原 50 MiB、只提取所选文件、缺失/损坏/截断/非法文件及取消 |
| 文件与持久化事务 | platform、transfer：相机既有行为、ID 冲突、同名不同 ID、覆盖/副本/跳过、混合批次、空间不足、状态保存失败、200 套边界、恢复副本、分享失败 |
| 页面选择和入口 | transfer-page、runtime：构建后 VM 验证多选、重复选择必填、覆盖取消、重复点击、失败重试、离开取消、所有 ZIP 入口 |
| 导入准备和存储消费者 | model、broadband-installation：稳定 ID、保留答案和既有分组迁移，导入保存失败 |
| 媒体与问题关联消费者 | media-caption、issue-editor、all-node-swipe：备注、问题状态、检查项关联、父节点注释和实际影像在 ZIP 导入后保留 |

上述为按影响选择的测试，不运行全部本地单测或全部既有 E2E。VM/mock 验证不等于实际页面点击、系统文件选择/分享或真机证明。

## 实际界面和手机验收

固定池 runner 执行 `apps/wechat/tests/e2e/zip-transfer.cjs`。脚本仅在可丢弃租约中运行；房源及 ZIP 为前置夹具，系统文件选择/分享边界被 mock，选择、模式切换、提交和导航使用可见控件。截图和磁盘断言存入 `WECHAT_ARTIFACT_DIR`，不得把调用 handler 或 setData 冒充交互。

待用户确认实际导入/导出列表、归档标记、覆盖提示和取消流程；iOS/Android 手机另验真实文件选取、微信分享、跨设备 ZIP 导入，以及实际大文件与空间不足体验。实例池不健康时保留失败 receipt，不抢占或重启其他任务的实例；UI 门禁仍未通过。
