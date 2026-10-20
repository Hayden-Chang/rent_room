# iOS 同步开发与验收

基准：远程 main `6a07ecd97fe639e594a8cc5690196921cbe5574e`，2026-10-20 通过 GitHub Connector 再次实时核实。原小程序不变；不依赖历史 HTML 原型。源码拥有 12 个页面、76 个主题、302 个检查字段、13 个顶级分类、55个检查分组。原始字段总数不等于当前进度分母：无答案的新房源实际为0/204，之后受条件和分组答案影响。清单真源仍为 `apps/wechat/data/source-tree.json`；逐项基准见 [源码对照审计](SOURCE_PARITY_AUDIT.md)。

## 目标与当前阶段

以 SwiftUI 原生实现同一套功能与 UI。保留现有免费两套有效房源、免登录本机使用、微信登录、归档不占容量、账号隔离以及本机记录和媒体边界，增加手机号短信验证码及 Apple 登录入口。

首批组件为 `APPROVED`（用户明确回复“确认通过，继续完整业务开发”）：独立原生组件、DEBUG 评审宿主和测试已完成，6项定向单测、3项UI测试通过；7张真实截图已由主 agent 检查并展示。证据提交为 `e70ce5062b1db70b9d8469ba3aa6ed95f40afbf2`，详见 [组件验收证据](COMPONENT_REVIEW.md)。已取得用户批准，正在接入完整业务。Release 不提供评审入口，本阶段产物不是可发布的完整应用。

## 页面与功能对照清单

| 原页面 | iOS 必须保留的行为 | 实施状态 |
| --- | --- | --- |
| home | 两列房源卡片、空状态、新建/重命名、长按归档/单房源ZIP导出、容量限制；删除仅在归档页 | 已接真实本机 store；新建/归档与重启核对已通过原生交互验证，重命名与单套导出接线待补操作覆盖 |
| detail/清单 | 同一完整表单、阶段/搜索/多选筛选、默认折叠、条件可见、不涉及、选项/文字/数字/日期、左滑问题/备注/拍摄、动态费用 | 选项/折叠/左滑组件已批准；规则已复用并完成核心单测；完整页面已接入并进行原生验证 |
| detail/影像 | 照片/视频、筛选、预览、备注、关联检查项、删除 | 三列影像与独立备注已接；测试JPEG/MP4经真实转换/持久化/预览及重启通过，系统相册呈现/取消通过；真实系统选择与相机仍待验收 |
| detail/问题 + issue | 自动问题与手动问题、描述/媒体、解决/重开、编辑保存 | 手动问题及媒体草稿/保存/放弃/失败重试/重启/归档只读通过；自动问题原位编辑与问题卡片内嵌影像仍待补齐 |
| detail/总结 | 三种意向、总结备注、本机保存 | 第二批组件已批准并接入真实保存；原生重启核对通过 |
| compare | 选择2至3个未归档房源、字段与结果、问题摘要、隐藏相同属性 | 已接同源 comparison；真实选择/差异开关/表格操作通过，新增页面组合已批准 |
| settings | 可选登录、容量、上班地点、归档、操作引导、备份、权限、版本、退出 | 登录组件已批准；设置/归档/备份和手工上班地点已接线；其余见页面记录 |
| archive | 只读查看、长按还原/彻底删除、还原容量校验、删除失败保护 | 已接入，真实只读/还原与重启核对通过；容量与失败回滚已有核心单测 |
| templates | 已注册的完整/自定义模板页面、基础信息与控制项必留；当前无菜单入口，且store.add未使用默认模板设置 | 记录既有边界；不额外添加入口或宣称新建模板已生效 |
| import | 仅本应用ZIP；媒体、预览、多选、覆盖/新增副本、原子保存/容量净增校验；不覆盖本机全局设置 | ZIP核心双向兼容及失败/容量/账号保护通过；文件选择/房源多选/覆盖/新增副本/生成分享页面已接入；UI导出生成通过，文件选取导入与真实发送仍未操作验收 |
| speed-test | Wi-Fi确认、蜂窝流量确认、下载Mbps、完成自动回填、旧值并发修改/取消/失败保护 | 第五批已批准并接完整页面；固定范围传输下两步确认/回填8.39/重启、拒绝/取消保留手工值、重复进入、后台取消及重试通过；真实测速未验收 |
| workplace | 搜索/定位/手工地址、地图联动与持久化 | 已接实际页面；固定HTTP下搜索选点、手工保存/清空及重启通过；真实CoreLocation权限配合XCTest模拟坐标，附近使用/保存/重启通过；真实GPS与供应商仍未验收 |
| commute | 通勤查询、数据有效性校验、确认回填 | 第四批已批准并接业务页，固定HTTP下实际起终点选取/路线确认/回填24分钟/重启通过；真实供应商尚未验收 |
| capacity | 房源包、购买/恢复、服务端权益、退款和幂等 | 待实现；原生支付需 StoreKit 适配 |
| shared | 保存失败与恢复、上次数据副本、身份目录隔离、跨平台备份兼容、引导 | 保存/恢复、账号目录/认领、ZIP核心通过定向单测；第四批引导已批准并接首次新建，真实锚点/四步/左滑/偏好及重启通过 |

## 视觉来源

`apps/wechat/src/app.wxss`：底色 `#F5F7FB`、文字 `#1C2638`、次要文字 `#667187`、主色 `#4D56DF`、选中底 `#ECEEFF`、分割线 `#E5E9F1`、问题色 `#BB4149` / `#FFF0EF`。卡片圆角16、页面边距16、按钮高度至少44。房源卡片图片区142、正文144、列间距10。图标及空状态图直接复用原 PNG，许可证随资源保留。

第一批评审包括房源卡片/空状态、清单选项/折叠/左滑、账号卡片与短信表单。清单样例使用真实 `fieldView` 显示契约：“纱窗正常”显示“是/否/没有”，底层值仍为“正常/有问题/没有”；另一行采用“密封条正常”。新增 Apple 按钮使用 AuthenticationServices 的官方 `SignInWithAppleButton`。组件回调不代表完成业务；评审宿主明确不写磁盘、不建立账号、不发放容量。短信服务未接通时真实呈现错误，不显示发送成功或登录成功。

## 身份与平台待接入项

线上接口仍只有微信 `POST /session`；新后端接口尚未部署。手机号需要短信供应商、验证码限流/过期/校验与正式服务端会话；Apple 需要开发者团队、最终 Bundle ID/能力、nonce 与服务端凭证验证。不得将手机号或 Apple user identifier 直接视为可信后端账号。认证令牌不得进入房源备份。

现有服务在 `model_server` 的独立 FastAPI `rent-room-api`；已在独立后端 [Draft PR #87](https://github.com/Hayden-Chang/model_server/pull/87) 扩展同一服务，未部署。不新增第二套独立身份库。是否关联不同登录方式须在服务端明确定义，不能凭邮箱相同自动合并账号。

数字扩容在原生 iOS 中需适配 StoreKit 商品与验证，不直接调用微信虚拟支付；商品配置及真实交易验收单独记录。记录和媒体继续在本机，不因新增登录自行增加云同步。

## 原生工程与测试

工程真源为 `ios/project.yml`、`.xcodegen-version`、Swift 源码和测试。`scripts/run-xcodebuild.sh` 先运行本项目新建的 `scripts/check-xcodegen.sh`，核对固定版本2.45.4、生成确定性与三个 target。生成的 `ios/Xunju.xcodeproj` 不提交。最低 iOS 17；Bundle ID `com.keeline.xunju.ios` 暂用于开发，正式签名前再核对归属。

使用共享 Simulator Management runner 的实时配置及租约，不直接操作其他模拟器。所有 DerivedData、`.xcresult` 和计划均位于外部唯一目录。下表是首批组件的精确选择，不是当前完整App的最终head计划；完整业务完成后按最终风险重新确定最多3项最终UI。所有新增测试在开发阶段执行。

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

## 业务核心进展

完整页面进展见 [BUSINESS_PAGES.md](BUSINESS_PAGES.md)。原生业务核心和认证测试、第二批组件证据及未完成边界见 [BUSINESS_CORE.md](BUSINESS_CORE.md)。首批 UI 的批准不代表完整 App 已交付。

地点、通勤、测速和四步引导的同源桥接、第四及第五批批准、业务接入和定向验证见 [UTILITIES.md](UTILITIES.md)。前五批均已批准，不重复索要批准；问题媒体、部分清单交互和原生购买仍需补齐。

第六批三列影像、问题照片/视频草稿、分类/分组左滑与“不涉及”已获用户批准并接入完整业务。累计19项定向UT及4条业务UI场景通过，含真实文件转换/保存/预览/重启、放弃清理、失败重试与归档只读；历史失败和精确复用依据见 [MEDIA_INTEGRATION.md](MEDIA_INTEGRATION.md)。独立组件的15张截图与审批记录见 [MEDIA_COMPONENTS.md](MEDIA_COMPONENTS.md)。

第七批问题卡片内嵌影像、44pt检查项缩略图与自动问题输入组合已完成独立渲染/操作验证（2UT/2UI有效通过、7张原始截图）。状态REVIEW_READY，等待用户确认，尚未接入业务；见 [RELATED_MEDIA_COMPONENTS.md](RELATED_MEDIA_COMPONENTS.md)。
