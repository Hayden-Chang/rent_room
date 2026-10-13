# macOS 微信开发者工具实例池

**实验状态：双实例人工准备后的并行隔离已验证；通用 runner 的全新 profile 冷启动仍未通过。不得作为其他 Agent 的默认测试入口。** `run` 必须显式传 `--experimental`；[现场报告与未完成项](../../docs/wechat/INSTANCE_POOL_VALIDATION.md) 区分已经证实的能力和失败记录。下列内容描述实现及诊断用法，不代表完整流程已验收。

适用版本：微信开发者工具 Stable **2.01.2510290（NW.js）**，macOS，最多两槽。Python 3.9+、Node.js 24。它是本机测试基础设施，不改变小程序业务代码，也不自动上传、发布或合并。

## 为什么不能只复制 App

本机实验发现两个必须处理的工具行为：

1. `wechatwebdevtools` 外层启动器在退出路径中按通用进程名清理 Daemon，可能误伤另一安装的守护进程。runner 只直接启动副本的 `Contents/MacOS/wechatdevtools`，不运行外层启动器、`open` 或可能自动拉起启动器的厂商 CLI。
2. 内部 MiniCode 服务固定使用 `32123`，失败只回退到 `33233`；原实例加两个副本会卡住。初始化只对池内副本的 `core.wxvpkg` 做两处等长端口替换，校验匹配次数、保存原文件和前后 SHA-256。原安装保持不变。版本变化必须重新验证，不自动打猜测性补丁。

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

任一端口占用即失败，不终止占用者。默认不增加第三槽。

## 提交测试

先在各自 worktree 构建小程序，使用 **built project / dist** 提交。测试脚本须使用给定端口和产物目录；执行 cwd 是冻结后的工程，脚本路径使用绝对路径。

```sh
python3 /绝对路径/scripts/wechat-pool/pool.py \
  --root /Volumes/mac2/codex-builds/wechat-instance-pool run \
  --project /绝对路径/apps/wechat/dist --experimental --wait 300 --timeout 120 \
  -- node /绝对路径/your-test.cjs
```

回调环境：`WECHAT_WS_ENDPOINT`、`WECHAT_PROJECT_PATH`、`WECHAT_RUN_ID`、`WECHAT_SLOT_ID`、`WECHAT_ARTIFACT_DIR`。可用 `WECHAT_NODE` 指定 health probe 的 Node 路径；SDK 默认来自本脚本目录下的锁定依赖，`WECHAT_AUTOMATOR_MODULE` 仅用于显式诊断。

```js
const automator = require('/绝对路径/scripts/wechat-pool/node_modules/miniprogram-automator');
const mini = await automator.connect({wsEndpoint: process.env.WECHAT_WS_ENDPOINT});
try {
  // 此处运行真正的测试并断言。不得直接调用 handler 冒充用户交互。
  await mini.screenshot({path: process.env.WECHAT_ARTIFACT_DIR + '/screen.png'});
} finally {
  mini.disconnect();
}
```

两个任务获得不同槽位；更多任务 FIFO 等待。每次执行使用全新的 profile，登录种子相同但业务存储不共享，因此上一轮写入不应出现在下一轮。运行时、插件可写副本、工程快照、结果文件均按 run ID 隔离。

源码复制前后核对文件哈希和 Git HEAD；拒绝符号链接和复制过程中的变化。个人工具配置 `project.private.config.json` 不进入快照哈希。receipt 的 `sourceHead` 是提交背景，`sourceStatus` 与 `snapshotHash` 才能说明脏工作区的实际输入；不能把脏快照冒充干净 PR head。执行后再次核对快照，防止测试修改被测源码。

## 生命周期与恢复

- 原子 allocator 锁只覆盖分配；每槽使用内核文件锁。等待者不占运行槽。
- 回调和运行时继承租约描述符。监督进程退出时不会按 TTL 抢占仍在运行的子进程。
- PID 与完整启动身份匹配后才允许退出本次创建的进程组。禁止按应用名 kill、关闭全部窗口或重启其他 Agent 工具。
- 遗留运行时仍活着的槽位会隔离为 `busy-or-quarantined`；不会为了腾槽自动杀掉它。查 receipt/runtime.json 后处理该具体任务。
- 超时/失败写入失败 receipt 并清理本次运行时。保留原始日志，不以成功重试覆盖失败记录。
- `runs/<runId>/` 含 profile 和登录信息，属于私有本机数据。分享时只取脱敏的 receipt、assertions 和截图；不要上传整个 run 目录。
- 退出本次任务后释放租约，不修改既有微信实例。需要回滚时停止提交新任务、等待池内任务结束，保留目录和证据即可；不必动原安装。

```sh
python3 scripts/wechat-pool/pool.py --root /Volumes/mac2/codex-builds/wechat-instance-pool status
```

## 验证范围与限制

`test_pool.py` 测试调度、锁继承、源码冻结、失败/冲突保护和种子白名单；`make-fixture.py`、`smoke.cjs` 是独立于业务包的基础设施验证夹具，检查实际运行时、同名存储/文件、重载和截图。夹具用 SDK 写入测试状态，不声称验证了真实点击/手势。

本机 3.17.3 基础库下曾出现 SDK `Page.data()` / 元素查询超时；连接、运行时读取、导航和截图可用。实例池不修复这个 SDK 问题，也不把调用 handler 算作 UI 验收。需要真实鼠标的操作仍共享 Mac 桌面，应串行协调；本 runner 只允许不占桌面输入的 SDK 回调并行。此版本没有跨 CUA 会话的强制鼠标锁，不能同时安排多个 Agent 拖动桌面窗口。

SDK 使用官方 `miniprogram-automator@0.12.1`，其依赖较旧；这是隔离的开发依赖，不进入小程序产物。不要在这里运行来历不明的工程或脚本。

```sh
python3 -m unittest discover -s scripts/wechat-pool -p 'test_*.py' -v
python3 scripts/wechat-pool/make-fixture.py /private/tmp/pool-fixture demo '<已授权 AppID>'
python3 scripts/wechat-pool/pool.py --root /Volumes/mac2/codex-builds/wechat-instance-pool run \
  --project /private/tmp/pool-fixture --experimental -- node /绝对路径/scripts/wechat-pool/smoke.cjs
```
