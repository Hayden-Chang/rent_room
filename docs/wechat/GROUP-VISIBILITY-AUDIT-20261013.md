# 清单展开与隐藏条件专项排查

2026-10-13，在 `codex/pest-group-expand` 上继续检查；本记录接续 [虫害修复记录](PEST-GROUP-FIX-20261013.md)，其中 15 项测试是前一阶段结果。用户随后明确排除宽带条件；本记录以收窄后的最终范围为准。

## 发现与修复

| 位置 | 原因及影响 | 本地处理 |
| --- | --- | --- |
| 虫害鼠害 | 路径首节点被当作普通分类剥除，根检查组控件不可达 | 保留受控根节点；展开显示控件和七项明细 |
| 隔音与噪音 | 同一根节点问题，整组是/否控件遗漏 | 同一修复覆盖；六项明细与独立折叠验证通过 |
| 宽带条件（不修改） | 用户明确要求不用处理 | 已撤回空结构过滤；标题及明细的原有显示条件保持不变，测试验证现状与数据保留 |
| 清单模板搜索 | WXML 用搜索词强制展开，覆盖用户点击的折叠状态；箭头与显示状态可能不一致 | 每个搜索结果分类独立折叠；新关键词默认展开；清空搜索恢复普通视图的折叠状态 |

没有把权限、没有或不涉及等合理隐藏条件强行移除。带控件的组即使隐藏明细，也保留控件以便用户恢复。普通分类默认折叠、条件和已有答案不因浏览而改变。

## 范围与证据

源清单共 13 分类、77 个唯一路径节点、55 个受控分组、76 个 topic、303 个字段。受控根节点只有隔音与噪音和虫害鼠害两处。

新增数据驱动审计：55 个分组逐一核对控件可达、折叠/重开、适用的没有/不涉及/权限切换；76 个 topic 逐字段核对满足前提后在分类和搜索中可达，折叠分类后隐藏，浏览不改写房源。权限控制字段通过组控件测试而非重复字段行验证。另验证宽带条件保持原有行为，以及二房东/中介分支的隐藏、恢复和附件保留。模板两项测试使用构建后 Page、模拟 setData 和实际 WXML 展开表达式，不把它当作真实页面点击。

修复前：模板两项测试均因搜索结果无法收起失败。早期审计曾为宽带空标题建立一个失败用例，其他首批 131 项通过；用户排除宽带后，将该用例改为保护原有标题与明细条件，不再将其列为待修缺陷。日志为 `apps/wechat/artifacts/pest-group/audit-before.log`、`template-before.log`。前次虫害三个失败用例保留于 `before.log`。

最终范围验证：撤回宽带处理后重新构建并运行全部本次新增/修改用例及有影响的既有用例，155 项通过，23 项未选择，未运行全量套件。日志为 `apps/wechat/artifacts/pest-group/final-scope-tests.log`。早期审计与失败日志保留，不替代最终结果。

Node 24.19.0，Vitest 5.0.3；命令在 `apps/wechat` 执行：

```sh
node scripts/build.mjs
node node_modules/vitest/vitest.mjs run tests/template-fold.test.js tests/group-visibility-audit.test.js tests/root-group-fold.test.js tests/root-group-runtime.test.js tests/unanswered-group-fold.test.js tests/unanswered-group-runtime.test.js tests/inspection-wording.test.js tests/model.test.js tests/detail-filter.test.js -t 'root|pest|plain categories|unanswered|sofa|not-applicable|normal questions|saved group|functional sink|starts all categories|folding is independent|controls remain reachable|exposes every eligible detail|preserves the existing broadband|hides and restores its conditional branch|template|filter selection|multi-select filters|phase and search'
node scripts/check.mjs
```

影响映射：`formView` 的根路径处理 → 新增数据审计、root/unanswered group 模型及构建后 runtime、既有问句控件/默认折叠/模板快照、detail-filter 中筛选提交/清除/阶段搜索三项；模板展开视图 → template-fold 两项。命令有 23 项未选择。宽带用例用于确认撤回后的行为与原基线一致。

构建仍为 13 分类、76 topic、303 字段；官方 wcc 8 文件、wcsc 6 文件通过。当前构建后的生产代码此后未修改。最终提交 SHA 记录在 `apps/wechat/artifacts/pest-group/final-scope-validated-head.txt`。

## 待验收与交付边界

自动化证明模型、Page 局部处理逻辑和 WXML 条件表达式，不证明真实触摸、像素或设备表现。桌面控制先前返回 `noWindowsAvailable`，没有取得此次新界面的真实截图。

仍需在隔离测试房源和独立 worktree 工程中实际核对三处修复及条件恢复。未更改用户已有房源、清除缓存或操作手机。用户在获知真实界面尚未验收后明确要求“合入”，本次按该指令执行合并，不把该授权描述为真实界面验证通过。

远程推送在早期阶段曾因缺少明确授权被自动审批拒绝；用户随后明确要求“合入”，据此执行分支推送、PR 审查和合并。不上传体验版或发布。

## 最新主线组合验证

已将分支无冲突重放至 `5f50839a87dd7151fade0563408ce52dbb6c3034`，包含主线分隔线修复和底部标签切换状态保留。核对重放后应用差异，仍只有根检查组和模板搜索折叠三处修复，宽带逻辑保持原样。

验证提交 `5cfb1315b2cafe68c4aab9e4bf8aef22c986226e`：重新构建、上述 155 项用例，加上 `tests/detail-navigation.test.js` 的 `restores a deep checklist after a short media page and retains form view state`，共 156 项通过，30 项未选择。增加导航用例是为验证 `formView` 与最新主线的标签恢复逻辑组合。官方 wcc/wcsc 通过；日志位于 `apps/wechat/artifacts/pest-group/merge-head-tests.log`。

最终 PR 提交在该验证提交之后只更新本 Markdown 记录；源码、测试、资源、依赖、配置和构建输入均无变化，可复用该次结果。最终 SHA 另存 `apps/wechat/artifacts/pest-group/merge-validated-head.txt`，并写入 PR 描述。
