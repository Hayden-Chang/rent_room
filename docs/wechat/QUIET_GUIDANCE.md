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

## 待完成的实际界面验收

截至本次准备，三槽池全部因健康检查失败处于隔离状态，仍有常驻进程。按照仓库维护规则保留现场，尚未重启或抢用槽位，尚无当前代码的实际截图及用户视觉批准；PR 保持草稿。

维护恢复后，在共享池租约及隔离数据内执行以下最小场景：

1. 首次新建房源，确认原阶段/筛选/左滑教学和新房源引导可见。
2. 逐项真实点击完成现场 C、D、E，确认没有填写推荐或自动跳动；完成 F 后确认跨阶段提示仍出现，最后完成全部时确认结束提示；重开核对记录。
3. 打开额度不足页，截图确认新文案、按钮可读且没有“小饼干”。成功态仅可用隔离夹具检查布局，不把夹具当作真实支付证据。

旧 `tests/e2e/xiaoda-forward-native.cjs` 等历史验收脚本含同阶段推荐假设，不能用其旧断言验收本需求；恢复工具后需按以上新场景调整所选脚本并实际执行。未运行全量单测、全量 E2E 或真机测试，未合并、上传或发布。
