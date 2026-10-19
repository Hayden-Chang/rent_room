# iOS 同步开发与验收

基准：远程 main `6a07ecd97fe639e594a8cc5690196921cbe5574e`，2026-10-19 通过 GitHub Connector 实时核实。原小程序不变；不依赖历史 HTML 原型。源码拥有 12 个页面、76 个主题、302 个检查字段、13 个顶级分类。清单真源仍为 `apps/wechat/data/source-tree.json`。

## 目标与当前阶段

以 SwiftUI 原生实现同一套功能与 UI。保留现有免费两套有效房源、免登录本机使用、微信登录、归档不占容量、账号隔离以及本机记录和媒体边界，增加手机号短信验证码及 Apple 登录入口。

当前为 `REVIEW_READY`：独立原生组件、DEBUG 评审宿主和测试已完成，6项定向单测、3项UI测试通过；7张真实截图已由主 agent 检查并展示。证据提交为 `e70ce5062b1db70b9d8469ba3aa6ed95f40afbf2`，详见 [组件验收证据](COMPONENT_REVIEW.md)。未取得用户批准，尚未接入完整业务。Release 不提供评审入口，本阶段产物不是可发布的完整应用。

## 页面与功能对照清单

| 原页面 | iOS 必须保留的行为 | 实施状态 |
| --- | --- | --- |
| home | 两列房源卡片、空状态、新建/重命名/删除、长按管理、容量限制 | 卡片与空状态组件待评审；业务待实现 |
| detail/清单 | 同一完整表单、阶段/搜索/多选筛选、默认折叠、条件可见、不涉及、选项/文字/数字/日期、左滑问题/备注/拍摄、动态费用 | 选项/折叠/左滑组件待评审；完整规则待移植 |
| detail/影像 | 照片/视频、筛选、预览、备注、关联检查项、删除 | 待实现 |
| detail/问题 + issue | 自动问题与手动问题、描述/媒体、解决/重开、编辑保存 | 待实现 |
| detail/总结 | 三种意向、总结备注、本机保存 | 待实现 |
| compare | 多房源对比、字段与结果、问题摘要 | 待实现 |
| settings | 可选登录、容量、上班地点、归档、操作引导、备份、权限、版本、退出 | 登录组件待评审；其他待实现 |
| archive | 只读查看、还原与有效房源容量校验 | 待实现 |
| templates | 模板和独立清单、模板管理 | 待实现 |
| import | ZIP/表格输入校验、媒体、预览、覆盖/新增副本、原子保存/容量校验 | 待实现 |
| speed-test | Wi-Fi/蜂窝网络实测、单位、结果确认回填、失败保护 | 待实现 |
| workplace | 搜索/定位/手工地址、地图联动与持久化 | 待实现 |
| commute | 通勤查询、数据有效性校验、确认回填 | 待实现 |
| capacity | 房源包、购买/恢复、服务端权益、退款和幂等 | 待实现；原生支付需 StoreKit 适配 |
| shared | 保存失败与恢复、上次数据副本、身份目录隔离、跨平台备份兼容、引导 | 待实现 |

## 视觉来源

`apps/wechat/src/app.wxss`：底色 `#F5F7FB`、文字 `#1C2638`、次要文字 `#667187`、主色 `#4D56DF`、选中底 `#ECEEFF`、分割线 `#E5E9F1`、问题色 `#BB4149` / `#FFF0EF`。卡片圆角16、页面边距16、按钮高度至少44。房源卡片图片区142、正文144、列间距10。图标及空状态图直接复用原 PNG，许可证随资源保留。

第一批评审包括房源卡片/空状态、清单选项/折叠/左滑、账号卡片与短信表单。清单样例使用真实 `fieldView` 显示契约：“纱窗正常”显示“是/否/没有”，底层值仍为“正常/有问题/没有”；另一行采用“密封条正常”。新增 Apple 按钮使用 AuthenticationServices 的官方 `SignInWithAppleButton`。组件回调不代表完成业务；评审宿主明确不写磁盘、不建立账号、不发放容量。短信服务未接通时真实呈现错误，不显示发送成功或登录成功。

## 身份与平台待接入项

现有接口只有微信 `POST /session`。手机号需要短信供应商、验证码限流/过期/校验与正式服务端会话；Apple 需要开发者团队、最终 Bundle ID/能力、nonce 与服务端凭证验证。不得将手机号或 Apple user identifier 直接视为可信后端账号。认证令牌不得进入房源备份。

现有服务在 `model_server` 的独立 FastAPI `rent-room-api`；本分支不部署或修改该服务。后续扩展同一服务，不新增第二套独立身份库。是否关联不同登录方式须在服务端明确定义，不能凭邮箱相同自动合并账号。

数字扩容在原生 iOS 中需适配 StoreKit 商品与验证，不直接调用微信虚拟支付；商品配置及真实交易验收单独记录。记录和媒体继续在本机，不因新增登录自行增加云同步。

## 原生工程与测试

工程真源为 `ios/project.yml`、`.xcodegen-version`、Swift 源码和测试。`scripts/run-xcodebuild.sh` 先运行本项目新建的 `scripts/check-xcodegen.sh`，核对固定版本2.45.4、生成确定性与三个 target。生成的 `ios/Xunju.xcodeproj` 不提交。最低 iOS 17；Bundle ID `com.keeline.xunju.ios` 暂用于开发，正式签名前再核对归属。

使用共享 Simulator Management runner 的实时配置及租约，不直接操作其他模拟器。所有 DerivedData、`.xcresult` 和计划均位于外部唯一目录。最终 UI 选择固定为以下三个方法，排序按认证边界、数据交互、核心展示风险；所有新增测试在开发阶段执行。

| 边界 | 精确测试选择器 |
| --- | --- |
| 原有 PNG 在原生 Bundle 中可解码 | `XunjuTests/ComponentLogicTests/testParityImagesAreAvailableToNativeViews` |
| 原图标真实绘制，防止可解码但全透明 | `XunjuTests/ComponentLogicTests/testParityIconRendersVisiblePixels` |
| 手机号和验证码格式，含空/长度/非ASCII/换行边界 | `XunjuTests/ComponentLogicTests/testPhoneRequiresElevenMainlandDigits`；`testCodeRequiresSixASCIIDigits` |
| 单选反选/切换，不删除其他附属状态 | `XunjuTests/ComponentLogicTests/testChoiceCanClearAndSwitchWithoutCouplingProblemFlag` |
| 仅显式参数启用 DEBUG 评审宿主 | `XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface` |
| 登录入口/禁用状态/服务失败保留输入/不假报发送 | `XunjuUITests/ComponentReviewTests/testLoginEntriesAndPhoneFailureKeepsInput` |
| 同页展开折叠保留答案、单选、真实左滑/备注回调 | `XunjuUITests/ComponentReviewTests/testChecklistDisclosureSelectionAndSwipe` |
| 两列卡片与空状态、真实点击回调 | `XunjuUITests/ComponentReviewTests/testHouseCardsAndEmptyState` |

三项 UI 测试只验证组件。相机、GPS、Apple真实授权、短信发送、服务端登录、支付、完整功能与 UI 对齐尚未验证，不能据本批截图声明 iOS 完成。
