# 小程序模块职责与开发验证

核对日期：2026-10-13。适用于当前 `apps/wechat` 布局；修改前仍需核实当前分支源码。执行门禁见 [AGENTS.md](../../AGENTS.md)，既往测试结果与未验收项见 [VALIDATION.md](VALIDATION.md)。本文列出命令和验证边界，不代表这些检查已经在当前提交执行成功。

## 模块职责

下表路径相对于 `apps/wechat/`。职责变化时同步更新本表及受影响接口。

| 路径 | 当前职责与协作边界 |
| --- | --- |
| `src/app.js` | 应用生命周期；为当前未登录目录或已验证账号创建唯一 `service`，后台触发保存；页面从 `getApp().service` 取得共享服务 |
| `src/lib/account-session.js`、`account-storage.js`、`guest-storage.js`、`auth-page.js` | 微信登录、自有后端身份核验、本地账号归属和页面守卫；详见 [账号说明](ACCOUNT_LOGIN.md) |
| `src/lib/source-model.js`、`src/lib/model.js` | 字段、条件、分组、模板、统计、对比及导入状态校验；规则优先在此集中实现 |
| `src/lib/store.js` | 状态修改、订阅和保存，通过 adapter 访问持久化；保留写入失败可恢复语义 |
| `src/lib/platform.js` | 组装 store 与微信文件、媒体、权限及导入导出调用；平台失败在此与业务结果衔接 |
| `src/lib/capacity.js`、`src/lib/billing.js` | 房源容量计算、服务端权益缓存、复用账号令牌的房源包购买/恢复；[接口与验证映射](CAPACITY.md) |
| `src/lib/files.js` | ZIP 流式编解码、清单校验、媒体大小与 CRC 校验 |
| `src/lib/ui.js` | 页面取得 service、提示、确认及保存状态订阅的公共辅助 |
| `src/pages/` | 页面显示、局部交互状态与用户操作编排；共享业务状态通过 service 处理 |
| `src/lib/commute.js`、`pages/commute/` | 房源到上班地点的公交/驾车查询、路线校验与确认回填；[契约与验证](COMMUTE_ROUTES.md) |
| `src/components/field-row/` | 字段输入、焦点、左滑操作等组件行为及事件；与页面的事件接口保持明确 |
| `data/source-tree.json`、`data/source-provenance.json` | 原始清单源与来源记录；修改需检查字段映射及来源说明 |
| `scripts/source-core.mjs`、`scripts/build.mjs` | 清单生成、应用打包和开发者工具工程配置生成 |

## 生成关系与数据保护

- `data/source-tree.json` 经构建脚本转换为 `src/lib/topics.json`；后者是生成文件，不手工修补。
- `src/` 经构建输出到 `dist/`；`dist/project.config.json` 的 AppID、基础库和编译选项来自 `scripts/build.mjs`。
- `build` 会重新创建 `dist/` 并保留已有 `dist/project.private.config.json`。每个任务独立构建，不在其他任务正在使用的输出目录运行。
- 微信开发者工具导入当前 worktree 的 `apps/wechat/dist`。确认实际打开路径与被测提交一致，避免误测旧工程。
- 测试数据需与用户记录隔离；重建 `dist` 不等于清空微信存储。若运行环境的数据隔离尚未验证，不执行删除、导入覆盖或缓存清理等破坏性测试。
- 文档放根目录 `docs/`，业务数据源放 `apps/wechat/data/`。`dist/`、`artifacts/`、密钥、个人配置及本机数据不进入 Git。

## 已有验证入口

从独立 worktree 的根目录进入应用。Node 版本遵循根 `.nvmrc`（当前为 24）；锁文件属于应用自身。

```sh
cd apps/wechat
npm ci
npm run build
npm test -- tests/model.test.js tests/files.test.js tests/platform.test.js tests/runtime.test.js
npm run check
npm run package
```

以上是常见组合，测试文件必须按本次改动调整，不能将示例中的四个文件当作全部覆盖：

| 改动边界 | 现有测试入口 |
| --- | --- |
| 条件、模板、统计、状态与持久化规则 | `tests/model.test.js`，涉及问句/选项兼容时增加 `tests/inspection-wording.test.js` |
| ZIP 与媒体备份 | `tests/files.test.js`；微信文件操作加 `tests/platform.test.js`，多选/覆盖/原子导入加 `tests/transfer.test.js`，页面编排加构建后的 `tests/transfer-page.test.js`；见 [传输验收](ZIP_TRANSFER.md) |
| 微信接口、权限/文件失败和存储 adapter | `tests/platform.test.js` |
| 构建后 App/Page 与共享 service | 先 `npm run build`，再 `tests/runtime.test.js` |
| 输入焦点、占位及左滑组件行为 | `tests/field-row-placeholder.test.js`、`tests/field-row-swipe.test.js`，并做实际页面交互验收 |

- `npm test` 运行当前全部 Vitest 用例；共享模型或影响范围较广时按测试门禁决定是否执行，不因纯文档修改运行应用全套。
- `npm run check` 消费已有 `dist`，检查 JS/JSON、页面/组件、配置与体积，并调用微信开发者工具的官方 `wcc` / `wcsc`。通过 `WECHAT_COMPILER_DIR` 指向实际编译器目录；缺失时明确报告未执行，不能用普通 JS 构建替代。
- `npm run package` 将已有 `dist` 打包到 `artifacts/xunju-wechat-preview.zip`，不自动重新构建。源码变化后先构建和相关验证再打包；ZIP 不是微信平台上传或真机运行的证据。
- `check` 的结果写入 `artifacts/compile-result.json` 和编译日志。每次验证使用独立证据目录保存结果，避免后续同名输出覆盖原始失败或 PR 验收证据。
- VM、mock 和组件 handler 测试验证有限的逻辑边界，不证明真实渲染、事件绑定、触摸命中、系统权限或设备性能。

## 页面、真机与交付证据

### CI 预览与机器人编号

生成真机预览码使用 [scripts/wechat-ci/README.md](../../scripts/wechat-ci/README.md) 的统一入口。先在本任务构建 dist，再由 runner 冻结、自动领用 2～30 号上传；编号首次分配后 24 小时到期，重复预览不续期；满额时按最早分配顺序循环复用并跳过正在上传的编号，旧租约可提前失效。它独立于开发者工具实例池，不启动本地 UI。

机器人 1 只用于用户明确授权的正式版更新，不能用于普通预览。固定 SDK 2.1.48；机器默认共享注册表、密钥路径、失败日志及安全边界见 runner 文档。修改 runner 时仅运行 `scripts/wechat-ci/test_leases.py` 和 `sdk.test.cjs` 中新增/受影响测试；不因基础设施修改重跑无关应用测试。现场证据见 [CI_ROBOT_LEASES.md](CI_ROBOT_LEASES.md)。

- 关键页面流程使用真实点击、输入、滑动和导航，等待目标元素或状态；断言可见结果与实际业务状态。保存流程需重开核对，媒体备份需核对实际文件内容。
- UI 变更展示当前提交的实际截图；真机覆盖受影响的相机/相册、权限拒绝与恢复、键盘、文件和手势。涉及连续切页时记录设备、数据量、计时方式及结果。
- 预览码生成、扫码运行、体验版上传、提审与发布分别验证，并标明尚需用户操作或尚未取得证据的阶段。
- PR 记录 head SHA、命令和结果、截图/日志路径、mock 边界与未验证项；合并前由主 agent 审查最终 head 和适用门禁。原始输出可作为本地或 CI 附件保留，验证摘要放 `docs/wechat/`。
- 微信三槽常驻池见 [现场报告](INSTANCE_POOL_VALIDATION.md) 和 [runner](../../scripts/wechat-pool/README.md)。本 Mac 统一执行 `/Volumes/mac2/codex-builds/wechat-instance-pool/runner/pool.py`；三槽冷启动、并行夹具、第四任务排队和同 PID 复用已有现场证据。手动退出且原控制器/子进程全部退出后，下次领用自动启动；正常任务归还不退出工具。活的异常槽保留隔离并由维护者处理，不抢用其他实例。`--experimental` 只兼容旧命令。该基础设施验证不替代业务 E2E；仓库仍没有已验收的统一 npm E2E 命令、官方 Skills/MCP 或 MiniTest 接入契约。
- 接入上述能力时，先用隔离测试项目验证，再在本文件登记真实命令、版本、授权前置条件、会话/数据隔离和证据路径。采用 Skills/MCP 时读取实际安装版本的说明与 schema，不能凭旧文档猜工具参数。

### 地图配置（2026-10-13）

`build` 在生成文件前检查地点查询Key；读取优先级和本机共享路径见 [应用说明](../../apps/wechat/README.md#地点查询构建配置)。新 worktree 不能仅凭构建/上传成功断言地图可用。改动构建配置时运行 `tests/map-build-config.test.js`；运行时回归选 `tests/runtime.test.js` 和 `tests/places.test.js`。离线测试可显式使用 `WECHAT_ALLOW_MISSING_MAP_KEY=1`，不得将该产物用于真实地图验收。
