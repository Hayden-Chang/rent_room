# 微信开发者工具双实例验证（2026-10-13）

状态：**独立双实例实验通过；通用实例池首次启动及常驻连续复用验收尚未通过，禁止作为默认测试入口。**

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

[runner 说明](../../scripts/wechat-pool/README.md) 和脚本位于 `scripts/wechat-pool/`。本机实验池位于 `/Volumes/mac2/codex-builds/wechat-instance-pool`，两个槽位使用独立 App、IDE/自动化/MiniCode 端口。实现 FIFO、内核租约、源码快照、每槽常驻 profile 与工具进程、身份校验和 receipt。正常任务归还只清理小程序数据、关闭项目及释放租约，下个任务复用同一存活进程。

调度与保护用例通过不等于完整 runner 可用。现场新 profile 出现过配置格式迁移异常、项目元数据未就绪、AppID/基础库为空和页面健康超时。补齐 `storage_meta.json` 后迁移异常消失；冷启动导入/重启方案仍在诊断。窗口截图确认过项目已打开但模拟器白屏，不能用 HTTP 200 或 SDK 连接成功冒充页面验收。

失败 receipt、私有 profile 与日志保留在池的 `runs/<runId>/`，不得将整个目录上传（包含登录态）。原始实验另存 `/private/tmp/wechat-isolation-01a1348c/`。源码和本报告不包含登录种子。

完成接入前还必须在最终 runner 上取得：两个真实任务并发通过、第三任务等待后通过、连续任务复用同一 PID、复用前后的测试数据清理、归还一槽不影响另一槽、常驻进程与槽位登记一致及原实例不受影响的连续证据。尚未将仓库约定改为强制使用这个池，也未替其他 Agent 切换测试入口。

## 常驻复用修订（2026-10-13）

按用户要求将每任务退出改为领用与归还。工具进程和登录 profile 归槽位长期持有；任务持有独立快照和租约。清理通过该槽位的 SDK 端口限定在小程序 storage 与 USER_DATA_PATH；清理后重开项目以重新初始化 App 内存状态。异常槽位隔离并保留进程，不自动重启、不抢占旧版活实例，也不设置空闲淘汰。

修订通过 15 项 Python 测试及 3 项 Node VM 测试。其中两个连续任务使用真实替身进程验证 PID 不变、归还后存活及租约释放；微信协议被 mock。另验证清理失败、控制器崩溃不会把占用槽位重新分配。此次只修改 runner 与说明，没有重启、迁移或清理其他 Agent 正在使用的槽位。这些结果不替代仍待完成的微信现场首次启动和连续复用验收，PR 保持 Draft。
