# 房源详情页状态保留

## 范围

同一次房源详情访问中，清单、影像、问题、总结各自记住滚动位置。清单展开状态、阶段、搜索和筛选保留；离开详情再进入时重新初始化，各房源不共享位置。不新增磁盘持久化。

## 实现与审查

- 原实现直接替换页面内容，共用的窗口滚动位置被短页面截断。
- 离开前读取窗口位置及清单项位置，渲染目标页后无动画恢复；中间状态隐藏，防止显示顶部再跳动。
- 分类用名称、分组及字段用稳定标识记录位置。影像关联改变布局时，优先保持原项目的屏幕位置；项目消失时使用邻近项目，均消失时回退到原偏移并由平台限制到有效范围。
- 每次切换收起左滑和键盘；切换请求串行处理并保留最后一次目标，页面卸载后放弃待处理回调。
- 本地最终审查修正分类锚点：使用分类名称，避免筛选结果变化时列表序号指向另一分类。

## 验证

工作目录：`apps/wechat`。基础提交：`a7950df`，分支：`codex/detail-tab-state`。

1. 修复前：`npm test -- tests/detail-navigation.test.js -t 'preserves each bottom tab'` 按预期失败，清单期望恢复 1100，实际为 300。日志：`artifacts/navigation-before.log`。
2. 修复后：`npm run build` 通过；`npm test -- tests/detail-navigation.test.js tests/runtime.test.js`，9 项通过。日志：`artifacts/navigation-build.log`、`artifacts/navigation-after.log`。
3. `npm run check` 通过，官方 wcc 编译 8 个文件、wcsc 编译 6 个文件。日志：`artifacts/navigation-check.log`。

测试映射：

- `detail-navigation.test.js`：8 个新测试覆盖深层清单往返及筛选折叠状态、四页重复往返、影像关联引起布局变化、项目移除及空页面、读取位置期间快速切换、渲染期间快速切换、房源隔离与退出重置、卸载后回调。
- `runtime.test.js`：现有构建运行时测试覆盖修改后的详情页初始化与刷新，以及填写、媒体筛选和共享存储消费者。
- 仅运行上述定向测试，没有运行完整测试集。

## 未完成的证据与交付

- 单元测试使用构建后的页面逻辑和模拟布局/微信 API，不证明真实 WebView 的绘制、滚动时序、键盘收起或切换耗时。
- 微信开发者工具自动化被关闭的 Service Port 阻止；未更改安全设置。尝试通过界面导入隔离工程，目录选择器操作未可靠完成，因此没有真实页面往返或截图证据。
- 远端 Git 拉取因 SSH publickey 认证失败；本地 gh 认证状态也提示已有 token 无效。尚未完成远端同步、推送或 PR。
- 主目录与原 `miniprogram-wechat` worktree 的未提交变更均保留；当前运行工程尚未应用此修复。
- 状态：本地实现和定向验证完成，尚未达到合并或发布验收条件。


## 2026-10-13 开启服务端口后的实际渲染验证

用户开启 Service Port 后，CLI 已成功启动本 worktree 的 `apps/wechat/dist`，通过本机 9433 自动化端口连接。环境为开发者工具 Stable 2.01.2510290、基础库 3.17.3、iPhone 12/13 (Pro) 模拟视口 390 × 844。首次启动提示配置解析失败；磁盘 JSON 验证有效，重新编译后工程正常运行。

被验证的产品代码仍为 `0a151c6`，本轮没有修改产品代码。仅在专用的「状态保留验证 · 1013」房源内建立合成图片/问题数据、变更影像关联，没有修改其他房源记录。该测试房源保留用于复核。

实际 WebView 布局断言：

- 清单 → 影像 → 清单：返回前后滚动坐标均为 1120。
- 四页独立位置：清单 1120、影像 250、问题 400、总结 0，往返后均恢复。
- 阶段、搜索词、筛选条件、筛选区域显隐、展开状态全部保留；筛选后滚动 400，往返后仍为 400。
- 退出并重新进入详情：回到顶部、所有分类默认折叠，搜索和筛选重置。
- 在影像页把测试图片关联到上方检查项后，真实清单高度增加 52 像素；返回坐标由 1120 调整为 1172，原阅读锚点「通风与采光」仍位于视口 y=-24。
- 快速依次请求影像、问题、总结、清单，最终清单仍处于 1172。

完整断言记录：`docs/wechat/detail-tab-state-runtime.json`。现场脚本保存在 `apps/wechat/artifacts/navigation-ui/validate.cjs`、`layout-change.cjs`；测试 SDK 装于 `/private/tmp/rent-detail-ui/node_modules`，可通过 `NODE_PATH` 指向该目录运行脚本。原始适配失败记录亦保留在 artifacts 下。

证据边界：官方 SDK 的 `Page.*` 接口在当前开发者工具中没有响应，路由包装也出现导航已发生但返回报错的情况。本次改用官方 App-Service `evaluate` 调用真实页面事件处理器、微信原生路由和 `wx.createSelectorQuery` 读取实际 WebView 布局。它验证了渲染集成行为，未验证鼠标/触摸事件派发。页面截图接口三次超时，尚无往返前后截图对比；最初折叠清单截图不能替代最终证据。记录中的耗时包含测试查询与主动等待，不能当作用户体感切换延迟。

更新状态：服务端口阻塞已解除，实际渲染坐标与状态恢复验证通过；真实手势、视觉闪动及真机体验仍未验收。远端同步/PR 的认证阻塞未在本轮处理，未合并或发布。


## 2026-10-13 合入前组合验证

用户在知悉截图和真实手势证据边界后明确要求合入。GitHub Connector 核验主线为 `cb03d735d990668aa412c8e0f703384e3cfb4c95`，对应对象已存在于共享 Git 对象库；本机 SSH 拉取仍因 publickey 认证失败。仅在任务分支整合主线，未更新脏的主 checkout。

主线带入筛选原子更新与未选择分组展开，`index.js` 存在冲突。解决时保留主线 `checklistData`、`updateChecklist`、筛选与媒体筛选更新方式，给 `refresh` 增加本任务需要的 patch 和完成回调，并保留本任务的分页面位置与生命周期逻辑。解决后的候选源码 SHA 为 `757068c52d3657d8d50ec9adefa67fde010bfc40`。

先前默认 Node 25 的组合检查通过后，按项目要求切换 Node 24.21.0，重新构建并执行最终定向检查：

- `node scripts/build.mjs` 成功。
- `node node_modules/vitest/vitest.mjs run tests/detail-navigation.test.js tests/detail-filter.test.js tests/runtime.test.js tests/unanswered-group-runtime.test.js`，18 项通过。覆盖本次全部导航用例、发生交叉改动的筛选刷新，以及详情初始化/刷新和分组展开。
- `node scripts/check.mjs` 成功，官方 wcc 8 文件、wcsc 6 文件通过。
- Node 24 日志：`apps/wechat/artifacts/merge-node24-{build,tests,check}.log`。依赖独立复制至当前 worktree；两处 lockfile 的依赖内容相同，仅根 engines 声明不同，最终运行满足本仓库 engines。

在同一端口 9433 重新执行候选代码的真实 WebView 布局集成检查，清单 1120、影像 250、问题 400、总结 0 的往返位置恢复，阶段/搜索/筛选/展开状态保留，以及重新进入清单重置均通过。先检查运行实例已有主线的 `checklistData` 方法，避免把旧构建结果当成候选验证。结果见 `docs/wechat/detail-tab-state-merge-runtime.json`，原始结果与脚本位于 `apps/wechat/artifacts/navigation-merge-ui`。

这是页面事件处理器与真实 WebView 布局的集成证据；沿用已说明的边界，不声称已取得真实点击、截图或真机验收。本轮没有再次尝试已知超时的截图接口。候选源码和测试在最终验证通过后未再修改；后续只增加本文及运行记录，证据可复用至文档提交及相同 Git tree 的远端提交。

## 最终主线分隔线整合

远端 main 更新到 `98017a6`（PR #6）。逐文件核对远端 5 个 blob 与本地 `dca2933` 完全相同，在独立工作树整合该提交；详情模板同时保留滚动锚点和 `hide-divider` 属性。整合提交 `ed4318c` 使用 Node.js 24.21.0 重新构建，导航、筛选、详情运行时、未选择分组、字段占位与左滑共 6 文件 27 项测试全部通过；官方 wcc 8 文件、wcsc 6 文件编译通过，包体 994022 字节。分隔线改为透明且保留边框宽度，没有改变锚点几何；未重新声称截图或触摸验证。最终发布通过 GitHub 连接器创建完整内容一致的树，以远端 main 为父提交，核对远端树 SHA 与本地验证树相等。
