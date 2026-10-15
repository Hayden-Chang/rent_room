# 设置与清单入口精简验证

日期：2026-10-15。基线：`39b3586530bf22efef0965391110a38bf96d57f3`；业务及测试提交：`0254c4a36d9757df9c32e2ebbaeead4b66d1c5dd`。独立 worktree：`.worktrees/simplify-settings-checklist`，分支：`codex/simplify-settings-checklist`。主工作区的现有修改未调整。

## 行为与数据边界

- 归档列表为空时只显示“还没有归档房源”；有房源时保留长按提示。
- 移除设置中的“重新查看引导”，引导仅由新建房源及“新房源显示操作引导”开关控制；旧重播参数不再生成临时演示房源。
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

最终检查远端 main 仍为上述基线。`0254c4a` 之后只补充本验证文档，并在尚未执行的 E2E 中提前截图、增加物理文件落盘断言；业务源码、单测与构建配置均未变化，复用 62 项单测及官方编译证据。E2E 仅通过 Node 语法检查，不能算执行通过；后续需要在可用池槽位完整执行。
