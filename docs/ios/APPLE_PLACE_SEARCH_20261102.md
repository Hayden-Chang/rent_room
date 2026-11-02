# Apple 地点搜索与跨地区验证（2026-11-02）

## 当前结论

房源和上班地址已统一切换到原生 Apple 地点服务。关键词查询移除旧房源/地图中心的偏置，保留 Apple 相关性顺序；定位和拖图继续按附近范围及距离排序。保留保存、重启回显、取消、手动地址与坐标存储边界。微信和通勤接口不在本次范围。

**跨地区查询存在环境差异，不能宣称全面修复：**

| 环境 | 真实在线结果 |
| --- | --- |
| iPhone 14 Pro / iOS 18.3.1 模拟器，中文 | 上海 → California → Cupertino 街道 → 选择 → 重启回显，全程通过 |
| iPhone 16 / iOS 26.5 模拟器，中文 | 上海查询通过；California 首条为北京加州健身房，坐标 39.952368,116.42034，验收失败 |
| 同一 iPhone 16 / iOS 26.5，en-US / en_US，原网络 | 完整纽约街道 `350 Fifth Avenue, New York, NY, United States` 首条为北京口腔诊所，纬度 39.940298，验收失败 |
| macOS 26.2 独立 Apple SDK 查询 | 美国地址解析无匹配；全球范围、显式美国区域、英文 locale、补全查询均未获得美国结果 |

两个模拟器使用相同生产代码，运行于同一 Mac；未修改机器网络设置。iOS 26 检查使用 `1c8b30c`，iOS 18 最终检查使用 `b07242a9841586d6d5ac22ee9d73386ef5762782`，两者只差测试的语言断言与截图时机，生产源码完全一致。测试不启用真实位置，也不访问用户记录。结果不证明所有 iOS 18 可用或所有 iOS 26 均失败。

PR #118 保持草稿，未合并、部署或安装真机。没有新增地址供应商、转发后台或改变机器代理配置。

## 原因调查

1. 原实现安装包带天地图 Key 时走国内范围的天地图分支；界面显示 Apple 地图不能证明搜索使用 Apple。此分支已从 iOS `PlaceSearch` 移除。
2. 应用自己传入旧中心并按距离重排，会让跨地区结果受旧地点影响。本次去掉关键词中心，保留 SDK 排序；距离只用于展示。
3. [Apple 官方协议 Attachment 6](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/) 明确包含高德在中国提供的地图服务，并声明服务在不同国家/地区/语言的可用性可能不同。这里只用于核实供应关系，不将其推断为所有跨境查询必然不可用。
4. [MKLocalSearch.Request.region](https://developer.apple.com/documentation/mapkit/mklocalsearch/request/region) 是搜索范围提示；[regionPriority.default](https://developer.apple.com/documentation/mapkit/mklocalsearchregionpriority/default) 允许范围外结果。二者没有承诺切换服务供应商。
5. [MKGeocodingRequest.region](https://developer.apple.com/documentation/mapkit/mkgeocodingrequest/region) 默认覆盖全球，但本机单独调用仍对 California、California United States、美国加利福尼亚州及 Cupertino 街道返回无匹配；`zh_CN` 与 `en_US` 相同。因此未把未验证有效的地址解析拼接进生产代码。

**推断而非已证实根因：**剩余问题更符合 Apple 地区服务/数据覆盖或设备服务状态差异。由于两个模拟器版本和历史状态不同，尚不能区分系统版本回归、地区判断、服务缓存或网络路径。未做同设备不同网络 A/B，不能断言只由 IP、SIM、Apple ID 或语言触发；也不能承诺服务端 Apple Maps API 必定解决。后者还需独立凭据和实测。

## 回归证据

工作树 `/private/tmp/rent-room-ios-apple-place-search-20261102`，分支 `codex/ios-apple-place-search-20261102`。基线 `f7f79434925d082dde9e26a9ae70c53ed40590e0`。通过共享 Simulator Management runner 租约构建/运行，使用仓库 `scripts/run-xcodebuild.sh` 与 XcodeGen 2.45.4。

证据根目录 `/private/tmp/rent-room-apple-search-evidence/`，命令和精确选择器见相应 `*-command.sh` 与 `*-plan.json`，完整结果为 `*.xcresult`。不运行全量用例。

| 轮次 | 源码 / 范围 | 结果与解释 |
| --- | --- | --- |
| red | 基线 + 2 个新测试 | 首次因缺少 esbuild 未启动测试，属于环境失败 |
| red-02 | 相同基线 + 2 UT | 1 过 / 1 失败：关键词仍传入上海中心；附近对照通过，构成行为性红灯 |
| green | 60c1d50，19 UT + 3 UI | 18 过 / 4 失败：单测浮点严格相等及 3 UI 被首次货币弹窗阻挡；未到在线搜索 |
| green-02 | 1c8b30c，19 UT + 3 UI，iOS 26.5 | 20 过 / 2 失败：单测写死中文附近词；真实 California 返回北京。两个夹具业务 UI 全程通过 |
| green-03 | b07242a，19 UT + 3 UI，iOS 18.3.1 | **22 过 / 0 失败 / 0 跳过**。修正单测语言假设，并在坐标断言前留截图；生产源码未变 |
| us-english-26 | d8c17f4，0 UT + 2 UI，同一 iPhone 16 / iOS 26.5 | 0 过 / 2 失败 / 0 跳过。英文流程实际语言断言通过，完整纽约街道返回北京；中文流程上海成功后，在第二次输入前等待键盘失败，此项不作为 California 查询证据 |
| us-proxy-26 | 9b28f02，0 UT + 1 UI，同一 iPhone 16 / iOS 26.5 | 0 过 / 1 失败 / 0 跳过。已启用扩展并仅选择本任务模拟器进程树，但没有捕获到任何连接；纽约首条仍为北京，纬度 39.940298。此轮不能作为美国出口 A/B |

`green-03` 的 3 个 UI 场景：

- `LivePlaceSearchTests/testCaliforniaAndStreetSearchReplaceChineseWorkplaceAndPersist`：真实 Apple 服务，公开上海地标→California→美国街道，验证坐标范围、选择及重启地址；无网络夹具。
- `UtilityBusinessTests/testHouseMapReentryFocusAndAddressPersistAfterRelaunch`：固定地点响应，真实房源页面操作、选点、输入聚焦、手动改址与重启。
- `UtilityBusinessTests/testSystemLocationWithSimulatedPointCanSelectWorkplace`：CoreLocation 模拟坐标和固定地点响应，权限、两次定位选择与重启；不代表真机 GPS 成功。

19 UT 覆盖 Apple 路由（带天地图 Key 仍不请求旧传输）、海外坐标存储、附近/关键词顺序、取消/过期响应、无匹配与断网区别、候选关闭、手动地址以及重新打开不发请求。

## 已检查的真实截图

- [iOS 18：California 正确结果](evidence/apple-place-search-20261102/ios18-california.png)
- [iOS 18：美国街道地址重启后保留](evidence/apple-place-search-20261102/ios18-us-address-relaunch.png)
- [iOS 26：California 错误匹配北京](evidence/apple-place-search-20261102/ios26-california-failure.png)（从原测试录像末帧提取，未修改内容）
- [iOS 26 英文：完整纽约街道仍返回北京](evidence/apple-place-search-20261102/ios26-english-new-york-failure.png)

主 agent 已逐张检查。iOS 18 美国街道结果截图中地图瓦片尚未加载完整，因此不宣称海外地图渲染验收完成。真机、不同网络/地区组合和 iOS 26 剩余在线问题仍需验证。

## 单模拟器美国出口隔离研究

用户要求仅本任务模拟器使用美国出口，不影响 Mac 其他应用或其他模拟器。原 Wi-Fi HTTP/HTTPS/SOCKS 均指向 `127.0.0.1:7897`，本次只读备份与复核完全一致，没有切换系统代理。`127.0.0.1:1081` 的独立请求出口已验证为美国，但这不证明 MapKit 使用该出口。

[mitmproxy Local Capture](https://docs.mitmproxy.org/stable/concepts/modes/#local-capture) 支持精确 PID 选择；其 [macOS 扩展源码](https://github.com/mitmproxy/mitmproxy_rs/blob/main/mitmproxy-macos/redirector/network-extension/TransparentProxyProvider.swift) 将未命中 PID 的流量交回系统。可在共享 runner 的本任务有效租约内解析目标模拟器的 `launchd_sim`，仅匹配该进程树。按应用名称匹配不能代替这一隔离边界。

用户随后明确批准安装与启用。官方 PyPI `mitmproxy-rs` / `mitmproxy-macos` 0.12.15 安装在任务独立 Python 环境；应用安装到 `/Applications/Mitmproxy Redirector.app`。签名、公证校验通过，Team ID `S8XHQB96PW`；系统回读扩展 `org.mitmproxy.macos-redirector.network-extension` 为 `[activated enabled]`。授权步骤已完成，没有待确认的授权提示。没有安装 CA，也没有解密 HTTPS。

已完成以下诊断，原始记录在证据根目录：

| 诊断 | 观察 | 能证明的范围 |
| --- | --- | --- |
| `pid-isolation-probe-03.log` | 被选 PID 的直接 HTTPS 连接与 DNS 被捕获，出口 US；未选对照继续经 7897，出口 JP | 精确 PID 筛选和 SOCKS5 转发可工作 |
| 同一探针中的 loopback 分支 | 即使选中 PID，其到 `127.0.0.1:7897` 的连接仍未被捕获，出口 JP | 当前扩展不能接管该本机代理连接 |
| `process-proxy-mapkit-probe.log`，macOS 独立程序 | 设置 Apple 公开进程代理 API 后，普通 URLSession 为 US；MapKit 仍返回北京，转发日志没有地图连接 | 进程内普通 HTTPS 的出口不能代替 MapKit 出口证据；不是 iOS 设备测试 |
| `us-proxy-26.xcresult` / `us-proxy-network.log` | 有效租约内只选择目标 `launchd_sim` 进程树，包含其 geod；51 次 PID 名单更新、0 个连接事件；纽约结果仍错误 | 未建立 MapKit 经美国出口的证据，不能据此判断美国用户也会失败 |

当前扩展源码用 remote/local 均为 nil 的 `NENetworkRule`。Apple 的 [规则说明](https://developer.apple.com/documentation/networkextension/nenetworkrule/init(remotenetwork:remoteprefix:localnetwork:localprefix:protocol:direction:)) 及本机 Xcode 26.5 SDK 的 `NENetworkRule.h` 明确此类规则排除 loopback。结合独立探针，确认了现有 `7897` 本机代理路径的覆盖缺口。由于本轮没有实际 MapKit 连接，仍不能断言它具体走了该路径；缓存、已有连接或共享服务等可能性尚未排除。

临时桥接已实现 TCP 和经 SOCKS5 转发的 DNS；其他 UDP 未支持，不能作为完整 VPN。动态 PID 发现也可能漏掉新进程的首次连接。未修改扩展签名或源码，未把共享宿主服务纳入范围。单模拟器美国出口方案目前尚未达标，需要解决 loopback/实际服务连接覆盖后再做网络对照；不因普通探针通过而放行上线。

本轮 run ID `rent-room-us-proxy-en26-01a19adf`，目标 SHA `9b28f02ebeb520bd0cf5fe47addcb7efe8d839ce`，UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`，选择器 `XunjuUITests/LivePlaceSearchTests/testEnglishUSAddressSearchAcrossStatesAndPersist`。配置为证据目录的 `us-english-config.json`，构建缓存由共享 runner 分配为 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-6daf59b494416c091df13e6b-simulator`，scheme 为 Xunju。构建退出 0，测试退出 65，完整 summary 与附件已导出，原始截图已检查。

测试租约已释放，转发控制会话和 `18081` 临时监听器已停止，扩展保留安装及启用状态。`proxy-after-network-extension.json` 与原备份逐项一致。正式美国出口对照、真机与美国用户上线验收均未完成。

英文对照 run ID 为 `rent-room-us-market-en26-01a19adf`，UDID 为 `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`，完整证据为 `us-english-26.xcresult` / `us-english-26-summary.json`。退出码 65，租约已释放。新增测试提交 `d8c17f4e3eccaecd2b4b694ec59476f8256339e7` 没有修改生产源码。
