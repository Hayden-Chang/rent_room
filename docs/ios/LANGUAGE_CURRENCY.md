# iOS 中英与货币类型

## 产品契约与实现

用户于 2026-10-30 回复「没问题」，批准语言、货币选择和定位说明组件，并继续完整业务接入。交付分支 `codex/ios-language-currency-20261030`，Draft PR [#95](https://github.com/Hayden-Chang/rent_room/pull/95)。

- 简体中文、英文、跟随系统三种选择，默认跟随系统首选支持语言；没有中英时回退英文。本机持久化，不随登录账号切换。
- 首次完成清单排序及记录模式设置后，显示「获取当前位置自动识别货币类型」。用户可以定位、手选或使用美元。处理后不重复弹出。
- 设置项为「货币类型」。按需申请使用期间定位，由系统地理编码识别国家；拒绝、失败、无法识别均回退 USD。只有已同意、仍选择自动、已有系统权限时才在回到前台更新。无后台定位，识别过程不向应用服务器上传或持久化坐标。
- 手动币种优先。取消、后台切换和迟到的定位回调不能覆盖后来的选择。
- 新建房源保存 `currencyCode`。默认币种变化只影响以后新建的房源；旧记录缺失币种按 CNY 解释。金额不换算，房源卡片、清单费用、对比、导入导出保留币种；不同币种的相同数值仍属于差异。StoreKit 商品价格维持商店返回值。
- 英文翻译只作用于显示，保存的检查项和选项仍使用原有业务值。房源名、备注、地址、媒体说明、自定义费用和旧记录中的自定义选项保持原文；英文搜索映射回原有字段。对比中的“其他”标签与用户补充文字分别处理。

## 文案与资源来源

所有本次新增或修订的英文产品文案均调用 `agy --model gemini-3.8-flash-high --mode plan -p <提示词>`，模型 ID 来自本机 `agy models`。没有人工重写英文值。只发送产品文案，不发送房源或账号数据。

- 组件：`ios/Localization/region-zh.json`、`region-prompt.txt`、`region-en.agy.json`、`region-provenance.json`，190 条，其中 162 种货币。
- 全应用：`app-zh.json`、`app-prompt-01..04.txt`、`app-en-01..04.agy.json`、`app-provenance.json`。4 批共 1,300 条初始文案；上下文修订保留为单独的 `app-*-prompt.txt` 和 `app-*-en.agy.json`，由回执记录覆盖顺序、键集合及哈希。
- 分享封面：`share-zh.json`、`share-prompt.txt`、`share-en.agy.json` 的 5 条文字通过 agy 生成；内置 imagegen 按 `share-image-prompt.txt` 保留原插画构图并替换文字，输出 `ios/Xunju/Resources/InspectionShareCover-en.png`。原中文 JPG 保留。`share-provenance.json` 记录文案与图像哈希。
- `build-regional-copy.mjs` 和 `build-app-copy.mjs` 校验源文案、生成结果、提示词哈希及占位符，再生成打包资源。后者同时生成 `en.lproj/InfoPlist.strings`、`zh-Hans.lproj/InfoPlist.strings`，覆盖应用名、相机、麦克风、位置用途。
- `scripts/check-xcodegen.sh` 包含上述 `--check`，并校验原生 JS bundle 与 XcodeGen 2.45.4 的确定性生成；`.xcodeproj` 不提交。

Apple 原生登录按钮、授权框、相册等系统控件的语言由 iOS 管理；应用内手动语言切换不修改设备语言或替换授权机制。[Apple 原生按钮说明](https://developer.apple.com/design/human-interface-guidelines/sign-in-with-apple/)。

## 验证范围与证据

使用任务独立 worktree `/private/tmp/rent-room-ios-language-currency-20261030`、隔离 Node 24、共享 Simulator Management runner 及仓库 `scripts/run-xcodebuild.sh`。未改动主工作区的已有未提交文件。构建与测试期间源码冻结。

已执行开发证据：

| 运行 | 实际结果与用途 |
| --- | --- |
| 组件 review run-05 | 源码 `45a5121e33e094d0f09baba102379dc43109b377`，7 单测 + 3 组件 XCUITest 全通过；截图获用户批准。此前自动币种行误显示手动币种，review run-04 新断言失败后修复。 |
| integration run-01 | 15 个定向单测通过：偏好、币种快照、旧记录、实际 ZIP 导出预览、取消与迟到回调，以及容量/落盘/损坏恢复。 |
| integration run-02 | 2 个中文业务 XCUITest 通过：手动 GBP/EUR、重启不换算、真实系统拒绝后 USD。 |
| integration run-03 | 3 个业务 XCUITest 通过，包含首次完整清单后的系统授权及真实地理编码。模拟器注入伦敦坐标后，CLGeocoder 实际返回 GB 并使用 GBP。新增费用无单位断言按预期失败，证明原「物业费」未带币种。 |
| integration run-04 | 费用标签回归通过；16 个单测中定位模拟器用例的固定 yield 等待未等到回调，产生 3 条断言失败。改为有界等待实际状态；不是产品拒绝逻辑失败。 |
| integration run-05 | 19 单测中 17 通过，另外两项是测试夹具/读取方式错误：使用不存在的“基本信息”类别、把编译后的二进制 strings 当 UTF-8。3 个 UI 中英文录入/对比/重启和中文系统拒绝通过；英文首次流程在错误的 StaticText 选择器停止，截图证实页面已英文，未据此宣称后续授权已验证。上述观测方式均已修正。 |
| JS 搜索 | `apps/wechat/tests/model.test.js` 的 `localized display search` 单例通过，20 例未选；未运行整个共享模型套件。 |
| 旧选项回归 | `legacy-wheel-before.log` 断言实际 `[true,true]` 与预期 `[false,true]` 不符，旧自定义「放弃」会被翻译。修复后同一断言通过；永久用例 `ios/tests/currency-localization.test.mjs` 与 Native AppCopy 测试共同保护用户原文及固定天数单位。 |

已合并主线 `ab9c02f55e5a3043bee5a74e7f8f6fd96f902d2a`：保留增量桥接缓存、移除自动通勤查询、触摸轨迹设置；手工冲突限于桥接摘要添加币种、AppRoot 合并环境与触摸图层、设置页同时保留两个功能，JS bundle 从源码重建。合并后的 8 个桥接增量/缓存回归及 1 个币种 JS 用例通过，最终单测补选增量状态、字段适配和触摸偏好集成。当前完整功能最终 PR head 验证待运行；不能把以上阶段证据称作最终全绿。最终候选 SHA、选例、结果及截图将在通过后补充。

### 最终选例依据

按风险排序选 3 个 XCUITest：

1. 英文录入与手动币种：中文系统上手动切英文，英文搜索、新建 EUR 房源、旧 GBP 记录、对比与重启，再回到跟随系统。
2. 英文首次设置：默认跟随英文系统，完整清单设置后才弹窗、真实系统授权、模拟伦敦坐标经真实地理编码得到 GBP、重启不重复。
3. 中文拒绝：真实系统拒绝后 USD，重启不再次申请。

单测覆盖全部新增/修改方法，并按变更选择原有字段适配、旧滚轮值、共享搜索、比较、导入原子性、容量、持久化与恢复用例。组件阶段 3 个新增 UI 用例已在开发阶段执行；最终仅选择上述 3 个完整业务方法。没有运行全量单测或 UI 套件。

所有原始尝试保留在 `artifacts/localization-review/`、`artifacts/localization-integration/`，包括计划、完整命令、日志、回执、汇总及原图。每个 integration 结果包为 `/Volumes/mac2/codex-builds/rent-room-regional-integration-20261030-NN.xcresult`，构建包为同前缀 `.build.xcresult`。实际设备为 iPhone 14 Pro / iOS Simulator 18.3.1 (22D8075)，UDID `8F178971-C203-4690-A83B-253046EACBB1`。原图 1178×2556；共享 runner 给本 worktree 分配的历史命名 DerivedData 为 `/Volumes/mac2/codex-builds/time-fragment-dd-shared-5c197e8b90abdeeb43babf93-simulator`。

持久证据目录：`/Users/pc/.codex/visualizations/2026/10/29/01a18878-d8ae-72f2-a0cf-3e4662baf2b2/ios-language-currency/`。主 agent 已查看英文设置、费用输入、原文房源名、多币种卡片、比较和首次引导截图；开发截图揭示登录说明截断，已允许按内容换行。英文分享封面 5 条文字与 agy 结果一致。

## 明确边界

- 本次支持中英操作、海外币种记录和国家识别。保留最新主线移除自动通勤查询的行为；既有天地图地点服务没有扩展为全球地点服务。海外地址可手动记录，海外地点检索、路线、各国租金周期/面积单位不在此次已验证范围。
- 定位成功证据使用模拟器坐标及真实系统权限、真实 Apple 地理编码，不是真机 GPS；无后台定位验收。系统权限、相机、实拍和商店购买未做真机测试。
- 未覆盖所有设备尺寸和辅助功能字号；最终 3 个 UI 用例不证明所有页面视觉完全一致。
- 未合并、未安装到真机、未发布。组件已有视觉批准，完整业务截图将作为本次交付证据。
