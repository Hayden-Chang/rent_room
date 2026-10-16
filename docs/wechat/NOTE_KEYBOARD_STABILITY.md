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

`note-editor.cjs` 的首次运行缺少登录构建地址，未进入业务路径；补齐 mock URL 后，SDK 的 Page 元素查询在点击影像标签前超时。保留失败，不能据此声称点击、输入、保存和重开的端到端验证成功。原生渲染脚本首次测量在页面就绪前执行，后续又发现微信选择器不支持标签名查询；对应失败保留并修正夹具与测量。

本地完整日志、前后几何数据、实际截图与 pool receipt 汇总在 `apps/wechat/artifacts/note-keyboard-stability/`；预览码与上传回执另存其 `preview/` 子目录。

## 待手机验收

在修复预览中进入影像 → 照片下方“＋” → 连续输入多行 → 收起/再次弹起键盘 → 保存 → 重开，确认键盘稳定、输入区与按钮可用、内容持久化。清单左滑备注同样复验，并关注快速取消后再次打开。iOS/Android 系统键盘仍需各自真机确认。

PR 保持草稿，UI 待用户明确确认后才可合入；本次预览不等于正式发布。
