# iOS 中英与货币类型

## 用户确认的产品契约

- 支持简体中文、英文，默认跟随系统首选语言；未匹配中英时回退英文。手动选择本机持久化，与登录账号无关。
- 首次完成清单排序、选择记录模式后，提示「获取当前位置自动识别货币类型」。用户可请求定位、手动选择，或使用美元。
- 设置项叫「货币类型」。自动模式按所在国家或地区识别；手动选择优先，定位结果不得覆盖它。
- 拒绝定位默认美元。定位失败或国家无法识别同样回退美元，用户仍可手动调整。
- 国家变化只更新新房源的默认币种。每个房源需保存自己的币种，旧金额不自动换算；备份、导入、展示、对比必须保留其含义。
- 仅使用期间按需定位，不做后台跟踪。货币设置不改变 StoreKit 商品价格。
- 全部英文 UI 文案及后续修订通过 `agy -p` 生成。

## 本批边界：组件评审

状态：REVIEW_READY，真实 XCUITest 截图和主 agent 检查已完成，待用户视觉确认。

本批包含：设置中的两行入口、语言三选一、货币自动/手动选择与搜索、首次货币定位说明弹窗，以及这些组件使用的独立偏好模型和中英资源。

正常应用启动、现有设置页和首次清单业务未接入新组件。只有 Debug 显式 `--component-review regional-settings` 参数会打开评审宿主；Release 排除宿主。宿主使用唯一 `--regional-review-id` 对应的可丢弃 UserDefaults 域，不访问真实房源或账号数据。国家识别回调在宿主模拟 GB 或拒绝，不能据此声称实际 GPS/地理编码、系统权限或完整首次流程已验收。

用户确认新增组件后继续接入：全应用本地化、首次设置后的单次触发、系统定位/国家识别及前台更新、每房源币种快照/旧数据迁移、金额展示与备份兼容。海外地图/通勤可用性、租金周期和面积单位仍需按功能逐项核查；当前组件证据不证明全面海外可用。

## 文案来源

- 模型：`gemini-3.8-flash-high`，由本机 `agy models` 实际返回。
- 调用：`agy --model gemini-3.8-flash-high --mode plan -p <region-prompt.txt 全文>`；只发送产品文案，不含用户数据。
- 中文源：`ios/Localization/region-zh.json`；提示词：`region-prompt.txt`；英文原文：`region-en.agy.json`；回执：`region-provenance.json`。
- 190 个条目，其中包含 162 种货币名称。英文没有人工重写；双语语言列表的英文自称使用生成结果中的 `language.english`。
- 生成/验证入口：`node ios/scripts/build-regional-copy.mjs` / `node ios/scripts/build-regional-copy.mjs --check`。检查中文源哈希、英文哈希、提示词哈希、键集合及占位符，并生成 `ios/Xunju/Resources/RegionalCopy.json`。
- 不直接修改资源中的英文；修改中文需求后重新通过 `agy -p` 生成，更新回执并运行验证入口。

## 定向测试映射

本批独立组件尚未改动共享 JavaScript、业务页面、存储记录或备份，因此不把旧业务全套测试作为此阶段的验证范围。

| 变更边界 | 精确用例 |
| --- | --- |
| 系统语言顺序、手动覆盖、未知语言回退 | `XunjuTests/RegionalPreferencesTests/testSystemLanguageMatchesPreferenceOrderAndFallsBackToEnglish` |
| 国家到货币映射、未知国家回退 | `XunjuTests/RegionalPreferencesTests/testCountryDetectionMapsSupportedCountriesAndFallsBackToUSD` |
| 自动/手动优先级、拒绝美元、无效币种 | `XunjuTests/RegionalPreferencesTests/testDetectionUpdatesOnlyAutomaticSelectionAndDenialUsesUSD` |
| 偏好重载、系统语言变化、处理标记 | `XunjuTests/RegionalPreferencesTests/testChoicesPersistIndependentlyOfSystemLanguage` |
| 中英完整性、占位符、代码/中英搜索 | `XunjuTests/RegionalPreferencesTests/testBilingualCatalogHasMatchingKeysPlaceholdersAndSearchableCurrencies` |
| Debug 显式入口及原入口保护 | `XunjuTests/RegionalPreferencesTests/testRegionalReviewRequiresExplicitKnownRoute`、`XunjuTests/ComponentLogicTests/testReviewHostRequiresExplicitKnownSurface` |
| 真实切换、同屏更新、重启保留 | `XunjuUITests/RegionalSettingsReviewTests/testLanguageSwitchIsImmediateKeepsScreenAndPersistsAfterRelaunch` |
| 搜索选择、重启保留、自动识别回调 | `XunjuUITests/RegionalSettingsReviewTests/testCurrencySearchManualSelectionAndAutomaticCountryChange` |
| 拒绝按钮/拒绝回调、美元回退、手动选择 | `XunjuUITests/RegionalSettingsReviewTests/testLocationDeclineAndDeniedCallbackUseUSDAndManualChoiceRemainsAvailable` |

使用仓库固定 XcodeGen 2.45.4、隔离 Node 24、共享模拟器 runner 和 `scripts/run-xcodebuild.sh`。未运行全量单测或全量 UI 测试。最终结果见下文。

## 验证过程中发现并修复的问题

1. 首次构建受 Git 全局 HTTPS → SSH 重写影响，ZIPFoundation 无法拉取。仅为本任务子进程设置 `GIT_CONFIG_GLOBAL=/dev/null`，未修改共享 Git 配置。run-01 为环境失败，没有执行测试。
2. run-02 的 7 个单测通过，3 个界面用例都停在返回按钮查询：父容器的辅助功能标识覆盖子按钮。修复为显式包含子元素后，run-03 的 7 个单测和 3 个界面用例全部通过。
3. 主 agent 在 run-03 的原始截图中发现：手动选 CNY 后，自动识别行错误地显示当前手动值。新增精确断言，run-04 在修复前仅运行该界面用例，按预期失败：`Manual selection must not relabel the detected currency.`。修复只把自动识别行数据源从 `preferences.currencyCode` 改为 `preferences.automaticCurrency`，手动结果和自动结果分开显示。run-04 使用 run-03 源码加这一个回归断言；修复与断言一并提交到 `45a5121e33e094d0f09baba102379dc43109b377`。

全部原始尝试、日志、命令、测试计划和汇总保留在本 worktree 的 `artifacts/localization-review/`，没有把重试通过当作初次通过。

## 最终组件验证与截图

- Draft PR：[95](https://github.com/Hayden-Chang/rent_room/pull/95)。分支：`codex/ios-language-currency-20261030`。
- 已验证源码：`45a5121e33e094d0f09baba102379dc43109b377`；基线：`eb75079b3e46726e5742cc4c861dc7a278d9dd31`。
- run-05：上述 7 个定向单测 + 3 个 XCUITest 全部通过，0 失败、0 跳过。修复前 run-04 的新增断言在此轮通过。没有运行全量单测或全量 UI 测试。
- 实际执行设备：iPhone 14 Pro / iOS Simulator 18.3.1（22D8075），UDID `8F178971-C203-4690-A83B-253046EACBB1`；原始截图为 1178×2556。
- 命令与选例：`artifacts/localization-review/command-05.txt`、`plan-05.json`，经 `scripts/run-xcodebuild.sh` 和共享 runner 执行；单测覆盖偏好核心和入口，3 个 UI 用例分别覆盖语言、货币自动/手动、拒绝/手动选择三个独立风险。
- 完整日志、receipt、xcresult 汇总：同目录 `run-05.log`、`receipt-05.json`、`summary-05.json`。完整结果：`/Volumes/mac2/codex-builds/rent-room-regional-review-20261030-05.xcresult`；构建结果为同前缀 `.build.xcresult`。
- runner 实际 DerivedData：`/Volumes/mac2/codex-builds/time-fragment-dd-shared-5c197e8b90abdeeb43babf93-simulator`；该历史命名目录按本 worktree 隔离。构建与测试均 exit 0。
- 12 张原始附件：`artifacts/localization-review/attachments-05/`。未改像素的持久副本和逐图 SHA-256：`/Users/pc/.codex/visualizations/2026/10/29/01a18878-d8ae-72f2-a0cf-3e4662baf2b2/ios-language-currency/`，图集为 `界面验收.md`，索引为 `screenshots.json`。该目录 `evidence/` 同时保留各次计划、命令、日志、汇总和回执。
- 主 agent 已检查最终设置入口、语言选择、货币列表、手动人民币状态及中英定位弹窗：标题/说明可读，选中态清晰，手动 CNY 与自动 USD 分别显示；先前也检查了搜索键盘及切换/拒绝状态。未覆盖所有屏幕尺寸、放大文字或真实系统定位权限。
- XcodeGen 2.45.4 确定性生成及 190 条中英资源来源/占位符校验通过。生成的 `.xcodeproj` 不进入提交。
- GitHub Connector 返回该源码提交 statuses 和 PR workflow runs 均为空，不能据此声称远程 CI 通过。

通过后的唯一后续变更为本 Markdown 验收记录；检查与 `45a5121` 的 diff，只要仍仅涉及本文且不影响执行、资源、配置、生成输入或选例，即复用上述证据。截图始终归属于 `45a5121`，不改称来自文档提交。

组件尚未获用户视觉批准，不可按完整功能或可发布版本交付。按 `ios-ui-component-review-gate` 的要求，收到明确批准后才接入正式业务。未合并、未真机安装、未发布。
