# 微信开发者工具后台启动验收（2026-10-14）

本次修复在独立诊断槽通过冷启动、打开项目、重载、截图、清理归还和同 PID 复用：约 75 秒、860 次 LaunchServices 前台采样中，前台始终为 Codex，未观察到开发工具激活。三个正式槽的 PID 35433 / 30348 / 31087 和 idle 状态在验证前后均未改变。这里只验证本机 Stable 2.01.2510290，不声称支持其他工具版本，也不替代业务点击/真机验收。

## 原因与最终行为

项目初始化会调用 NW 窗口的 `restore()`。独立诊断记录中，调用时间为 `1791958497.107`，前台变为工具 PID 70072 的时间为 `1791958497.150`，相差约 43 毫秒。仅禁用 `show()`、`focus()` 和启动时加 `open -g` 都挡不住此入口。

最终 runner 仍直接运行内部 `wechatdevtools`，没有采用 Finder/open、外层启动器、Info.plist 原生入口改写或签名修改。它只在持有槽位独占租约、原进程已停止后修改池副本：

- 保留原 package.json 备份和原厂 document-start 脚本，manifest 指向独立 `pool-background.cjs`，拼接原厂脚本保持其逻辑。
- 首窗口 `focus:false/show:false`；项目窗口 `focus:false/show:true`，允许模拟器初始化和渲染。
- 对 get/open/getAll 的窗口句柄抑制自动 `show/focus/restore/requestAttention`，同时覆盖浏览器 `nw` 和独立 Node 上下文的 `global.nw`。
- 仅在进程带有 `WECHAT_POOL_BACKGROUND=1` 时生效。遇到未知版本、越界脚本路径、未知资源改动则拒绝启动，不覆盖未知内容。
- 固定入口升级不立即重启正式槽。旧进程在下一次独占领用时迁移本槽一次，其他正在使用的槽继续运行。正常归还保留进程和登录态。

后台运行表示不主动激活前台，项目窗口仍可在后台渲染。完全隐藏项目窗的对照试验虽然没有抢焦点，但 App/page 健康检查超时，因此没有采用。需桌面鼠标的操作仍须串行协调。

## 最终证据

验证基线为 main `226bb195bd665419021335c9df41b648b01bf504` 加本 PR 改动。执行时尚未提交，源码、测试、SDK 锁文件和验证输入的 SHA-256 记录在 [tested-inputs.json](background-evidence-20261014/tested-inputs.json)；最终候选提交与这些文件逐项比对，具体候选 SHA 记录在 PR 描述。文档证据整理不改变运行输入。

- 11 个 Python 精确回归用例通过：[完整日志](background-evidence-20261014/python.log)。
- 6 个 Node VM 用例通过：[完整日志](background-evidence-20261014/node.log)。
- 冷启动 run `41c730c8efd247668daadff606d15444`、复用 run `26ad1ee579904aa99893730d1e29b0b3` 均 passed/idle，同 PID **72151**；第二次 `runtimeReused:true`。报告见 [campaigns.json](background-evidence-20261014/campaigns.json) 的 `inactive-verified`。
- 两次夹具均断言初始 storage 为空，写入唯一 run ID 到内存、storage 与文件，重载后核对持久化并截屏；[冷启动断言](background-evidence-20261014/cold-assertions.json)、[复用断言](background-evidence-20261014/reuse-assertions.json)。
- 实际画面：[冷启动截图](background-evidence-20261014/cold.png)、[复用截图](background-evidence-20261014/reuse.png)。这是基础设施夹具，没有声称业务点击或手势通过。
- 前台监测只读取 `lsappinfo front` 和 `info -only pid,bundleid`，目标间隔 75ms，实际约 90ms。860 次采样、零读取错误、仅 Codex 一个前台事件；采样有时间分辨率限制，不声称证明任意未来窗口和毫秒级瞬态。

现场命令为 `python3 -B /private/tmp/wechat-inactive-verify.py`，诊断池 `/private/tmp/wechat-background-20261014` 的端口为 19953/19963/32263/33363。监测覆盖两个完整 `pool.py run --project <fixture> --wait 5 --timeout 60 -- node <smoke.cjs>`，回调前后均有健康与清理检查。原始日志/profile 保留在本机私有目录，禁止上传整个目录。脱敏的成功场景日志位于本证据目录的 `cold-*.log`、`reuse-*.log`。

## 自动化回归映射

Python cwd 为 `scripts/wechat-pool`，命令 `python3 -B -m unittest -v <精确选择器>`，以下名称均加前缀 `test_pool.PoolTests.`：

| 变化边界 | 精确用例 |
| --- | --- |
| 启动前窗口策略、环境变量 | `test_background_policy_is_applied_before_process_launch` |
| 原厂脚本保留、重复配置 | `test_background_startup_preserves_vendor_script_and_is_idempotent` |
| 路径和未知修改保护 | `test_background_startup_refuses_unknown_edits_and_outside_paths` |
| 暖复用、旧策略迁移、租约释放 | `test_two_jobs_reuse_one_live_process_and_release_the_lease` |
| 配置冷启动、准备锁 | `test_new_project_metadata_is_loaded_before_health_check`、`test_project_preparation_is_serialized_but_callback_is_not` |
| 关闭后恢复、活进程保护 | `test_closed_quarantined_resident_can_be_leased_again`、`test_dead_tool_with_live_controller_is_not_reclaimed`、`test_live_pid_with_changed_identity_is_never_reclaimed` |
| 控制器崩溃、归还失败 | `test_controller_crash_does_not_reassign_a_leased_resident`、`test_return_failure_quarantines_resident_without_killing_it` |

Node 命令 `node --test background.test.cjs`，6 个用例全部为本 PR 新增，覆盖自动激活、可渲染的无焦点创建、可选回调、重复 get、环境开关、枚举窗口、独立 Node 上下文及 restore。没有运行应用全套或业务 UI 全套。

修复前行为失败证据均保留：主线首窗仍请求焦点 [red.log](background-evidence-20261014/red.log)；枚举句柄绕过策略 [enumeration-red.log](background-evidence-20261014/enumeration-red.log)；独立 Node 上下文绕过 [context-red.log](background-evidence-20261014/context-red.log)；新 restore 回归调用了 8 次原生恢复而期望 0 次 [restore-red.log](background-evidence-20261014/restore-red.log)。最后一项使用 `node --test --test-name-pattern='restoring a project window' background.test.cjs` 在增加 restore 抑制前失败，修复后通过。

## 保留的失败与排除方案

[campaigns.json](background-evidence-20261014/campaigns.json) 保留各轮结果，不能只看 SDK passed 而忽略前台失败：

1. 直接后台 Popen、只抑制 show/focus、只改同名原厂注入文件、改独立注入入口、补 getAll、补 global.nw 均仍出现前台激活。旧资源可能优先从厂商打包文件加载，因此最终使用独立入口。
2. 初期 NSWorkspace 读数滞留在 SecurityAgent，用户反馈没有弹窗；该读数废弃，改用独立 LaunchServices 采样。没有读取系统认证界面内容。
3. `LSUIElement` 导致底层 ICU 资源路径错误，撤回。原生 `open -g -j -n` 第一次受 LaunchServices 旧缓存影响，尝试了已失效签名的外层入口，被系统拒绝；没有绕过签名检查。使用唯一 bundle ID 登记内部入口后，锁屏期间曾超时；解锁重试（`native-unlocked-verified`）SDK 冷/暖通过，但 9.835 秒时仍抢前台，方案撤回。
4. 禁用 restore 且全部窗口隐藏（`restore-verified`）没有前台激活，但健康检查超时；最终改为项目窗不激活地显示，保留初始入口隐藏，才同时通过焦点与 SDK 验证。

所有试验只使用本任务独立副本。诊断 Info.plist 已恢复；诊断外层启动器另存为 `wechatwebdevtools.pool-unused` 防止旧缓存误启动，生产 app 和系统安全策略未改动。失败原始 receipt 与 runtime-history 保留。

参考：[NW.js Window API](https://docs.nwjs.io/References/Window/)、[实际新窗口 restore 实现](https://github.com/nwjs/nw.js/blob/nw-v0.54.0/src/resources/api_nw_newwin.js)、[独立 JavaScript 上下文](https://docs.nwjs.io/For%20Users/Advanced/JavaScript%20Contexts%20in%20NW.js/)。源码用于定位；本修复是固定版本的本机池适配，不是厂商支持声明。
