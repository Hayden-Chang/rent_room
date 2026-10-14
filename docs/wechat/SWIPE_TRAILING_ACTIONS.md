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

## 2026-10-14 按钮真机确认与备注键盘遮挡

用户对 `0bb0f8d` 预览反馈「很好，这个已经修复了」，确认本轮三按钮问题解决；随后提供新截图，显示备注输入框下半部及操作区被 iPhone 键盘遮挡。该确认仅覆盖按钮修复，不代表新备注改动已经验收或授权合入。

原备注弹层固定在屏幕底部，textarea 未声明 fixed、仍使用默认页面上推，也没有按键盘高度定位整个面板。现在检查项备注和影像备注均声明 `fixed=true`、`adjust-position=false`，通过 focus/keyboardheightchange 的实际高度设置弹层底部；小屏上收缩输入区，标题和 44px 按钮保留。`hold-keyboard=true` 避免点击保存时先失焦收键盘导致按钮移位；关闭时主动收键盘并归零高度，页面隐藏时只归零高度、不丢弃草稿，关闭后迟到的事件不影响其他弹层。参考 Tencent textarea 对这些原生属性的说明：https://github.com/Tencent/tdesign-miniprogram/blob/develop/packages/components/textarea/props.ts 。

回归 `note-keyboard.test.js` 从真实 WXML 绑定派发键盘高度事件；旧包 6 项失败，其中两种备注的弹层 bottom 在键盘高度为 300 时仍为 0。`note-sheet-layout.cjs` 将真实模板/CSS 渲染为浏览器 DOM，模拟键盘边界：320×480、390×756、430×844，检查项/影像备注、键盘打开/收起共 12 状态；旧包全部 6 个键盘打开状态输入框被遮挡，修复版 12 状态通过。该适配器不模拟微信原生输入框或真实键盘事件。

增量选择：键盘状态与绑定 `note-keyboard.test.js`；备注保存/取消/重载 `media-caption.test.js`；左滑进入备注及保存 `field-row-inline-actions.test.js`；页面隐藏与导航 `field-row-swipe-scope.test.js`。共 4 文件 31 项通过，官方 wcc 9 / wcsc 7 通过。没有修改 field-row，复用已通过的按钮回归与用户真机确认。证据在 `artifacts/note-keyboard-before/` 和 `artifacts/note-keyboard-fixed/`，新备注避让待手机复验。

## 2026-10-14 手动输入不弹键盘

用户确认 `1d233a3` 备注输入框不再遮挡，但地址等手动输入框点击后键盘完全不弹；地址搜索框可用。源码差异与该反馈吻合：地址搜索组件在 swipe-shell 外；手动文本、数值、日期控件位于有 catchtouchstart 的左滑祖先中。没有取得新的原生 focus 事件日志，故仍将左滑触摸拦截视为待真机确认的原因，不能宣称已测得微信底层聚焦行为。

保留 swipe-shell 作为整行布局、操作按钮定位与裁剪边界，将手势监听移到标题、选项区和操作托盘。原生 input/picker 仍在相同显示位置，但触摸路径不再经过左滑 start/move/end；文字选择、输入和日期选择交还原生控件。其他输入与地图的事件路径不变。标题和右侧选项均可左滑，托盘右滑和三按钮短按继续使用已确认的处理逻辑，备注键盘避让保持不变。

`field-row-events.test.js` 新增文本/数值/日期触摸路径及输入时收起菜单回归：旧版 4 项均因 touchstart 被 start 捕获失败，新版通过；新增标题模板事件路径检查，既有选项、操作按钮、取消和误触检查继续通过。`field-row-swipe-scope.test.js` 增加原生控件祖先无手势监听约束。同前述 6 个 field-row 相关文件共 57 项通过，官方 wcc 9 / wcsc 7 通过。模板只移动事件属性，没有改 DOM 层级、条件或 CSS，复用既有几何结果；不重跑未变化的备注布局测试。

证据保存在 `artifacts/native-entry-before/` 与 `artifacts/native-entry-fixed/`。上述为 WXML 事件路由及 handler 验证，不证明真机键盘弹出；需新预览验证地址文本、面积数值、日期选择及已确认的按钮/备注体验。

## 2026-10-14 恢复输入框上的整行左滑

用户否定 `71e4385`：填写框也属于整行，必须同时支持轻点填写、左滑展示三个按钮；是/否选项同样区分点击与滑动。上一轮把原生控件排除出手势路径的方案违反这一要求，对应“输入框不能开始手势”的测试也编码了错误的验收标准。前节仅保留历史经过，不再作为当前交互契约。

重新核对 Tencent TDesign 与 Vant Weapp 的 swipe-cell WXML，两者都用 bindtouchstart 监听容器的触摸开始，而非在输入控件祖先 catchtouchstart。当前实现把 start/move/end/cancel 恢复到完整 swipe-shell，使用不截断传播的 bindtouchstart；原生 input/picker 与选项始终在同一手势区域内。原外层 bodyStart 会在事件冒泡时撤销正在识别的手势，因此只给地图及额外输入/备注/媒体区域保留它，不与整行识别器重复运行。按钮自身的 catchtouchstart 与已获用户真机确认的 touchend 单次分发保持不变，输入框祖先没有 catchtouchstart。短按保留原生聚焦与选项点击；识别为横向滑动后保持既有点击抑制，避免改答案。没有修改答案、媒体、备注键盘高度逻辑、DOM 层级或 CSS。

参考源码（不是当前微信内核聚焦行为的直接证明）：
- https://github.com/Tencent/tdesign-miniprogram/blob/develop/packages/components/swipe-cell/swipe-cell.wxml
- https://github.com/youzan/vant-weapp/blob/dev/packages/swipe-cell/index.wxml

替换错误约束后，`71e4385` 的事件/范围测试 4 项失败、33 项通过，失败覆盖文本/数值/日期框起手左滑及完整祖先绑定。修复后相关 6 文件共 59 项通过，包括输入框起手滑动、短按后聚焦/输入事件处理、纵向滚动、附件区隔离、选项点击、三按钮无 tap 序列与去重。测试中的 focus/input 仍由夹具派发，不代表原生键盘已弹出。官方 wcc 9 / wcsc 7 通过，构建差异只有 field-row/index.wxml；不重跑未改变的布局和备注键盘逻辑测试，复用既有证据。

证据：`apps/wechat/artifacts/full-row-native-before/tests.log`、`apps/wechat/artifacts/full-row-native-fixed/`。当前三槽池查询均为 busy-or-quarantined，没有抢占实例或新开发者工具截图。真机仍需验证：直接在地址/数值填写框内部左滑打开三按钮；轻点输入能填写；是/否轻点选择、左滑不改答案；三按钮与备注键盘避让保持可用。本轮待手机验收，不合入或正式发布。

## 2026-10-14 短距离与快速甩动手感

用户反馈 `0b1560c` 左滑常常只动一点就收回，并明确要求短距离的快速左甩也应展开。源码检查发现：展开/收起必须超过 36px；达到 8px 后，只要横向位移没有超过纵向的 1.2 倍就永久锁成纵向；已锁横向时 touchend 不更新最后坐标；页面 onPageScroll 无条件 closeSwipe 会清掉正在识别的手势。以上是可重放的失败路径，不代表已经录得用户手机的全部事件原因。

参考 Vant Weapp 的捕获阶段方向识别与条件 catchtouchmove，以及 TDesign 等待方向明确的做法：保留整行 bindtouchstart，move 改为 capture-bind 并仅在已识别横向拖动时捕获后续 move。方向不明确时继续观察，明确纵向后不切换为横向。页面滚动不打断未定向/横向手势，松手后沿用 250ms 的点击抑制窗口忽略滞后的滚动通知；新的触摸立即解除抑制，纵向滚动、页面隐藏和显式外部收起仍可关闭菜单。

普通拖动阈值从 36px 调为 20px。快速甩动依据最近 100ms 内的坐标与触摸时间计算横向速度，超过等于 0.3px/ms 且净位移至少 8px，按速度方向展开或收起；这满足用户所说的加速后短甩，不以整次按住时长平均，也不直接用噪声较大的二阶加速度。快划后停住会丢弃过期速度，快速反向收手按末段方向处理。touchend 总是纳入最终坐标，适应缺失最后 move 的短划。点击与三个按钮的短触分发保留。

研究来源（2026-10-14 读取开发分支源码；用于实现模式参考，并非本项目基础库原生行为证明）：
- https://github.com/youzan/vant-weapp/blob/dev/packages/swipe-cell/index.wxml
- https://github.com/youzan/vant-weapp/blob/dev/packages/mixins/touch.ts
- https://github.com/Tencent/tdesign-miniprogram/blob/develop/packages/components/swipe-cell/swipe-cell.wxs
- https://github.com/ionic-team/ionic-framework/blob/main/core/src/components/item-sliding/item-sliding.tsx （距离之外依据 velocityX 判断快速甩动，0.3 速度阈值）

新增复现覆盖短拖、斜向起手、松手坐标、滚动取消及速度路径：旧包 13 失败 / 46 通过。修复后的 8 文件增量共 89 项通过；涵盖 12px/25ms 短甩、同距慢拖、长按后末段加速、快划后暂停、微小抖动、纵向快划、反向短甩、反向收手、原生输入路径、三按钮去重及备注键盘状态。事件夹具增加捕获阶段和条件 catch 路由，但不能证明原生事件时序及手感。首轮有 8 项导航检查因旧组件替身缺少新增 closeOnScroll 方法失败，保留原始日志；补齐替身接口后，所有原导航断言均执行通过，没有修改产品导航策略或跳过断言。

增量映射：组件识别器/事件绑定 → field-row-swipe、field-row-events、field-row-swipe-scope；共享按钮/输入方法 → field-row-inline-actions、field-row-placeholder、address-bindings；页面滚动/生命周期 → detail-navigation、note-keyboard。官方 wcc 9 / wcsc 7 通过。CSS、布局、原生输入属性及备注模板未变，复用此前几何证据。失败与通过日志在 `apps/wechat/artifacts/swipe-feel-before/`、`apps/wechat/artifacts/swipe-feel-fixed/`。真机短划手感与键盘仍待新预览确认。

本轮工具池曾返回 2 号槽位 idle，遂通过 runner 领用冻结包并准备 SDK 元素触摸检查；run `9bbecaa9f5084ffd895a1c631b619848` 在 health-before 阶段失败，回调未执行，没有本次截图或 SDK 交互结果。失败 receipt 与 health-before 日志保存在 swipe-feel-fixed；未重置或绕过隔离槽位。与 `0b1560c` 预览逐文件对比仅三个产物改变：field-row/index.js、field-row/index.wxml、pages/detail/index.js，确认布局和备注模板等复用依据。

## 2026-10-14 手机验收与合入授权

用户试用 run `c9af82c6c0754e7897316c6e2fa6f4eb` 后明确反馈「没问题了，可以合入」。该预览是 `0b1560c` 上的未提交修复快照，已逐文件确认本地业务构建与手机预览一致。此反馈记录为整行点击/滑动、短甩手感及此前修复的用户验收和合入授权；并非新增 Android 或开发者工具自动化通过证据。随后提交修复，并在合入前检查最新主线组合与最终 PR head。

合入前最新主线为 `750fe4b`，包含地图配置修复和网速测试入口，与字段模板、详情页生命周期、测试上下文有三处文本冲突。整合保留当前完整 swipe-shell 与短甩算法，同时保留主线 speedTest 字段识别、测速入口、归档保护和 onShow 的重复导航复位。测速行的 grid 配置迁移到实际布局容器 swipe-shell，避免父级布局变更导致测试入口挤压；新增实际 WXML 事件路径回归，验证测速按钮轻点分发、滑动不导航。常规输入的测试选择器排除测速专用 input，防止新增模板分支使原有用例测错对象。

组合代码最终增量：12 个 Vitest 文件 121 项通过（上述 8 文件加 media-caption、speed-test-page、speed-test、map-build-config），覆盖 PR 新增/修改测试与主线交叉调用边界；官方 wcc 10 / wcsc 8 通过。扩展原有真实模板/CSS 浏览器几何测试，加入测速行，320/390/430px 展开/收起共 48 状态通过，新增测速输入至少 40px、测试按钮不越界、控件不压标题断言。备注模板/CSS 与已验收版本不变，复用 12 状态备注布局结果。完整日志与截图在 `apps/wechat/artifacts/merge-final/`。组合检查不同于新的手机验收；用户已批准的手势规则、三按钮处理和备注避让保持原样。当前主 agent 审查确认无剩余冲突、未覆盖主线功能，按用户授权合入，不进行正式版上传。
