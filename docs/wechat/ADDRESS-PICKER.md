# 内嵌地址选点

仅修改小程序；原型与 Figma 不在本次范围。

- 搜索框占位：搜索地址，更快填写。输入停顿 300 ms 后查询，以当前地图中心优先；首次空地址搜索尝试手机定位，拒绝后仍可按地点名称搜索。搜索词、候选列表和未确认的地图中心不保存。
- 定位按钮移动到手机当前位置并查询候选。拖图结束后查询新中心，候选显示在地图底部，每项有“使用”；未选择前不覆盖已有地址。搜索结果点击即应用。
- 使用结果同时保存地址、GCJ-02 坐标和地址绑定；恢复占位、收起候选。拖回已确认位置时隐藏候选；中心未变化的缩放不触发查询。误差容忍 8 米，防止浮点或地图抖动。
- 手填地址仍即时保存；补楼栋/单元/房号保留确认坐标。临时输入不完整时保留绑定供后续恢复，换小区则失效旧定位，停顿 600 ms 后展示新匹配结果。只在单个结果与完整输入确实匹配时自动同步，多个或模糊匹配要求点选。
- 地图保持内嵌，无 chooseLocation/openLocation 全屏入口；不因地图手势打开检查项左滑操作。查询失败、权限拒绝、归档只读、组件销毁及旧请求晚到均受保护。

## 接口与本地配置

采用用户指定会话的微信原生地图＋天地图方案，仅接入本次地址功能。天地图查询结果为地理坐标，接口边界与 GCJ-02 转换；转换近似值需真机与地图标注对照，不把数值往返测试当作地理精度实测。

- [官方搜索 V2](http://lbs.tianditu.gov.cn/server/search2.html)：周边 queryType=3，10 公里无匹配再普通地名查询；最多取回 30 条，前端按距离取 10 条。
- [官方逆地理编码](http://lbs.tianditu.gov.cn/server/geocoding.html)：中心详细地址与附近小区候选合并。附近“小区”查询与逆解析允许单侧失败。
- 请求域名为 `https://api.tianditu.gov.cn`，需在微信后台 request 合法域名中配置。手机定位需开通 `getLocation` 对应能力与隐私声明。未关闭工具域名校验。

构建通过环境变量 `TIANDITU_KEY` 注入应用 Key；不提交真实 Key，也不在错误提示或日志中打印。Key 会进入忽略的构建包，应按天地图应用 Key 管理；若改成服务端密钥，应使用后端代理，不能直接注入客户端。

测试专用环境变量 `WECHAT_TEST_DATA_ROOT=xunju-test-inline-address` 使用独立存储子目录，避免同 AppID 的开发者工具工程共享业务数据。仅允许 `xunju-test-` 前缀和字母数字连字符；正式构建不传该变量，保持原来的 `xunju` 数据目录。该配置不改变业务规则，不添加演示入口或测试数据到包内。

## 验证与限制

2026-10-13：真实天地图接口在深圳公开地点返回了 6 条附近关键词结果、8 条无中心搜索结果，以及中心地址＋10 条附近小区候选。接口证据保存在任务工作树 `apps/wechat/artifacts/live-places.json`，不含 Key。

自动化映射：

| 边界 | 测试 |
| --- | --- |
| 查询防抖、过期请求、定位/拖图/选择、手填同步、失败/空结果/只读 | address-picker.test.js |
| 天地图参数、坐标转换、地址拼接、距离排序、绑定和重载 | places.test.js |
| 内嵌地图事件绑定、排除左滑、无全屏入口、过期中心回调 | address-bindings.test.js |
| 输入事件、手势、App/Page、地址持久化/备份消费者 | field-row-placeholder、field-row-swipe、runtime、model、files、platform |

构建和官方 wcc/wcsc 检查成功。测试采用 Node 24.19.0。组件/VM 测试不等同真实手势验收。

开发者工具 Stable 2.01.2510290、基础库 3.17.3：已打开独立工程，观察到隔离存储的空首页。官方测试 SDK 0.12.1 可以连接并读取路由，但页面数据调用曾超时；桌面截图与 AX 状态曾不一致。本记录不宣称完整 UI、GPS、键盘或拖图缩放已验收。真机 iOS/Android 和用户 UI 确认是合并/发布前的剩余项；本次未上传体验版、提审或发布。

### 集成验证记录

- 实现 SHA：`7690c47b9845c7154006c277ad89bc0828d7d442`；基线：`cb03d735d990668aa412c8e0f703384e3cfb4c95`。与主线合并时保留筛选按钮 `hover-class` 和本次地址事件绑定。验证时工作树干净；后续仅追加本段文档，不影响源码、构建或测试。
- 正式配置重新构建后，12 个相关测试文件共 79 项通过，官方 wcc 9 个模板、wcsc 7 个样式通过，包体 1,012,193 字节。完整日志：`apps/wechat/artifacts/address-tests-production.log`、`compile-result.json`。
- 选择命令：`node node_modules/vitest/vitest.mjs run tests/address-bindings.test.js tests/address-picker.test.js tests/places.test.js tests/detail-filter.test.js tests/field-row-placeholder.test.js tests/field-row-swipe.test.js tests/files.test.js tests/model.test.js tests/platform.test.js tests/runtime.test.js tests/unanswered-group-fold.test.js tests/unanswered-group-runtime.test.js`。主线新增加的 detail-filter 与 unanswered-group 用例覆盖本次冲突处理后的页面绑定/模型组合；未运行无关措辞测试。
- 保留失败证据：`address-tests-final.log` 的 8 项失败使用了 rebase 前的旧 dist；重建后 `address-tests-integrated.log` 仅 runtime 固定 `/user/xunju/state.json` 断言失败，原因是当时构建为隔离测试目录。恢复正式构建目录后上述 79 项全部通过，未改弱断言。
- 最后一次重新打开本任务工程后，官方 SDK 仍在读取页面前超时；当前开发者工具前台属于其他任务，未操作该窗口。实际 UI 截图、搜索选择交互、拖图缩放及真机定位未取得有效验收证据，PR 保持草稿、不可合并。

### 2026-10-13 局部加载排查补充

用户要求保留其他工程窗口，不重启整个开发者工具。当前源码保持 `f4817db07e377e9b14a4034a39c7780006359d49`，仅补充诊断文档。

- App 逻辑层能够进入 detail，但嵌入模拟器的实际画面仍白屏；官方 SDK Page.data 和元素接口持续超时。相同 AppID/基础库的最小两页诊断工程也出现 appLaunch timeout，不能归因地图业务代码。
- 只关闭并重开本工程、完整重建隔离测试包、reset-fileutils、清理本工程 compile 缓存后，分离本工程模拟器恢复了实际画面。已通过实际点击进入测试房源并展开地图区域。截图：`apps/wechat/artifacts/address-picker-rendered.png`。其他工程未关闭或重启；最小诊断工程已关闭。底层根因尚未完全确定，记录为局部恢复方案。
- 新的确定阻碍：在小程序 App 运行时通过真实 wx.request 查询深圳公开地点，搜索返回 `request:fail url not in domain list`；附近查询也失败。未绕过域名校验。证据：`apps/wechat/artifacts/runtime-places.json`。
- 需在小程序后台将 `https://api.tianditu.gov.cn` 加入 request 合法域名，再刷新开发者工具的项目配置后继续。浏览器安全策略禁止本会话访问微信公众平台，因此该后台操作已交由用户完成。
- 定位曾以深圳公开地点固定坐标做测试前置，已调用 restoreWxMethod 恢复。尚未完成搜索输入、候选点击、拖图、缩放及真机定位验收；截图仅证明展开状态已绘制。
- 本地 dist 当前为 `xunju-test-inline-address` 隔离测试包，不能当作正式发布产物。没有修改用户已有房源；测试房源只存在隔离目录。PR 继续保留草稿，不合并或发布。

### 2026-10-13 域名刷新与 Key 类型诊断

- 用户完成 request 合法域名配置后，在本工程详情 → Project Settings → Domain Name 刷新，已读到 `https://api.tianditu.gov.cn`。本工程旧调试连接在重载后失效，改用空闲独立端口恢复；没有重启共享开发者工具或关闭其他任务工程。
- 更新后的真实 `wx.request` 已越过微信域名检查，但天地图返回 HTTP 403，响应 `msg: 权限类型错误`。用户随后确认现有 Key 为“服务器端”，选择另建“浏览器端”应用再验证直连；尚待新 Key 的本地文件路径。不能将旧的命令行查询成功视为小程序调用成功。证据：`apps/wechat/artifacts/request-diagnostics.json`、`runtime-places.json`（均不含密钥）。
- 界面输入对照中，普通检查项搜索可粘贴并筛选，地址搜索框未能获得焦点。移除地址组件外层多余 `catchtouchstart/move/end`，继续由 field-row 的 map 分支排除左滑手势。这项修正的真实输入复验尚未完成：当前模拟器再次出现逻辑层已导航、实际画面未同步及 `__subPageFrameEndTime__` 为空的基础库错误。不能标记交互验收通过。
- 修正后重建隔离包，address-bindings、address-picker、field-row-swipe、places 共 28 项测试通过；官方 wcc 9 模板、wcsc 7 样式通过。GPS 固定公开坐标的 mock 已恢复。搜索候选选择、拖图、缩放与重载保持仍待真实交互验证；PR 保持草稿。

### 2026-10-13 浏览器 Key 接入及实际交互复验

验证源码为 `b4da13dd6bb34bb8b08c1da70aa763a714e06c30`，执行前工作树干净；本段仅补充证据。新的浏览器端 Key 保存在忽略的本地文件（权限 0600），未进入 Git 或报告。继续开启域名校验，未使用请求头或证书绕过。

- 真实小程序 `wx.request` 返回 HTTP 200、`status.infocode=1000`，普通搜索 8 条；应用地点服务返回深圳公开地点附近关键词结果 6 条、逆解析与附近候选 11 条。证据：`apps/wechat/artifacts/request-browser-diagnostics.json`、`runtime-places.json`。此前服务器端 Key 的 403 已解决。
- 开发者工具 Stable 2.01.2510290、官方 automator 0.12.1。本工程通过私有本地配置使用基础库 3.15.2 后，Page.data 与元素接口恢复；其间原共享运行时端口自行消失，随后仅重新打开本任务工程，因此不能将恢复唯一归因于基础库版本。未主动重启整个工具或关闭其他任务工程。源码默认基础库仍为 3.17.3，尚无该默认版本完整交互通过的证据。
- 官方 SDK 输入搜索词、点击真实搜索结果：6 条候选，选中后同时写入地址和坐标，清空搜索并隐藏候选；reLaunch 后持久化内容一致。没有直接调用业务 handler 或 setData 代替操作。证据：`address-ui-result.json`、`address-search-ui.png`。
- 点击定位、点击“使用”：只将 GPS 固定为深圳公开地点，地点服务仍为真实请求。出现 11 条候选，使用前原地址保持，使用后地址及坐标更新、候选收起。证据：`map-location-ui.json`、`map-gps-candidates.png`、`map-gps-used.png`；最后两张截图已目视检查。固定定位 mock 已恢复，之后出现的真实定位授权弹窗已取消，未采集用户实际位置。首次候选等待 15 秒超时，诊断重试通过，不隐去首次失败。
- 桌面 CUA 的地图坐标拖动反复返回 `noWindowsAvailable`；官方 SDK 的触摸序列没有改变实际地图中心，因此拖动与缩放仍未验收。原生点击/粘贴也未改变搜索框值，不能用 SDK input 的成功替代键盘焦点验证。地图 SDK tap 后路由仍为 detail，但真机手势仍是剩余门禁。
- `map-gps-used.png` 显示真实底图、单个中心点和下方已填地址。当前仅开发者工具部分流程通过；iOS/Android 真机 GPS、键盘、拖动、缩放以及用户 UI 确认仍待验收。PR 保持草稿，未合并、上传或发布。所有测试记录只写入 `xunju-test-inline-address` 隔离目录，原有房源数据未修改。

### 2026-10-13 真机授权反馈与恢复入口修复

- 用户反馈 iPhone 将位置权限设为“使用小程序时允许”后，原预览版已经能够定位。因此，先前仅凭后台“暂无权限”推断本次故障一定由主体/类目限制导致，证据不足；本次实际故障为用户端授权。保留 `wx.getLocation`，不变更类目或改用模糊定位。
- 修复前，用户拒绝定位只有笼统提示，没有设置入口；已有地图中心时点“重试”还会查询旧中心，而非重新获取位置。新增 4 项控制器回归在旧实现全部失败，日志 `apps/wechat/artifacts/location-recovery-before.log`。
- 对明确的用户拒绝错误显示原生 `button open-type="openSetting"` 的“去设置开启”。只有设置返回已允许定位，且页面未销毁、未变成只读、没有发生新的地址交互，才自动重新定位。拒绝/取消保留原地址；设置开启后也须点击候选“使用”才写入新地址。系统定位拒绝提示前往手机系统设置，其他定位失败不再一律归咎用户权限。
- 改动边界为地址控制器、组件事件及样式。重建隔离包后，`address-picker`、`address-bindings`、`field-row-swipe`、`places` 4 文件 33 项通过，官方 wcc 9 模板、wcsc 7 样式通过，包体 1,014,328 字节。日志 `location-recovery-after.log`。新增组件测试覆盖授权返回、仍拒绝、过期回调、销毁、只读。
- 本轮实际页面验证未完成：官方自动化在加载阶段超时，开发者工具显示 Simulator does not response，基础库 3.15.2 逻辑层 timeout；未把单测当作系统授权 UI 验收。保留 `location-recovery-ui.cjs` 作为本地复验脚本，未取得新入口有效截图。未重启共享工具或关闭其他任务工程。新预览码供用户在真机继续验证；PR 仍为草稿，不合并或发布。

### 2026-10-13 表单输入宽度调整

用户确认上一版无问题后，要求地址输入紧接标签、短数值不占用过宽空间，并检查同类字段。本次只改 field-row 布局类和样式：13 个普通文字字段（另一个 t 字段为地图，不参与）使用标签实际宽度和剩余输入空间；30 个数值字段统一为 96px 输入框并右对齐，覆盖楼层、面积、租金、通勤时间、月数及各项费用。长标签最多 104px，可换行；选择按钮、值类型、保存和左滑逻辑不变。

- 重建后 `field-row-placeholder`、`field-row-swipe`、`address-bindings` 3 文件 15 项通过；官方 wcc 9 模板、wcsc 7 样式通过。仅低影响布局调整，复用上述相关行为测试，不新增只重复 CSS 实现的单测。日志：`apps/wechat/artifacts/field-width-tests.log`。
- 按新约定通过只读公共入口提交三槽池，run ID `68d87e34faaf46f886c898379f0410c9`。第 1 槽的 `health-before.log` 连接 SDK 后等待 app/page 失败，布局回调尚未执行，槽位由 runner 隔离。证据：`/Volumes/mac2/codex-builds/wechat-instance-pool/runs/68d87e34faaf46f886c898379f0410c9/receipt.json`。未自行删锁、改池配置、重启或切回默认实例。
- 该 run 背景提交为 `0d79305`，sourceStatus 记录两份布局文件的未提交修改，不能把快照称为干净 head 测试。后续只提交这两份已检查文件和本段记录，未重新修改布局。新布局实际截图、真机预览码及用户确认仍待实例池恢复后完成；此前二维码不包含本次布局调整。
