# 再等等后恢复原填写位置

日期：2026-10-24。最初复现基线：`be53224e033f7222f4ea8f0aaf0185512218bb4d`。交付前更新到临时集成分支 `997e398db2563c0b1a31d25b895b5f9ad49259ef`，在修复提交 `a2a057e2e44e0b9b9cee3d01c14955431e99603a` 重新构建并验证。

## 临时集成方式

用户指定 [PR #56](https://github.com/Hayden-Chang/rent_room/pull/56) 的 `codex/xiaoda-onboarding-20261023` 为临时开发集成分支。后续 Agent 从该分支建立独立任务分支和 worktree，通过子 PR 合回该分支；不直接向它推送业务修改，不把子 PR 直接合入 main。最终由 PR #56 汇总，现有 UI 审批、测试与发布门禁保留。

本修复分支：`codex/xiaoda-wait-position-20261024`，交付为 [草稿 PR #66](https://github.com/Hayden-Chang/rent_room/pull/66)，尚未合并。

## 原因与修复

A 大项填写一部分后，用户完成 B，小搭按既有规则推荐续写 A。`showFilling` 把气泡插在 A 前，`locateFilling` 立即滚到气泡；原 `waitFilling` 只删气泡，没有保存或恢复 B 的位置。气泡移除还会改变其下方的文档坐标。此问题不涉及推荐排序或答案丢失。

保留已确认的气泡布局及推荐规则。在新推荐首次显示前保存当前字段的稳定锚点与屏幕位置；点“再等等”并成功保存关闭状态后，等待气泡移除，按仍存在的锚点无动画恢复，所有锚点消失时回退到原滚动位置。重复刷新不覆盖原位置。点击“去填写”仍进入推荐目标；继续编辑、切换视图、关闭、隐藏页面、退出或切换账号会使迟到的测量失效。保存失败保留提示与原位置供重试。

## 验证边界

- 新增 `apps/wechat/tests/onboarding-wait-position.test.js`，通过构建后的 App/Page 与生产 store 走 A 部分填写、B 完成、再等等的顺序；布局替身模拟气泡插入和移除、字段坐标及滚动边界。
- 修复前主用例失败：B 字段期望屏幕 top 为 120，实际为 1700。修复后恢复为 120，同时断言答案、筛选、展开和顺序不变，重开不重复提示。
- 覆盖推荐接受、保存失败重试、前方布局变化、已保存推荐进入页面、继续编辑及切页/隐藏/退出/账号切换时取消延迟滚动。
- 影响集为上述新文件及 `onboarding.test.js`、`onboarding-target.test.js`、`detail-navigation.test.js`、`xiaoda.test.js`：分别覆盖位置与失效边界、引导生命周期、推荐目标、清单导航及推荐状态。5 文件 59 项通过；未运行全量测试。官方 wcc 20 / wcsc 21 文件编译通过。保留[修复前失败](wait-position-evidence-20261024/before.log)、[页面入口回归失败](wait-position-evidence-20261024/entry-before.log)、[最新基线测试](wait-position-evidence-20261024/unit-integrated.log)及[官方编译](wait-position-evidence-20261024/compiler-integrated.log)。
- 定向原生点击脚本为 `apps/wechat/tests/e2e/xiaoda-wait-native.cjs`：夹具仅准备前置状态，由真实界面点击 B 最后一项和“再等等”，记录前后字段坐标、截图及重开结果，不直接调用被测 handler。**原生点击验收未完成**：早期字段选择器错误已修复，随后两轮等待点击超时；最新冻结提交的两轮排队分别等待 180 / 300 秒，均因没有空闲槽位而未进入测试。见[尝试记录](wait-position-evidence-20261024/ui-attempts.json)。单测与编译不替代界面或手机验收，用户视觉确认亦待完成。
- 本地日志：`apps/wechat/artifacts/wait-position/`，含修复前失败、入口异步问题的失败及修复后结果。
- PR 创建后主 agent 复核实际 diff、范围及验证证据，未发现新增代码阻断；可见行为门禁仍未通过。基线后来前进到 `6e7a702a18d2b154842ad1632a084c9184493264`，差异仅为 `AGENTS.md` 的 11 行临时集成约定。`git merge-tree` 组合检查退出 0，组合树相对已验证提交也仅有该文档差异，业务代码、测试、构建输入与测试选择等价，无须仅为该文档重跑。之后本 PR 的证据整理也只增加文档与日志。

命令在 `apps/wechat` 执行，Node.js 24.19.0：先构建，再运行 `node node_modules/vitest/vitest.mjs run tests/onboarding-wait-position.test.js tests/onboarding.test.js tests/onboarding-target.test.js tests/detail-navigation.test.js tests/xiaoda.test.js`，最后 `node scripts/check.mjs`。
