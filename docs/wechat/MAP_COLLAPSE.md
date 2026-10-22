# 地图自动收起验证（2026-10-22）

房源和上班地址共用 `address-picker`。搜索框输入或清空时自动展开地图；点击“使用”/搜索结果、手填地址变化后收起地图；“展开地图”恢复当前页面中的中心和缩放，不调用 GPS。收起后不挂载原生地图，迟到的定位/区域回调不能移动视野。手动收起保留待执行搜索；只读地图继续显示已保存的位置。

## 本轮修订：搜索输入自动展开

按用户最新反馈修正搜索交互：从收起状态输入搜索文字立即展开，搜索响应到达后继续展开；手动收起待执行搜索时，响应不会自行打开地图。选择结果触发的程序清空搜索词仍保持收起。手填地址继续收起，展开保留中心与缩放。

源码与测试提交 `c3ca7bca8d5bc90920405ac642a11a57cdd1c5a3`。更新的回归在旧实现上3失败/4通过；修改后5文件共46项通过（地图回归由7项增至8项，新增清空搜索展开检查）。Node24构建和官方wcc/wcsc编译通过。日志为 `/private/tmp/rent-room-map-collapse-20261022/wechat-search-expand-{red,green,build,check}.log`。

本轮实际渲染尝试：共享池 run `0376df10ed2e4703924e466ff4d4c793`，冻结源码 `c3ca7bc`、工作树干净，槽1、runner PID49667、工具PID50687、工具2.01.2510290。`health-before.log` 以 `App service health timeout` 失败，回放尚未执行，未取得本轮截图。receipt 保存在 `/Volumes/mac2/codex-builds/wechat-instance-pool/runs/0376df10ed2e4703924e466ff4d4c793/`，命令输出在 `wechat-search-expand-render.log`。池按协议保留并隔离异常实例；未重启、抢占其他槽位或改动共享SDK。

最新“搜索自动展开”的实际渲染、原生输入仍待验收；下面旧图仅保留历史，不作为新交互通过证据。

## 首轮历史：搜索输入收起（已被上述规则替代）

### 代码和自动化

生产及测试提交 `5ef38f040e22cd50abdf0cbcda219b9c0e2487ca`，独立分支 `codex/map-auto-collapse-20261022`，基于 main `f66f50c20cdcbacbbe8f55b6ebc99a563a3d949d`。主目录原有删除及未跟踪内容均未修改。

| 边界 | 定向用例 |
| --- | --- |
| 收起/展开、选点、手填、待执行搜索、迟到 GPS、只读 | `tests/address-map-collapse.test.js`（7项）及 `tests/address-picker.test.js`（13项） |
| 微信区域事件、缩放属性、延迟回调及字段绑定 | `tests/address-bindings.test.js`（8项） |
| 坐标、选点和持久化规则 | `tests/places.test.js`（8项） |
| 上班地址页面和已有状态 | `tests/workplace-runtime.test.js`（9项） |

上述45项通过。构建及官方 `wcc`、`wcsc` 各14文件/12页面编译检查通过；只选择本次影响的5个测试文件，没有运行全量 suite。命令为 `npm run build`、`npm test -- tests/address-map-collapse.test.js tests/address-picker.test.js tests/address-bindings.test.js tests/places.test.js tests/workplace-runtime.test.js`、`npm run check`，测试构建使用 `WECHAT_TEST_DATA_ROOT=xunju-test-map-collapse-20261022`。

最终检查使用临时官方 Node **24.22.1**（`npm exec --package=node@24`），构建、上述45项测试及官方编译全部通过；未更改系统 Node 或项目依赖。初步检查使用 shell 默认 Node25，最终结果以上述兼容版本为准。Node24构建与下述截图冻结快照的108个文件逐字节一致，差异为空；证据见 `wechat-node24-tests.log`、`wechat-node24-check.log` 和 `wechat-node24-equivalence.json`。其后仅新增本文档，生产及测试源码与5ef38f0一致。

初始5项新增回归在原生产代码上均因无收起状态/手填会拉回旧中心而失败；审查又增加待执行搜索和只读中心检查，修复前2项按预期失败。失败、通过和后续 Node 24 检查日志在 `/private/tmp/rent-room-map-collapse-20261022/wechat-*.log`。

### 首轮实际渲染及证据边界

通过固定共享池入口 `/Volumes/mac2/codex-builds/wechat-instance-pool/runner/pool.py`，run ID `b66661c22b4946ea90a0bd2258b5d796`，槽1、常驻PID12727、工具2.01.2510290、基础库3.17.3。测试数据根独立且可丢弃，完成后已清理、归还；工具进程保留。

`MAP_REVIEW_HANDLER_REPLAY=1` 模式调用实际生产处理函数，再通过组件 `createSelectorQuery` 确认地图节点已出现/消失后截屏。记录器核对“使用”后地址/坐标、搜索和手填后的收起、三次展开的中心 `{latitude:22.5405,longitude:113.951}` 和缩放16一致。**这是处理函数回放及真实渲染证据，不是原生点击/输入 E2E。** 没有调用用户真实 GPS 或查询供应商，地点服务使用固定夹具。

- 原始 receipt、8张780×1506截图及 `map-collapse.json`：`/Volumes/mac2/codex-builds/wechat-instance-pool/runs/b66661c22b4946ea90a0bd2258b5d796/`。
- 本批工具中底图瓦片未加载，能看到原生地图容器/中心标记及折叠结果；不将属性一致当作地图底图、原生拖拽/缩放或物理设备定位通过。
- 前4轮自动化导航/元素查询等待超时；同租约只读检查确认路由和截图可用，但元素接口不返回。原生桌面工具选择该窗口也两次超时，第5轮人工记录器只停止了本任务回调PID，由池正常清理。
- 第6轮修正组件ID后完成状态回放，但截图早于视图提交，且追加文件读取报错；保留该轮原始输出，不用其空白/旧帧截图验收。第7轮改为观察实际地图节点后取得当前有效截图。原生交互、文件系统重载及手机中文键盘均未验证。
- 原始失败 receipts 与日志保留在本次目录的 `wechat-e2e*.log`、`wechat-native-05.log`、`wechat-render-06.log` 以及各 pool run 内；没有修改共享SDK、工具版本或用户工程。

当前为待用户确认版本，未合并或发布。确认组件外观后仍需手机/原生输入验收；iOS组件及外部手填地址接入边界见独立原生分支的 `docs/ios/MAP_COLLAPSE_REVIEW.md`。
