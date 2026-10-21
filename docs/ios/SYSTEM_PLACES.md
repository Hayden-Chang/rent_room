# iOS 系统地点服务修复（2026-10-21）

## 故障与用户选择

p10002 上的 `bae4e4c` 开发版在点击定位后提示“地点查询失败，请重试或手动填写地址”。安装包有定位权限说明及地图配置，但 `build-native-config.mjs` 复用小程序的浏览器 Key；原生 `URLSession` 请求不匹配该权限类型。

经用户明确授权执行一次公开地标查询，天地图官方 `/v2/search` 返回 HTTP 403、`code=301012`、`msg=权限类型错误`，无地点结果。诊断使用已部署包的配置，不发送用户坐标、不输出 Key、不跟随重定向。此证据来自 Mac 请求，并非真机网络抓包，不证明手机 GPS 的成功或失败。最初诊断请求被自动权限审核拒绝，未执行；用户随后单次授权后才执行，授权已消耗。

用户选择：“iOS 改用系统地点服务：不需天地图 Key，界面保持原样，但搜索结果可能不同”。

## 修复范围

- 房源与上班地点共用 `NativePlaceService`，普通 Debug / Release 默认调用 `MKLocalSearch`。iOS 26 使用 `MKReverseGeocodingRequest`，iOS 17–25 使用 `CLGeocoder` 逆地址解析。均通过系统 SDK 获取地址，不依赖天地图 Key，也没有转发到自有后端。
- 保留搜索框、地图、定位、附近“使用”、手工地址、只读状态与现有持久化；仅来源标记更新为“系统地图”。原生坐标继续在存储边界转换为原清单的 GCJ-02，读取时转换回原生坐标，保存仍调用原 `place` / `workplacePlace` 规则。
- 查询无副作用；选择后才保存。离开页面、新搜索或账号变化舍弃过期结果；每个 SDK 请求各自持有取消操作，设12秒取消期限。逆地址与附近搜索分别容错，有一项可用时继续提供真实结果，两项均失败时显示重试；不伪造地址或坐标。
- DEBUG 夹具必须同时具备业务测试 UUID 与既有显式开关，替换系统地点客户端而不替换选择/保存流程；Release 不包含该夹具。
- **通勤路线仍走原天地图独立接口，未在本次迁移，也未宣称其真实查询可用。** 地点服务迁移不修复路线 Key 的权限类型问题；后续需独立处理。小程序源码、登录、容量及用户记录未改动。

## 回归与证据

工作树：`rent_room/.worktrees/ios-parity-20261019`；分支：`codex/ios-parity-20261019`。使用 XcodeGen2.45.4 和共享模拟器 runner；生成工程不提交。

- 修复前 `xunju-system-places-20261021-red-01`：新增 `testPlaceSearchStartsWithoutTiandituKeyAndDoesNotChangeRecords` 确实失败，搜索任务为空且提示“地点查询暂不可用”。失败为产品行为，非编译或环境问题。之后仅随生产 API 移除 Key 参数调整构造调用，保留原断言；旧“缺 Key 必须停止地点查询”的测试契约同时退役。
- `green-01`：Swift 6 编译发现并发调用的协议需声明 Sendable；测试未启动。修正声明后按相同范围重新运行，保留失败 bundle。
- `green-02`：10项定向 UT、真实系统地图查询 UI、模拟系统定位 UI 通过；房源选点/通勤串联 UI 在选中房源地点后的附近列表断言失败。层级证据显示地图已出现、搜索文字已清空，但没有附近结果，也没有加载/错误提示。检查发现原生候选点与 GCJ-02 存储再转换回来的坐标存在微小精度差，房源存储回显触发 `synchronizeLocation`，取消了正在发起的附近刷新。
- `roundtrip-red-01`：新增 `testHouseSelectionRoundTripDoesNotCancelNearbyRefresh` 确实失败；合成测试点纬度31.2304读回为31.230399999999996，严格不等造成刷新取消。`didSelect` 改为先使用同一存储坐标读回的值；没有放宽比较、改写已有坐标或删除断言。
- `green-03`：2项受影响 UT（坐标读回、选择保存）与3项 UI 全部通过。房源选点、上班地点、通勤夹具确认、重启与归档只读串联69.078秒；真实系统搜索/逆地址/选择/重启23.456秒；CoreLocation权限与模拟坐标选择/重启20.065秒。UI共112.599秒，不含构建与启动收尾。
- 去重为11项UT、3项UI通过；系统客户端与其余模型逻辑在02至03之间未变，复用02中不受 `didSelect` 坐标规范化影响的9项UT。没有运行全量测试，也没有声称整个 iOS PR 通过最终合并门禁。两次产品回归失败和一次编译失败完整保留。
- 新增 `testLiveSystemPlaceSearchSelectionAndRelaunch` 是独立的真实系统 SDK 集成检查：只在 UUID 隔离数据下查询公开地标，不启用网络夹具，也不使用用户 GPS。其结果与确定性单测、模拟坐标检查分别报告，不作为离线 CI 必过门禁。

日志和计划：`artifacts/ios-location-20261021/`（本地忽略）；各轮完整 `.xcresult` 位于 `/Volumes/mac2/codex-builds/xunju-system-places-20261021-<run>.xcresult`。真机安装、启动和用户当前位置实际验收仍需各自的结果，不由模拟器测试推断。

系统 API 依据：[MKLocalSearch](https://developer.apple.com/documentation/mapkit/mklocalsearch)、[iOS 26 逆地理编码](https://developer.apple.com/videos/play/wwdc2025/204/)。
