# iOS 与原小程序逐界面 UI 差异清单

核对日期：2026-10-20。下列 25 项保留原始审计结论。后续已实现隔离原生组件并完成增量交互验证，见 [小程序 UI 对齐评审](MINIPROGRAM_UI_REVIEW.md) 和其中的 58 张运行截图；新组件尚待用户批准和业务接入，因此没有将下列项目全部改标为“已解决”。

- 小程序基准：GitHub Connector 当次读取 `main` 为 `6a07ecd97fe639e594a8cc5690196921cbe5574e`。当前工作区 `apps/wechat/src` 与此 SHA 的 Git diff 为空。
- iOS 基准：`codex/ios-parity-20261019` 的 `f8545f605439d730ea2427d5d8e9c7cf641c7746`。与已装到 p10002 的构建源 `87e2383` 相比，`ios/` 无差异。
- 范围：12个小程序注册页面，另拆开详情四个分页、登录、影像预览/来源、备注及引导等状态。比较依据为当前两端源码，并查看19张既有真实截图辅助核对；本轮没有重新运行全部页面，也没有取得两端同一手机、同一数据、同一状态的完整成对截图，因此不宣称逐像素或完整真机验收。
- 标记：**待对齐**表示源码已确认偏离原 UI；**平台差异**表示原生系统或支付/地图组件造成的区别，仍需按产品目标决定保留程度；**已批准新增**表示用户明确要求的变化；**待实机**表示还不能从现有证据确认实际表现。
- 下列数字是源码的 CSS px / SwiftUI pt 配置值，不能直接当成截图物理像素差。主色、底色和原 PNG 已复用，并非全套视觉都需要重做。

1. **全局导航、卡片与反馈**
   - **平台差异**：小程序使用微信导航栏、胶囊与 tabBar；iOS 使用 NavigationStack 和自制底栏。实际旧截图可见 iOS 系统圆形返回/工具栏按钮，导航区高度和外观不相同。
   - **待对齐**：iOS 房源主底栏标签10pt、最小高度56pt；详情底栏13pt、48pt。详情未选中文字复用 `#667187`，原详情最终样式为 `#8D95A3`。
   - **待对齐**：原普通卡片间隔12；iOS 多个页面用 VStack spacing16。原许多操作失败用短暂 Toast，iOS `WorkspaceRoot` 用须点“知道了”的 Alert；原保存错误横条整条可点重试，iOS 多了独立“重试保存/尝试恢复”按钮。
   - 来源：`src/app.json`、`src/app.wxss`、`src/lib/ui.js`、`AppRoot.swift`、`Theme.swift`。

2. **首页：空状态与房源列表**
   - **待对齐**：原导航标题“我的房源”，iOS 为“寻居 · 看房手记”。
   - **待对齐**：原有房源时右下角52×52悬浮“＋”；iOS 改成右上导航栏“＋”，并且空状态也显示该按钮。原空状态只保留正文“添加房源”入口。
   - **待对齐**：原双列卡片横间距10，iOS 为12。卡片封面142、正文144、圆角16、原图标与主要文字内容已沿用，不把它们列为缺失。
   - 来源：`src/pages/home/index.{json,wxml,wxss}`；`HomePage.swift`、`HouseCard.swift`。

3. **新建、重命名与房源长按菜单**
   - **待对齐 / 平台差异**：原使用微信可编辑 Modal；iOS 为中等高度 Sheet，标题与操作按钮位置不同。原“新建房源 / 填写房源名称或地址 / 保存”，iOS 为“添加房源 / 填写房源名称 / 确定”。
   - **待对齐**：原长按显示底部操作菜单“重命名、归档房源、导出房源 ZIP”；iOS 为系统 contextMenu，文案改成“重命名、归档、导出 ZIP”。
   - **待对齐**：原选择归档后有“归档后保留全部记录，可在设置中还原”的二次确认；iOS 菜单点“归档”直接执行，缺少确认界面。容量满时原引导到容量页，iOS 当前输入 Sheet 就地报错并保留输入，反馈流程不同。
   - 来源：`src/pages/home/index.js`、`src/lib/ui.js`；`HomePage.swift`、`AppRoot.swift/TextPrompt`。

4. **房源详情：四个分页与状态保留**
   - **待对齐**：原底栏显示“影像 N”“问题 N”，iOS 固定为“影像”“问题”，缺少计数。
   - **待实机，源码缺口已确认**：原详情保存各分页滚动锚点，并保留阶段、搜索、筛选与展开状态；iOS 用 switch 切换子 View，清单状态和影像筛选为子 View 的 @State，没有同等分页滚动锚点存取。需用实际切页确认重置范围，不能称已达到原交互一致。
   - **待对齐**：原归档提示为主色文字，iOS 改成次要灰色文字。
   - 来源：`src/pages/detail/index.{wxml,wxss,js}`；`HouseDetailPage.swift`、`HouseMediaPage.swift`。

5. **清单页：进度、筛选、字段和动态费用**
   - **待对齐**：原清单右下除回顶部外还有52pt拍摄悬浮入口；iOS 只保留48pt回顶部按钮，缺少清单级拍摄入口，拍摄须进入某条检查项操作。
   - **待对齐**：原筛选选项位于带12内边距和圆角12的白色容器；iOS 直接放置 ChoiceFlow。原普通非同行字段上下内边距12，iOS AnswerInput 为4；行密度不同。
   - **待对齐**：原文字字段标题最大104，输入占剩余宽度；iOS 标题和输入均申请弹性宽度。原输入聚焦后隐藏占位提示，iOS 保留系统默认占位行为。原普通输入/其他说明最长2000，iOS 输入绑定截到10000。
   - **待对齐**：原字段可渲染“原照片编号：…”；iOS 当前字段组件没有 photoRef 展示。原会隐藏组标题前指定字段分割线，iOS 字段组件始终绘制底部分割线。
   - **待对齐**：原动态费用“＋”是居中透明44pt图标；iOS 为通用柔色全宽按钮。原添加后清除搜索/筛选并展开新费用所在组，iOS 只调用 addCost，没有同等界面展开处理。
   - 来源：`src/pages/detail/index.{wxml,wxss,js}`、`src/components/field-row/*`；`HouseDetailPage.swift`、`InspectionFieldRow.swift`、`AnswerInput.swift`。

6. **清单行左滑、问题标记与备注摘要**
   - **待对齐**：原左滑操作托盘随手指连续位移，并处理距离/速度、反向滑动；iOS 多个组件仅在 DragGesture 结束时切换显示，动画反馈不同。
   - **待对齐**：原全页面只展开一条操作托盘，点击别处或纵向滚动先收起；iOS 标题行共享 activeHeading，普通选择行/输入行各自维护 actionsOpen，未统一协调。具体触摸表现仍需真机复核。
   - **待对齐**：普通 AnswerInput 没有根据 field.problem 给整行增加原有问题红底/红字；同行 InspectionChoiceRow 已有此样式。后者的备注直接 Text 展示，没有原普通字段摘要的两行上限；AnswerInput 已有两行上限，不混为一谈。
   - 来源：`src/components/field-row/index.{js,wxml,wxss}`；`InspectionChoiceRow.swift`、`AnswerInput.swift`、`ChecklistHeadingRow.swift`。

7. **检查项备注、影像备注弹层**
   - **待对齐 / 平台差异**：原为白底自制底部弹层，标题在正文、取消/保存位于底部并随键盘移动；iOS 为可在中/大高度切换的系统 Sheet，标题和取消/保存移到导航栏。
   - **待实机**：键盘避让、下拉关闭和点击遮罩的行为不能据旧截图判断全部一致；本轮未在真机重新操作。
   - 来源：`src/pages/detail/index.wxml` 的 note/mediaNote sheet；`HouseDetailPage.swift/NoteEditor`。

8. **影像列表**
   - **待对齐**：原右下52pt相机悬浮按钮，iOS 改成底部整行“拍照或录视频”主按钮，明显增加固定区域占用。
   - **待对齐**：原视频缩略卡显示“视频 Ns”，iOS MediaTile 不传时长，只显示“视频”。
   - **待对齐**：原长按缩略图弹出关联/取消关联/移除菜单，问题附件长按进入问题详情；iOS 缩略图无同等长按管理，改为点开影像详情后操作。
   - **待对齐**：原仅整个房源无影像时显示空状态；iOS 当前筛选结果为空也显示“还没有影像”，已有照片但筛选视频时文案不准确。归档有备注时原为静态文字，iOS 仍是打开只读备注的按钮。
   - 来源：`src/pages/detail/index.{wxml,js}`；`HouseMediaPage.swift`、`MediaGallerySurface.swift`。

9. **影像预览、关联检查项与全部关联影像**
   - **待对齐 / 平台差异**：原调用微信 previewMedia，传入整组媒体和当前索引；iOS 当前单个 Sheet 展示一张照片或一个视频，没有同等整组左右切换。照片视图未提供手势缩放实现。
   - **待对齐**：原关联检查项是详情上的搜索底部弹层；iOS 是带导航栏和系统搜索的 List Sheet。原44pt关联缩略图/“+N”点击同一组预览，iOS “+N”另开带筛选/备注的关联图库，操作层级不同。
   - 来源：`src/lib/platform.js/preview`、`src/pages/detail/index.{wxml,js}`；`HouseMediaPage.swift/MediaDetailPage`、`FieldRelatedMedia.swift`、`RelatedMediaSurface.swift`。

10. **问题列表与问题卡片**
    - **待对齐**：原右下“＋”悬浮入口，iOS 改成底部整行“新建问题”主按钮。
    - **待对齐**：原“需要关注 · N”使用 section-title 的16号半粗体；iOS 为14号普通文字。原空状态副标题17号，iOS 为16号。
    - **平台差异**：原 video 与 iOS AVKit VideoPlayer 控件外观不同。照片三列、视频独占一行、待跟进/已解决及自动问题行内编辑已接入；不将旧版纯文字问题卡列作当前缺失。
    - 来源：`src/pages/detail/index.{wxml,wxss}`；`IssuesPage.swift`、`RelatedMediaSurface.swift`。

11. **新建/编辑问题**
    - **待对齐 / 平台差异**：原是完整路由页面，iOS 是模态 Sheet，页面顶部形态与返回手势不同。
    - **待对齐**：原备注 textarea 自动增高，iOS TextEditor 为最小160并采用内部编辑/滚动；长备注下卡片与下方影像位置会不同。原取消按钮为白底，iOS 使用柔色按钮。
    - **待对齐**：原归档问题显示主色只读条；iOS 为普通灰色说明。系统视频控件与键盘工具栏亦不同。
    - 已保留标题/必填/选填、两张卡片、三列照片、整行视频及底部1:2取消/保存结构。早期 `16a-native-issue-editor.png` 是已替代版本，不能用它断言当前缺少这些组件。
    - 来源：`src/pages/issue/index.{wxml,wxss}`；`IssuesPage.swift/IssueEditor`、`IssueEditorSurface.swift`。

12. **总结页**
    - **待对齐**：原意向分段外框高度52，iOS 最小按钮44加上下3内边距约50；原备注外框固定200，iOS TextEditor 最小200后另加外部12内边距，备注区域更高。
    - 意向三项、“放弃这套”、已选主色、圆角及备注文案已沿用。长文本换行、键盘覆盖和只读态需同机实测。
    - 来源：`src/pages/detail/index.{wxml,wxss}`；`SummaryInput.swift`。

13. **对比页：选择与结果**
    - **待对齐**：选择卡片横间距同首页，原10，iOS12；未选勾选框原边框 `#C4CAD5`，iOS 用通用分割线 `#E5E9F1`。
    - **待对齐**：原“隐藏相同属性”控件与下方表格间距20，iOS VStack 为16；开关采用系统 Toggle，外观随 iOS 变化。
    - 2至3套、左下勾选、封面142/正文126、属性列26%、差异黄色背景、底部选择按钮结构已对齐。长属性/长房源名在 SwiftUI Grid 与 CSS flex 下的换行仍待成对截图核对。
    - 来源：`src/pages/compare/index.{wxml,wxss}`；`ComparisonPage.swift`。

14. **“我的”：未登录与已登录**
    - **待对齐**：原已登录显示54pt可选头像、20号可编辑昵称和13号主色登录状态；iOS 只显示16号登录状态文字，缺少头像和昵称编辑。
    - **待对齐**：原“退出登录”在整页底部，白底红字；iOS 放在首张账号卡内，使用柔色按钮。
    - **待对齐**：原卡内菜单有分割线，iOS 的上班地点/归档/引导及导入/导出行未绘制相同分割线。原“数据与备份”为16号半粗体，iOS 为13号灰色普通文字；版本显示也从小程序版本变成写死的0.1.0。
    - **平台差异**：“微信权限管理”改为“权限管理”，打开本 App 的 iOS 设置；开关样式为系统 Toggle。
    - 来源：`src/pages/settings/index.{wxml,wxss,js}`；`SettingsPage.swift`。

15. **微信、手机号与 Apple 登录**
    - **已批准新增**：原仅微信登录；iOS 增加手机号按钮、短信表单与官方黑色 Apple 按钮，账号卡更高，后续卡片随之下移。这是既定范围，不建议通过删入口消除差异。
    - **待实机 / 配置边界**：当前 iOS 微信点击提示暂不可用，Apple 准备失败会显示服务不可用文字；真实服务还未配置验收，不能当作原微信登录的同等成功状态。用户已决定保持三种方式及现有账号逻辑，本审计未提出改绑或账号合并。
    - 来源：`SettingsPage.swift`、`LoginComponents.swift`；`src/pages/settings/index.wxml`。

16. **房源位置选择与上班地点页**
    - **平台差异**：原使用微信 map，iOS 使用 MapKit；底图、地名、标注、版权标识与缩放交互不完全相同，不能把“地点信息来源：天地图”理解成两端底图相同。
    - **待对齐**：原上班地址为浅底多行 textarea，最小72、最大144；iOS 为无同等浅底容器的2至5行 TextField。原标题17号，iOS15号。
    - **待对齐**：原上班地点空地图提示“选择上班位置”；iOS WorkplacePage 未覆盖共用组件默认提示，显示“选择房源位置”。
    - 搜索框、300高地图、定位、230高搜索结果、128高附近列表等主要配置已沿用；重试文字/按钮及细边框颜色不同。
    - 来源：`src/components/address-picker/*`、`src/pages/workplace/*`；`LocationPages.swift`、`PlacePickerSurface.swift`。

17. **通勤路线查询与起点修改**
    - **平台差异**：底图和起终点 Marker 换成 MapKit 样式；路线选择的对勾/圆圈使用 SF Symbol，原为文字符号。
    - **待对齐**：原点房源起点后在当前通勤页面切换到选点卡，保留“取消”和“选择后更新这套房源的地址”；iOS 推入“选择房源位置”新页面，缺少这句提示，退出依赖导航返回。
    - **待对齐**：原上班地点已有地址时为“修改 ›”，iOS 为“更改 ›”；原无可用路线时确认按钮为指定灰底灰字，iOS 为主色按钮降透明度。
    - 起终点卡、240高地图、时间、路线信息、选中背景、1:2取消/确认与明确回填文案均已沿用。
    - 来源：`src/pages/commute/index.{wxml,wxss}`；`LocationPages.swift/CommutePage`、`CommuteComponents.swift`。

18. **网速测试与流量确认**
    - 本轮源码未发现主体结构的大幅改版：下载速度、52号数值、Mbps、6高进度条、取消/重试保存/重新测速、Wi-Fi和移动流量两步确认均对应原流程。
    - **平台差异**：微信 showModal 改为 UIKit Alert，系统弹窗和按钮外观不同。
    - **待对齐**：原完成反馈“测速结果已回填”并返回时 Toast“网速已回填”；iOS 组件为“测速结果已保存”，未提供同等返回成功 Toast。
    - **待实机**：网络变化、键盘/返回、取消/后台及实际提示停留时间未在本轮重新逐项操作，不把历史夹具测速当真实网络视觉验收。
    - 来源：`src/pages/speed-test/*`；`SpeedPage.swift`、`SpeedStatusCard.swift`、`SpeedNetworkConsent.swift`。

19. **归档房源列表**
    - **待对齐，结构差异大**：原仍为双列封面卡，显示已归档标签、租金、地址、面积和问题数；iOS 改成单列文字卡，缺少封面、标签、租金、地址和面积。
    - **待对齐**：原提示“长按房源可还原或删除”，操作藏在长按菜单；iOS 卡内直接显示“只读查看 ›”“还原”“永久删除”以及检查进度，操作入口和风险按钮曝光位置都不同。
    - 来源：`src/pages/archive/index.{wxml,wxss,js}`；`HomePage.swift/ArchivePage`。

20. **ZIP 导入页**
    - **待对齐，结构差异大**：原是左侧勾选框+名称/地址/检查记录数/影像数，iOS 用右侧 Toggle，仅保留名称/影像数和归档文字，缺少地址、检查记录数及“共N套、已选N套”。原正文大标题也未保留。
    - **待对齐**：原进入页面即打开文件选择；iOS 先显示页面，再点“选择 ZIP 文件”。选择后原显示实际文件名和“重新选择 ZIP”，iOS 复制后按钮采用内部固定文件名“房源备份.zip”。
    - **待对齐**：原冲突必须明确选择“覆盖”或“新增副本”，提示本机目标名称；iOS segmented Picker 默认选中新增副本，提示和排列顺序不同，且未选中房源也可显示处理控件。
    - **待对齐**：原固定底部“取消 / 导入 N 套”，iOS 操作在滚动正文中且不显示数量；原完成后提示新增/覆盖数量并回首页，iOS 留在当前页显示笼统导入数量。
    - 来源：`src/pages/import/index.{wxml,wxss,js}`；`BackupPage.swift`。

21. **ZIP 导出与分享**
    - **待对齐**：同样缺少原列表的勾选框、地址、检查记录数、总选择数和固定底部取消/导出栏；原空数据提示“还没有可导出的房源”，iOS 没有相同正文空状态。
    - **待对齐**：原选择变化后自动准备 ZIP，点“导出 N 套”直接打开分享；iOS 需先点“生成房源 ZIP”，成功后再点“分享房源 ZIP”。原发送取消/重试提示与 iOS ShareLink 反馈不同。
    - **平台差异**：微信文件发送改为 iOS 系统分享面板。底层 ZIP 支持相同不能代表选择/发送界面一致。
    - 来源：`src/pages/import/index.{wxml,js}`、`src/lib/platform.js`；`BackupPage.swift`。

22. **房源容量、购买与恢复**
    - **平台差异**：原固定显示微信价格¥1.99；iOS 从 StoreKit 商品读取本地化价格，新增加载、未开放、等待确认等状态。当前正式商品未配置，不能把组件夹具¥1.99当真机价格。
    - **已批准新增相关变化**：原“微信登录后购买 / 微信登录并恢复容量”，iOS 为“登录后购买 / 登录并恢复容量”，再弹出整个设置页供三种登录选择；原已登录“刷新容量”改为“恢复已购容量”。
    - **待对齐**：原摘要与商品卡中的纵向间距、数值下方留白，以及购买按钮和恢复链接的间距与 iOS 的 VStack 配置不同，需在真实商品可见后做同状态截图校正。
    - 两张白卡、容量数值38号、10套/包与主要颜色已沿用。
    - 来源：`src/pages/capacity/*`；`CapacityPage.swift`、`CapacitySurface.swift`。

23. **四步操作引导**
    - 标题、四步文案、遮罩、高亮、白色引线、知道了、最后一步“不再自动显示”和自动左滑演示主体已对应原结构，本轮未发现整页重做式差异。
    - **待对齐**：原引导影像图标22，iOS swipeDemo 对 coach-media 使用26。原遮罩是整个页面固定层，iOS overlay 附着清单滚动内容，导航栏/底栏单独禁用或隐藏返回；覆盖范围不同。
    - **待实机**：卡片定位、窄屏换行、旋转/安全区、背景点击与真实滑动演示需同机对照，不能据锚点计算相近称像素一致。
    - 来源：`src/pages/detail/index.{wxml,wxss}` 及 coach 代码；`CoachOverlay.swift`、`HouseDetailPage.swift`。

24. **权限、启动、损坏恢复与异常弹窗**
    - **平台差异**：微信权限管理、相册/相机选取改为 iOS 设置、PhotosPicker 和 UIImagePickerController，系统控件外观不同；iOS 还多一层“添加影像”的来源选择 Sheet。原一次可选9个影像，iOS PhotosPicker 当前一次选择一个。
    - **待对齐**：原账号等待为“正在确认登录状态…”；iOS 初次载入为 ProgressView“正在读取本机记录…”，顶层打开失败另有“本机记录暂时无法打开 / 重试”。原恢复入口在“我的”单独卡片，iOS 集成于 SaveBanner。
    - **待实机**：权限拒绝/恢复、原生键盘、系统文件选择、图片缩放、分享取消/重试的完整触摸表现尚无本轮成对证据。
    - 来源：`src/lib/auth-page.js`、`src/pages/settings/index.wxml`、`src/lib/platform.js`；`AppRoot.swift`、`HouseMediaPage.swift`。

25. **清单模板页：隐藏路由边界**
    - 小程序已注册模板页，但当前菜单没有入口；iOS 没有对应模板页面。若把所有注册路由都计入“完全一致”，这是页面缺口；按当前用户可达 UI 则两端均无入口。
    - 原模板文案“完整 · 303 项”与实际302字段不一致，属于原现状；不能凭此把 iOS 统计改成303，也不将其算成当前可见首页差异。
    - 来源：`src/app.json`、`src/pages/templates/index.wxml`、[原始源码审计](SOURCE_PARITY_AUDIT.md)。

证据使用说明：

- 已查看的小程序空首页、未登录设置、未登录容量截图位于 `.worktrees/review-optional-login-20261019/apps/wechat/artifacts/optional-login/screenshots/`。它们是历史运行证据，当前差异仍以最新 main 的 WXML/WXSS/JS 核实，未把该旧 worktree 当最新 main。
- 已查看 iOS 房源、清单、总结、对比、备份等业务截图，及后续影像、问题、地点/通勤、引导、容量和短信的组件/业务截图，统一位于 `/Users/pc/.codex/visualizations/2026/10/19/01a153f1-2c5b-7130-9ac8-1717a9eabf0c/`；精确来源和等价边界分别见 BUSINESS_PAGES、MEDIA_COMPONENTS、RELATED_MEDIA_INTEGRATION、UTILITIES、CAPACITY_COMPONENTS、CAPACITY_INTEGRATION 文档。
- 查看过的旧 `ios-business/16a-native-issue-editor.png` 已被第六批问题编辑界面替代；旧 ZIP 导入截图也不是当前 main 的完整文案依据，均排除为“当前页面”的证据。组件截图上的“评审状态”、测试价格、夹具房源名称和影像业务标题不属于正式 UI 差异。
- 本清单覆盖当前代码能确认的结构、内容和交互差异；缺少相同数据/字体设置/机型的截图，未测量的换行、系统控件外观和手势细节保留为待实机。既往组件批准仍有效，不等于完整 App 已和原版完全一致；修复本清单需另行实施和按影响验收。
