# 精简模式接入与验收（2026-10-24）

需求：[小搭首次见面流程与文案](https://chatgpt.com/space/page_f978312f402881919e066ebe0d9bc4c1)，读取版本 sequence 16，更新时间 2026-10-23T14:51:53.422316Z。此任务仅接入精简模式；继承小搭分支 e46716f 的引导基础，不修改该任务的工作区或 PR。

## 行为与数据边界

- 首次排序后展示左右两种模式的同一门窗示例，默认精简，互斥选择。排序草稿只写入最后确认的模板，选择中断可续接。
- 设置中的模板列表区分勾选与进入编辑。勾选后点击确定才用于之后新建的房源；未确认返回提供更换并退出、不更换并退出、继续选择。恢复原选项不再询问。
- 两套模板各自保存排序和停用项，保存编辑不切换当前模板。已有房源继续使用创建时的快照，不改答案、问题、备注或影像。
- 老设置没有 selectedTemplate 时继续使用详细模式；只有首次模式页预选精简，避免替旧用户修改选择。
- 精简包含 61 个文档确认的统一记录项（现场 53、合同 8），以及保留逐项的基本信息、费用、房东身份与产权、押金退还时间。全模板共 99 个字段，空白房源计数 99；详细模式原 302 个字段、初始适用计数 204 保持不变。
- 合并项显示完整说明与精确选项，不提供子项展开。结果、问题标记、备注、影像使用同一个稳定字段 ID；普通备注不创建问题；完成度和问题各计一次。左滑教学定位实际合并项。
- 退房只含“押金退还时间”“退房保洁费用和要求已确认”，顺序固定。“入住前房东重新做卫生”在该组外。删除文档指定的合同分支与家具家电齐全项。
- 混合模式房源可对比；只属于另一模板的项显示“不涉及”，不伪造详细子项答案。ZIP 保留模板快照及关联媒体。

## 来源与生成

路径相对于 apps/wechat：

| 文件 | 职责 |
| --- | --- |
| data/source-tree.json | 详细清单真源；精简保留的逐项字段也从这里取得 |
| data/simple-checklist.json | 精简标题、说明、选项及 Page 块来源；simple_01 至 simple_61 是稳定 ID，调整文案不重新编号 |
| scripts/simple-core.mjs | 保留、合并和删除规则；检查源数据格式 |
| scripts/build.mjs | 同时生成详细与精简清单 |
| src/lib/simple-topics.json | 生成文件，禁止手改 |
| lib/model.js、store.js、templates.js | 模式选择、房源快照、统计、对比与校验 |
| pages/welcome、templates、template-edit | 首次选择、独立模板编辑和未确认退出 |
| tests/e2e/simple-mode-render.cjs | 隔离数据的真实开发者工具渲染与明确标注的协议探测 |

## 定向验证

环境：Node 24、Vitest 5.0.3、微信开发者工具 2.01.2510290、基础库 3.17.3。隔离数据根 xunju-test-simple-20261024。主工作区、用户数据和其他槽位不改动。

| 影响边界 | 测试文件 |
| --- | --- |
| 精简内容、独立快照、旧记录、合并计数、查询/对比、ZIP、无效输入 | simple-mode.test.js |
| 构建后的首次选择、模式续接、编辑隔离、未确认退出、实际磁盘写入失败 | first-meeting-runtime.test.js |
| 共享模型、完成推荐、教程锚点 | model.test.js、xiaoda.test.js、onboarding.test.js、onboarding-target.test.js |
| 模板折叠、字段左滑、筛选、导航 | template-fold.test.js、field-row-swipe.test.js、detail-filter.test.js、detail-navigation.test.js |
| ZIP/导入、保留费用 | files.test.js、transfer.test.js、parking-recurring-cost.test.js、cost-phase.test.js |
| 构建配置 | auth-build-config.test.js、map-build-config.test.js |

87d2461 的 16 个文件 / 154 项通过；349a288 增加 ZIP 字节回读与真实保存失败；cbe742f 完成模板退出确认和示例排版，重跑两个新增/修改测试文件，22 项通过。当前共 158 项不同用例。87d2461 到 cbe742f 的源码差异只涉及 welcome/templates 页面，模型、构建、字段组件及其他测试没有变化，故复用其余 14 个文件的通过证据；不运行全量套件。

应用代码验证 SHA：cbe742f047fb8b111495ad02b292d324130d3186。官方编译 wcc 20 文件、wcsc 21 文件均退出 0；15 页、2,050,119 字节。原始日志在本 worktree 的 apps/wechat/artifacts/simple-mode/，包括 unit.log、extra-unit.log、final-unit.log、build-final.log、compile-final.log。

命令（从 apps/wechat 执行；本机 Node 使用固定绝对路径）：

```sh
WECHAT_TEST_DATA_ROOT=xunju-test-simple-20261024 node scripts/build.mjs
node node_modules/vitest/vitest.mjs run tests/simple-mode.test.js tests/first-meeting-runtime.test.js tests/model.test.js tests/xiaoda.test.js tests/onboarding.test.js tests/onboarding-target.test.js tests/template-fold.test.js tests/field-row-swipe.test.js tests/detail-filter.test.js tests/detail-navigation.test.js tests/files.test.js tests/transfer.test.js tests/parking-recurring-cost.test.js tests/cost-phase.test.js tests/auth-build-config.test.js tests/map-build-config.test.js
node node_modules/vitest/vitest.mjs run tests/simple-mode.test.js tests/first-meeting-runtime.test.js
node scripts/check.mjs
WECHAT_NODE=/Users/pc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node python3 /Volumes/mac2/codex-builds/wechat-instance-pool/runner/pool.py --root /Volumes/mac2/codex-builds/wechat-instance-pool run --project "$PWD/dist" --wait 300 --timeout 180 -- /Users/pc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node "$PWD/tests/e2e/simple-mode-render.cjs"
```

## 实际渲染与未完成验收

- 首次 run 4c5d9e77a783445c838f3dc2507a3dc2 在首次 reLaunch 失败，没有产生截图。测试改为等待应用首次重定向完成，并用 switchTab 进入设置；未修改生产导航以绕过失败。
- run 6c81688165e94010a7441709bfae0c7b 在干净提交 349a288 上得到 12 张实际截图。Page 元素查询 8 秒无响应，interaction-failure.json 保留原始错误，没有真实点击通过的声明。
- 最终 run fab73617fc5243d59d437426d674ec29 在干净提交 cbe742f 上通过，13 张截图已逐张检查。冻结产物 SHA-256 为 a35046a7e3fd6ba93246df4812464fa1b3f814a7d0e4a69eb2bd0c373451dfe5；第 3 槽归还 idle，常驻进程保留。图集为本 worktree 的 artifacts/simple-mode-20261024/index.html，delivery-manifest.json 记录每张原始 PNG 的尺寸、SHA-256 和来源。
- 截图使用隔离夹具、直接控制器调用和真实微信渲染；不能代替点击、返回手势、拖动、左滑或真机验收。本轮没有重试已知无响应的 Page 点击协议。

草稿交付，未合并、未部署、未发布。真实交互及用户视觉确认完成前不声明可合并。合入依赖小搭 PR #56；最终集成者应核对当时的基分支组合与受影响验证。
