# 小搭只向后引导（2026-10-24）

用户最终确认规则见 [首次完成与补填的 20 条场景](XIAODA_FIRST_COMPLETION_CASES.md)。下文较早验收记录保留原始证据，其中“修改或清空重填已完成 B 后重新引导”已被最新第 6、18 条取代。

## 当前实现

- 每个大项仅在首次完成时触发。完成历史永久保留在该房源内；已完成项修改、清空后补齐不重播。缺少历史的旧记录，按修改前已完成项补入历史，避免清空后误当首次。
- 从本次首次完成位置向后查找第一个当前未完成项，不按历史最远位置或最近活动回头。结束提示、等待、返回列表不关闭后续首次完成引导；补完 A 仍能继续 B、C。
- 严格按房源保存顺序中的最后有效现场项提供阶段选择，不绑定名称；较早现场项后面已无待填现场项时只提供普通费用推荐。费用与合同已全完成时，最后现场项显示等待/返回结束引导。
- 最后合同项提供结束引导；有前置遗漏时不宣称整套完成。整套真正完成优先使用完成文案，无论本次来源是否列表末尾。
- 等待保留位置、展开状态和答案；重新进入不重播旧提示。输入中的首次完成提示等到失焦再显示，不在连续输入字符之间生成重复提示。保存错误时暂停显示/接受，输入仍保留，成功保存后可继续原首次提示。
- “无”“无费用”属于有效结果变化；备注、问题标记和媒体不用于触发完成。答案、媒体、模板顺序及小搭关闭作用域保留。

## 定向验证映射

基线：`591f135`。Node 24.19.0，Vitest 5.0.3。

| 边界 | 选择器 / 证据 |
| --- | --- |
| 只向后、跳过已完成、最近活动不抢先、重新填写 B、末尾不回绕、跨阶段及关闭/重进 | `tests/xiaoda.test.js` 的 `completion recommendations`，修复前 7 项按预期失败，修改后 12 项通过 |
| 生产页面延迟、输入结束、接受引导、取消/切页/服务变化保护 | `tests/onboarding.test.js` |
| 向后引导后的“再等等”位置、保存失败、重进、重复填写来源及撤销 | `tests/onboarding-wait-position.test.js` |
| 渲染夹具的旧回头预期 | `node tests/e2e/xiaoda-filling-fixtures.mjs`，所有夹具构造断言通过；不作为 UI 点击证据 |
| 实际 B→C→D、修改 B→D、末尾不回 A、重开保存 | `tests/e2e/xiaoda-forward-native.cjs`，由原生 UI 点击驱动，夹具仅准备前置数据 |
| 原有“再等等”真实位置回归 | `tests/e2e/xiaoda-wait-native.cjs`，预期目标同步为 C |

已执行：上述三个 Vitest 文件共 74 项通过。`npm run build` 通过；`npm run check` 的官方 wcc 20 个 WXML、wcsc 22 个 WXSS 全部通过。没有执行全量单测或全量 UI 套件。

本地日志：任务 worktree 的 `apps/wechat/artifacts/forward-only/{red,logic-green,focused,build,check}.log`。真实 UI 的结果单独记录，不以 VM 或编译替代。

## 当前提交的实际点击证据

生产与测试提交：`7da997dbfcb8ec2be771ff74a128a1696657d990`，工作区干净。开发者工具 Stable 2.01.2510290、基础库 3.17.3，使用三槽池的可丢弃测试工程。不是物理手机验证。

`xiaoda-forward-native.cjs` 的 run `ef137a11aebb4113a3c603bf7a52fd6d` 通过，receipt 状态 `passed`、槽位归还 `idle`。实际通过 CUA 的原生可访问性按钮执行填写和接受/取消，未直接调用被测 handler：

- A 1/2，B 完成 → 提示 C。
- 接受 C、完成 C → 提示 D。
- 接受 D、仅填第一项，再将 B 最后一项改为“否” → 跳过已完成 C，提示 D，完成来源确认为 B。
- 选择“再等等”，完成 D → 没有提示返回未完成 A，也没有错误宣称全屋完成。
- 重新进入详情，答案和 A 的备注保留，没有重播提示。

截图及状态：`apps/wechat/artifacts/forward-only/native/`，重点为 `02-B-to-C.png`、`04-B-skips-C-to-D.png`、`05-no-backtracking.png`、`assertions.json` 与 `receipt.json`。构建快照 hash：`ac88e146a14d28c3b60c523416f28e9cc5dd4838af0c14b2e11b55d83ce1b463`。

基础设施记录：首次 run `d9467fe6f480421db5ddd5db967846f8` 仅排队超时，没有执行点击；后续正常获得槽位。CUA 坐标点击出现 `noWindowsAvailable`，使用同一已租用窗口的原生可访问性按钮成功操作，没有替换为 handler 调用。

主 agent 已在 PR 创建后独立检查远程最终 diff、9 个文件范围、失败/通过日志和上述原生证据，未发现需要返工的问题。核对时 main 仍为 `591f135d3216a60efe53124069bdb14a8225787d`，GitHub 可合并，未返回 workflow runs 或 commit statuses；不将空列表称为 CI 通过。PR #76 保持草稿，UI 效果等待用户确认，未合并、未发布。

## 位置回归及最终证据等价

旧脚本的 run `f8d2ff245e3e446a8e72aad847b045df` 在首个设置页的导航成功回调等待中超时，尚未填写。将脚本准备阶段改为等待实际路由（提交 `0f6f35b`），保留所有后续业务与位置断言。单独重跑 `xiaoda-wait-native.cjs` 的 run `87c12b2313ed4bdbaca2b34b6ab28f54` 通过：原生点击 B 的最后答案后推荐 C，点击“再等等”后 B 最后一项的 top 从 180px 恢复为 180px，阶段/筛选/折叠/答案不变，重开仍保留答案且不重播提示。receipt 为 passed，槽位归还 idle；本地附件位于 `apps/wechat/artifacts/forward-only/wait-native/`。

`7da997d → 0f6f35b` 仅改 `tests/e2e/xiaoda-wait-native.cjs` 的导航等待一行，生产源码、三个已验证单测文件、主流程 E2E、构建脚本与依赖无差异。两个提交的 `apps/wechat/src` tree 都为 `456f7c161d4ff132953d5064a36478f327cf26ea`。因此复用 74 项单测、官方编译和主流程实际点击证据；新导航准备逻辑由该位置回归的成功重跑验证。之后仅补充本记录，未改变代码、测试或构建输入。两个测试构建仅使用各自可丢弃的数据根名称，不修改业务配置。

命令（工作目录 `apps/wechat`，Node 使用本机 24.19.0）：

```sh
node node_modules/vitest/vitest.mjs run tests/xiaoda.test.js -t 'completion recommendations'
node node_modules/vitest/vitest.mjs run tests/xiaoda.test.js tests/onboarding.test.js tests/onboarding-wait-position.test.js
WECHAT_TEST_DATA_ROOT=xunju-test-xiaoda-forward-20261024 npm run build
npm run check
node tests/e2e/xiaoda-filling-fixtures.mjs
```

两个原生测试均通过固定 pool.py 入口以 `WECHAT_POOL_UI_REVIEW=1`、明确任务 dist 和脚本绝对路径执行；完整 command、版本、提交和快照见对应 receipt。只选择这两条 UI 路径，未运行完整既有 UI 套件。

## 直接完成最后现场项的阶段选择（2026-10-24）

手机验收指出：直接填写“电路网络与隐私”后，没有“看看其他房子 / 去填写”的阶段选择。`2ae4c87` 的阶段分支仍要求所有现场类别完成，前面有空项时会生成普通 `next` 提示。本次仅将阶段选择条件改为“完成来源是现场项，向后的实际目标是费用与合同”；全屋完成、顺序与不回头规则不变。前面有遗漏时使用中性文案，不错误宣称现场已全部完成。

代码及测试提交：`42c4741e97fc5eb0728f3f459a42de195b240c95`。新增精简/详细真实模板、继续下一个现场项、跳过已完成费用项，以及两个页面选择分支的回归。修复前的断言均能复现 `kind: next` 而非 `phase`；详细模式初始测试漏填“没有宽带”后新增的条件字段，保留该准备失败，修正为逐项读取有效字段后在原源码上复现相同业务失败。

验证映射及结果：

- `xiaoda-flow.js` 的来源/目标阶段与提示文案：`tests/xiaoda.test.js`，包含真实详细/精简模板和原向后规则。
- 提示排队、阶段锚点、接受与返回：`tests/onboarding.test.js`，新增两个分支用例；原生产页面计时、取消和切换保护全部保留。
- 原向后推荐的位置恢复：`tests/onboarding-wait-position.test.js`。
- 三个文件共 79 项：首轮 78 通过、1 项详细模式准备失败；仅补齐动态条件字段后精确重跑两种模式 2 项通过，未改动生产源码。组合为 79 项通过。日志位于 `apps/wechat/artifacts/forward-only/phase-boundary/` 的 `red.log`、`detailed-red.log`、`focused.log`、`modes-green.log`。
- build、官方 wcc 20 WXML / wcsc 22 WXSS 通过；旧渲染夹具的跨阶段预期同步为 `phase`，构造断言通过。未执行全量测试。

新增原生点击脚本 `tests/e2e/xiaoda-phase-native.cjs` 使用未裁剪的精简模板、空房源、独立测试数据。run `e3dbdd745e2a4bffa97cae4f512d5bfb` 在干净 `42c4741` 上通过，快照为 `be5774899701102bf043ae558c224b6722be3cb21fc24cf9b4956d80d468faf3`。两轮均由 CUA 点击四个真实结果按钮，确认其余项未填写，提示在屏幕内可见，再分别点击“去填写”和“看看其他房子 → 返回房源列表”，费用展开、回到列表及答案保留断言均通过。未直接调用被测 handler，不宣称物理手机已验收。收据、截图及状态归档在 `phase-boundary/native/`。

本次相对 `2ae4c87` 的唯一生产变化是现场转费用分支的条件与文案，原 A/B/C/D 与位置脚本全部类别均为现场，无法进入该分支；模板顺序、目标选择、onboarding 生产代码及两条原脚本未改。因此复用前两条原生点击证据，用新增阶段选择路径覆盖本次变化。后续文档提交不改变源码、测试、构建输入或选择。PR #76 继续保持草稿，等待手机效果确认，未合并发布。

## 阶段选择严格取决于最后现场位置

用户进一步明确：“不是说看完电路网络与隐私，而是说看完在清单列表中现场检查的最后一项的时候，才出现这个”。上一版没有绑定类别名称，但条件“现场来源 + 费用目标”仍过宽。现在只在本次完成的类别等于该房源保存顺序中最后一个有效现场类别时提供阶段选择；模板排序和停用后，实际最后项的名称可变化。较早类别即使已无其他未完成现场项，也不提前提供这个二选一。普通向后目标选择及全屋确实完成时的提示不变。

生产与测试提交 `523a57e91ae7937127f533bcec6816de2de188be`。新增回归覆盖最后项已完成后再写较早项、不同名称与保存顺序、费用穿插在现场类别之间。前一版 `c58a091` 上两项按预期失败（错误产生 `phase`）；名称/排序用例已通过，证明原先并非名称硬编码。修改后重跑三个受影响 Vitest 文件共 82 项全部通过；build 与官方 wcc 20 WXML / wcsc 22 WXSS 通过。完整日志在 `apps/wechat/artifacts/forward-only/last-onsite/`。

新增 `tests/e2e/xiaoda-last-onsite-native.cjs` 在完整精简模板里将“隔音与噪音”排到现场列表最后。原生点击 run `a3af341a550646ca9967bf1f30cbeb2f` 在干净 `523a57e` 上通过，快照 `65423204a9e329a08341e4e52e62f19aa4c88d8386da3b3841a76f27698c136d`：完成前面的“电路网络与隐私”只显示普通下一项提示；实际点击进入并完成最后的“隔音与噪音”，才显示阶段二选一；接受后进入费用与付款，五个答案保留。截图、状态、收据在 `last-onsite/native/`。夹具只准备模板和空房源，填写和接受均为 CUA 原生点击，不直接调用被测 handler。

相对 `c58a091` 唯一生产变化为阶段来源必须是最后现场类别。原默认模板阶段测试 `e3dbdd745e2a4bffa97cae4f512d5bfb` 的来源原本就是最后现场项，条件仍为真；原 A/B/C/D 与位置测试没有费用目标，条件仍为假；onboarding 生产逻辑、原脚本、模板内容、构建配置均未变，因此复用这三条未受影响的真实点击证据，新换序脚本覆盖本次条件差异。后续文档提交不改变执行输入。主 agent 复核条件、顺序与截图，草稿 PR 仍等待用户手机确认，未合并发布。

## 费用与合同结束后可先等等

按用户补充，完成费用与合同最后一个有效大项时提供结束引导，左侧“先等等”、右侧“返回房源列表”。前面有遗漏时使用中性文案，整套确实完成时保留原完成文案。所有返回引导共用左侧等待按钮：只清除当前提示，不关闭小搭、不设置新房源引导、不导航、不动答案。返回提示是固定悬浮层，不改变页面流或滚动位置，因此沿用 `waitFilling` 的无位置快照分支即可。

业务及测试提交 `f71ee80a1dfeb00bae251f5ee20c9048a69fe61b`。`xiaoda-flow.js` 新增最后合同项结束分支；`onboarding.fillingCurrent` 沿用生成规则校验该来源，允许前面有遗漏时显示结束提示，同时保持来源完成、服务切换、输入中断等校验；WXML 增加左侧按钮。普通下一项及最后现场项的阶段规则不变。

定向映射：最后合同项/排序/中性文案由 `xiaoda.test.js` 覆盖；等待不导航、不滚动、不重播、答案/展开状态保留、返回按钮、撤销和存盘失败由 `onboarding.test.js` 覆盖；原“再等等”位置恢复由 `onboarding-wait-position.test.js` 覆盖。基线 `c4c5e89` 的 5 项回归按预期失败，修复后三个文件共 87 项全部通过。build、官方 wcc 20 WXML / wcsc 22 WXSS、更新后的渲染夹具构造断言通过；未执行全量测试。完整日志在 `apps/wechat/artifacts/forward-only/finish-wait/`。

新增 `xiaoda-finish-wait-native.cjs` 使用完整精简模板，仅准备合同类别最后一个结果尚未填写，其余阶段仍为空。run `c40158c7314b4b59b29fd9549014ae01` 在干净 `f71ee80` 上 passed，快照 `cfdfa8622cd724527a0878095f70d5a77b33acfa653660c583fb04f2cc791aea`。CUA 原生点击最后答案后显示中性结束文案和左右两个按钮；点击“先等等”后仍在详情页，最后字段 top 为 500px → 500px，答案/备注/筛选/展开状态保留；改写最后答案再次触发，点击右侧后回到列表，重开仍保留记录且没有旧提示。截图、状态、收据在 `finish-wait/native/`，不存在被测 handler 直接调用；物理手机仍待用户验收。

本次只新增费用与合同结束分支、允许该返回提示显示及返回卡片的左侧按钮。此前普通向后与最后现场阶段的来源不属于最后合同类别，且其 UI 为 next/phase 分支；原 B/C/D、位置与最后现场项换序证据仍适用。默认阶段测试的“看看其他房子”随后使用返回卡片，其新增等待按钮由本次真实返回卡片的等待/接受两条路径覆盖。主 agent 已复核生产差异、最终测试和实际按钮位置。后续仅更新文档，不改变执行输入；继续保持草稿，未合并发布。
