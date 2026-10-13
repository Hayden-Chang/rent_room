# 筛选闪动修复验证 · 2026-10-13

## 行为与原因

筛选按钮沿用原生 `button-hover` 点击态；同时，已选中的“全部”仍执行 `setData` 和全量 `refresh()`。真正切换条件时，选择状态和结果列表分两次提交，更新还包含无关的影像、问题列表和页面标题。

本次取消阶段、筛选面板及影像筛选按钮的默认点击态。重复选择直接返回；清单的条件、选中标记和结果一起提交，只更新清单相关字段；影像筛选只提交媒体类型和可见影像。搜索沿用相同的清单更新路径。完整 refresh 仍用于进入页面与业务数据变化。保存格式、筛选并集规则、各条件的折叠状态保持不变。

## 自动验证与影响映射

测试运行环境：macOS，Node.js v25.9.0，Vitest v5.0.3。仓库推荐 Node.js 24；本机本轮使用的是已有 Node.js 25，未安装或升级运行时。依赖从现有工程复制到本 worktree 的独立 node_modules，锁文件未改变。

| 边界 | 用例与结果 |
| --- | --- |
| 重复选择、原子更新、媒体局部更新、按钮按压配置 | `tests/detail-filter.test.js`，8 个新增用例；旧代码 8 个均按预期失败，修复后 8 个通过 |
| 构建后的 App/Page 与共享 service | `tests/runtime.test.js`，1 个通过 |
| 筛选并集、分类折叠、默认折叠 | `tests/model.test.js -t 'OR filters\|folding is independent\|starts all categories collapsed'`，3 个通过，其余未执行 |
| WXML/WXSS 与包配置 | `npm run check`，wcc 8 个 WXML、wcsc 6 个 WXSS 成功，7 个页面 |

精确命令（在本 worktree 的 `apps/wechat`）：

```sh
npm run build
npm test -- tests/detail-filter.test.js
# 上述命令在修复前执行：8 failed，原因包括重复选择仍更新、一次点击提交两次、缺少 hover-class="none"。
npm run build
npm test -- tests/detail-filter.test.js tests/runtime.test.js
npm test -- tests/model.test.js -t 'OR filters|folding is independent|starts all categories collapsed'
npm run check
```

原始日志位于 `apps/wechat/artifacts/filter-flicker/`：`before.log`、`after.log`、`model.log`、`check.log` 及 build 日志。官方编译结果为 `apps/wechat/artifacts/compile-result.json`。未运行全量单测或全量 UI 测试。

这些测试验证逻辑层提交次数、同步状态、结果内容与已有记录保留；静态按钮测试防止恢复默认按压效果。它们不证明真实设备上每一帧的渲染效果。

## UI 与交付边界

检查开发者工具时，前台存在非本次操作打开的原生路径选择对话框。为避免打断其他操作，本次未改动该窗口、切换工程或使用共享用户数据执行测试。尚无本修复版本的开发者工具点击截图或真机帧级证据，UI 待验收；未上传预览、体验版或正式版本，未合并。

待验收：导入本 worktree 的 `apps/wechat/dist`，分别重复点击阶段“全部”、筛选面板“全部”、影像“全部”；切换“已记录/有备注/全部”并检查选中标记、结果和折叠恢复；确认按钮不再出现默认闪色。使用隔离的测试记录，不清理现有业务缓存。
