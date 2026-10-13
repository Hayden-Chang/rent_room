# 清单展开与隐藏条件专项排查

2026-10-13，在 `codex/pest-group-expand` 上继续检查；本记录接续 [虫害修复记录](PEST-GROUP-FIX-20261013.md)，其中 15 项测试是前一阶段结果。

## 发现与修复

| 位置 | 原因及影响 | 本地处理 |
| --- | --- | --- |
| 虫害鼠害 | 路径首节点被当作普通分类剥除，根检查组控件不可达 | 保留受控根节点；展开显示控件和七项明细 |
| 隔音与噪音 | 同一根节点问题，整组是/否控件遗漏 | 同一修复覆盖；六项明细与独立折叠验证通过 |
| 宽带条件 | 所有明细前提未满足，纯结构标题仍可展开，结果为空 | 无可显示明细也无可操作子组的结构标题不显示；宽带选择没有后显示；保存内容保留 |
| 清单模板搜索 | WXML 用搜索词强制展开，覆盖用户点击的折叠状态；箭头与显示状态可能不一致 | 每个搜索结果分类独立折叠；新关键词默认展开；清空搜索恢复普通视图的折叠状态 |

没有把权限、没有或不涉及等合理隐藏条件强行移除。带控件的组即使隐藏明细，也保留控件以便用户恢复。普通分类默认折叠、条件和已有答案不因浏览而改变。

## 范围与证据

源清单共 13 分类、77 个唯一路径节点、55 个受控分组、76 个 topic、303 个字段。受控根节点只有隔音与噪音和虫害鼠害两处。

新增数据驱动审计：55 个分组逐一核对控件可达、折叠/重开、适用的没有/不涉及/权限切换；76 个 topic 逐字段核对满足前提后在分类和搜索中可达，折叠分类后隐藏，浏览不改写房源。权限控制字段通过组控件测试而非重复字段行验证。另测宽带条件，以及二房东/中介分支的隐藏、恢复和附件保留。模板两项测试使用构建后 Page、模拟 setData 和实际 WXML 展开表达式，不把它当作真实页面点击。

修复前：宽带空标题测试失败，其他首批 131 项审计通过；模板两项测试均因搜索结果无法收起失败。日志为 `apps/wechat/artifacts/pest-group/audit-before.log`、`template-before.log`。前次虫害三个失败用例保留于 `before.log`。

修复后：第一批 153 项通过，随后仅新增两项条件分支测试并分别通过，总计 155 项。后续新增测试未改动源码、构建输入、已有用例或环境，因此保留前 153 项证据；没有重新运行无关用例或全量套件。日志为 `audit-final.log` 和 `conditional-final.log`。

Node 24.19.0，Vitest 5.0.3；命令在 `apps/wechat` 执行：

```sh
node scripts/build.mjs
node node_modules/vitest/vitest.mjs run tests/template-fold.test.js tests/group-visibility-audit.test.js tests/root-group-fold.test.js tests/root-group-runtime.test.js tests/unanswered-group-fold.test.js tests/unanswered-group-runtime.test.js tests/inspection-wording.test.js tests/model.test.js tests/detail-filter.test.js -t 'root|pest|plain categories|unanswered|sofa|not-applicable|normal questions|saved group|functional sink|starts all categories|folding is independent|controls remain reachable|exposes every eligible detail|hides the empty broadband|template|filter selection|multi-select filters|phase and search'
node scripts/check.mjs
node node_modules/vitest/vitest.mjs run tests/group-visibility-audit.test.js -t 'hides and restores its conditional branch'
```

影响映射：`formView` 的根路径和空结构过滤 → 新增数据审计、root/unanswered group 模型及构建后 runtime、既有问句控件/默认折叠/模板快照、detail-filter 中筛选提交/清除/阶段搜索三项；模板展开视图 → template-fold 两项。第一批命令有 23 项未选择，第二批只选择新增两项。

构建仍为 13 分类、76 topic、303 字段；官方 wcc 8 文件、wcsc 6 文件通过。当前构建后的生产代码此后未修改。最终提交 SHA 记录在 `apps/wechat/artifacts/pest-group/audit-validated-head.txt`。

## 待验收与交付边界

自动化证明模型、Page 局部处理逻辑和 WXML 条件表达式，不证明真实触摸、像素或设备表现。桌面控制先前返回 `noWindowsAvailable`，没有取得此次新界面的真实截图。

在隔离测试房源和独立 worktree 工程中，需实际核对四处修复及条件恢复，用户确认 UI 后才能合入。未更改用户已有房源、清除缓存或操作手机。

远程推送此前被自动审批拒绝，要求明确授权向 `Hayden-Chang/rent_room` 上传源码、测试和文档。本次用户要求继续排查，没有提供该授权，因此没有再次推送、创建 PR、合并、上传体验版或发布。
