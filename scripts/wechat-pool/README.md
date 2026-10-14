# macOS 微信开发者工具实例池

**本机基础设施已验证：三槽关闭后按需启动、三个真实模拟器回调并行、第四任务 FIFO 排队、同 PID 接续复用。** 详细结果及历史失败见[现场报告](../../docs/wechat/INSTANCE_POOL_VALIDATION.md)。正常归还保留工具进程；手动退出后，下次任务会在确认原控制器及子进程全部退出后自动启动。工具崩溃、登录失效和业务 UI 验收仍按下文边界处理。

适用版本：微信开发者工具 Stable **2.01.2510290（NW.js）**，macOS，最多三槽。Python 3.9+、Node.js 24。它是本机测试基础设施，不改变小程序业务代码，也不自动上传、发布或合并。

## 为什么不能只复制 App

本机实验发现两个必须处理的工具行为：

1. `wechatwebdevtools` 外层启动器在退出路径中按通用进程名清理 Daemon，可能误伤另一安装的守护进程。runner 只直接启动副本的 `Contents/MacOS/wechatdevtools`，不运行外层启动器、`open` 或可能自动拉起启动器的厂商 CLI。
2. 内部 MiniCode 服务固定使用 `32123`，失败只回退到 `33233`；原实例加两个副本会卡住。初始化只对池内副本的 `core.wxvpkg` 做两处等长端口替换，校验匹配次数、保存原文件和前后 SHA-256。原安装保持不变。版本变化必须重新验证，不自动打猜测性补丁。
3. 项目初始化的 `restore()` 会在 macOS 激活工具，即使已经禁用 `focus()`。runner 给池副本增加独立 document-start 入口，保留原厂脚本，首窗隐藏、项目窗以 `focus:false/show:true` 创建，抑制 `show/focus/restore/requestAttention`，同时覆盖窗口枚举和独立 Node 上下文。完全隐藏项目窗会导致模拟器初始化超时，所以后台运行指不抢前台，窗口仍可在后台渲染。真实冷启动、同 PID 复用、SDK 截图及前台采样见[后台启动验收](../../docs/wechat/BACKGROUND_STARTUP.md)。

不能对池内 App 使用 Finder/Open 或通用 `cua.getApp(path)` 来启动，因为它们可能重新执行外层启动器。SDK 通过明确的 `WECHAT_WS_ENDPOINT` 连接；禁止 `automator.launch()` 和厂商 `cli` fallback。

## 安装

在独立任务 worktree 中安装固定的自动化 SDK：

```sh
npm ci --ignore-scripts --prefix scripts/wechat-pool
```

选择全新的机器级池目录，不能放在某个任务的 dist 内。`--source-profile` 必须属于当前用户的已登录开发者工具：

```sh
python3 scripts/wechat-pool/pool.py \
  --root /Volumes/mac2/codex-builds/wechat-instance-pool init \
  --source-app /Volumes/mac2/application/wechatwebdevtools.app \
  --source-profile '/Users/pc/Library/Application Support/微信开发者工具/613da3c17d0ddc4cc8c026a2b6519f01'
```

只复制登录信息、工具设置、模拟器设备偏好，以及工具插件/基础库资源。没有复制项目列表、房源、媒体或小程序业务缓存。新旧偏好存储格式同时初始化，关闭设置同步和自动打开旧项目。登录态保存在权限受限的本机目录，不写到 Git、日志摘要或 PR；失效后需刷新登录种子，不能用清理原实例缓存来恢复。

初始化默认端口：

| 槽位 | IDE HTTP | 自动化 | MiniCode 主/回退 |
| --- | --- | --- | --- |
| 1 | 19651 | 19751 | 32161 / 33261 |
| 2 | 19652 | 19752 | 32162 / 33262 |
| 3 | 19653 | 19753 | 32163 / 33263 |

任一新槽端口占用即失败，不终止占用者。默认容量为 3，首次领用才启动工具；常驻不等于初始化时预启动。已有两槽池由维护者执行以下扩容，保留旧槽配置、profile、进程和租约；新增副本就绪后原子发布配置，不启动任何工具。已经排队的旧 runner 仍按原配置等待，新提交可见三槽。

```sh
python3 scripts/wechat-pool/pool.py --root /Volumes/mac2/codex-builds/wechat-instance-pool expand \
  --source-app /Volumes/mac2/application/wechatwebdevtools.app
```

重复扩容到三槽不产生新副本；中途失败保留诊断目录且不发布新配置，不覆盖部分副本。

## 提交测试

先在各自 worktree 构建小程序，使用 **built project / dist** 提交，`project.config.json` 必须包含明确的 `appid`、`libVersion`。测试脚本须使用给定端口和产物目录；执行 cwd 是本槽由冻结输入复制的工程，脚本路径使用绝对路径。

本 Mac 的已安装入口固定为 `/Volumes/mac2/codex-builds/wechat-instance-pool/runner/pool.py`，其脚本和锁定 SDK 独立于任务 worktree。旧 worktree 也用此入口；不要覆盖主工作区来同步 runner。维护者从已验收提交安装到 `runners/<SHA>/`，再原子切换 `runner` 链接；更新入口不重启常驻实例。

```sh
python3 /Volumes/mac2/codex-builds/wechat-instance-pool/runner/pool.py \
  --root /Volumes/mac2/codex-builds/wechat-instance-pool run \
  --project /绝对路径/apps/wechat/dist --wait 300 --timeout 120 \
  -- node /绝对路径/your-test.cjs
```

回调环境：`WECHAT_WS_ENDPOINT`、`WECHAT_PROJECT_PATH`、`WECHAT_RUN_ID`、`WECHAT_SLOT_ID`、`WECHAT_ARTIFACT_DIR`。可用 `WECHAT_NODE` 指定 health probe 的 Node 路径；SDK 默认来自本脚本目录下的锁定依赖，`WECHAT_AUTOMATOR_MODULE` 仅用于显式诊断。

```js
const automator = require('/Volumes/mac2/codex-builds/wechat-instance-pool/runner/node_modules/miniprogram-automator');
const mini = await automator.connect({wsEndpoint: process.env.WECHAT_WS_ENDPOINT});
try {
  // 此处运行真正的测试并断言。不得直接调用 handler 冒充用户交互。
  await mini.screenshot({path: process.env.WECHAT_ARTIFACT_DIR + '/screen.png'});
} finally {
  mini.disconnect();
}
```

三个任务获得不同槽位；第四个及更多任务 FIFO 等待。每槽长期持有独立工具进程、profile 和插件可写副本。任务归还后进程继续存活，下次领用直接复用。每槽固定使用 `slots/<slot>/project`，避免 NW 首次打开新路径时读到未初始化的 AppID/基础库；不可变输入保存在 `runs/<runId>/project`，被替换的旧工程保存在本次 run 的 `previous-project`。启动前将本任务配置登记到该槽独立 profile；AppID/基础库变化才在独占租约中重启本槽。项目准备由 `preparation.lock` 串行，避免并发启动/导入相互干扰；锁在回调前释放，三路测试仍并行。每个任务开始前、归还前，通过该槽位的明确 SDK 端口清空并核对小程序 storage 和 USER_DATA_PATH 文件。开始前清理后重开项目，使 App 内存状态重新初始化；这不会退出工具进程。池内只运行可丢弃测试数据的工程，不能把个人日常使用的实例纳入池。

源码复制前后核对文件哈希和 Git HEAD；拒绝符号链接和复制过程中的变化。个人工具配置 `project.private.config.json` 不进入快照哈希。receipt 的 `sourceHead` 是提交背景，`sourceStatus` 与 `snapshotHash` 才能说明脏工作区的实际输入；不能把脏快照冒充干净 PR head。执行后再次核对槽内工程，防止测试修改被测源码。只有根 `project.config.json` 按 JSON 值计算哈希，允许工具调整缩进；字段值变更仍失败。其他文件按原始字节校验。

## 生命周期与恢复

- 原子 allocator 锁只覆盖分配；每槽使用内核文件锁。等待者不占运行槽。
- 回调继承租约描述符，常驻工具进程不继承租约，避免归还后仍锁住槽位。监督进程崩溃后，`leased` 状态也阻止其他任务接管；不按 TTL 抢占。
- 正常归还只清理该任务小程序数据、关闭该任务项目并释放租约。工具进程、登录配置和插件资源保留，没有空闲自动退出机制。receipt 记录 `runtimePid`、`runtimeReused` 和 `residentState`。
- 后台策略只写入已停止的池内副本，不修改原安装、系统安全设置或签名。未知版本、脚本路径越界或资源出现未知改动时失败并隔离。旧版常驻进程在下一次取得独占租约后迁移一次；随后继续同 PID 复用。更新 runner 链接本身不重启任何实例。
- 测试失败或回调超时时，仅停止本任务仍运行的回调进程组；清理和关闭项目成功后仍可归还常驻实例。PID 与启动身份不符时拒绝操作。
- 工具启动、数据清理、项目关闭或进程身份检查失败时，槽位标记 `quarantined`，保留进程及日志供排查，不自动杀掉或交给下一任务。工具、原控制器及该 profile 子进程全部退出后，下一次领用可以自动恢复，并把旧 runtime 原样存入新 run 的 `runtime-history/`；原失败 receipt 保留。任一相关进程仍活着则继续隔离，不自动杀进程。实际发生过工具原生 `SIGSEGV` 留下孤儿子进程；这种情况需要统一维护者在核实任务已结束、持有该槽锁后处理。
- 旧版按任务启动的活实例不接管、不迁移、不停止。`busy-or-quarantined` 可能表示现有租约、旧版实例或待排查槽位，应检查 `runtime.json` 和 receipt。
- `slots/<slot>/resident-profile/` 含登录信息，`runs/<runId>/` 含工程和任务证据，均属于私有本机数据；旧版 run 目录也可能含 profile。分享时只取脱敏 receipt、assertions 和截图，不上传整个目录。
- 禁止按应用名 kill、关闭全部窗口或重启其他 Agent 工具。需要停用时先停止提交、等待任务归还；关闭常驻进程属于单独维护操作，不能影响原安装。

```sh
python3 scripts/wechat-pool/pool.py --root /Volumes/mac2/codex-builds/wechat-instance-pool status
```

## 验证范围与限制

`test_pool.py` 的测试覆盖调度、锁继承、源码冻结、失败/冲突保护、种子白名单、三槽扩容保护及常驻复用。复用测试使用真实替身进程，证明两个任务复用同一 PID、归还后进程存活且租约可再次获得；微信 HTTP/SDK 协议被 mock，不是微信现场验收。新增恢复保护、启动前元数据、准备锁和配置格式回归；本次按影响运行 14 个 Python 精确用例、3 个 health Node 用例，映射见现场报告。health 同时探测 App/页面和截图通道，单次 RPC 失败会在总截止时间内重新连接。`reset-data.test.cjs` 的 3 项 VM 测试覆盖数据清理范围和失败传播。`make-fixture.py`、`smoke.cjs` 是独立于业务包的基础设施验证夹具，检查实际运行时、同名存储/文件、重载和截图。夹具用 SDK 写入测试状态，不声称验证了真实点击/手势。

本机 3.17.3 基础库下曾出现 SDK `Page.data()` / 元素查询超时；连接、运行时读取、导航和截图可用。实例池不修复这个 SDK 问题，也不把调用 handler 算作 UI 验收。需要真实鼠标的操作仍共享 Mac 桌面，应串行协调；本 runner 只允许不占桌面输入的 SDK 回调并行。此版本没有跨 CUA 会话的强制鼠标锁，不能同时安排多个 Agent 拖动桌面窗口。

SDK 使用官方 `miniprogram-automator@0.12.1`，其依赖较旧；这是隔离的开发依赖，不进入小程序产物。不要在这里运行来历不明的工程或脚本。

```sh
# Python 用例按本次 diff 精确选择，示例：
(cd scripts/wechat-pool && python3 -m unittest test_pool.PoolTests.test_closed_quarantined_resident_can_be_leased_again)
node --test scripts/wechat-pool/health.test.cjs
node --test scripts/wechat-pool/reset-data.test.cjs
python3 scripts/wechat-pool/make-fixture.py /private/tmp/pool-fixture demo '<已授权 AppID>'
python3 /Volumes/mac2/codex-builds/wechat-instance-pool/runner/pool.py --root /Volumes/mac2/codex-builds/wechat-instance-pool run \
  --project /private/tmp/pool-fixture -- node /绝对路径/scripts/wechat-pool/smoke.cjs
```

`--experimental` 为旧命令保留的兼容参数，不再是提交测试的必需参数。
