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

## 2026-10-14 手机反馈后的整行手势修复

用户验收 `22cafad` 预览后指出：右侧选项也应能够起手左滑，且展开后的三个按钮无法点击。此前仅测了显示几何和直接调用 handler，未覆盖选项的实际 WXML 事件路径，也未检查操作按钮是否超出手势父容器。

现在 `swipe-shell` 自身占满整行，内部包含标题、答案控件及操作托盘；托盘在父容器范围内定位，不再依赖从标题列溢出绘制。地图、额外文本、备注及媒体附件仍在这个手势区域之外。选项收到滑动结束后的 tap 时直接忽略，保持菜单展开并保留原答案；新的明确按钮触摸会解除该次滑动的 tap 抑制。

新增 `field-row-events.test.js` 按真实 WXML 的 bind/catch 冒泡关系路由触摸和点击。旧版 5 项中 4 项失败，原因是从选项起手没有打开菜单；修复后全部通过。布局回归增加了操作按钮完整包含在手势父容器内的断言，旧版失败，修复版 42 状态通过。相关 Vitest 共 6 文件 38 项通过，官方 wcc 9 文件、wcsc 7 文件通过。源码与测试影响映射沿用上表，增加 WXML 事件路由层；未运行无关全量测试。

失败证据在 `artifacts/swipe-touch-before/`，通过证据在 `artifacts/swipe-touch-fixed/`。上述路由测试仍是组件模拟，几何仍是浏览器渲染；尚不能宣称手机上的三个按钮已经验收通过。统一开发者工具池仍为三个 quarantined 槽位，使用新手机预览继续验收。

## 2026-10-14 真机无 tap 的触摸证据与修复

用户复验 `7ef7809` 时，三个按钮点击后菜单均保持展开。诊断预览 `1014-D1` 保持业务逻辑不变，包装事件方法并延迟显示记录。手机截图的 11–22 条记录显示 flag、note、media 各自进入 start/end；始终为 A1（展开）、O-132、D0（未拖动）、S0（无点击等待），没有进入 trayAction。由此确认触摸命中按钮且该次操作没有送达 tap handler；不能把其进一步归因于某个微信内核缺陷。此前测试主动派发了 tap，遗漏了手机上的实际事件序列。

参考腾讯 TDesign 与 Vant Weapp 的 swipe-cell 源码核对手势与操作事件分离，微信官方事件文档本次无法直接获取；上游源码并未证明本项目的原生 tap 缺失原因：
- https://github.com/Tencent/tdesign-miniprogram/blob/develop/packages/components/swipe-cell/swipe-cell.wxml
- https://github.com/youzan/vant-weapp/blob/dev/packages/swipe-cell/index.ts

修复只针对已观测序列：在已展开的操作按钮上开始单指触摸，位移小于 8px、时间小于 350ms 且没有被识别为拖动时，touchend 直接进入原有 action 分发。滑动、长按、多指、取消、只读和未展开状态均不触发；抑制该次随后可能到达的 tap，新的明确触摸立即解除抑制。没有触摸事件的辅助功能 tap 仍使用原有入口。操作数据与页面媒体调用不变，但 wx.chooseMedia 从 touchend 唤起仍须真机验证。

`field-row-events.test.js` 按真实 WXML 路由重放 start/end、不主动补发 tap：旧版三个按钮均未产生 action，3 项失败、15 项通过；失败日志 `artifacts/swipe-touchend-before/events.log`。修复后覆盖上述边界、重复 tap 和连续操作；同前述 6 个相关文件共 52 项通过。官方 wcc 9 / wcsc 7 通过。源码布局和样式未变，复用 `7ef7809` 的 42 状态几何证据，不将其视作手机交互验证。

用户原始截图、测试及编译结果保存在 `artifacts/swipe-touchend-fixed/`。临时诊断构建代码从工作树移除，生成新普通预览前检查包中不存在诊断面板或记录器。原始诊断源码、构建补丁与冻结包保留在忽略的 `artifacts/swipe-diagnostic/`，没有进入 PR。工具池仍无可用槽位；待新预览的三按钮真机复验、UI 批准后再判断是否可合入。
