# 顶层检查组展开修复

基线：`cb03d735d990668aa412c8e0f703384e3cfb4c95`，分支：`codex/pest-group-expand`。

## 原因与行为

`formView` 无条件移除路径首节点，误把带状态控制的「虫害鼠害」和「隔音与噪音」当成普通分类。虫害组的状态按钮无法显示；旧版未选择时明细为空，基线已允许浏览未选择的明细，但旧记录选择「没有」后仍无法从页面恢复。

保留带控制的顶层节点并复用既有组行。展开外层分类即显示组控件和允许显示的明细，组行可独立收起、重开。普通分类、嵌套组默认状态和答案/统计规则不变；不迁移或删除模板、答案、备注、媒体。

## 验证

- Node 24.19.0，Vitest 5.0.3；依赖从同锁文件的既有 worktree 复制到本任务独立 node_modules，没有共享可写依赖目录。
- 新增虫害展开、已选没有后的恢复、搜索/筛选三个测试在修复前全部因根组控件缺失失败，见 `apps/wechat/artifacts/pest-group/before.log`。
- 增加隔音根组相邻覆盖，以及构建后 Page handler 的虫害收起/重开、重载数据保持测试。VM 使用独立内存文件系统，不接触用户数据。
- 最终选择 15 项通过，19 项未选择，未运行全量测试。命令（应用目录下，以 Node 24 执行）：

```sh
node node_modules/vitest/vitest.mjs run tests/root-group-fold.test.js tests/root-group-runtime.test.js tests/unanswered-group-fold.test.js tests/unanswered-group-runtime.test.js tests/inspection-wording.test.js tests/model.test.js -t 'root|pest|plain categories|unanswered|sofa|not-applicable|normal questions|saved group|functional sink|starts all categories|folding is independent'
node scripts/build.mjs
node scripts/check.mjs
```

选择映射：根路径建树 → 新增根组四项及构建后根组一项；既有嵌套组可见性/状态 → 未选择组四项及构建后沙发一项；复用控件与旧记录 → 问句前三项；分类默认折叠及独立折叠 → model 两项。

构建保持 13 分类、76 topic、303 字段；官方 wcc 8 文件、wcsc 6 文件通过。测试日志位于 `apps/wechat/artifacts/pest-group/final-tests.log`，编译结果位于 `apps/wechat/artifacts/compile-result.json`。最终提交 SHA 另记录在同一 artifacts 目录；提交仅封装已测源码、测试及本记录。

## 验收边界

开发者工具当前入口可读取，但点击导入后桌面控制返回 `noWindowsAvailable`，未能在独立工程完成真实点击或截图。VM handler 通过不等于触摸、渲染验收。待用户核对实际展开效果后才能合入；尚未合并、上传或发布。

待验收步骤：导入本 worktree 的 `apps/wechat/dist`；在隔离测试房源展开虫害鼠害，确认组状态和七个检查项；收起/重开；选择并取消「没有」确认原明细恢复；核对隔音组及普通分类。不得用用户已有房源更改答案来执行测试。
