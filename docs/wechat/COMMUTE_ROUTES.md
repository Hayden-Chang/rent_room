# 通行时间路线查询

2026-10-15；使用小程序内地图路线页。该功能待真实控件交互及用户视觉验收，不可据此文档合并或发布。

## 用户操作与保留状态

- 清单中的“公共交通通勤时间（分钟）”改为“公交地铁通行时间（分钟）”，字段 ID 不变。新旧模板均通过现有 `houseTopics` 标签归一化显示；不迁移答案、备注、问题或影像。
- 公交地铁与开车时间右侧分别显示“查询”；手填保留。归档房源禁用入口，直接打开查询地址同样受登录、账号和只读保护。
- 查询页固定从这套房源到全局上班地点。初始模式由字段 ID 决定，选择方案后更新地图与详情；仅“确定并填入”写入对应字段，分钟向上取整。
- 房源位置仍在查询页内搜索/选点，保存失败保留选点界面。上班地点直接读取 PR #24 的全局设置；缺失或需修改时，点击终点进入同一个 `/pages/workplace/index`，与“我的 → 上班地点”共用页面和数据。
- 从上班地点页返回后，地址或坐标有变化则清除旧路线并按原来的公交/开车模式重查；清空地点或手填其他地址导致坐标失效时，提示补选地图位置，不能确认旧路线。地点未变则保留已选方案和视野。改地点本身不会改写通行时间。
- 取消查询、空结果、服务错误、离开或账号变化不写通行时间；地点或原字段值在查询期间变化，拒绝确认并要求重查。写盘失败撤回本次时间更新，保留结果供重试，成功落盘后才返回。
- 页面标明数据来源、查询时刻及参考耗时；不表示实时早高峰预测。公交显示步行、换乘与所选分段信息。

## 模块与数据源

- `apps/wechat/src/lib/commute-fields.js`：两个稳定字段 ID 与模式映射，避免字段组件捆入路线解析器。
- `commute.js`：天地图公交/驾车适配、时间与距离校验、坐标转换、路线去重、几何和方向检查、声明式地图中心与缩放计算。
- `pages/commute/`：临时查询和选择状态；共享业务数据通过已有应用 service/store 处理。
- `workplace.js` 与 `pages/workplace/`：接入 PR #24 (`ebdd5fe`) 的单一上班地点设置，删除查询页内重复的上班地点选点流程。整合当前主线后，保留“我的”页账号、退出登录、容量功能，并给上班地点页补齐同样的账号保护。

PR #24 在本轮核对时仍是未合并草稿。#31 的任务分支包含该依赖供组合验证；应先完成 #24 合入，再核对 #31 与最新主线的差异。本轮没有合并任何 PR。

继续使用现有地点查询 Key 与 `https://api.tianditu.gov.cn`，未新增服务商、密钥或后端部署。公交调用 `transit?type=busline`，`postStr` 必须采用官方示例的小写 `startposition/endposition/linetype`；`linetype=7` 请求较快捷、少换乘、少步行。`segmentTime`/`segmentTransferTime` 按分钟计；同一段的多个 `segmentLine` 为备选，不能累加。驾车 `drive?type=search` 的 XML 中 duration 为秒、distance 为公里，分别请求较快与较短策略，重复路线合并。

数据检查会舍弃负值、缺少时间、无效坐标、断裂或方向颠倒的方案，不能保证原始站点/班次资料及时。公交实测仍含负耗时地铁方案；舍弃异常并不等于全部数据可靠。无可用路线时保留手填入口。未新增候车时间估算或出发时刻设置。

地图底图使用微信 map 组件，路线坐标在天地图边界由 GCJ-02 转地理坐标，请求结果转回 GCJ-02。初始视野按整条路线的 Web Mercator 包围盒计算，并给起终点留白；避免页面创建时依赖未就绪的原生视野调用。长路线、比例尺与真机对齐仍需现场核对。

## 定向验证映射

| 生产边界 | 自动测试 |
| --- | --- |
| 改名、新旧模板、不改旧答案、数据源参数、耗时单位、几何与错误分支 | `tests/commute.test.js` |
| 两种模式、共享上班地点页往返/改点/清空/未改、导航失败重试、防重复进入、房源选点保存、确认/取消、持久化重载、并发变化、写盘回滚、账号/页面生命周期、入口绑定 | `tests/commute-page.test.js` |
| 应用 service 和微信 adapter 消费者 | `tests/platform.test.js`、`tests/runtime.test.js` |
| 全部受保护页面（含路线页及接入的上班地点页）、账号退出/切换 | `tests/account-runtime.test.js` |
| 上班地点设置、自动保存/重试、文字地址失效坐标、设置页入口、权限文案限制、过期账号禁止写入 | `tests/workplace.test.js`、`tests/workplace-runtime.test.js` |
| 原有模板、统计和持久化消费者 | `tests/model.test.js` |
| 地址组件文案参数与既有地图事件 | `tests/places.test.js`、`tests/address-picker.test.js`、`tests/address-bindings.test.js` |
| 字段组件新增按钮与既有输入/滑动行为 | `tests/field-row-events.test.js`、`tests/field-row-placeholder.test.js`、`tests/field-row-swipe.test.js`、`tests/field-row-inline-actions.test.js` |

构建后执行上述精确文件的 Vitest 增量组合及 `npm run check`；不运行本地全量单测或全量 E2E。实现提交 `05ee332` 上该组合 13 文件、174 项通过；官方 wcc 14、wcsc 13 文件通过，12 页面、1,474,044 字节。最终 head、命令、输出与 UI 证据边界写入 PR 和本机 `apps/wechat/artifacts/commute/`。

## 共享上班地点整合验证（2026-10-15）

- 生产实现 `fd3c04f`，基线 `5ac60a6`，包含 #24 依赖 `ebdd5fe`。干净工作树构建后，上表 15 个精确测试文件共 193 项通过；官方 wcc 15、wcsc 14 文件通过，13 页面、1,481,630 字节。输出为 `apps/wechat/artifacts/commute/workplace-final-unit.log` 与 `workplace-final-compile.log`。
- 新增账号切换回归在 #24 原页面 bundle 上失败：旧页面把“不能写入”写入共享设置；同一测试在补齐账号保护后通过。失败记录 `artifacts/commute/workplace-before-guard.log`。
- 组合 UI 测试已提交固定池：`commute.cjs` 的 run `6b76d114ba0e49ad9ca2417649c269e5` 在回调前以 `App service health timeout` 失败；`workplace.cjs` 的 run `adfdf8b6a8bf4d938b71d436e14f3b81` 排队后以无可用槽位失败。状态检查三槽均为 busy-or-quarantined；没有抢用窗口或修改共享运行时。回执复制到 `artifacts/commute/workplace-integration/`。
- 本轮没有取得组合版本的真实截图或点击证据。之前的路线渲染截图属于旧界面，不能替代本轮共享设置入口及返回流程验收。依赖 #24 合入、实际交互、当前截图及用户视觉确认仍待完成。

## 现场证据与未完成项

- 公开北京地点的真实公交/驾车 API 返回已解析；微信内生产公交适配也取得 5 个候选。只证明这些样本及请求路径，不能据此推断所有城市、实时路况、班次或真机均通过。
- 第一轮 UI 测试因未设置登录服务地址停在身份夹具，未进入产品操作；后续 UI 构建显式使用 `WECHAT_API_URL=https://commute-fixture.example.invalid` 并模拟登录服务，该测试地址不可用于真实用户预览。
- `tests/e2e/commute.cjs` 覆盖可见查询、共享上班地点设置页往返、重新查询、取消、选择、确认及写盘回读；接入的 `workplace.cjs` 补齐当前登录前置，覆盖设置页既有操作。`parking-normal.cjs` 仅同步受改名影响的搜索词与标签。两者已实际执行，但 Page 元素查询均未到达被测控件，不能算通过。CUA 工具超时；没有采用页面 handler 或 setData 冒充点击。
- 已取得实际路线页渲染截图。首轮截图发现地图未包含完整起终点；后续原生视野探测未获得完成回调，之后改为显式中心/缩放并补几何覆盖。额外诊断确认登录页的自动 switchTab 曾覆盖立即打开的路线页，后续脚本先等待登录导航稳定；该前置条件修复不代表控件交互已通过。所有失败 receipt 和早期截图保留，不能作为最终视觉批准。
- 真实点击、完整地图最终像素、页内搜索/选点、系统权限、iOS/Android 真机及用户视觉确认仍是交付门禁。保留 Draft，不合并、不上传体验版、不提审或发布。

参考：[天地图公交](https://lbs.tianditu.gov.cn/server/bus.html)、[驾车](https://lbs.tianditu.gov.cn/server/drive.html)、[腾讯位置服务 map 组件指南](https://github.com/TencentLBS/tencentmap-miniprogram-skill/blob/main/references/map_component_guide.md)。官方站点本轮直接抓取受限，公交参数另与既有官方文档记录及本轮真实返回交叉核对。
