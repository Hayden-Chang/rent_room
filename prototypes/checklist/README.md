# HTML 清单与脑图原型

从当前本地原型提取的独立工程。`recovered/current-tree.json` 是设计数据；当前小程序构建使用 `../../apps/wechat/docs/source-tree.json`，两者不会自动同步。

```sh
node build-recovered.mjs
cp backup-config.example.json backup-config.json
python3 server.py --port 8876
```

打开 <http://127.0.0.1:8876/recovered-checklist.html> 或 <http://127.0.0.1:8876/recovered-mindmap.html>。备份写入相对路径 `backups/`，不进入 Git。个人备份目录可修改本机 `backup-config.json`。

```sh
python3 -m unittest verify_server verify_durable_storage
```

测试使用临时目录，不修改用户原目录。可选地图路线服务读取 `AMAP_WEB_SERVICE_KEY` 环境变量；不包含密钥。历史恢复页面、旧浏览器导出、过程截图和依赖固定机器路径的旧验证脚本仍留在原目录，未作为本工程运行依赖。

修改脑图前先阅读 [AGENTS.md](AGENTS.md)。本次导入的是磁盘快照，不包含浏览器未保存草稿。
