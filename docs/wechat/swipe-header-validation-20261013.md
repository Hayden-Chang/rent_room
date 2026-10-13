# 检查项标题左滑修复 · 2026-10-13

## 行为

左滑容器只包含描述标题与问题、备注、拍摄三个操作。答案、地图、输入、备注与媒体保持在容器外，不参与位移，也不撑高操作按钮。同行二选一仍保持同行，答案固定；三个操作各 44px，总展开宽度 132px，适配标题列。长标题按实际换行高度显示。

右滑从标题或操作按钮区开始均可收起；点击标题、其他 item、页面空白或悬浮区域可收起。答案按钮、分组操作和表单工具首次点击优先收起，下一次正常执行；导航与回顶部可同次完成。输入框允许聚焦并收起菜单。滚动和离开页面关闭临时状态，不改写答案、备注或媒体。

## 验证与影响映射

基线：9270183a34e3100a2b8424cd9c197b3781d4bae5。独立 worktree：`.worktrees/item-swipe-header`；分支：`codex/item-swipe-header`。Node v25.9.0、Vitest v5.0.3；使用已有环境，仓库推荐 Node 24，本轮未安装/升级运行时。依赖从已有工程复制到本任务独立 node_modules，锁文件未改。

- 新增 `field-row-swipe-scope.test.js`：最初六项在旧产物上全部按预期失败，分别为选项/附件仍位于滑动容器、操作按钮没有滑动祖先、跨 item 首次点击改答案、右滑结束误触操作、悬浮控件不在收起边界、分组答案先修改而未收起。
- 修复后该文件共 10 项通过，增加答案区不启动滑动、下一次点击可用、操作按钮新触摸可执行、标题手势后的 tap 抑制与导航/滚动/离开关闭。
- 受影响已有测试：`field-row-swipe.test.js`（6，手势阈值/互斥/只读/取消/操作）、`field-row-placeholder.test.js`（3，焦点与输入）、`detail-filter.test.js`（8，新增收起前置逻辑不影响既有筛选提交）、`runtime.test.js`（1，构建后页面与共享 service）。合计 28 项通过。
- `npm run check`：官方 wcc 编译 8 个 WXML、wcsc 编译 6 个 WXSS，通过，7 个页面。

命令均从 `apps/wechat` 执行：

```sh
npm run build
npm test -- tests/field-row-swipe-scope.test.js
# 旧代码：6 failed；原始输出 artifacts/swipe-header/before.log。
npm run build
npm test -- tests/field-row-swipe-scope.test.js tests/field-row-swipe.test.js tests/field-row-placeholder.test.js tests/detail-filter.test.js tests/runtime.test.js
npm run check
```

原始日志在本任务 `apps/wechat/artifacts/swipe-header/`（before.log、after.log、build-before.log、build-after.log、check.log）；编译结果在 `artifacts/compile-result.json`。没有执行全量单测或 UI 套件。

## 尚待 UI 验收

VM 测试和模板祖先断言验证逻辑与绑定范围，不是实际手势或像素证据。开发者工具 Stable 2.01.2510290 当前工程是另一个任务 `.worktrees/inline-address-map/apps/wechat/dist`，本轮仅只读查看，未切换/重启该会话，未改用户缓存或数据。本次版本暂无开发者工具截图和真机手势证据，因此 PR 为草稿、未达到合并门禁，未上传预览、体验版或发布。

待在独占且数据隔离的会话导入本分支 dist：

1. 找到非同行选项字段（如热水器等待时间），从标题左滑，确认仅标题移动、操作与标题等高，下方选项及附件位置不变。
2. 从选项区域左滑不能展开；同行“是/否”固定，长标题换行不裁切，三个操作可点。
3. 从标题和三个操作区分别右滑；点击当前答案、另一个 item、分类、空白、拍摄按钮、导航，核对收起与首次点击规则。
4. 点击三个操作确认只触发一次、归属正确；滚动和切页后菜单关闭；重开检查答案、问题标记、备注与媒体保留。
5. iOS/Android 真机复核受影响手势，并由用户确认 UI 后再合入。

## PR 最终复核

创建草稿 PR #5 后，主线前进到 cb03d735d990668aa412c8e0f703384e3cfb4c95（未回答分组折叠修复）。已无冲突合入任务分支，组合提交 faf66221ee047c63d28934b3e3cab52bd8005681。本 PR 对主线的业务 diff 未变；因主线改了页面使用的模型，重新构建并执行上述五个文件及新增主线的 `tests/unanswered-group-runtime.test.js`（直接调用本次修改的 fold/group 边界）：29/29 通过，官方编译再次通过。

最终命令：`npm test -- tests/field-row-swipe-scope.test.js tests/field-row-swipe.test.js tests/field-row-placeholder.test.js tests/detail-filter.test.js tests/runtime.test.js tests/unanswered-group-runtime.test.js`，以及 `npm run build` / `npm run check`。日志 build-final.log、final.log、check-final.log 保存在同一证据目录。当前主 agent 已独立复查远端 PR diff、八文件范围、旧失败与新通过证据；之后仅补充此文档，没有改变源码、测试或配置。UI 与真机证据仍未取得，草稿保持未合并。
