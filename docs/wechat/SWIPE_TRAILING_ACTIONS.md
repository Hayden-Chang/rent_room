# 清单左滑按钮靠右与标题保留

2026-10-13，基线 `1e095cf7a5eafee775d31726f8edc9ed3016d6bb`。

用户录屏中「非顶楼」左滑后标题消失，三个按钮停在行中央，右侧选项消失后留下空白。原布局把操作托盘定位在标题所在的 grid 列，同时将标题向左平移 132px。短标题因此完全移出可见区域；托盘靠的是标题列右沿而非整行右沿。

修复让整行成为定位和裁剪边界，托盘从右侧滑入，标题不平移。行内布局为 132px 操作区预留空间；数值输入仍为 96px 并靠右，文本输入与非行内选项保留。问题行尊重 8px 内边距。操作事件、答案及附件数据模型没有修改。

## 自动验证与证据边界

| 边界 | 选择与结果 |
| --- | --- |
| 真实 WXML/WXSS 的浏览器组件几何 | `tests/field-row-layout.cjs`；320/390/430px，二选项、三选项、数值、文本、长标题、非行内选项、问题行，展开/收起共 42 状态通过。检查标题不出界、不与按钮重叠、托盘在整行右沿、按钮 44px、行高不随展开改变。 |
| 手势、点击归属、只读与收起 | `field-row-swipe.test.js`、`field-row-inline-actions.test.js`、`field-row-swipe-scope.test.js` |
| 模板关联的焦点、输入与地图隔离 | `field-row-placeholder.test.js`、`address-bindings.test.js` |
| 上述增量 Vitest | 5 文件共 33 项通过，包含备注/问题/媒体归属及重载保持；VM/mock 证据，不等于真实手势。 |
| 官方编译 | `npm run check`：wcc 9 文件、wcsc 7 文件通过。 |

新增几何测试用真实组件模板、样式及 JS 状态，通过测试专用适配器将 WXML 转成 HTML，在 Chrome 无头浏览器测量。适配器会核对选项/输入数量，防止条件渲染错误被误认为布局成功。它不是微信渲染器，不替代开发者工具及手机验收。

同一测试在基线模板/样式上出现 21 个展开状态标题越过左侧边界的失败，修复版通过全部 42 状态。原版在 `artifacts/swipe-original/`；失败、截图和几何数据在 `artifacts/swipe-layout-before/`；修复版证据在 `artifacts/swipe-layout/`。

首轮增量测试有 32 项通过、1 项因旧 VM 测试未注入 `clearTimeout` 失败。当前主线页面隐藏时已调用引导计时器清理；只在该测试补充 `setTimeout/clearTimeout`，未改变或跳过下游断言。随后 33 项全部通过。

复验（从 `apps/wechat`，Node 24）：

```sh
npm run build
npm test -- tests/field-row-swipe.test.js tests/field-row-inline-actions.test.js tests/field-row-swipe-scope.test.js tests/field-row-placeholder.test.js tests/address-bindings.test.js
npm run check
# 外部测试工具目录安装 playwright@1.62.1；不进入业务包。
NODE_PATH=/path/to/test-tools/node_modules PLAYWRIGHT_EXECUTABLE_PATH=/path/to/chrome node tests/field-row-layout.cjs
```

使用 Node 24.19.0、Playwright 1.62.1、本机 Google Chrome。`FIELD_ROW_ROOT` 可指定基线组件目录，`LAYOUT_OUTPUT` 可指定独立证据目录。

## 待验收

本机统一微信开发者工具池的三个槽位均处于 `quarantined`，原因均为原有 health probe 失败。未重置池、接管实例或修改用户记录，尚无本次代码在开发者工具内的实际截图。

需要手机验证：左滑「非顶楼」标题仍可见、按钮在最右侧；右滑恢复原选项；逐个点击问题/备注/拍摄入口；检查未误改答案及已有附件。当前没有本次 iOS/Android 真机通过证据，也没有 UI 合入批准。预览、手机验收、合入和发布是不同阶段。
