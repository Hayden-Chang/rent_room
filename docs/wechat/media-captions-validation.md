# 照片与视频独立备注

影像页每个媒体下方显示「＋」，点击打开多行编辑框；保存后完整显示文字，点击文字可编辑。取消不修改已存内容，清空或只留空白后恢复「＋」。媒体备注独立于检查项备注，归档只读。保存失败保留输入和弹层并显示错误，可重试。

`media.caption` 是可选字符串，输入及导入上限为 10000 字符；旧媒体无需迁移。现有 ZIP 备份包含备注和媒体字节，Excel 仍遵循原有检查项列格式，不新增媒体备注列。

## 候选与测试

- 基线：`2ae6a7377293e6b0f4cd7f2503856c37015edcc6`。
- 本地源码候选：`9e6e4b34790180b3fe2658e74e1c9fba88590a66`；远端源码候选：`9fc2180ba4b824292bd491b5c4625aa7e89c977c`。
- 两者 Git tree 同为 `894e9955f1877d184dd4079d98c8b13bdb512a66`。SSH 认证失败，使用 GitHub Connector 发布相同内容；主工作区和其他任务 worktree 保持原状。
- Node.js 24.21.0，Vitest 5.0.3。构建成功，22 项定向测试通过、36 项未选中；未运行全量测试。
- 官方 wcc 8 个 WXML、wcsc 6 个 WXSS 编译通过；包体 1001247 字节。

从 `apps/wechat` 执行，`node` 指 Node 24：

```sh
node scripts/build.mjs
node node_modules/vitest/vitest.mjs run tests/media-caption.test.js tests/runtime.test.js tests/model.test.js tests/files.test.js tests/platform.test.js tests/detail-navigation.test.js tests/detail-filter.test.js -t 'media captions|built App|reloadable|disk failure|archive write protection|imports as new|malformed records|round-trips actual|rejects missing media|backup if original|saves camera files|restores|preserves each bottom tab|changes media filters'
node scripts/check.mjs
```

影响映射：新增 `media-caption` 的 7 项用例覆盖照片/视频独立多行备注、重载与筛选、修改/取消/清空、媒体预览参数、磁盘失败重试、归档与已删除目标、长度边界、ZIP 内容与旧记录校验；现有 runtime 覆盖打包页面与共享 service，model 选择持久化/归档/导入/非法记录，files 选择媒体 ZIP，platform 选择拍摄落盘及恢复，detail-filter/navigation 选择媒体筛选及页面往返。未改变拍摄平台 API。

最初备份测试误对 `readBackup` 已导入的返回值再次调用 `prepareImport`，导致测试前置条件失败；修正测试后该项单独通过，随后按最终影响映射执行完整定向集合，22 项通过。首次脚本因相对工作目录错误未创建测试文件，纠正后构建；不计为产品失败。

本地日志：`apps/wechat/artifacts/media-captions/{build,tests,backup-retry,final-tests,check}.log`。测试、产品源码与配置在最终通过后未修改；后续仅增加本文及证据，可复用同树源码验证。

## 实际开发者工具

2026-10-13，Stable 2.01.2510290，基础库 3.15.2，390px 宽模拟视口；独立工程路径 `media-captions/apps/wechat/dist`，自动化端口 9471。

只新建「影像备注验收 · 1013」房源，不清空缓存、不修改已有房源。图片使用包内示例插画，视频仅准备类型/时长数据用于备注界面，不声称实拍或播放验收。

- 通过原生桌面按钮点击打开影像页、添加备注和保存；输入使用官方 SDK 的 textarea input。
- 通过 SDK 元素 tap/input 添加视频备注、清空第三条备注恢复「＋」、取消第一条的修改。
- 重新打开详情后，通过影像标签点击看到原备注；检查持久化 `state.json` 中照片、视频和空备注均与预期一致。
- [实际截图](media-caption-evidence/with-notes.png) 显示第一张图片的完整 5 行文字、视频的 2 行文字、第三张图片的「＋」。对应三个备注区域实际高度为 116、56、44px，没有省略行或固定高度裁切。
- [运行断言](media-caption-evidence/ui-result.json)。原始脚本保留于 `apps/wechat/artifacts/media-captions/`。

环境与证据限制：初始基础库返回 undefined；仅本工程的忽略文件 `project.private.config.json` 改用已安装的 3.15.2，生产构建配置未变。首次 navigateTo 因工具内部状态超时，官方 SDK reLaunch 后恢复。早期长等待脚本已中断，最终增加 55 秒边界与逐步落盘后通过。首次截图捕获了页面切换隐藏中间帧，未当作视觉证据；切换完成后重新采集并直接读图确认，本文链接为最终画面。

## 审查和门禁

主 agent 在 PR 创建后重新审查五个源码/测试文件：备注按钮与预览区域为同级元素，备注点击不会冒泡到媒体预览；存储编辑沿用只读保护，媒体 ID 定位不会修改其他条目；旧记录兼容，ZIP 保留新字段。未发现阻断性代码问题。远端状态接口返回空 statuses，不能称为远端 CI 已通过。

尚待用户视觉确认以及真机系统键盘体验。未合并、未上传、未发布；保持 Draft。实际拍照/录视频与播放不属于本次已取得的 UI 证据。
