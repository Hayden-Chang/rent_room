# 小搭填写引导截图覆盖

需求：[小搭首次见面流程与文案](https://chatgpt.com/space/page_f978312f402881919e066ebe0d9bc4c1)。用户在2026-10-23要求补齐基础信息、各种下一项推荐、返回和下一套房源的截图。

以下每一行计划补拍一张独立的真实小程序截图。当前新截图为0/31，尚未完成，不代表以下画面已验收。截图准备使用真实清单快照和生产store计算推荐，后续状态由生产控制器构造；这属于渲染覆盖，不是用户真实点击、登录、支付或反馈服务验收。不得将缺少的截图替换成手绘界面。

| 编号 | 场景 | 截图文件 |
| --- | --- | --- |
| 01 | 首次引导填写基本信息 | `01-basic-intro.png` |
| 02 | 介绍结束后自动展开基本信息 | `02-basic-expanded.png` |
| 03 | 已停用基本信息：引导首个保留大项 | `03-no-basic.png` |
| 04 | 首个保留大项自动展开 | `04-no-basic-expanded.png` |
| 05 | 基本信息完成：推荐现场检查 | `05-basic-to-onsite.png` |
| 06 | 没有现场大项：直接推荐费用与合同 | `06-basic-to-contract.png` |
| 07 | 现场大项完成：下一项尚未填写 | `07-onsite-new.png` |
| 08 | 现场大项完成：优先续写最近填写过的项 | `08-onsite-partial.png` |
| 09 | 接受推荐：保留已填内容并展开下一项 | `09-partial-expanded.png` |
| 10 | 现场全部完成：继续填写或看看其他房子 | `10-onsite-complete.png` |
| 11 | 继续填写：切换并展开费用与付款 | `11-contract-expanded.png` |
| 12 | 费用完成：推荐尚未填写的合同 | `12-contract-new.png` |
| 13 | 费用完成：继续已填写一部分的合同 | `13-contract-partial.png` |
| 14 | 先写完费用与合同：回到未完成现场 | `14-cross-onsite.png` |
| 15 | 跨阶段填写：只剩基本信息 | `15-cross-basic.png` |
| 16 | 整套完成：引导返回房源列表 | `16-whole-complete.png` |
| 17 | 首次返回：先展示可选反馈 | `17-return-feedback.png` |
| 18 | 结束反馈：高亮入口添加第二套 | `18-second-invite.png` |
| 19 | 新增第二套：额度不足衔接小饼干 | `19-second-capacity.png` |
| 20 | 现场完成后选择先看其他房子 | `20-other-choice.png` |
| 21 | 看看其他房子：引导返回 | `21-other-return.png` |
| 22 | 返回列表：引导添加第二套 | `22-other-invite.png` |
| 23 | 先等等前：推荐续写未完成项 | `23-wait-before.png` |
| 24 | 先等等：提示消失并保留填写进度 | `24-wait-hidden.png` |
| 25 | 重新进入：不重复旧完成提示 | `25-reopen-hidden.png` |
| 26 | 另一个大项首次完成：重新推荐待续写项 | `26-new-completion.png` |
| 27 | 仅备注和问题标记：不触发完成引导 | `27-notes-only.png` |
| 28 | 关闭小搭：完成大项后不弹填写提示 | `28-disabled.png` |
| 29 | 第二套房源：直接引导填写基本信息 | `29-second-intro.png` |
| 30 | 基本信息最后完成：只显示整套完成 | `30-basic-last.png` |
| 31 | 只保留现场大项：完成后直接引导返回 | `31-only-onsite.png` |

脚本：`apps/wechat/tests/e2e/xiaoda-filling-fixtures.mjs`、`xiaoda-filling-render.cjs`。截图及运行记录：`artifacts/xiaoda-20261023/filling-cases/`。

本次应用生产代码未改动，仍对应ff07539；重新构建后，`xiaoda.test.js`、`onboarding.test.js`、`first-meeting-runtime.test.js`共3文件30项通过，官方编译通过，1,979,424字节。夹具生成时校验了推荐种类、目标与完成状态；夹具中的状态准备和直接控制器调用不冒充点击。

## 当前阻碍

首轮run `24143e9d46f943cb812dbdde372bbdab` 和诊断run `dbbc8a2208b54b73a1dcb21b424c129c` 均在页面状态探针报 `Function has non-object prototype undefined in instanceof check`，尚未取得新图，原始日志与收据已保留。移除组件查询后仍失败，已进一步将注入探针改为与应用ES2018构建目标兼容的基础语法；该改动尚未在开发者工具验证，不能称为已修复。公开搜索未查到适用当前工具版本的官方修复，官方自动化页面本次无法读取，不据第三方建议替换共享运行时。

第三次最小场景run `2391d34b823d4d2f947f4ad6f0c923eb` 排队期间，三槽均处于quarantined。第3槽由另一任务健康检查失败后隔离；本任务没有重启其他任务的实例、清用户缓存或绕过租约。按照工具池维护约定，已请求用户授权恢复第3槽，收到前不进行恢复。PR保持草稿，当前工作仅增加待执行的截图覆盖与记录。
