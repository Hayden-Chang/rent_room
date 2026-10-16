# 备注键盘稳定性修复 · 2026-10-16

## 问题与修复

用户录屏中，影像备注打开后，iPhone 键盘与备注弹层反复跳动，键盘很快收起，无法稳定输入。

原实现把 `auto-focus` 放在条件挂载的原生 textarea 上；键盘事件又改变其遮罩容器的底部及面板 padding/margin。新增几何回归证实，390/430px 宽的两类备注，键盘打开时面板高度从 343.5px 变为 273.5px。这证明存在聚焦期间的重排，不单凭浏览器模拟断言它是所有真机闪退焦点的唯一原因。

- 等面板的 setData 渲染回调和下一次视图 tick 完成后，再通过 focus 请求键盘。
- 关闭、隐藏、卸载或重新打开后，旧聚焦请求失效；失焦不关闭弹层、不丢弃草稿。
- 遮罩覆盖范围固定，仅移动备注面板；标题、输入区与按钮使用相同的内边距，不再按键盘状态切换布局。空间不足的小屏仍允许缩小输入区，保留至少 48px 输入高度及 44px 按钮。
- 保留 fixed、adjust-position=false、hold-keyboard=true，保存与媒体关联规则不变。清单备注和影像备注共用本次修复。

## 回归映射

| 边界 | 测试 |
| --- | --- |
| 焦点时序、迟到事件、关闭/隐藏/卸载、两类模板绑定 | `tests/note-keyboard.test.js` |
| 多行、取消、重开、持久化失败重试与媒体归属 | `tests/media-caption.test.js` |
| 左滑进入清单备注及保存 | `tests/field-row-inline-actions.test.js` |
| 详情生命周期与手势消费者 | `tests/field-row-swipe-scope.test.js`、`tests/detail-navigation.test.js` |
| 三种屏幕尺寸、两类备注、键盘收起/弹起与正常屏幕尺寸不重排 | `tests/note-sheet-layout.cjs` |
| 开发者工具实际渲染及几何；键盘高度为夹具 | `tests/e2e/note-editor-render.cjs` |
| 点击进入、多行输入、保存、重开、取消 | `tests/e2e/note-editor.cjs` |

修复前新增焦点检查 7 失败、原有 6 项通过；布局检查的 4 个正常屏幕稳定性断言均失败（70px 重排）。修复后上述五个 Vitest 文件共 59 项通过，12 个布局状态及 4 个稳定性比较通过，官方 wcc/wcsc 各 14 文件通过。未运行全量单测或全量 UI 套件。

执行入口（应用目录）：

```sh
npm run build
npm test -- tests/note-keyboard.test.js tests/media-caption.test.js tests/field-row-inline-actions.test.js tests/field-row-swipe-scope.test.js tests/detail-navigation.test.js
npm run check
node tests/note-sheet-layout.cjs
```

布局脚本需要运行环境提供 Playwright，`PLAYWRIGHT_EXECUTABLE_PATH` 可指向已安装的 Chrome；模拟键盘占位不是微信键盘或手机证据。原脚本的账号保护夹具随当前 Page 契约补齐。原生渲染测量使用 class 选择器，按固定遮罩的实际视口边界比较；不把开发者工具里缓存的 windowHeight 当作该帧的渲染边界。

## 实际验证边界

使用固定实例池及 `xunju-test-note-editor` 隔离数据；登录响应与示例图片为夹具。真实截图显示备注输入区和保存按钮；不把程序设置 sheet 或键盘高度称作用户点击、真实输入或 iPhone 键盘通过。

最终渲染 run `90e7099c2f9046bdad05a9fca0ee6940` 通过：两类面板在 0/300px 键盘高度夹具下均为 299px，输入区均为 160px，保存按钮为 44px，完整处于键盘边界上方。主 agent 已查看原始截图。工具 Stable 2.01.2510290、基础库 3.17.3；模拟器截图不包含真实系统键盘。

该 run 的提交背景为 `6568bb3` 加已记录的 class/测量修正；后续候选 `0203fa0` 合入最新主线 `1436009`。已检查其差异：备注 JS 源码不变，构建后的 WXML、WXSS 与全局样式逐文件哈希相同；主线新增内容为首页遮罩、地图标题和虫害选项，未改备注交互。详情 JS 包含共享模型，因此整包字节随虫害选项改变；审查确认该差异不影响这里的备注夹具或布局。按上述范围复用渲染证据，最终增量单测、生产配置构建、几何检查和官方编译另在整合后的候选执行。

`note-editor.cjs` 的首次运行缺少登录构建地址，未进入业务路径；补齐 mock URL 后，SDK 的 Page 元素查询在点击影像标签前超时。保留失败，不能据此声称点击、输入、保存和重开的端到端验证成功。原生渲染脚本首次测量在页面就绪前执行，后续又发现微信选择器不支持标签名查询；对应失败保留并修正夹具与测量。

本地完整日志、前后几何数据、实际截图与 pool receipt 汇总在 `apps/wechat/artifacts/note-keyboard-stability/`；预览码与上传回执另存其 `preview/` 子目录。

## 手机验收与合入授权

提供给用户的复验路径：影像 → 照片下方“＋” → 连续输入多行 → 收起/再次弹起键盘 → 保存 → 重开；同时关注清单左滑备注及快速取消后再次打开。

用户已在本会话反馈“验证通过了，合入主线吧”，接受 `d7efd5e` 修复预览（机器人 11）的实际效果并授权合入。此前待用户确认的 UI 门禁已满足；该确认不将 SDK 点击自动化的超时记录改写为通过。

合入前重新核对 main 仍为 `1436009`，修复源码、测试、构建配置均未再改变，合并无冲突；主 agent 复审无新增代码问题。最后一次修改只更新本节验收记录，复用业务候选 `0203fa0` 的 59 项定向测试、12 个布局状态、4 个稳定性比较和官方 wcc/wcsc 各 14 文件检查，以及已记录等价范围内的原生渲染证据。远程没有返回状态检查或 workflow runs，不声称远程 CI 已通过。本次授权仅合入代码，正式发布仍单独执行。
