# 减少清单内引导（2026-10-30）

## 行为范围

- 微信端取消同一阶段（房源、现场、询问签约）内一级检查项之间的填写推荐：现场 C→D、D→E、E→F 不再弹气泡、自动滚动或展开下一项。
- 首次使用的阶段、筛选和左滑教学保留；新建房源、跨阶段和结束引导保留。旧存档中尚未展示的同阶段推荐在进入清单时清理。
- 已有答案、备注、问题标记、媒体、完成历史和折叠状态保留。规则只在微信展示层执行，未修改共享完成度模型或原生 iOS 引导。
- 额度页去掉“小饼干”比喻，改为“主人，您的额度不够了啦，花 ¥1.99 就能增加 10 套房源额度！”，购买按钮为“¥1.99 增加额度”。购买成功标题为“房源额度已增加”；计费和订单确认逻辑未改。

## 定向验证

以下命令在任务 worktree 的 `apps/wechat` 下使用 Node.js 24 执行，构建数据根为可丢弃的 `xunju-test-quiet-guidance-20261030`：

```sh
WECHAT_TEST_DATA_ROOT=xunju-test-quiet-guidance-20261030 node scripts/build.mjs
node node_modules/vitest/vitest.mjs run tests/onboarding.test.js tests/onboarding-wait-position.test.js tests/onboarding-target.test.js tests/onboarding-icons.test.js tests/capacity-runtime.test.js tests/xiaoda.test.js tests/xiaoda-once.test.js
node scripts/check.mjs
```

| 边界 | 选择的测试 | 断言 |
| --- | --- | --- |
| 微信清单引导展示 | `onboarding.test.js` | 精简/详细模式 C→D→E→F 静默，跨阶段及全完成提示保留，首次教学保留；旧推荐清理；答案、备注、问题标记、媒体和折叠状态不变 |
| 保留引导的动画、取消和存储错误 | `onboarding-wait-position.test.js` | fixture 改为“房源基本信息→现场 C”，保留等待后位置恢复、迟到回调、失败重试和重开覆盖 |
| 首次教学定位与图标 | `onboarding-target.test.js`、`onboarding-icons.test.js` | 教学目标与入口保持有效 |
| 额度页 | `capacity-runtime.test.js`、官方编译检查 | 购买、恢复、失败及确认流程；新文案 WXML 编译 |
| 共享引导模型兼容 | `xiaoda.test.js`、`xiaoda-once.test.js` | 微信展示调整未改变共享完成度、去重和关闭规则 |

新增同阶段静默测试在修改前有 3 项预期失败（实际出现 D 推荐）；修复后通过。首次定向执行有 6 项位置用例失败，原因是旧 fixture 假设同阶段 B→C 仍有推荐；将同一位置模型的来源改为房源基本信息，并同步检查所有下游断言后，21 项位置用例通过。原始失败日志保留，不视为产品缺陷。

最终 PR head、完整命令及结果记录在 PR 与本地 `apps/wechat/artifacts/quiet-guidance/`。VM 测试和官方编译不替代实际开发者工具交互。

## 实际界面验收

用户明确授权恢复一个隔离槽位后，通过维护入口恢复第 3 槽。其他槽位未操作；排队、启动失败及首次教学拖动受阻的记录保留。最终执行 `tests/e2e/quiet-guidance-native.cjs`，共享池 run `a3e667d704cf4bb68de4fc4de65d24f3` 通过，源码 HEAD 为 `3962f27ada2c613118456dba54e5d9778abed623`，工作树干净。工具版本为 Stable 2.01.2510290，基础库 3.17.3；结束时完成隔离数据清理及项目关闭，常驻进程保留、槽位归还为 idle。

```sh
WECHAT_POOL_UI_REVIEW=1 WECHAT_NODE=/Users/pc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
python3 /Volumes/mac2/codex-builds/wechat-instance-pool/runner/pool.py \
  --root /Volumes/mac2/codex-builds/wechat-instance-pool run \
  --project "$PWD/dist" --wait 600 --timeout 1800 -- \
  /Users/pc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  "$PWD/tests/e2e/quiet-guidance-native.cjs"
```

精简/详细模式使用各自房源的隔离夹具，含基本信息、现场 C/D/E/F、费用和合同，共 7 个一级项、每项一个可填写字段，未声称完整生产模板验收。SDK 仅设置前置夹具、导航、观察和截图；所有答案、展开和引导按钮由原生可访问性点击触发，没有直接调用被测 handler。

- 新房源引导 → 基本信息 → 现场 C：气泡保留，实际点击可进入目标。
- 完成 C、D、E 后无填写推荐，下一项保持折叠；费用项完成后也不推荐同阶段合同项。没有自动滚动的断言由 VM 测试覆盖，实际 UI 验证气泡与折叠结果。
- 完成 F 后显示进入费用和合同的提示，实际点击可继续；全部完成后显示结束提示，返回列表后重开答案、原有备注和问题标记一致。
- 额度页截图确认完整新文案和购买按钮，无“小饼干”，无溢出。额度 1/1 来自隔离目录响应夹具；已登录按钮仅为展示状态夹具，没有真实登录或支付。

首次教学另有真实阶段截图；阶段/筛选“知道啦”按钮实际点击成功。原生拖动接口两次返回 `noWindowsAvailable`，所以完整首次左滑流程不作通过声明；相应逻辑未修改，并由定向 VM 测试覆盖。失败 run `33be2cd829a14a1ba0d44a412d0a3721` 保留，后来重新领用遇到的健康超时和排队超时也保留。

最终 153 项 VM 单测及官方编译通过于 `466baf4403ea76f61240c245933aee4054aec32a`；到实际 UI head 的唯一差异为独立原生验收回调移除上述不可执行手势前置步骤，业务源码、单测、构建输入、配置及选择器未变，因此复用这些结果。等价检查记录在 `artifacts/quiet-guidance/evidence-equivalence-3962f27.json`，实际截图、assertions、test.log 及 receipt 见 `artifacts/quiet-guidance/native-final/`。本记录的后续更新仅为文档，不改变执行输入。

旧 `xiaoda-forward-native.cjs` 等历史脚本含同阶段推荐假设，本需求以新增专用脚本为验收入口。未运行全量单测、全量 E2E 或真机测试；用户视觉批准仍待确认，PR 保持草稿，未合并、上传或发布。
