# 精简模式接入与验收（2026-10-24）

需求：[小搭首次见面流程与文案](https://chatgpt.com/space/page_f978312f402881919e066ebe0d9bc4c1)，读取版本 sequence 16，更新时间 2026-10-23T14:51:53.422316Z。此任务仅接入精简模式；继承小搭分支 e46716f 的引导基础，不修改该任务的工作区或 PR。

## 行为与数据边界

- 首次排序后展示左右两种模式的同一门窗示例，默认精简，互斥选择。排序草稿只写入最后确认的模板，选择中断可续接。
- 设置中的模板列表区分勾选与进入编辑。勾选后点击确定才用于之后新建的房源；未确认返回提供更换并退出、不更换并退出、继续选择。恢复原选项不再询问。
- 两套模板各自保存排序和停用项，保存编辑不切换当前模板。已有房源继续使用创建时的快照，不改答案、问题、备注或影像。
- 老设置没有 selectedTemplate 时继续使用详细模式；只有首次模式页预选精简，避免替旧用户修改选择。
- 精简包含 61 个文档确认的统一记录项（现场 53、合同 8），以及保留逐项的基本信息、费用、房东身份与产权、押金退还时间。全模板共 99 个字段，空白房源计数 99；详细模式原 302 个字段、初始适用计数 204 保持不变。
- 合并项直接显示完整说明与精确选项，不提供子项展开。结果、问题标记、备注、影像使用同一个稳定字段 ID；普通备注不创建问题；完成度和问题各计一次。左滑教学定位实际合并项。
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

## 说明直接显示（2026-10-24）

按用户最新要求，说明直接显示在对应检查项或分组标题下方；移除眼睛按钮、相关样式和展开状态。保留原说明全文、选项、问题、备注和影像；没有说明的项不增加内容。

应用代码 SHA e267e6d2e7300976a442bc07f0677342a543d634。field-row 三个源文件及完整渲染回调恢复到 699e86a 的说明直接显示版本；相对 699e86a 的应用源码、构建入口和数据源无差异，因此精简模式与模板流程复用此前证据。取消开关后移除 8 项不再适用的开关用例，保留此前对既有 swipeopen 通知及页面 service 的夹具修正；定向重跑 field-row-events、field-row-swipe、field-row-placeholder、field-row-inline-actions、field-row-swipe-scope，5 文件 / 73 项全部通过。此前旧夹具失败日志仍保留。

重新构建及官方 wcc/wcsc 检查通过，15 页、2,050,119 字节。日志为 apps/wechat/artifacts/simple-mode/description-visible-build.log、description-visible-unit.log、description-visible-compile.log。

从渲染回调选择家电、合同分组和问题备注三个受影响状态。局部回调为 apps/wechat/artifacts/simple-mode/description-visible-render.cjs，run b9b9a2ee3ac342af9ebd805a3cefa1fb 在干净 e267e6d 上通过，3 张截图逐张核对；第 3 槽归还 idle。快照 SHA-256 为 a35046a7e3fd6ba93246df4812464fa1b3f814a7d0e4a69eb2bd0c373451dfe5，与原 13 张流程截图的产物哈希相同。

本地图集 artifacts/simple-mode-20261024/index.html 已恢复说明直接显示：使用本轮 3 张新截图，其余 10 张复用上述相同应用产物的原始截图。delivery-manifest.json 逐图记录来源和哈希，旧眼睛图集已标记废弃。截图为隔离夹具及控制器准备状态的真实渲染，实际点击和用户视觉确认仍待验收；保持草稿，未合并或发布。


## 备注配色与完整左滑区域（2026-10-24）

精简及详细模式共用的 field-row 将用户备注颜色改为 `#3B6CA8`，不改变名称、自带说明、字号、位置和字重，不新增标签或底色。手势监听移到整个 `.field`，范围与问题项红色背景一致：名称、选项、说明、备注、其他输入、影像及内边距都可作为左滑起点。操作栏仍保留原有位置和尺寸。地图拖动保持原边界；普通点击、纵向滚动、只读保护及滑动结束防误触继续有效。

应用代码提交 `8ca12da5e30575d961ec60e497e25296cb664420`；渲染夹具提交 `8f24dee59d96cda4f61b08b7f8806cdbd66c1c1f`。两者间仅为详细模式夹具补齐“已有空调”的前置状态与问题计数断言，应用源码、数据、构建脚本和以下组件用例完全一致，84 项单测与编译证据可复用。

- 修复前对原产物运行 `node node_modules/vitest/vitest.mjs run tests/field-row-events.test.js -t 'whole item area'`，11 项中 6 项按预期失败：从留白、说明、备注、其他输入、缩略图及图片开始滑动无法打开操作栏；其余纵向、只读和普通点击边界通过。日志：`apps/wechat/artifacts/simple-mode/whole-area-before.log`。
- 修复后先构建，运行 `node node_modules/vitest/vitest.mjs run tests/field-row-events.test.js tests/field-row-swipe.test.js tests/field-row-swipe-scope.test.js tests/field-row-inline-actions.test.js tests/field-row-placeholder.test.js`，5 文件 / 84 项通过。映射：实际 WXML 事件路径、手势方向和防误触、整体边界、操作按钮与保存、原生输入焦点。更新原“附件不可滑”的旧用例为“第一次点击收起，下一次点击编辑”。日志：`note-swipe-unit.log`，前缀同上。
- `WECHAT_TEST_DATA_ROOT=xunju-test-simple-note-swipe node scripts/build.mjs` 和 `node scripts/check.mjs` 通过，15 页、2,050,085 字节，wcc 20 / wcsc 21 均退出 0。日志：`note-swipe-build.log`、`note-swipe-compile.log`。
- 新增 `tests/e2e/note-swipe-render.cjs`；最终 run `03163b2ea5fb4e14beaed723bc2b03e9` 在干净 `8f24dee` 上通过，精简/详细模式的普通备注、问题备注和展开操作区共 4 张实际截图。快照 SHA-256 `ebf9d3cd3443bf8dda52f7bbe619169a6720cd00f213c9b180382e41c31e4cd9`。第 3 槽按租约归还 idle。第一轮 `8a66fcf40b844ef49730fbc96244de07` 保留；其详细模式夹具未先确认空调存在，已补齐后重新截取，不属于产品计数修改。
- 图集：`artifacts/simple-mode-20261024/note-swipe/index.html`，来源及哈希：同目录 `delivery.json`。截图及操作区展开由隔离状态/控制器准备，WXML 事件回归验证组件逻辑，不代替原生触摸命中和手机体验。仍保持草稿，等待手机手势与视觉确认；未合并或发布。
