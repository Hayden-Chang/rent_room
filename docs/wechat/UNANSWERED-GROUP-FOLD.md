# 未选择分组的独立展开与折叠

2026-10-13，基于 `e7405702d30bd190690441d9819674e73dafeb08`。

沙发等存在性分组未选择答案时，页面原先只切换箭头，明细仍被存在性条件隐藏。现在仅清单视图使用 `includeUnanswered`，允许查看、搜索和筛选尚未确认存在的对象。统计、问题汇总、对比和批量填写继续使用原有默认条件；展开不填写答案、不改变完成数量。明确选择「没有」「不涉及」以及转租许可的条件保持不变。

## 回归与影响映射

- `unanswered-group-fold.test.js`：24 个可见存在性分组展开／折叠／再展开，选择与统计不变；沙发搜索和未记录筛选；备注、影像保留；取消「没有」后恢复；实际填写子项确认存在；不涉及和许可条件。
- `unanswered-group-runtime.test.js`：构建后的 App/Page 在 VM 中执行折叠 handler，沙发四个子项随展开状态显示，选项和统计不变，保存重载后仍无隐式答案。
- `model.test.js` 精确选择默认折叠、存在性统计、跳过、许可、筛选、独立折叠、对比用例，覆盖共享入口的默认调用者。
- `inspection-wording.test.js` 精确选择分组标题、历史分组状态、水槽记录保留，覆盖视图与旧状态兼容。

修复前，在本任务 worktree 临时使用基线的两个模型源文件并重新构建，运行最终新增测试：4 项因子项不可见而失败，1 项边界保护通过。随后恢复修复源码并重新构建。原始输出保存于 `apps/wechat/artifacts/unanswered-group-fold/before-final-tests.log`。

使用 Node.js 24.19.0，从 `apps/wechat` 运行：

```sh
node scripts/build.mjs
node node_modules/vitest/vitest.mjs run tests/unanswered-group-fold.test.js tests/unanswered-group-runtime.test.js tests/inspection-wording.test.js tests/model.test.js -t 'unanswered|sofa|not-applicable|normal questions|saved group states|sink group|starts all categories|presence changes|skippable groups|permission control|folding is independent|OR filters|compares 2-3'
node scripts/check.mjs
```

结果：15 项通过、14 项未选；未运行全量单测或 UI 套件。官方 `wcc` 检查 8 个 WXML、`wcsc` 检查 6 个 WXSS 成功。输出保存在 `artifacts/unanswered-group-fold/final-tests.log`、`final-compile.log`；提交 SHA 记录在同目录 `validated-head.txt`。本地依赖独立复制自锁文件一致的已有安装，无依赖或锁文件变更。

## 验收边界

VM handler 测试不代表真实点击、渲染或触摸命中。开发者工具当前运行另一任务的 `detail-tab-state` 工程；尝试独立导入本工程时，入口窗口变暗但未显示可操作的导入面板，未成功打开本次构建，也未获得实际运行截图。没有清理用户数据或改动其他任务源码。

实际 UI 待验收：用独立测试房源展开「卧室与家具收纳」，在沙发选项均未选中时点击标题连续展开／折叠／再展开，核对四个子项与未选状态，并检查搜索和未记录筛选。UI 证据及用户确认未取得，PR 保持草稿，未合并、未上传或发布。
