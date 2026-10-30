# 小程序点选与首页数据传输优化（2026-10-30）

状态：PR #96 草稿，尚未满足实际 UI 验收门禁，未合入、未上传、未发布。

基线：`fe52b6f969422fb5914b76b1d24f1ee9d6c32e06`。冻结代码及测试：`46e80e247ec8b3d4965f86663b5980bf869a5a77`。之后仅添加本报告和证据，不改变执行内容。iOS PR #87 已经用户批准，独立合入基线。

## 问题与修改

详情每次选择都会把完整 house（含模板、答案）与所有 sections 传给视图。现在仍从完整业务状态计算下一帧，但只 setData 变化的数据路径：行身份、数组长度或结构变化时整体替换对应集合，删除字段时整体替换对应对象。没有变化时跳过更新；需要回调时保留空更新回调。标题相同不重复设置。

首页原先展开整个房源对象给卡片，现在只传 WXML 与导航使用的 id、name、address、decision、stats、rent、area、cover。存储仍保留完整对象。没有延迟保存、降低持久化保证或修改选项/样式。

## 测量与边界

Node 24，构建后的真实 Page 业务逻辑，VM 中的同步 JSON setData 模拟、内存文件系统。各 12 次交替点选，前后串行运行。以下中位数由原始 JSON 的中间两项平均计算；基准脚本控制台的 medianMs 使用上中位数，不能直接当作表中中位数。JSON 原始样本均保留。

| 房源数 | 点选业务链耗时中位数（前→后） | 点选 patch 字节中位数（前→后） | 首页卡片字节（前→后） |
| --- | --- | --- | --- |
| 1 | 36.35 → 14.22 ms | 89,063 → 979 | 72,417 → 183 |
| 30 | 101.33 → 59.07 ms | 89,063 → 979 | 2,170,906 → 4,872 |

点选 patch 减少约 98.9%，30 房源首页约 99.8%。初次变化的 patch 为 1,657 字节，后续约 979–981 字节。每次仍有两次 setData；本次减少的是内容体积，并未声称减少为一次调用。

这是业务链与桥接数据体积基准，不是微信原生渲染耗时、触摸到显示延迟或真机 FPS。30 房源的保存计算仍会随数据量增长。早期并发测试期间的测量也保留为 before-benchmark.json / after-benchmark.json；资源竞争会影响时长，最终表只使用 paired-*.json 的串行样本。

## 回归与验证

新增回归在未修改基线失败：详情 patch 为 89,063 字节，超过 4,096 字节阈值；无变化 refresh 仍更新完整对象；30 房源卡片为 2,170,872 字节，超过 20,000 阈值。完整原始详情失败日志保留在 `/private/tmp/wechat-performance-20261030/before-tests.log`（包含大型 fixture diff）；首页失败日志已附。

新测试覆盖 patch 大小、无变化回调、完整快照一致性、重复选择/筛选/条件组/删除、保存失败与重试、备注/媒体/问题保留、持久化重载、首页导航与原记录不变。

现有 setData mock 原本仅 Object.assign，不能正确应用 wx 数据路径；改为 JSON 克隆及路径应用，原断言保留。两项既有 fixture 问题在未修改基线复现：跨记录导入没有准备第二条记录容量；速度页导航场景误触新手引导。只修复对应场景前置条件。一次新增组状态断言误期望清空，已改为符合原语义的恢复正常，并验证。这些测试维护不计为产品收益。

### 冻结版本的定向测试

29 个相关文件，359 项：首轮 358 通过，账户恢复的一项测试 5 秒超时；原记录 final-tests.* 保留。唯一失败精确复核：

`tests/account-runtime.test.js -t 'restores only after checking the current WeChat identity and separates two accounts'`

同一 SHA，无源码或测试更改、未延长超时，804 ms 通过，其余 30 项跳过。组合证据为 358 项原通过 + 1 项精确复核通过。怀疑大批工作进程的调度影响，但未证明具体超时根因；单独通过不抹去间歇超时。未重跑整个工程测试集。

影响映射和文件选择：

- detail refresh / data-path helper：detail-performance、detail-render、all-node-swipe、detail-decision、cost-none、detail-filter、custom-cost、field-row-inline-actions、field-row-swipe-scope、detail-navigation、missing-items-runtime、media-caption、issue-editor、note-keyboard、missing-config-none、onboarding-wait-position、onboarding、root-group-runtime、unanswered-group-runtime。
- detail 的地址与子页面返回：address-bindings、commute-page、speed-test-page、transfer-page。
- home 卡片消费者及 App/账户容量：home-performance、guest-runtime、runtime、account-runtime、capacity-runtime、first-meeting-runtime。

均为 apps/wechat/tests 下的 .test.js。选择涉及该边界的现有文件内测试；账户文件等附带的其他断言也执行，未当作单独产品收益。

运行环境：`NODE=/private/tmp/rent-room-node24-20261030/node_modules/node/bin/node`，cwd 为隔离 worktree 的 apps/wechat。命令为 `$NODE scripts/build.mjs`；`$NODE node_modules/vitest/vitest.mjs run <上述 29 文件> --reporter=default --reporter=json --outputFile=/private/tmp/wechat-performance-20261030/final-tests.json`；唯一失败用上述 -t 精确选择，写入 account-exact-retry.json。随后 `$NODE scripts/check.mjs`、`$NODE scripts/package.mjs` 均成功。

官方编译：15 页面，2,051,254 字节；wcc 20 文件、wcsc 22 文件均 exit 0。本地 zip 已生成，未上传。远程 statuses/workflow runs 查询为空，不声称 CI 通过。

### 实际 UI 验证尚未执行

新增最小流程 `tests/e2e/choice-performance-native.cjs`：原生点选顶楼 是→否→是、热水器 没有→正常→异常；检查持久化与备注保留，重开详情及首页截图。准备 fixture 与打开折叠区域允许代码执行；业务选择只允许真实点击。未把 mock 调用算为 UI 操作，也未把页面重开称为冷启动。

两次共享实例池执行均在 health-before 超时，业务脚本未启动：

- 槽位 1：54abdbacee8244d782c0625dd6351478
- 槽位 2：49cc3919ad9944e394d1650e2c297b9a

两次均为 App service health timeout；没有产品点击或截图验收证据。完整 receipts 与 snapshot 仍在 `/Volumes/mac2/codex-builds/wechat-instance-pool/runs/<run-id>/`，health-before.log 附于此目录。没有通过关闭别人的工具或修改共享运行时绕过失败。

所需 UI 测试仍未执行，PR 不可声明 merge-ready。开发者工具健康恢复后应在隔离数据根重新运行这一个流程，再取得用户视觉验收。当前 main 已推进到 5a08dc0c1000217aff38c9a0c3ea9985465413c4；本报告不宣称已完成该新基线的集成等价性验证，正式合入前需重新检查。

## 审查

当前 agent 对发布的 PR 差异完成独立复读：生产改动仅详情增量 patch 和首页字段投影；核对了模板引用、集合替换/字段删除、回调、标题、持久化与导航消费者，未发现需要修改的产品缺陷。原生 UI 脚本未经执行，因此不能据此给 UI 审查结论。

证据：[evidence/performance-20261030](evidence/performance-20261030)。原始失败及重试都保留，证据追加不修改执行内容。

### 可复制的精确文件选择

```sh
"$NODE" node_modules/vitest/vitest.mjs run \
  tests/account-runtime.test.js \
  tests/address-bindings.test.js \
  tests/all-node-swipe.test.js \
  tests/capacity-runtime.test.js \
  tests/commute-page.test.js \
  tests/cost-none.test.js \
  tests/custom-cost.test.js \
  tests/detail-decision.test.js \
  tests/detail-filter.test.js \
  tests/detail-navigation.test.js \
  tests/detail-performance.test.js \
  tests/detail-render.test.js \
  tests/field-row-inline-actions.test.js \
  tests/field-row-swipe-scope.test.js \
  tests/first-meeting-runtime.test.js \
  tests/guest-runtime.test.js \
  tests/home-performance.test.js \
  tests/issue-editor.test.js \
  tests/media-caption.test.js \
  tests/missing-config-none.test.js \
  tests/missing-items-runtime.test.js \
  tests/note-keyboard.test.js \
  tests/onboarding-wait-position.test.js \
  tests/onboarding.test.js \
  tests/root-group-runtime.test.js \
  tests/runtime.test.js \
  tests/speed-test-page.test.js \
  tests/transfer-page.test.js \
  tests/unanswered-group-runtime.test.js \
  --reporter=default --reporter=json \
  --outputFile=/private/tmp/wechat-performance-20261030/final-tests.json
```
