# 楼道标题修正（2026-10-22）

将 `topic_14` 的上级检查标题显示为“楼道状况正常”，保留 `f14_0` 的“楼道卫生正常”。分组源名称为“楼道状况”；正常问句由现有规则生成。只修改源树对应标题及旧房源模板的显示投影，分组/字段 ID、顺序、问题、备注、媒体和已存模板快照不变。

## 验证与范围

- 生产代码基准 main `f66f50c20cdcbacbbe8f55b6ebc99a563a3d949d`，首个实现 SHA `30d07d158b5004b68f77d2a0cb20910d2ea03063`，Draft PR #43。
- `WECHAT_TEST_DATA_ROOT=xunju-test-corridor-20261022 npm --prefix apps/wechat run build` 通过。字段数仍为 302；源树 JSON 仅一处标题变更，生成 topics 仅对应 topic title 和 path title 两处变更。
- `npm --prefix apps/wechat test -- tests/inspection-wording.test.js`：5/5 通过；新增用例覆盖新/旧模板、分组/子项区分、字段 ID/顺序、搜索及整个房源 JSON 不变。其余用例复用同一显示投影检查。没有全量测试。
- 初版新增测试将楼道子项数误写成4，实际源码为3（卫生、异味、照明）。按源码修正测试预期后通过；没有增删产品字段，不将此测试维护错误记为产品缺陷。
- 主 agent 已在 PR 建立后独立检查 Connector diff 与本地 source、生成关系、用例和验证范围；无额外代码发现。远程 statuses 返回空，不代表 CI 通过。

## 实际界面与限制

界面检查严格通过共享微信三槽池，构建使用独立数据根，未读取/清空用户房源。工具版本 2.01.2510290，基础库 3.17.3。所有尝试冻结的 dist SHA-256 均为 `d69610811e12707e09282612233afcd0ddb2f765ef32f11ac4f68f1a9d2d2e41`。

- `af3127553c314d6788a366ca6fda5971`：回调无分步日志超时，无通过证据。
- `2af25b1e54b74ad79cc7b432178e901f`：补充分步日志和RPC超时边界，确定已连接、准备旧模板并导航；在 `page.$` 搜索输入元素的 RPC 超时，未达到标题观察，无通过证据。
- 将驱动改为 `tests/corridor-title.render.cjs`：生产搜索 handler 仅准备渲染前提，通过应用侧真实布局查询与 simulator screenshot 验收标签。它不声称原生输入/点击/手势 E2E。
- `b2a7d3ffe86f46d4a638776c89b5f802`：渲染回调尚未启动，实例连接重置，runner 自动隔离槽2；未重启工具、删锁或接管其他槽。
- 后续相同渲染检查由 runner 排队选择健康槽，最终结果见 PR 最新说明。

原始证据在 `/Volumes/mac2/codex-builds/wechat-instance-pool/runs/<run-id>/`。定向测试日志在本 worktree 的 `artifacts/corridor-title/wording.log`。未发布、未提供真机证据。截图或用户视觉批准缺失时保持 Draft，不称为验收完成。

最终池尝试 `4568fd5f4ffd4d9083fc8764c6d9773a` 排队后取得槽1，但在回调启动前的 health 检查失败，槽1也自动隔离。最终三槽没有可用实例；不再重复提交或修复共享基础设施。**小程序实际渲染及截图仍 BLOCKED，转换后的 render 驱动尚未执行，不能声明 UI/E2E 通过或 merge-ready。** 未运行官方编译器、原生输入/点击/手势或真机验收。

初次文案测试来源为提交前相同源码；首个提交只保存这些字节。后续仅替换本机界面验收驱动并追加本文，生产源码、源树、生成 topics 和 Vitest 用例未改，5项UT证据可等价复用，不把原日志改称来自后续 SHA。主工作区、iOS开发分支及其他任务的工具进程均未被修改或退出。
