# 验证记录

本文记录原有验证结果；下列命令和测试路径均相对 `apps/wechat/`，执行前先 `cd apps/wechat`（从仓库根目录）。清单源文件位于该目录的 `data/source-tree.json`。本次目录迁移的验证见 [仓库验证记录](../repository/VALIDATION.json)。

## 自动验证映射

所有测试均为本次新增，按新增边界选择以下四个文件，没有运行其他项目的测试。

| 边界 | 测试文件 | 关键断言 |
| --- | --- | --- |
| 原始清单与业务状态 | tests/model.test.js | 303 字段与原树逐项一致、202 初始有效项、条件不丢旧答案、独立问题标记、筛选、模板快照、对比未知值、只读保护、存储失败 |
| 文件交换 | tests/files.test.js | ZIP 实际媒体字节、路径穿越及缺失文件拒绝、Excel 数字零/中文/多选、公式和非法格式拒绝 |
| 微信文件接口 | tests/platform.test.js | 拍摄文件持久化后重载、权限失败、磁盘满重试、完整恢复、损坏保存保留、删除及失败回滚 |
| 打包运行时 | tests/runtime.test.js | 构建后 App/Page 在无 Node/DOM 的 VM 中运行、页面共用 store、实际处理输入与选项、落盘 |

命令（使用 Node.js 24）：

```sh
node node_modules/vitest/vitest.mjs run tests/model.test.js tests/files.test.js tests/platform.test.js tests/runtime.test.js
npm run check
```

编译检查同时验证 7 个页面、WXML/WXSS 官方编译、JS/JSON 解析、AppID、密钥设置扫描与主包大小。`artifacts/validation.log` 和 `artifacts/compile-result.json` 保存最终结果。

最终结果（2026-10-11）：四个测试文件共 35 项通过；官方 wcc 编译 8 个 WXML、wcsc 编译 5 个 WXSS 均成功；7 个页面，工程总计 965732 字节。原 HTML 清单文件的 SHA-256 与输入快照相同。ZIP 完整性检查通过。

## 修复中的失败证据

- 删除磁盘写入失败时，原实现会先让房源从内存消失，无法正常重试。新增 `failed deletion keeps the archived record and its media available for retry` 在修复前失败（得到 undefined，预期 archived=true）；修复后保留记录和媒体，并支持重试。
- 导入写入失败时，原实现会报告导入成功。新增 `does not report an import as successful when persistence fails` 在修复前失败（未抛错）；修复后撤回导入，保留原记录。
- 对应证据：`artifacts/delete-failure-before.log`、`artifacts/import-failure-before.log`。文件系统故障由测试适配器注入，不修改原 HTML 数据。

## 开发者工具观察

使用正式 AppID 打开工程；用户完成登录和 Trust & Run 后，首页运行，工具错误计数为 0。通过界面创建「验收测试 · 阳光公寓」，进入清单，看到 13 分类默认折叠与初始 0/202；走完四步引导；打开基础信息分类。重新构建后测试房源仍存在。

早期实际截图发现 style-v2 默认按钮宽度挤压工具条，已对页面和组件显式覆盖，并补充本地 PNG 图标。之后原生 UI 自动化滚动报 noWindowsAvailable，截图刷新不可靠，因此未把早期截图当成最终视觉验收。最终样式仍需用户在工具或手机上复核。

## 尚待真机完成

1. iOS 与 Android 分别拍照、录视频、选相册，退出后重开检查媒体仍可预览。
2. 拒绝权限后能继续手动填写；授权后地图选点联动地址。正式 AppID 的定位接口资格和隐私声明按微信后台实际设置验收。
3. 两套/三套房源对比、连续清单/影像/问题/总结切换的体感和耗时。
4. 导出含媒体 ZIP，在另一台手机导入并核对文件；微信分享仅由用户选择接收方。
5. 归档只读、还原编辑、完整备份后再验证永久删除。

目前没有手机预览成功或真机验收的证据，未提交审核或发布。

## 手机预览码

官方 CLI 预览调用因开发者工具 Service Port 关闭而未完成。未授权开启新的安全接口，未修改该设置。UI 自动点击预览未可靠触发。可由用户在已打开的开发者工具中点击「预览」后扫码，当前无成功生成预览码的证据。

## 2026-10-12 输入框与左滑操作复核

使用桌面操作在开发者工具实际复现：空白数值输入框已聚焦但仍显示占位文字，控制台提示 field-row 缺少 focus/blur 事件处理方法。源文件及构建文件中已有处理逻辑；改为明确的 handleInputFocus/handleInputBlur 名称后，清除编译缓存并重新编译，实际画面确认聚焦时占位文字消失，空白失焦时恢复。没有清除业务数据缓存，也没有更改现有答案、备注或媒体。

同一实际页面确认左滑显示问题、备注、相机三个图标，右滑收起；「电梯」三项选项与标题保持同一行。证据位于 artifacts/placeholder-20261012/：runtime-before.png、runtime-focused.png、runtime-blurred.png、runtime-swipe-icons.png。该验收只覆盖上述行为，不代表全部 Figma 状态已完成逐像素验收。

本次最终构建后，field-row-placeholder、field-row-swipe、runtime 三个测试文件共 10 项通过；官方 WXML/WXSS 编译检查通过。占位测试同时覆盖输入数值 0、预填内容、清空和「其他内容」独立焦点状态。

## 2026-10-12 设备状态问句统一

共 25 处统一为「xx正常」与「是 / 否 / 没有」：电梯、窗帘、阳台、地漏、马桶、花洒、排气扇、水槽/水龙头、燃气与灶具、抽油烟机、床、床垫、衣柜、书桌、椅子、沙发、茶几、餐桌、空调、冰箱、洗衣机、热水器、插座通电、宽带，以及纱窗字段。权限、容量和普通二选一检查不改变语义。

选项显示标签与存储值分开，既有「正常 / 有问题」答案无需重写即显示为「是 / 否」。水槽在新旧模板快照中均补上整组状态控制；未选择前保留原有明细可见性，选择「没有」只隐藏明细，不清空答案、备注或影像。增加水槽状态记录后，全新完整清单初始有效项由 202 变为 203，字段总数仍为 303。

新增 inspection-wording 四项测试在修改前全部因缺少预期标题、选项标签及水槽状态分组失败。修改后覆盖全部可见三选一分组、旧选择回显与取消、水槽不存在/恢复及明细记录保留、纱窗旧值与独立问题标记。旧模型初始总数断言随新增水槽状态更新；遍历测试明确排除不渲染选项的根分类节点。

最终检查：官方 wcc 8 文件、wcsc 6 文件通过；inspection-wording、model、files、runtime、field-row-placeholder、field-row-swipe 六文件共 41 项测试通过。选择依据为模板视图与条件/统计规则、备份与 Excel 的模板消费者、打包运行时，以及使用选项标签的字段组件交互。桌面实际展开厨房分类确认三项标题和按钮，截图 artifacts/inspection-wording-20261012/kitchen-runtime.png。未点击用户已有记录的答案按钮。
