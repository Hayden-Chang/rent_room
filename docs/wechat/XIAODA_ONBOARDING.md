# 小搭首次见面实现与验收

需求来源：[小搭首次见面流程与文案](https://chatgpt.com/space/page_f978312f402881919e066ebe0d9bc4c1)。用户本版决定：精简占位、默认详细；不跳过首次流程；旧用户不重走；无需登录也保存进度；开发时更换静态资源包；小搭逐字说话；反馈真实落库；免费1套，购买后续接原新建/恢复动作。

## 实现范围

首次排序可拖动、停用和原位恢复，至少保留一项。模板保存仅影响之后新建的房源。第一次教学使用真实阶段与筛选控件，高亮选项自动展开；左滑步骤必须实际滑动；完成进度跨页面重开恢复。静态图片和语义姿态、打字组件、流程状态相互独立。

填写期间根据实际已处理结果推荐下一类别，备注和媒体不算完成。原始优先顺序与当前房源展示顺序分开，阶段过滤保留。首次完成记录持久化；当前房源/今天/永久关闭有独立作用域。首次返回列表先显示一次性可选反馈，再显示后续新建引导。反馈失败保留输入与请求号，服务端成功确认后感谢。

免费容量改1套；已超额旧房源仍可编辑，归档释放额度。新建/恢复操作意图随登录迁移，购买取消可回退，待确认订单不得提前续接。旧客户端兼容见后端 PR #95。

模板编辑的自定义返回及系统返回使用同一“保存并退出/不保存退出/继续编辑”决策。系统返回通过 page-container 保护草稿，参考[微信官方示例](https://github.com/wechat-miniprogram/miniprogram-demo/tree/master/miniprogram/packageComponent/pages/view/page-container)。iOS边缘返回和Android物理返回尚需真机确认。

## 验证映射

| 生产边界 | 定向测试文件（apps/wechat/tests/） |
| --- | --- |
| 新旧进度、模板、关闭、推荐、资源、打字和反馈 | xiaoda.test.js、first-meeting-runtime.test.js、onboarding.test.js、onboarding-target.test.js、onboarding-icons.test.js、template-fold.test.js |
| 真实左滑事件 | field-row-swipe.test.js、detail-navigation.test.js、detail-filter.test.js |
| 容量规则、续接和支付协议 | capacity.test.js、capacity-runtime.test.js、billing.test.js、capacity-config.test.js |
| 本机持久化、账号迁移、页面隔离 | model.test.js、parking-recurring-cost.test.js、cost-phase.test.js、guest-storage.test.js、account-runtime.test.js、account-storage.test.js、platform.test.js、runtime.test.js、settings-simplification.test.js |
| 容量影响导入、备份及错误回滚 | transfer.test.js、transfer-page.test.js |
| 构建入口与配置 | auth-build-config.test.js、map-build-config.test.js、官方wcc/wcsc检查 |

使用 Node24.19.0，运行上述26个文件，不运行全量本地测试。后端 Python3.12.14 隔离环境执行 `test_rent_room_capacity.py` 与 `test_rent_room_feedback.py`，77项通过；首轮缺少PyYAML的环境问题已修复。前端旧用例中依赖“免费2套”的夹具已改为新边界或明确使用已购包，保留原数据回滚与账号隔离断言。

## UI证据与限制

工具：WeChat DevTools2.01.2510290，基础库3.17.3，共享实例池第3槽，可丢弃 `xunju-test-xiaoda-20261023` 数据。小程序源码由runner冻结。`tests/e2e/xiaoda.cjs` 执行真实点击/拖动/左滑，但本机 SDK 在首个 Page 元素查询处超时；失败保留于 run `4e16a24889904e4cae4066440ba1f0eb`。桌面控制按完整第3槽App路径连接也连续超时，未接管其他实例。

`tests/e2e/xiaoda-render.cjs` 是明确的渲染补充：用状态夹具和导航生成真实工具像素，不能替代点击验收。已发现并修复 WXML 换行显示为实体、步骤4重开后动作栏未展开：根因是跨原生view的组件选择器返回空，按已渲染组件的真实字段ID重新定位。原失败画面及诊断保留于 runs `d6987b909bcf42e9ab239b248ff470d1`、`cec81516c7704502a6b202820e544dbf`。

首次交付代码提交：前端 `5fb6fca012c5451a3a9caf1f38c62954d8dfdc86`，后端 `e2693cef687043b4aa17726197b3f9d92bf662ae`。前端26个文件共263项、后端77项定向测试通过。官方wcc/wcsc编译通过，15个页面，构建体积1,977,479字节。当次文档归档提交33c0dbe未改变已验证代码；后续展示调整见下节。

首次交付渲染run为 `84e5972badc94f30be8d05faae47fcc2`，sourceHead与上述前端提交一致，sourceStatus为空，冻结源码摘要 `9b3174a168b36ef7528f8c610043482ea50c89d98d30b964c1a49b19e05bd9eb`。13张截图覆盖排序、模式、首次新建、四步教学、基本信息、反馈、容量、模板与命名；步骤4实际字段动作栏展开，offset为-132。运行结束后第3槽恢复idle，未保留任务租约。

本地归档位于本工作树的 `artifacts/xiaoda-20261023/`，`index.html` 为截图索引，另含运行收据、范围声明、编译与测试日志和交互失败收据。原始工具池证据根：`/Volumes/mac2/codex-builds/wechat-instance-pool/runs/`；测试日志根：`/private/tmp/xiaoda-validation/`。主工作区未修改，未部署、未发布、未实付。

当前 UI 门禁未通过：需恢复交互工具或在真机检查排序、五种筛选、左滑后三个按钮、模板三选退出，以及支付/登录后续接；还需用户确认视觉效果。不得因渲染测试或单测通过而合并。


主线在开发期间前进到4422ab4（停车费分组与回家路线文案），已无冲突合入任务分支，重新生成清单并补充停车费/阶段、详情导航/筛选组合验证。审查补充：用户主动切阶段、搜索、折叠、切页或开始填写时收起旧提示，取消待执行的自动滚动。

当前agent已审查最终代码差异，覆盖资源解耦、进度迁移、推荐中断、保存回滚、容量协议兼容和反馈入库，未发现新的代码阻断项。上述UI与真机验证缺口仍是合并门禁。交付为草稿 [前端PR #56](https://github.com/Hayden-Chang/rent_room/pull/56) 和 [后端PR #95](https://github.com/Hayden-Chang/model_server/pull/95)，后端协议须先上线再发布前端。


## 排序页标注调整（2026-10-23）

按用户截图删除自我介绍中的“你的看房搭子”和列表上方两行操作说明；垃圾桶改为固定红色线框图标，按钮右侧留12px外边距，按钮宽48px、图标宽24px。首次排序与模板编辑复用同一组件，停用/恢复和拖动事件均保留。实际截图发现全局 `button:not([size=mini])` 覆盖原间距，已提升局部选择器优先级后核对内移生效。

代码提交 `3a0268896e847fc8497be45640a12d4deb3e608a`。与前次交付 `33c0dbe` 相比仅5个welcome/template-editor展示文件变化；业务状态、存储、接口和测试配置不变，保留此前未受影响的验证证据。本次重跑 `first-meeting-runtime.test.js`、`xiaoda.test.js`、`template-fold.test.js`、`settings-simplification.test.js` 共29项通过；官方wcc/wcsc编译通过，构建体积1,978,111字节。不为纯文案和样式新增镜像实现测试。

状态读回辅助脚本在截图后触发SDK `Function has non-object prototype 'undefined' in instanceof check`，更改返回值格式仍未解决。保留失败runs `aedb943cf0e3422d809d56b9c399e39c`、`9b9fb1d9a5954ac6ad3a1fc6e8d03d45`、`9e76cb5609a04c609f81e659979463a0`；其中后两次排序页截图已实际核对文案、图标及内移。该异常未证明已修复，也不作为交互通过证据。PR仍为草稿，首次流程的真实交互与用户视觉批准门禁维持未通过。


后续纯截图补拍run `a7d51034f9db49d884a46cbea0b9854c` 也在工具接口报错，未取得新的模板页画面。最终交付排序页采用run `9b9fb1d9a5954ac6ad3a1fc6e8d03d45` 的 `sort-updated.png`，sourceHead为3a02688、sourceStatus为空；此图已人工核对，但整个辅助脚本结果仍为failed。归档位于 `artifacts/xiaoda-20261023/sort-revision/`，包含四次收据、日志、截图及回调；预览页已将旧模板截图明确标注为待更新。池收据记录任务结束，实例恢复idle。未继续改动业务代码或操作其他任务实例。

## 阶段文案与关键词强调（2026-10-23）

阶段按钮展示为“全部 / 基本情况 / 现场检查 / 费用与合同”，仍使用原阶段筛选值，不改存档、分组或筛选行为。保留开头说明，后续三行使用用户指定文案：

- 看房前—了解房屋基本情况
- 看房中—现场检查房屋细节
- 选定后——核对费用与合同条款

“基本情况”“现场检查”“费用与合同”使用黄色加粗；删除“想一起看，就选‘全部’”。小搭接收独立highlight词组，以纯文本分段显示；逐字输出途中即强调已显示的关键词字符，完整占位与可见文字使用相同字重，避免换行抖动。无highlight的普通台词保持原样。

代码 `3b999adc2a978d6dc4afe1928302fc108dbf9af5`：新增 `xiaoda-speech.test.js` 3项，覆盖部分关键词、Unicode/空文本、隐藏暂停/继续和替换消息。重跑该文件及 `xiaoda.test.js`、`onboarding.test.js`、`onboarding-target.test.js`、`onboarding-icons.test.js`、`detail-filter.test.js`、`detail-navigation.test.js`、`first-meeting-runtime.test.js`，8个文件59项通过；官方编译通过，1,979,302字节。与384da06相比仅详情展示、小搭文字组件及新文本分段函数/测试变化，其余业务与后端证据仍适用。

实际渲染run `677f736380eb43398d8308df56de63ae` 通过，冻结源码3b999ad且工作树干净，第3槽结束后恢复idle。`phase-complete.png` 已核对三阶段名称、三个黄色加粗词组、删除的结尾及按钮无截断；归档在 `artifacts/xiaoda-20261023/phase-revision/`。两次截图都已完成文字输出，不能作为逐帧动画证据；逐字中途强调、暂停及消息替换由新增组件计时器测试验证。该run使用前置数据与导航，不替代真实点击/手势验收。

## 筛选教学标注调整（2026-10-23）

筛选按钮增加展开/收起箭头：收起时向下，展开时向上。第2步进入和续接时自动展开选项，高亮目标从整个搜索/筛选区域改为具体的 `#filter-options`；文案为“点击里面的内容可以筛选哦”。“知道啦”不再因尚未展开或未选择条件而禁用，可直接进入左滑教学。筛选的多选语义、已有记录和第3步的真实左滑要求保留。

生产代码为 `f681d1a9716e7551c42c02e6ee3f4ee979e7abc5`。新增2项回归在修改前均以预期行为失败：选项未自动展开；继续按钮被展开状态阻挡。修改后 `onboarding.test.js`、`onboarding-target.test.js`、`onboarding-icons.test.js`、`detail-filter.test.js`、`detail-navigation.test.js`、`xiaoda-speech.test.js` 共6文件41项通过，官方wcc/wcsc编译通过，1,979,721字节。后续7baf99f和1d028cf仅调整E2E选择器/日志，生产源码和上述单测与环境均相同，复用41项结果；改动的两条E2E分别执行并单独报告，不复用其旧结果。

局部交互run `76e8e2c87d764d4d9eb1e1094d1f56da` 已取得真实筛选教学截图，且读回确认第2步、展开状态及布局ready；点击步骤在SDK元素查询/调用边界超时，未取得真实点击通过证据。截图已人工确认选项区域高亮、输入框变暗、展开箭头、指定文案和明亮的确认按钮。改用类选择器的诊断run `a2330d777ee44da8ac948ad0a197c437` 在夹具初始化时遇到SDK异常，未能完成选择器比较。保留两次失败，不将渲染或单测算作E2E通过。

完整E2E run `8afe0520c64f4a3ab2cab8b4350a6759` 在首个排序编辑器查询超时，未进入筛选阶段；冻结源码为1d028cf且工作树干净。三次运行均已结束，第3槽恢复idle。最新截图和三次收据、日志及本次编译/回归日志归档在 `artifacts/xiaoda-20261023/filter-revision/`；截图索引已替换筛选教学画面。后续仅更新文档，生产代码与上述测试及截图对应版本相同。当前agent复核本次差异，未发现新增代码阻断项；真实交互与用户视觉批准仍未通过，PR保持草稿。

## 容量页文案精简（2026-10-23）

按用户标注删除三处说明：“当前未归档房源 / 额度上限”、“每套未归档房源占用 1 套额度，归档或彻底删除后释放。额度无有效期。”和“购买前需微信登录，登录后继续当前操作。”只修改容量页WXML，额度数字、套餐标题、购买/稍后/恢复按钮及恢复房源场景提示保留，容量、登录、支付和续接逻辑不变。

生产代码ff07539。构建后执行 `capacity.test.js` 与 `capacity-runtime.test.js` 共2文件29项通过；官方wcc/wcsc编译通过，15页面，1,979,424字节。纯文案删除不新增镜像测试，其余未受影响的既有证据继续适用。

实际渲染run `5861c3134bd541c3a40e08da762dfa2f` 通过，源码背景为ff07539，工作树仅有本文档改动；应用源码与已测试提交相同，冻结摘要 `3b420208df1be3b5a9cafca57200313b63224c0a61f4fe745633327366998a5a`。三处说明消失、卡片间距及按钮显示已人工核对。前一次run `d4804db3cf6f422e914ad625210473fd` 在SDK导航报错，保留原失败；第二次仅调整截图脚本为原生页面导航并核对路由，未修改业务。两次结束后第3槽均恢复idle。截图、回调、日志和收据归档在 `artifacts/xiaoda-20261023/capacity-revision/`，预览页已替换旧容量图。本次只验证展示，不增加登录或支付交互通过的声明。主agent已复核本次单一WXML差异，PR保持草稿，未合并发布。
