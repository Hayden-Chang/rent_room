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

## 2026-10-15 个人资料与登录页亮度

「我的」删除账号编号、记录总数及顶部本机存储说明，保留登录状态和仅计算未归档房源的容量。头像/昵称直接在原位置调用微信选择控件，本机按账号保存，不追加资料页或云同步。头像先复制再原子提交资料，失败保留旧头像和昵称；退出或切换账号后的旧控件回调不得写入新会话。

登录页的添加房源保持亮紫色、白字和完整不透明度；登录层背景透明，仍拦截背景操作。修改前运行 `38c1be71e2a54ebeacf16dd10fa365e8` 实测按钮 opacity 为 0.45，亮度断言失败。最终运行 `83956eb32c4a43f1ad67882388e66576` 确认 opacity 为 1、按钮色为 rgb(77, 86, 223)、文字白色、登录背景透明、disabled 仍为 true，三处已删内容无渲染节点；资料卡重开后读取相同昵称和持久头像路径。截图、receipt 和结果位于 `apps/wechat/artifacts/profile-review/`。

定向验证：`account-profile`、`account-runtime`、`account-storage`、`settings-simplification`、`capacity-runtime`、`runtime` 六文件 59 项通过。最后一次修改仅补充登录背景透明样式；原生渲染与官方 wcc/wcsc 检查随后重跑通过（11 个页面），业务测试按 JS 未变保留有效。测试使用 `xunju-test-profile` 隔离目录；身份和资料为夹具，原生选择器、系统键盘与真机触摸尚待扫码验收，不能把截图或程序导航当成点击端到端通过。此前登录转场的真机验收仍待用户确认，保持草稿 PR。


## 2026-10-15 登录、资料与容量的主线集成

整合主线 `2b5f9a79a257cc6c90d5f70e2328e0ff6dfd8cff`（ZIP 多选导入导出与路线回填），业务验证候选为 `5170cc95d79caf06fc89d1af6d2b04f2f65916f6`。覆盖导入按整批未归档数量的净增量预检，允许归档副本、容量不增加的覆盖和释放容量的替换；归档转未归档超额时先拒绝再写媒体。修改前两项交叉回归分别复现了提前写入媒体、错误拒绝归档副本，原始记录保存在 `apps/wechat/artifacts/merge-review/preflight-before.log`。

定向测试共 199 项通过：account-profile、account-runtime、account-storage、auth-build-config、billing、capacity-config、capacity-runtime、capacity、platform、transfer、transfer-page、runtime、settings-simplification、workplace-runtime、detail-navigation、commute-page 共 191 项；model 仅选择 `durable store and migrations` 的 8 项。精确命令和边界映射见 `apps/wechat/artifacts/merge-review/plan.json` 与 `commands.json`。首轮旧夹具的路由、资料对象和隐藏页面假设已更新；一次 202 套完整清单用例并行运行超时，分步诊断与原断言单例复验保留在 `campaign-22bd991/`，没有放宽超时或断言。最终候选限制文件并发后完整定向集通过，未执行全量单测。官方 wcc/wcsc 各 14 文件通过，12 页面；恢复正常构建后确认未打入测试数据根目录。

固定池 2 号实例的原生证据：资料与亮度 `b34360fdc4f34348aced5529a237ae98`；登录渲染及三轮详情往返 `e38a2f1354bd4bf2b5039e1e3f5bcd7c`；归档容量渲染 `cab0a05e282b4975af3c14ab05fe4e55`。实际按钮为完整不透明亮紫色、登录背景透明；恢复 tabBar 时待完成渲染为 0，三轮导航中首页登录层均为 false；两条记录含一条归档时容量为 1 / 2。主 agent 已查看首页、资料、详情及容量截图。资料证据来自 `22bd991`，与最终候选之间只变更独立容量渲染测试的隔离目录守卫和总数读取，业务、构建输入、资料测试及运行环境完全一致，记录在 `profile-equivalence.json`。

截图、日志和 receipt 汇总于 `apps/wechat/artifacts/merge-review/`。上述原生验证使用身份/房源/资料夹具与导航 API，不宣称真实点击、微信资料选择器、支付或手机转场已验证。此前点击用例的 SDK 查询超时记录继续保留，不能用渲染结果覆盖。用户随后已接受现方案并明确要求合入；原草稿阶段待确认状态由本次合入授权取代，正式发布仍单独处理。
