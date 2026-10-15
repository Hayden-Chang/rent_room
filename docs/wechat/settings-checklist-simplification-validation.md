# 设置与清单入口精简验证

日期：2026-10-15。基线：`39b3586530bf22efef0965391110a38bf96d57f3`；业务及测试提交：`0254c4a36d9757df9c32e2ebbaeead4b66d1c5dd`。独立 worktree：`.worktrees/simplify-settings-checklist`，分支：`codex/simplify-settings-checklist`。主工作区的现有修改未调整。

## 行为与数据边界

- 归档列表为空时只显示“还没有归档房源”；有房源时保留长按提示。
- 移除设置中的“重新查看引导”，引导仅由新建房源及“操作引导”开关控制；旧重播参数不再生成临时演示房源。
- “版本”使用独立设置行，展示微信发布版本，开发环境无发布版本时使用 package.json 的版本。
- 移除“检查模板”入口。后续新建房源使用完整清单；已有房源的模板快照、额外检查、答案、问题标记、备注和媒体不迁移、不删除。
- 移除常规“恢复上一次本机保存”入口，只有已有数据读取失败、写入受阻时显示异常恢复操作。保留确认和当前不可读文件副本；恢复写入失败不报成功、不解锁写入、不覆盖上一份可读副本，允许重试。
- 移除清单末尾“＋ 自定义检查”和新增 handler；历史自定义检查继续显示并保留数据。

## 定向自动化验证

Node.js `24.19.0`，Vitest `5.0.3`。依赖锁文件与已有 main-preview worktree 相同，复制锁定依赖到本任务独立 node_modules，未修改依赖及 lockfile。

从 `apps/wechat` 执行，`node` 为 `/Users/pc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node`：

```sh
node scripts/build.mjs
node node_modules/vitest/vitest.mjs run tests/settings-simplification.test.js tests/onboarding.test.js tests/runtime.test.js tests/platform.test.js tests/model.test.js tests/detail-navigation.test.js tests/detail-filter.test.js
node scripts/check.mjs
```

最终 `0254c4a`：**7 文件 62 项通过**；未运行全量单测或既有 UI 套件。

| 改动边界 | 最小用例映射 |
| --- | --- |
| 设置版本、正常/异常恢复与旧数据保留 | 新增 `settings-simplification.test.js` 8 项 |
| 取消重播与保留新建四步引导 | 修改 `onboarding.test.js`，执行该文件全部 10 项 |
| store.add、save、recover 与文件 adapter | `model.test.js`、`platform.test.js`；文件级是本次共享存储边界的最小完整选择，覆盖重载、失败重试、删除保护、媒体及导入 |
| 详情页生命周期、共享 service 与清单导航 | `runtime.test.js`、`detail-navigation.test.js`、`detail-filter.test.js` |

新增规格用例先在未改动业务代码上运行：7 项按预期失败，包含新房源仍套用隐藏字段、没有独立版本值、没有异常恢复状态，以及仍提供新增自定义 handler。日志：`apps/wechat/artifacts/simplification/before.log`。

异常恢复提交失败另有精确回归：文件原子替换失败后旧实现仍提示“已恢复”，并会用损坏内容覆盖 previous.json。先运行 `-t 'preserves the last readable save'`，按预期在成功提示断言失败；修复后纳入上述 62 项。日志：`artifacts/simplification/recovery-before.log`、`artifacts/simplification/final-0254c4a.log`。

官方编译检查：wcc 11 文件、wcsc 9 文件均退出 0，9 页面，包大小 1,266,561 字节。原始结果：`artifacts/compile-result.json`。VM、mock 与官方编译不作为渲染、点击或真机证明。

## 真实界面检查

新增 `apps/wechat/tests/simplification.e2e.cjs`，通过固定实例池入口执行。映射覆盖常规设置项、版本行、引导开关的落盘、空/非空归档提示、四步实际按钮点击、清单末尾、历史自定义分类，以及读取异常后的确认恢复。仅测试前置数据通过 SDK 准备；被测操作使用真实渲染元素点击，不直接调用页面 handler。

```sh
WECHAT_NODE=/Users/pc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
python3 /Volumes/mac2/codex-builds/wechat-instance-pool/runner/pool.py \
  --root /Volumes/mac2/codex-builds/wechat-instance-pool run \
  --project "$PWD/apps/wechat/dist" --wait 180 --timeout 120 -- \
  /Users/pc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node \
  "$PWD/apps/wechat/tests/simplification.e2e.cjs"
```

Run `97bf851164af4fec88f9244add615fa4`，干净源码 head `0254c4a`，冻结快照 `7bb601584d3f485a00983f3b464f832f2cf39507a1d8623d7869c76986535fed`。排队 180 秒后失败：`No free slot; active/orphan instances were not stopped`，测试回调未执行，没有真实页面或截图证据。没有用户 UI 批准或真机验收，不能标为 merge-ready。保留实例池原始 receipt；没有重启、接管或清理其他任务的实例。

原始 runner 证据目录：`/Volumes/mac2/codex-builds/wechat-instance-pool/runs/97bf851164af4fec88f9244add615fa4/`。该目录可能包含私有配置，仅分享脱敏结果，禁止上传整个目录。

最终检查远端 main 仍为上述基线。到 `ac443e1` 为止，`0254c4a` 之后只补充本验证文档，并在尚未执行的 E2E 中提前截图、增加物理文件落盘断言；业务源码、单测与构建配置均未变化，复用 62 项单测及官方编译证据。当时 E2E 仅通过 Node 语法检查，不能算执行通过。

## 手机反馈后的引导文案与字体修正

用户要求“新房源显示操作引导，改为操作引导”，并指出字体不一致。源码中按钮菜单使用 14px、字重 500，普通 view 菜单继承页面的默认字重 400。提交 `79594c8f361405ed6f60d45c515128a6d95c7811` 缩短名称，并在设置页局部样式中统一 menu 的字体继承、14px 字号、500 字重和 1.5 行高，版本行也遵循同一规范；其他页面及引导开关语义未修改。

该提交构建后精确执行 `settings-simplification.test.js`、`runtime.test.js`，**2 文件 9 项通过**。业务 JS、持久化及引导模块未变，其余已通过单测保持等价，不重跑全量。日志：`apps/wechat/artifacts/simplification/guide-typography/ut-79594c8.log`。官方 wcc 11 文件、wcsc 10 文件通过，包大小 1,266,634 字节；日志为同目录 `compile-79594c8.log`。本次是低影响文案/样式调整，没有增加只复述样式声明的单测。

实例池 run `5c5b08315716445e9c1374d97845a63b` 使用槽 2、干净 head `79594c8`，冻结快照 `026bdb0c813bad59f2202a255e80831ed644a81d481a13b066e230b6b12bc252`。成功进入设置页并取得实际截图，主 agent 已读图确认短文案显示且字体粗细与相邻菜单一致。随后 SDK 的 `.page` 元素查询超时，尚未执行计算字体断言和点击流程，**不能记为 E2E 通过**；未重复无变化运行，也未接管其他实例。

实际截图：`apps/wechat/artifacts/pr25-preview/settings-79594c8.png`。预览采用统一 CI 租约的机器人 3，run `cff2133965a84e12ad6fa6fa5b09d5af` 返回成功；核对干净 head、全部构建哈希及二维码哈希，已取得新预览码 `apps/wechat/artifacts/pr25-preview/qrcode-79594c8-cff21339.jpg`。预览成功不代表用户已验收或正式发布，PR 继续保持 Draft。
