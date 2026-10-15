# 通行时间路线查询

2026-10-15；使用小程序内地图路线页。该功能待真实控件交互及用户视觉验收，不可据此文档合并或发布。

## 用户操作与保留状态

- 清单中的“公共交通通勤时间（分钟）”改为“公交地铁通行时间（分钟）”，字段 ID 不变。新旧模板均通过现有 `houseTopics` 标签归一化显示；不迁移答案、备注、问题或影像。
- 公交地铁与开车时间右侧分别显示“查询”；手填保留。归档房源禁用入口，直接打开查询地址同样受登录、账号和只读保护。
- 查询页固定从这套房源到全局上班地点。初始模式由字段 ID 决定，选择方案后更新地图与详情；仅“确定并填入”写入对应字段，分钟向上取整。
- 缺少坐标或文字地址与坐标失配时，在页内复用地址搜索/地图选点。选中房源位置更新该房源地址；选中上班地点全局保存。选点保存失败保留选点页供重试。
- 取消查询、空结果、服务错误、离开或账号变化不写通行时间；地点或原字段值在查询期间变化，拒绝确认并要求重查。写盘失败撤回本次时间更新，保留结果供重试，成功落盘后才返回。
- 页面标明数据来源、查询时刻及参考耗时；不表示实时早高峰预测。公交显示步行、换乘与所选分段信息。

## 模块与数据源

- `apps/wechat/src/lib/commute-fields.js`：两个稳定字段 ID 与模式映射，避免字段组件捆入路线解析器。
- `commute.js`：天地图公交/驾车适配、时间与距离校验、坐标转换、路线去重、几何和方向检查、声明式地图中心与缩放计算。
- `pages/commute/`：临时查询和选择状态；共享业务数据通过已有应用 service/store 处理。
- `workplace.js`：复用 PR #24 的地点数据工具；不合入该草稿 PR 的独立设置页面。此处的结构与其 `workplaceLocation*` 字段兼容。

继续使用现有地点查询 Key 与 `https://api.tianditu.gov.cn`，未新增服务商、密钥或后端部署。公交调用 `transit?type=busline`，`postStr` 必须采用官方示例的小写 `startposition/endposition/linetype`；`linetype=7` 请求较快捷、少换乘、少步行。`segmentTime`/`segmentTransferTime` 按分钟计；同一段的多个 `segmentLine` 为备选，不能累加。驾车 `drive?type=search` 的 XML 中 duration 为秒、distance 为公里，分别请求较快与较短策略，重复路线合并。

数据检查会舍弃负值、缺少时间、无效坐标、断裂或方向颠倒的方案，不能保证原始站点/班次资料及时。公交实测仍含负耗时地铁方案；舍弃异常并不等于全部数据可靠。无可用路线时保留手填入口。未新增候车时间估算或出发时刻设置。

地图底图使用微信 map 组件，路线坐标在天地图边界由 GCJ-02 转地理坐标，请求结果转回 GCJ-02。初始视野按整条路线的 Web Mercator 包围盒计算，并给起终点留白；避免页面创建时依赖未就绪的原生视野调用。长路线、比例尺与真机对齐仍需现场核对。

## 定向验证映射

| 生产边界 | 自动测试 |
| --- | --- |
| 改名、新旧模板、不改旧答案、数据源参数、耗时单位、几何与错误分支 | `tests/commute.test.js` |
| 两种模式、选点保存、确认/取消、持久化重载、并发变化、写盘回滚、账号/页面生命周期、入口绑定 | `tests/commute-page.test.js` |
| 应用 service 和微信 adapter 消费者 | `tests/platform.test.js`、`tests/runtime.test.js` |
| 全部受保护页面（含新增路线页）、账号退出/切换 | `tests/account-runtime.test.js` |
| 原有模板、统计和持久化消费者 | `tests/model.test.js` |
| 地址组件文案参数与既有地图事件 | `tests/places.test.js`、`tests/address-picker.test.js`、`tests/address-bindings.test.js` |
| 字段组件新增按钮与既有输入/滑动行为 | `tests/field-row-events.test.js`、`tests/field-row-placeholder.test.js`、`tests/field-row-swipe.test.js`、`tests/field-row-inline-actions.test.js` |

构建后执行上述精确文件的 Vitest 增量组合及 `npm run check`；不运行本地全量单测或全量 E2E。实现提交 `05ee332` 上该组合 13 文件、174 项通过；官方 wcc 14、wcsc 13 文件通过，12 页面、1,474,044 字节。最终 head、命令、输出与 UI 证据边界写入 PR 和本机 `apps/wechat/artifacts/commute/`。

## 现场证据与未完成项

- 公开北京地点的真实公交/驾车 API 返回已解析；微信内生产公交适配也取得 5 个候选。只证明这些样本及请求路径，不能据此推断所有城市、实时路况、班次或真机均通过。
- 第一轮 UI 测试因未设置登录服务地址停在身份夹具，未进入产品操作；后续 UI 构建显式使用 `WECHAT_API_URL=https://commute-fixture.example.invalid` 并模拟登录服务，该测试地址不可用于真实用户预览。
- 新增 `tests/e2e/commute.cjs` 覆盖可见查询、取消、选择、确认及写盘回读；`parking-normal.cjs` 仅同步受改名影响的搜索词与标签。两者已实际执行，但 Page 元素查询均未到达被测控件，不能算通过。CUA 工具超时；没有采用页面 handler 或 setData 冒充点击。
- 已取得实际路线页渲染截图。首轮截图发现地图未包含完整起终点；后续原生视野探测未获得完成回调，之后改为显式中心/缩放并补几何覆盖。额外诊断确认登录页的自动 switchTab 曾覆盖立即打开的路线页，后续脚本先等待登录导航稳定；该前置条件修复不代表控件交互已通过。所有失败 receipt 和早期截图保留，不能作为最终视觉批准。
- 真实点击、完整地图最终像素、页内搜索/选点、系统权限、iOS/Android 真机及用户视觉确认仍是交付门禁。保留 Draft，不合并、不上传体验版、不提审或发布。

参考：[天地图公交](https://lbs.tianditu.gov.cn/server/bus.html)、[驾车](https://lbs.tianditu.gov.cn/server/drive.html)、[腾讯位置服务 map 组件指南](https://github.com/TencentLBS/tencentmap-miniprogram-skill/blob/main/references/map_component_guide.md)。官方站点本轮直接抓取受限，公交参数另与既有官方文档记录及本轮真实返回交叉核对。
