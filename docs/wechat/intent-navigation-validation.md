# 意向取消与详情导航按压态验证

日期：2026-10-15。任务分支：`codex/intent-navigation-feedback`；[PR #30](https://github.com/Hayden-Chang/rent_room/pull/30)。

## 行为与范围

- 总结页标题改为“意向”。三个选项保持单选，再点当前选项清空意向并保存。
- 意向修改只同步 `house.decision`，保留备注、检查记录、问题和影像，以及其他面板的渲染状态。
- 意向选项与房源内四个导航按钮使用 `hover-class="none"`，去掉默认灰色按压反馈。主导航是 `app.json` 中的微信原生 tabBar；详情页继续保留独立滚动恢复。
- 仅修改详情页逻辑与模板。未修改模型、存储格式、主导航、主题或设计稿。Figma 对应总结意向选择器与详情底部导航；标题和取消交互按本次用户要求调整。

## 自动回归映射

| 改动边界 | 选择器 | 建立的行为 |
| --- | --- | --- |
| 意向选择/取消与局部更新 | `tests/detail-decision.test.js`（8项，全部新增） | 三项分别选择/取消、重开、互斥、其他数据与面板保留、归档只读、保存失败及重试、文案与按压配置 |
| 四个导航的按压反馈及原有切页 | `tests/detail-navigation.test.js`（9项，新增1项） | 无默认按压态、滚动位置与邻近锚点恢复、快速点击最后一次生效、重复点击、退出隔离 |
| 同页面既有筛选刷新边界 | `tests/detail-filter.test.js`（8项） | 过滤和渲染更新保持局部、重复选择无更新、现有筛选按钮无默认按压态 |
| 构建后页面及共享服务 | `tests/runtime.test.js`（1项） | 无 Node/DOM 环境运行，共用 store、输入/筛选与持久化 |

Node.js `24.19.0`。未运行全量单测或全量既有 UI 测试。

```sh
cd apps/wechat
npm run build
npm test -- tests/detail-decision.test.js tests/detail-navigation.test.js tests/detail-filter.test.js tests/runtime.test.js
npm run check
```

修复前：`before.log` 保存按钮按压配置缺失及无法取消等失败；初次测试夹具缺 `clearTimeout`，修正后重新用 main 原页面打包执行，`before-harness-corrected.log` 中 6 项业务断言失败，包括三选项无法取消、重开后无法清空、整页重绘和未保存取消。夹具错误不计入产品复现。

业务提交 `a714893e2f975968dbc02752cd3f8972c8613e83`，基于 `abe9603741327a0cf81aeac3abbb6f0c91a30427`。main 在首次验证后合入 #25，涉及详情页与 store，已无冲突重放本次提交并重新构建、运行全部所选用例：**26/26 通过**；官方 wcc **11 个 WXML**、wcsc **10 个 WXSS** 通过，主包 **1266787 字节**。

后续提交 `2da8cfd0c5d77a978087b5bcf396d556dd78cb36` 只为同一条 E2E 增加阶段日志、单步超时与初始截图。已检查 `a714893..2da8cfd` 差异：业务源码、单测、生成输入、配置、依赖、Node 环境与单测选择未变，复用上述26项及官方编译结果；更新后的唯一 E2E 单独重跑。其后的本文档修改不影响执行。

本地日志相对于任务 worktree：`apps/wechat/artifacts/intent-navigation/`，最新主线组合结果为 `rebased-build.log`、`rebased-tests.log`、`rebased-compile.log`；原失败与旧 head 日志保留。

## 真实 UI 与交付门禁

新增最小流程 `tests/e2e/intent-navigation.cjs`：真实控件点击三项选择/取消并读取持久化文件，重开核对；连续往返四个标签，按压背景采样与截图。直接写 store 仅建立可丢弃房源前置条件，不作为交互证据。计时包含 SDK 查询耗时，不当作真机输入延迟。

仅通过固定三槽池 runner 领用隔离数据，不接管用户或其他任务实例。工具 Stable `2.01.2510290`，基础库 `3.17.3`，SDK `miniprogram-automator@0.12.1`。

首次 run `9a9431b8e62545bd9ec35eae3bf9257e`：槽2健康检查通过，UI 回调110秒超时，没有截图或交互断言。该次输入为重放前的 `7335ddf`，不作为最终 UI 通过证据。日志保留于共享池对应 `runs/<runId>/test.log`，不是产品断言失败或真实交互通过。

最终 run `31bab8749da243a4bcb0fb7c9ca78f0b` 使用重放后的产物与新增诊断脚本：连接、创建隔离房源、打开详情页及截图均成功；`page.waitFor('.detail-tabs')` 内的控件查询接口15秒无返回，回调失败，尚未执行任何导航/意向点击。断言输出为 `passed:false`、三个结果数组均为空。实际截图 `detail-initial.png` 已由主 agent 用 `read-images` 核对：清单与四个底部标签正常显示，但该静态图不证明灰闪修复或意向取消。该结果定位到自动化控件查询阻塞，没有将其当作产品行为失败或通过。

两次原始 receipt 保存在共享池对应 run 目录；脱敏摘要、日志、断言和截图已复制到本任务 `apps/wechat/artifacts/intent-navigation/<runId>/`。最终 run 的 Git 状态仅多出本文档的未跟踪初稿，运行源码与 `2da8cfd` 一致。未清理用户数据、重启其他任务工具或绕过实例池。

主 agent 已在 PR 创建后另行复核五个代码/测试文件、差异范围、失败/通过证据及检查状态，无新增代码问题；GitHub 未返回该 head 的 PR 工作流运行。尚未取得完整真实 UI、手机体验或用户 UI 确认，PR 保持草稿，不具备合并门禁，未合并或发布。
