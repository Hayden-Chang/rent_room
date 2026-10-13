# 同行选项动画与左滑操作候选修复 · 2026-10-13

状态：代码和局部逻辑验证完成，**实际按钮失效的现场根因仍未确认，UI 待验收，不可合并**。

## 行为与范围

- 同行选项保留在原来的网格位置，放入裁切容器；横向位移按标题左滑进度从 0 到 -100%，随拖动收起，放手和关闭菜单时使用 180ms 过渡。右滑、点击其他位置和页面收起均复用 offset 归零，选项向右展开。选中值和组件不卸载；非同行选项及附件保持原位。
- 三个按钮直接接收新的 touchstart，复用现有手势方向判断，点击进入独立 trayAction，避免依赖普通内容点击的 dismissal 分支。右滑仍沿 shell 处理，不能触发操作；只读、菜单关闭、手势尾随 tap 均不执行。
- 已确认并修复的邻接缺陷：菜单关闭后，延迟超过 250ms 的旧 action 事件仍可修改问题标记；新入口要求菜单仍展开，且重复点击只执行一次。
- 用户报告的“三个按钮实际点不动”尚无成功的运行时复现。直接绑定属于待现场确认的事件边界修复，不能将 VM 测试通过当成原问题已解决。

## 基线与测试

独立分支 `codex/swipe-inline-actions`，基线 `0fd8b416ff6b419ba0a97f296af86a6c3a99f676`。主目录和已有小程序工作树的修改未改动。只修改 field-row 的 JS/WXML/WXSS，新增一个回归文件。

从 worktree 的 apps/wechat 执行：

```sh
npm run build
npm test -- tests/field-row-inline-actions.test.js tests/field-row-swipe-scope.test.js tests/field-row-swipe.test.js tests/field-row-placeholder.test.js
npm run check
```

27 项通过，未跑全量套件。影响映射：新文件 7 项覆盖三按钮显式触摸/事件唯一性、关闭后旧事件、动画绑定/原值保留、只读保护、页面问题标记/备注保存/媒体入口及重载；既有 swipe-scope 11 项覆盖事件祖先、关闭和页面入口，swipe 6 项覆盖方向/阈值/取消/互斥，placeholder 3 项覆盖同组件焦点与输入。页面集成通过真实 store 和内存 adapter，chooseMedia 被替换为参数记录，**不证明相机/相册可用**。

初始新增 6 项在旧构建上 5 失败、1 通过：三项缺少按钮自身绑定、一项缺少动画结构、一项关闭后旧事件误触发。最终的 `stale taps` 用例另在冻结基线产物独立目录执行，1 项按预期失败（多发出 flag action）；修复后通过。静态绑定失败不是原生触摸失效的复现。

官方编译通过：wcc 8 文件、wcsc 6 文件、7 页面。日志在 `apps/wechat/artifacts/swipe-inline/`：before.log、before-stale-final.log、build.log、after.log、check.log。没有在通过后修改业务代码或测试。

## 现场阻碍与剩余验收

按 AGENTS.md 使用三槽常驻池，本轮基线复现租用槽 2，run ID `363ed85a36b040ad845b942c99258b48`。SDK 可连接但 App/Page 服务始终未就绪，health-before.log 最终为 `App service health timeout`；回调未执行，未创建测试房源、未取得截图或按钮实点证据。runner 保留实例并将槽位标记为 quarantined，未接管其他实例、未清用户缓存。桌面 cua.getState 同样超时。

池失败 receipt 位于 `/Volumes/mac2/codex-builds/wechat-instance-pool/runs/363ed85a36b040ad845b942c99258b48/receipt.json`。这次失败属于基线工程启动阻碍，不是候选 UI 测试结果。

待维护者恢复测试环境后，在任务构建产物上实测：同行选项左收右展及中途反向；右滑/外部点击恢复；三个图标各自单击触发正确字段且不重复；标题、答案、备注、图片状态保持；iOS/Android 受影响手势及相机/相册验证。展示实际截图并取得用户 UI 确认后，才能合入。未上传、发布。
