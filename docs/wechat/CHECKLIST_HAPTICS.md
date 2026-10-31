# 清单震动与 iOS 对齐

2026-10-31。基线 `185fd8ae54744fbeed5272a94f1b348bc89f930e`；已验证代码提交 `b8c7e1bbc2a38469831daef689f77584c0f106f7`。

## 行为

- 对照 `ios/Xunju/Components/MiniProgram/MPChecklist.swift` 的 selection/disclosure 触发点：普通选项、多选、父项选项、无、不涉及，以及手动展开/折叠各请求一次 `wx.vibrateShort({type:'light'})`。
- 选择父项导致自动展开只反馈一次。恢复数据、重新渲染、普通输入、滑动、长按显示操作栏、关闭操作栏和被拦截的点击不触发。
- 只读状态禁止选择反馈，但允许展开/折叠反馈；没有展开状态的标题不反馈。
- API 缺失、同步异常或失败回调均静默处理，继续原有业务操作。没有长震动回退、音效、统计或上传。
- 微信只能映射为 light；不宣称与 iOS selection / soft intensity 0.5 的物理震感完全相同。

## 自动化映射与结果

Node 24.19.0，Vitest 5.0.3。所有命令在 `apps/wechat` 执行，先通过 `WECHAT_TEST_DATA_ROOT=xunju-test-haptics-20261031 node scripts/build.mjs` 构建隔离验证包。

| 变化边界 | 最终选择 | 结果 |
| --- | --- | --- |
| 震动触发、只读、误触、输入静默、API 失败；修改后的组件事件夹具 | `tests/field-row-events.test.js` | 63 通过，其中新增震动用例 17 项 |
| 组件→真实页面→store，详细父项自动展开、精简选项、折叠与重载保留数据 | `tests/checklist-haptics-runtime.test.js` | 2 通过 |
| 原有无选项、父项、跨行关闭与滑动保护 | 下列 6 个精确选择 | 6 通过，52 项未选中 |

```sh
node node_modules/vitest/vitest.mjs run tests/field-row-events.test.js tests/checklist-haptics-runtime.test.js
node node_modules/vitest/vitest.mjs run tests/cost-none.test.js tests/missing-config-none.test.js tests/all-node-swipe.test.js tests/field-row-inline-actions.test.js tests/field-row-swipe-scope.test.js tests/field-row-swipe.test.js -t 'binds the trailing none|uses text input and the trailing none|a heading tap folds|readonly actions stay|a first tap on another item|a swipe finishing'
node scripts/check.mjs
```

最终共 71 项通过，未运行全量单测或 UI 套件。修改前新增震动组为 12 失败、5 通过，失败原因均为预期 light 请求实际为空，见 `before.log`。初版运行时测试错误地假定精简模式含详细模式的分组；修正为精简选项和分类折叠后两种模式通过，保留原失败日志。

官方编译：21 个 WXML、23 个 WXSS，15 页、2,061,818 字节，均通过。编译执行于 `322b9b8`；到已验证代码提交仅 UI 验收脚本变化，`apps/wechat/src`、构建脚本及锁文件 diff 为空，复用该编译结果。

## 真实开发者工具点击

固定三槽池，槽 1，DevTools Stable 2.01.2510290，基础库 3.17.3。测试脚本：`apps/wechat/tests/e2e/checklist-haptics.cjs`。使用生产页面和组件、可丢弃夹具；震动 API 替身只记录调用，点击由 CUA 原生界面输入完成。

```sh
WECHAT_POOL_UI_REVIEW=1 WECHAT_HAPTICS_NATIVE_CLICKS=1 python3 /Volumes/mac2/codex-builds/wechat-instance-pool/runner/pool.py --root /Volumes/mac2/codex-builds/wechat-instance-pool run --project "$PWD/apps/wechat/dist" --wait 120 --timeout 500 -- node "$PWD/apps/wechat/tests/e2e/checklist-haptics.cjs"
```

上述命令从仓库根目录执行。脚本等待 `AWAIT_NATIVE_CLICK`，依次点击虫害鼠害分组的“是”、标题折叠、标题重开；不调用业务 handler 代替被验收操作。启动前的搜索及折叠仅安排夹具。断言同时检查父项选中、页面展开状态、实际渲染子行、三次 light 请求及房源数据不变。

最终 run `c074296635864651bfe15393d3c70a30`：通过，源码状态为空，源提交为已验证代码提交；快照 `e8ee078573f284ccfe0f67dd5a9d857624f91912f4e021343d9265dac2fb4b12`。槽位归还为 idle。

保留的早期记录：`b94b5724d5ff457a9d4e51fc1eb9a6fa` 元素查询超时；`b7172fd8adb544c7bf41c436e4b65094` 首次引导导航抢占测试页面，后增加就绪等待。`11cd468279824e04b228a8df369ad585` 只检查展开和计数，未充分验证实际选中且截图早于渲染，不计入最终 UI 证据；最终脚本已补齐断言。

本机整理证据：`/Users/pc/.codex/visualizations/2026/10/31/01a19265-5fa3-7073-9852-e950fcd0e0c4/wechat-haptics/`。包含最终截图、断言、脱敏回执摘要、最终两组测试日志、编译日志及早期失败日志。原始池日志仍在对应 run 目录。

## 验收边界

最终截图确认选中及重开后保留备注和问题标记；不是全应用视觉审计。开发者工具仍显示警告/错误计数和既有“影像 undefined”文案，本任务不宣称控制台无错误或完整产品验收通过。

物理马达震感、不同 iPhone/Android 的轻震支持和用户体验确认尚未完成；尚未合并、上传体验版、提审或发布。本记录为验证后的纯文档补充，不改变生产代码、测试、生成输入或选择集。
