# 脑图保存与恢复

正常入口：`http://127.0.0.1:8876/recovered-mindmap.html`。

右上角区分已保存到磁盘、仅保存在浏览器、正在保存、自动重试与版本冲突。服务断开后，待保存稿连同基准版本留在浏览器；重新连接会自动重试，重开当前标签页也能恢复待保存队列。每个窗口另存一份草稿，版本历史可查看未同步稿。

“版本历史”可查看完整版本、预览增删/改名/移动/属性/顺序差异。应用前归档磁盘现稿和本窗口草稿。预览后另一窗口有新修改时，版本检查会阻止覆盖。“比较本窗口与磁盘”用于明确解决冲突。

主稿：`recovered/current-tree.json`。
历史：`recovered/source-history/`（按内容版本编号保存，不自动删除）。
第二份备份：项目根目录 `rent_home/脑图备份/`。其中 `latest.json` 是最新稿，`versions/` 保留完整版本。目标由 `backup-config.json` 设置。每次成功保存时自动更新；失败不影响主稿保存，服务运行时每 30 秒重试并补齐历史。启动服务也会检查备份。

第二目录仍在同一磁盘，可防误覆盖与浏览器数据丢失，不能防整块磁盘损坏。停止本地服务时不会运行备份重试。看房填写记录仍使用原有浏览器记录与导出备份功能，本次磁盘版本历史覆盖的是脑图定义。

生成页面：`node build-recovered.mjs`（不重置已有主稿）。
启动：`CHECKLIST_SOURCE_PAUSED=1 python3 server.py --port 8876`。

测试映射：
- 保存重试、确认丢失、离线刷新、读写竞态和冲突：`node verify-save-safety.mjs`、`node verify-source-client.mjs`、`node verify-preserve-source.mjs`。
- 版本差异：`node verify-history.mjs`。
- 原子保存、恢复留档、第二份备份故障/重试、损坏历史：`python3 -m unittest verify_durable_storage.DurableStorageTests verify_server.TreeStoreTests`。
- 旧页面拒写、历史读取、过期版本拒写：`python3 -m unittest verify_server.RecoveredRouteTests`。
- 仅用于隔离页面验收：`python3 serve-safety-preview.py`，端口 8878，数据位于 `output/save-safety-ui/`。
