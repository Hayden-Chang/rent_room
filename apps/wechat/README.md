# 寻居 · 微信小程序

原生 WXML/WXSS 小程序，本地保存看房记录。AppID：`wxf43c7f280c98efca`。版本 0.1.0。

## 使用

1. 微信开发者工具导入本工程的 `dist` 目录（发行 ZIP 中为 `wechat` 目录）。
2. 使用具有此 AppID 开发权限的账号登录，点击编译。
3. 点击工具栏「预览」，用微信扫码进行手机验收。相机、相册、地图权限需要手机实测。

工程源码在 `src`，`dist` 是可重新生成的产物。不要直接在 `dist` 修改业务代码。构建保留开发者工具的 `project.private.config.json`，发行包不包含该文件。

## 已实现

- 房源新建、搜索、意向筛选、重命名、归档、还原及归档只读。
- 13 个分类、76 个主题、303 个原始字段；保留原字段顺序、选项、条件与分组规则。新房源有效检查项初始为 202，随条件变化。
- 一张完整表单，分类默认折叠，分组独立展开；阶段筛选、搜索、组合筛选。
- 数字、日期、单选、多选及「其他」说明；问题标记独立于答案；备注和缩略图；自定义检查项。
- 照片/视频拍摄、相册选择、本地持久保存、预览和关联检查项。
- 问题汇总、手动问题、总结、意向；2—3 套房源对比与只看差异。
- 完整/自定义模板；新房源保存模板快照，修改默认模板不改已有记录。
- ZIP 房源导入导出：可多选房源，包含实际媒体字节；同 ID 房源由用户选择覆盖或新增副本，保存失败整体回滚。
- 每次输入自动保存；上一版本恢复；损坏文件保留；写入失败保留会话输入并提示重试。导入和永久删除只有成功落盘后才生效。

## 数据边界

数据在当前微信小程序的本地目录，没有账号或云同步。清理小程序数据或换手机前，请导出 ZIP 完整备份。ZIP 只包含所选房源的记录、模板快照、问题、备注和媒体，不迁移个人设置或上班地点。仅接受本应用当前导出的 ZIP，不提供 Excel/JSON 入口或旧文件转换。

取消导入文件、解压媒体和导出媒体的固定总大小限制；使用 256 KiB 分块读写。实际仍受微信存储、分享和设备资源约束，失败会提示并保留原记录。现有拍摄/相册入口的单个影像 50 MB 限制保持原行为。归档可还原；永久删除需用户二次确认，清除本机记录、对应媒体及上一版本内的该房源，已导出的备份不受影响。

本版本没有登录、云端 AI、会员、支付、路线规划或自动网络测量。电话通话质量与数据网络质量保留为不同检查项。上班地点仅为本地记录。

## 开发与验证

需要 Node.js 22.12+ 或 24 LTS（本次 Vitest 使用 Node.js 24）。

```sh
npm ci
npm run build
npm test -- tests/model.test.js tests/files.test.js tests/platform.test.js tests/runtime.test.js
npm run check
npm run package
```

`check` 使用已安装微信开发者工具的官方 `wcc` / `wcsc`。默认安装位置位于 `/Volumes/mac2/application/wechatwebdevtools.app`；其他电脑请通过环境变量 `WECHAT_COMPILER_DIR` 指向工具内 `node_modules/wcc-exec`。

ZIP 的规则、精确测试选择与待验收项见 [ZIP 传输说明](../../docs/wechat/ZIP_TRANSFER.md)。

测试映射和验收边界见 [根目录验证说明](../../docs/wechat/VALIDATION.md)。发行包输出 `artifacts/xunju-wechat-preview.zip`。

## 设计来源与交付状态

- HTML 原型：http://127.0.0.1:8876/recovered-checklist.html
- Figma：https://www.figma.com/design/IcJzmxGcnzi4icPgrdBjYA/Untitled?node-id=106-155
- 原始树、SHA-256 与来源记录：`data/source-tree.json`、`data/source-provenance.json`。
- 颜色、导航与折叠行为根据已读取的 Figma 节点和最新交互记录实现。相机/回顶部 SVG 复用原 Figma 生成脚本；导航图标使用现有原型依赖中的 Lucide（许可证随包附带）。Figma 图标导出超时，因此不宣称逐像素一致。
- 当前交付为可运行的本地验收版本。尚未完成 iOS/Android 真机相机、相册、选点及性能验收，也没有提交审核或发布。
- 仓库已归入 `Hayden-Chang/rent_room`，源码路径为 `apps/wechat`。通过工作分支和 PR 交付；GitHub 上传不代表小程序已上线。

## 地点查询构建配置

预览包需要天地图**浏览器端** Key。构建依次读取 `TIANDITU_KEY`、`TIANDITU_KEY_FILE` 指定的纯文本文件、应用目录 `.env.tianditu-browser-key`、本机共享文件 `~/.config/rent-room/tianditu-browser-key`。本机共享文件可供新 worktree 自动使用，建议权限0600；不得提交Key或配置文件，也不要使用服务器端Key。

缺少配置、指定文件不可读或文件为空时，构建在清理旧产物前失败。仅不验证地图网络的离线测试可显式设置 `WECHAT_ALLOW_MISSING_MAP_KEY=1`；这种产物不用于地图验收或发布。构建日志不打印Key，构建包中的客户端Key仍可被提取，须在服务平台配置适用限制。

```sh
TIANDITU_KEY_FILE=/本机私密目录/tianditu-browser-key npm run build
npm run check
```

生成预览码仍使用仓库统一的 `scripts/wechat-ci/ci.py preview`。代码版本和构建配置需要同时核对，上传成功不能证明地图查询配置正确。
