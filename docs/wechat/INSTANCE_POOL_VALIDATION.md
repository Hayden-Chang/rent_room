# 微信开发者工具实例池验证（更新于 2026-10-14）

当前状态：**本 Mac 的三槽按需启动、真实夹具并行、第四任务排队和同 PID 复用已通过。** 正常归还不退出工具；手动退出后，只要控制器及 profile 子进程也已退出，下次领用自动启动。基础设施夹具不替代业务交互验收。

## 2026-10-14 修复与现场验收

修复了关闭后仍被旧 `quarantined` 记录永久挡住的问题；恢复前核实工具、原控制器、profile 残留进程均已退出，并保留旧 runtime 和失败 receipt。活的旧实例、PID 身份不符及残留子进程仍不抢占。

启动使用固定槽位工程路径和启动前 AppID/基础库登记，避免新路径首次导入时缓存空配置。输入仍按 run ID 冻结并校验。工具重排 `project.config.json` 缩进不再被误报为改动，真实值变化仍拒绝。项目准备串行，回调三路并行；健康检查要求 App、页面和截图通道全部可用，并处理页面重载丢失 RPC 的情况。

版本：macOS、DevTools Stable 2.01.2510290 / NW 91、基础库 3.17.3、SDK 0.12.1。固定入口为 `/Volumes/mac2/codex-builds/wechat-instance-pool/runner/pool.py`；保留三槽容量。`--experimental` 仅作旧命令兼容。切换 AppID/基础库时只在独占租约内重启本槽，普通任务保留 PID。

### 最小现场场景与实际结果

1. 关闭本任务已空闲的全部三槽后，用正常 runner 同时提交 A/B/C：三者分别自动启动 PID 29670 / 30348 / 31087，并在各自回调中完成空存储检查、同名键/文件写入、重载读回与截图。回调使用屏障保持三个租约同时占用。
2. 提交 D：receipt 处于 queued 且无 slot；只归还 A 后，D 获得 1 号槽并复用 PID 29670，初始测试存储为空。四任务均通过且归还后保留进程。见 [冷启动 receipts](instance-pool-evidence-20261014/registered-cold-campaign/receipts.json) 和 [第四任务队列](instance-pool-evidence-20261014/registered-cold-campaign/queue.json)。
3. 另一次暖复用期间，2、3 号槽复用通过；1 号工具在 11:31:40 原生 `SIGSEGV`，该任务失败并保留隔离，不能将本次验收描述为全程无故障。见 [失败 receipt](instance-pool-evidence-20261014/warm-parallel-campaign/receipts.json) 与 [崩溃摘录](instance-pool-evidence-20261014/native-crash.txt)。工具主进程退出后残留 helper 29692，自动分配正确拒绝接管。维护者核实失败任务及主进程已退出、持有本槽独占锁后，只清理该 profile 的孤儿 helper；未重启 2、3 号槽。
4. 清理后用同一 runner 再提交：1 号自动启动 PID 35433，2、3 号复用 PID 30348 / 31087。三个回调同时完成，随后 `Promise.all` 连接三个端口，并行读回同名 storage/file 及截图：三个唯一 run ID 各自保持一致。D 再次排队后复用 2 号 PID 30348；四任务均 passed/idle。见 [恢复与复用 receipts](instance-pool-evidence-20261014/crash-recovery-campaign/receipts.json)、[并行读回](instance-pool-evidence-20261014/crash-recovery-campaign/parallel-read.json) 和 [队列](instance-pool-evidence-20261014/crash-recovery-campaign/queue.json)。

| 槽 1（C） | 槽 2（A） | 槽 3（B） |
| --- | --- | --- |
| ![C](instance-pool-evidence-20261014/crash-recovery-campaign/parallel-1.png) | ![A](instance-pool-evidence-20261014/crash-recovery-campaign/parallel-2.png) | ![B](instance-pool-evidence-20261014/crash-recovery-campaign/parallel-3.png) |

此次验证使用可丢弃夹具，通过 SDK 设置状态，不声称验证点击、手势、租房业务或云同步。本次未调用外层启动器或停止其他 Agent 的活实例。三槽现场结束均空闲、进程保留；本任务额外 Diagnostic.app 已按身份关闭。普通归还保留登录 profile；最初失效的登录种子/旧配置修复及维护备份留在私有 `maintenance/`，不上传身份数据。

### 回归映射与证据等价

[脚本/测试/锁文件 SHA-256 清单](instance-pool-evidence-20261014/validated-inputs.json) 固定现场输入；receipts 的 runnerHash 均为 `d71002c0811286219f9747c3c52857d10b509d04f100858edbb34ce61d441692`。上述冷启动、暖复用失败和恢复验证使用同一代码；恢复不是代码重试修复，也不抹去原生崩溃。故障时不自动终止活进程、已全部退出时下一任务自动启动是本次交付边界；不保证第三方工具不会崩溃。登录过期仍需维护，不能清理原安装来恢复。

本次仅运行以下 14 个 Python 精确 selector（`test_pool.PoolTests.` 前缀）和 3 个 Node health 回归，无应用全套或真实桌面输入测试：

| 改动边界 | Python selector 后缀 |
| --- | --- |
| config 值哈希、冻结输入 | `test_tool_json_formatting_is_allowed_but_config_changes_are_detected`、`test_snapshot_freezes_code_and_excludes_personal_config`、`test_snapshot_rejects_symlink_and_concurrent_edit` |
| 关闭后恢复与活进程保护 | `test_closed_quarantined_resident_can_be_leased_again`、`test_dead_tool_with_live_controller_is_not_reclaimed`、`test_live_pid_with_changed_identity_is_never_reclaimed` |
| 元数据冷启动、固定路径、配置变化、复用 | `test_new_project_metadata_is_loaded_before_health_check`、`test_two_jobs_reuse_one_live_process_and_release_the_lease` |
| 准备串行、回调并行 | `test_project_preparation_is_serialized_but_callback_is_not`、`test_three_concurrent_owners_and_fourth_waiter` |
| 锁继承、孤儿与归还失败 | `test_controller_crash_does_not_reassign_a_leased_resident`、`test_live_orphan_quarantines_only_its_slot`、`test_child_keeps_lease_if_supervisor_releases_descriptor`、`test_return_failure_quarantines_resident_without_killing_it` |

执行 `cd scripts/wechat-pool && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v <以上精确 selectors>`：14 passed，[完整日志](instance-pool-evidence-20261014/python-selected.log)。`node --test scripts/wechat-pool/health.test.cjs`：3 passed，[完整日志](instance-pool-evidence-20261014/node-health.log)，覆盖丢失 App RPC、空页面栈和未就绪截图通道。启动替身使用真实独立 sleep 进程；微信协议 mock 边界明确。原有 reset-data 源码未改，真实场景每次准备和归还均验证清理。

新增回归的修复前失败：[死槽恢复](instance-pool-evidence-20261014/recovery-red.log)、[启动前登记](instance-pool-evidence-20261014/startup-red.log)、[App RPC](instance-pool-evidence-20261014/health-red.log)、[截图就绪](instance-pool-evidence-20261014/render-red.log)、[准备锁](instance-pool-evidence-20261014/preparation-red.log)、[配置格式](instance-pool-evidence-20261014/config-format-red.log)。原始私有报告位于 `/private/tmp/wechat-pool-recovery-20261014/` 和池 `runs/<runId>/`；这里只提交脱敏字段、断言、选定日志与截图，不包含 profile/登录种子。

下面保留 2026-10-13 的历史验收范围及未完成记录；这些段落中的“未通过”表示当时状态。

## 已取得的现场证据

本机 macOS，微信开发者工具 Stable 2.01.2510290，基础库 3.17.3。使用两个 App 副本和独立 profile，IDE 端口 19451/19452、自动化端口 19551/19552；原安装保持不变。

两个会话同时连接，各自使用同名 `pool-counter` 存储键和 `pool-marker.txt` 文件，分别写入 7 和 11。重载页面后，页面数据、存储和文件读回保持各自的值。两张实际模拟器截图与断言见 [证据目录](instance-pool-evidence-20261013/parallel.json)：

| 实例 A | 实例 B |
| --- | --- |
| ![A：7](instance-pool-evidence-20261013/a-parallel.png) | ![B：11](instance-pool-evidence-20261013/b-parallel.png) |

关闭 A 项目后 B 仍保留 11；再退出本次 A 的进程，B 的自动化连接及原实例当时的 9435、9437、19361 端口仍可连接。见 [关闭范围记录](instance-pool-evidence-20261013/close-check.json)。这是 SDK 状态与存储隔离测试，没有声称验证了按钮点击或真实手势。

## 实验中的跨实例影响

最初用厂商外层启动器打开副本时，副本退出路径按通用 Daemon 名称清理，**误终止了原实例的守护进程 PID 71268**。当时原主进程 PID 71269 和上述端口仍存活，但不能将本次全过程称为“完全无影响”。已向用户披露；未擅自重启原实例来恢复守护进程。[原始启动器日志](instance-pool-evidence-20261013/launcher-cross-instance.txt)。

后续实验改为直接启动池副本的 `Contents/MacOS/wechatdevtools`，不再调用外层 `wechatwebdevtools`、Finder/open 或带自动启动 fallback 的 CLI。退出时只操作已记录身份的本任务进程组及明确带本任务唯一 profile 参数的残留进程。

验证期间原实例后来发生进程更替；本任务未发起该更替，原因未查明。对其他 Agent 正在使用的实例不做恢复、缓存清理或残留进程清扫。

## 必须隔离的额外端口

该 Mac 安装中的 MiniCode 服务固定尝试 32123，冲突时回退到 33233。原实例与第一个副本占用后，第二副本不能正常启动。只修改本任务副本内两处等长端口常量，记录前后 SHA-256 和原文件备份；原安装不修改。

参考实现：[第三方 Windows 多实例工具的端口补丁](https://github.com/Ethanxegg/wechatide-multi-instance/blob/main/scripts/patch-minicode-port.js)。它用于交叉核对固定端口问题，不作为 Mac 已获厂商支持的依据；本次 Mac 结论来自本机源码与现场实验。

## 实例池实现与未完成项

[runner 说明](../../scripts/wechat-pool/README.md) 和脚本位于 `scripts/wechat-pool/`。本机实验池位于 `/Volumes/mac2/codex-builds/wechat-instance-pool`，三个配置槽位使用独立 App、IDE/自动化/MiniCode 端口。实现 FIFO、内核租约、源码快照、每槽常驻 profile 与工具进程、身份校验和 receipt。正常任务归还只清理小程序数据、关闭项目及释放租约，下个任务复用同一存活进程。

调度与保护用例通过不等于完整 runner 可用。现场新 profile 出现过配置格式迁移异常、项目元数据未就绪、AppID/基础库为空和页面健康超时。补齐 `storage_meta.json` 后迁移异常消失；冷启动导入/重启方案仍在诊断。窗口截图确认过项目已打开但模拟器白屏，不能用 HTTP 200 或 SDK 连接成功冒充页面验收。

失败 receipt、私有 profile 与日志保留在池的 `runs/<runId>/`，不得将整个目录上传（包含登录态）。原始实验另存 `/private/tmp/wechat-isolation-01a1348c/`。源码和本报告不包含登录种子。

完成接入前还必须在最终 runner 上取得：两个真实任务并发通过、第三任务等待后通过、连续任务复用同一 PID、复用前后的测试数据清理、归还一槽不影响另一槽、常驻进程与槽位登记一致及原实例不受影响的连续证据。2026-10-13 用户随后授权合入、扩为三槽并通知其他 session，已将统一领用方式写入 AGENTS.md；此授权不改变上面的现场证据范围。

## 常驻复用修订（2026-10-13）

按用户要求将每任务退出改为领用与归还。工具进程和登录 profile 归槽位长期持有；任务持有独立快照和租约。清理通过该槽位的 SDK 端口限定在小程序 storage 与 USER_DATA_PATH；清理后重开项目以重新初始化 App 内存状态。异常槽位隔离并保留进程，不自动重启、不抢占旧版活实例，也不设置空闲淘汰。

修订通过 15 项 Python 测试及 3 项 Node VM 测试。其中两个连续任务使用真实替身进程验证 PID 不变、归还后存活及租约释放；微信协议被 mock。另验证清理失败、控制器崩溃不会把占用槽位重新分配。此次只修改 runner 与说明，没有重启、迁移或清理其他 Agent 正在使用的槽位。这些结果不替代仍待完成的微信现场首次启动和连续复用验收，该轮交付时 PR 保持 Draft；随后用户授权合入并扩容。

## 三槽配置与接入

初始化默认容量改为 3，扩容命令只复制并登记缺少的槽位；不更改前两槽的 App、profile、runtime.json 或租约，不启动工具。第 3 槽端口为 19653/19753/32163/33263。扩容中的复制失败、端口冲突不会发布部分配置；重复调用保持三槽。三个租约可同时占用，第四任务等待，归还一槽后继续。

测试选择：本 PR 新增的池模块测试全部属于新增基础设施边界；18 项 Python 测试覆盖初始化、扩容、调度、源码/状态保护和复用，3 项 Node VM 测试覆盖小程序数据清理。未修改应用业务和 UI，不运行无关应用全套或追加真实桌面操作。微信首次启动、三槽真实并发和连续复用仍是单独待验收项，不能用配置槽数或替身进程测试冒充。合入不代表小程序发布。
