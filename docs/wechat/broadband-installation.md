# 宽带安装条件整组显隐

仅修改微信小程序。HTML 原型、原型脑图及用户房源数据不做迁移覆盖。

“宽带条件”改名为“宽带安装条件”，分组自身使用“宽带不存在”条件。宽带正常选“是”或“否”时，标题及子项整组隐藏；选“没有”才显示；取消选择恢复未答状态时隐藏。已有房源、导入房源的模板快照在读取时应用相同规则，不写回快照，不删除答案、备注、问题标记或媒体。

## 验证与证据

基线：GitHub main `5f50839a87dd7151fade0563408ce52dbb6c3034`。SSH 和本机 HTTPS 凭据不可用，通过 GitHub Connector 读取签名提交，重建后核对 Git SHA 完全一致；对应 Git tree `f8e2e646dc1728604facaac81a9495460aa1307d` 已存在本机。所有修改位于独立 `codex/broadband-installation` worktree。

新增 `apps/wechat/tests/broadband-installation.test.js` 共 4 项测试。修复前 3 项按预期失败：新房源、已有快照与重新加载后的房源，在宽带正常时仍有 `topic_83` 分组行；快照不变性测试通过。原始失败在 Node 25.9.0 上复现。最终构建、测试和编译使用项目要求的 Node 24.21.0。

从 `apps/wechat` 执行：

```sh
node scripts/build.mjs
node node_modules/vitest/vitest.mjs run tests/broadband-installation.test.js tests/inspection-wording.test.js tests/model.test.js tests/runtime.test.js -t 'installation|normal questions|saved group states|functional sink|every original|categories collapsed|presence changes|template snapshots|compares 2-3|persists reloadable|imports as new|built App'
node scripts/check.mjs
```

结果：15 项通过，14 项未选中；未运行全量测试。官方 wcc 8 个文件、wcsc 6 个文件通过，构建仍含 303 字段、76 主题、13 分类。

选择依据：新增测试覆盖整组行及其子项在新旧模板下的显隐、隐藏时的筛选/问题/对比排除、重载和导入、答案与媒体保留。既有测试仅选择清单生成一致性、默认折叠、条件分组、模板快照、房源对比、存储/导入、问句和水槽兼容、构建后的 App/Page 共享状态。其余测试不在本次影响范围。

首次构建在沙箱内因工作区写入权限失败，后续测试因未生成 dist/清单而失败；这些不是产品回归证据。授权隔离工作区写入后重新构建，定向测试全部通过。

真实开发者工具：Stable 2.01.2510290，基础库 3.17.3，iPhone 12/13 (Pro) 模拟视口。专用自动化端口 9441 与其他项目分开。仅新建并操作“宽带整组隐藏验收 · 1013”，没有清除缓存或修改其他房源。

- 实际 WebView 分组矩形验证：没有 → 5 个分组，正常/有问题 → 4 个分组，再选没有 → 5 个分组；对应安装分组标题和两个子项均按条件存在或缺席。
- 已存运营商多选、备注、问题标记和图片关联在全部切换中保持不变，重新进入页面后仍保留。
- 实际截图 `normal.png` 显示“宽带正常：是”被选中，宽带详情后直接衔接“手机信号正常”，没有安装分组标题或空白占位。截图调用超时后延迟落盘，已人工读图确认状态。
- 原生桌面操作出现 `noWindowsAvailable`，官方 Page 元素 API 超时。本次集成使用真实页面的生产事件处理器及真实 WebView 布局查询，不能宣称验证了指针/触摸事件派发。未做真机验收。

本地原始日志、脚本、运行断言及截图保存在 `apps/wechat/artifacts/broadband-installation/`（不提交生成产物）。PR 仍待用户视觉确认，未合并或发布。
