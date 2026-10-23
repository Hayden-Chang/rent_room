# 小搭首次见面实现与验收

需求来源：[小搭首次见面流程与文案](https://chatgpt.com/space/page_f978312f402881919e066ebe0d9bc4c1)。用户本版决定：精简占位、默认详细；不跳过首次流程；旧用户不重走；无需登录也保存进度；开发时更换静态资源包；小搭逐字说话；反馈真实落库；免费1套，购买后续接原新建/恢复动作。

## 实现范围

首次排序可拖动、停用和原位恢复，至少保留一项。模板保存仅影响之后新建的房源。第一次教学通过真实阶段/筛选/左滑控制展开；完成进度跨页面重开恢复。静态图片和语义姿态、打字组件、流程状态相互独立。

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

最终代码提交：前端 `5fb6fca012c5451a3a9caf1f38c62954d8dfdc86`，后端 `e2693cef687043b4aa17726197b3f9d92bf662ae`。前端26个文件共263项、后端77项定向测试通过。官方wcc/wcsc编译通过，15个页面，构建体积1,977,479字节。此后的文档归档提交不改变已验证代码。

最终渲染run为 `84e5972badc94f30be8d05faae47fcc2`，sourceHead与上述前端提交一致，sourceStatus为空，冻结源码摘要 `9b3174a168b36ef7528f8c610043482ea50c89d98d30b964c1a49b19e05bd9eb`。13张截图覆盖排序、模式、首次新建、四步教学、基本信息、反馈、容量、模板与命名；步骤4实际字段动作栏展开，offset为-132。运行结束后第3槽恢复idle，未保留任务租约。

本地归档位于本工作树的 `artifacts/xiaoda-20261023/`，`index.html` 为截图索引，另含运行收据、范围声明、编译与测试日志和交互失败收据。原始工具池证据根：`/Volumes/mac2/codex-builds/wechat-instance-pool/runs/`；测试日志根：`/private/tmp/xiaoda-validation/`。主工作区未修改，未部署、未发布、未实付。

当前 UI 门禁未通过：需恢复交互工具或在真机检查排序、五种筛选、左滑后三个按钮、模板三选退出，以及支付/登录后续接；还需用户确认视觉效果。不得因渲染测试或单测通过而合并。


主线在开发期间前进到4422ab4（停车费分组与回家路线文案），已无冲突合入任务分支，重新生成清单并补充停车费/阶段、详情导航/筛选组合验证。审查补充：用户主动切阶段、搜索、折叠、切页或开始填写时收起旧提示，取消待执行的自动滚动。

当前agent已审查最终代码差异，覆盖资源解耦、进度迁移、推荐中断、保存回滚、容量协议兼容和反馈入库，未发现新的代码阻断项。上述UI与真机验证缺口仍是合并门禁。交付为草稿 [前端PR #56](https://github.com/Hayden-Chang/rent_room/pull/56) 和 [后端PR #95](https://github.com/Hayden-Chang/model_server/pull/95)，后端协议须先上线再发布前端。
