# 地图自动收起组件评审（2026-10-22）

本次仅评审原生地点组件：点击“使用”或搜索结果、输入搜索文字、外部手填地址变化时收起地图，保留搜索结果和“展开地图”入口。再次展开恢复完整 MapCamera（中心、距离、方向和倾角），不主动请求 GPS。隐藏地图不参与点击或无障碍导航；只读地图仍可查看。

## 范围和接入边界

- 基于尚未合并的 iOS 开发分支 `codex/ios-parity-20261019`，父提交 `4cabe5fb8ef5f87704cce947fc59ce91e0b01327`；本次子分支 `codex/ios-map-auto-collapse-20261022`。
- `PlacePickerSurface` 已实现交互，Debug 显式地点评审宿主使用同一组件和外部地址参数。正式 `LocationPages.swift` 尚未传入外部手填地址；须经本次视觉批准后再接入房源/上班地址变化，并验证手填失效坐标时仍保留当前视野。
- 评审宿主候选地点为固定夹具；地图为真实 MapKit，平移使用原生手势。宿主选点不写房源，不代表业务保存或物理 GPS 已验收。
- `reviewCameraChanged` 仅在 Debug 编译，普通业务调用为 nil；用于读回真实相机距离，不改变相机决策。

## 自动化证据

共享 runner `/Volumes/mac2/projects/git_repo/run_self/Simulator Management/bin/sim-test-run.mjs`，实时配置 `config/runner.json`。本批使用 iPhone 16 / iOS 26.5，UDID `5FC4A20B-AF44-4A92-BF91-B0096BEBF1D9`。构建均经项目 `scripts/run-xcodebuild.sh` 和固定 XcodeGen 2.45.4；未改工程配置或提交生成工程。

| 源码边界 | 精确方法 | 结果 |
| --- | --- | --- |
| 选点、搜索、手填地址及相机保留 | `XunjuUITests/UtilityReviewTests/testPlaceMapCollapsesAfterUseAndSearch` | `e9320c4` 通过；平移后比较中心及相机距离，并保存7张状态图 |
| 只读地图 | `XunjuUITests/UtilityReviewTests/testReadOnlyMapHidesEditingAndLocationActions` | `e9320c4` 通过 |
| 搜索选择、定位权限及设置入口 | `XunjuUITests/UtilityReviewTests/testPlaceSearchSelectionAndPermissionFallback` | `7321c0a` 单方法重跑通过 |

不选择独立 UT：本次状态和相机仅存在于 SwiftUI 组件内，未修改业务模型或查询服务；通过上述真实 UI 方法验证交互边界。未运行全部 UT/UI suite。

- 修复前 `4fea0d6` 新增 UI 回归在“Using a place must collapse the map”断言失败（构建成功，1方法1失败）。首次尝试因本机 Git URL 重写导致公开 Swift Package SSH 拉取失败，改为仅进程内 HTTPS 配置后取得上述有效失败。
- `c2090a8` 初轮3 UI通过，但主 agent 查看截图发现恢复 region 会改变缩放，未将其视为视觉通过。改为 MapCamera 并固定原生地图内部高度。
- `e9320c4` 批次2通过1失败。唯一失败是定位按钮边缘点击未触发权限提示；检查录屏和合成触点后，把可见 padding 移到按钮 label 内，使整个可见按钮响应。`7321c0a` 只改该命中边界，未改相机、收起状态、只读或测试夹具；复用2项通过结果，精确重跑失败方法。没有把不同尝试说成一次完整全绿。

原始证据：

- 计划及日志：`/private/tmp/rent-room-map-collapse-20261022/ios-*-plan*.json`、`ios-*.log`。
- 修复前：`/Volumes/mac2/codex-builds/xunju-map-collapse-20261022-red-02.xcresult`。
- 最后完整批次：`/Volumes/mac2/codex-builds/xunju-map-collapse-20261022-green-02.xcresult`。
- 单方法修复：`/Volumes/mac2/codex-builds/xunju-map-collapse-20261022-permission-03.xcresult`。
- 原始截图：`/private/tmp/rent-room-map-collapse-20261022/ios-attachments-02/`、`ios-attachments-03/`；截图1178×2556。
- 构建缓存由 runner 按本任务 worktree 分配：`/Volumes/mac2/codex-builds/time-fragment-dd-shared-357a8997fd7cb49447f18397-simulator`。实际执行 slot/lease 在执行时已核实，完成后释放。

当前为待用户批准的组件评审，未合并、真机安装或发布。手机中文输入、真实 GPS，以及房源/上班地址正式页面的保存与重启属于批准后接入验证。
