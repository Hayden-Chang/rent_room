# 看房搭子真机开发版部署

用户于2026-10-20明确选择开发分支 `codex/ios-parity-20261019` 的 `4a3bb4d`，允许新增本项目部署入口，并安装隔离“寻居开发版”到“华为p10002”。本次仅新增部署工具和文档，App 业务源码保持该提交的内容。三个登录入口及现有账号逻辑保持不变。

## 项目契约

- 入口：`bash scripts/deploy-ios-device.sh --help`；必须在 `--copy-id <id>` 隔离副本与 `--canonical` 正式身份之间明确选择。
- 工程真源：`ios/project.yml`；通过 `scripts/run-xcodebuild.sh` 检查 XcodeGen 并构建。使用正常 `Xunju` scheme、Release 配置，不使用 StoreKit 测试 scheme 或 DEBUG 启动参数。
- 正式身份：`com.keeline.xunju.ios` / 看房搭子。仅在用户明确指定原 App 或 StoreKit 沙盒等必须使用该身份的验收中使用 `--canonical`；安装会更新同 Bundle ID 的 App 并沿用数据容器，不卸载或清空数据。
- 开发副本：`com.keeline.xunju.ios.dev.<copy-id>` / 看房搭子开发版。copy-id 为3至32位小写 ASCII 字母和数字，以字母开头。本任务固定复用 `iosparity20261019`，后续更新沿用此副本及其本机数据。
- 显式输入当前分支、完整 SHA、设备 CoreDevice ID、设备名、硬件 UDID 和签名团队。拒绝脏 worktree、来源改变、设备不匹配、错误签名或共享 Keychain / App Group；不自动切换设备、身份或团队。
- 此次从本机 Apple Development 公共证书 OU 核实团队为 `N3Z6DDSQCJ`。不将证书 CN 中的个人后缀当成团队。开发签名允许 Xcode 为该副本更新 provisioning 并注册指定设备。
- 输出必须在 worktree 外的唯一新目录；保存生成检查/构建日志、xcresult、签名校验、安装、安装后读回和启动 JSON 及总回执。不会卸载、清空、删除或导入房源数据。
- 本机记录与媒体保存在独立 App 容器；签名检查拒绝共享 Keychain / App Group。隔离副本的 Apple / 微信回调、服务端 audience 和 StoreKit 正式商品需单独配置，不能据本次部署宣称真实登录或购买完成。

## Apple 沙盒购买的正式身份安装

使用 `--canonical` 替换 `--copy-id`，其他来源、设备、签名参数仍必须全部填写。该模式继续使用普通 `Xunju` scheme、Release 配置和 Apple Development 签名，不启用 `.storekit` 本地测试配置或注入交易；保留 main 的中英文 App 名称和权限文案。正式身份必须使用精确 App ID 的开发 provisioning profile，拒绝 wildcard profile。

安装后在真机的「设置 → 开发者 → 沙盒 Apple 账户」登录同开发者团队的测试账号，再从 App 的「我的 → 房源点数」购买。开发签名 App 不要求退出正常 Apple 账户，也不要求先上传或提审；购买确认中应显示 Sandbox 环境。沙盒使用 Apple 服务器和 App Store Connect 商品，不实际扣款。参考 [Apple 沙盒测试说明](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox)。

验收必须分别确认商品价格、Apple 购买确认、交易验证后增加 10 点、重启后余额保持。安装或部署保护测试成功不能作为购买成功证据；测试账号密码留在手机上输入，不写入命令或回执。

## 本次目标与命令

2026-10-30 按用户要求统一当前显示名为“看房搭子”；内部 Bundle ID 及隔离副本数据身份不变。本次更名没有执行真机安装，下方 2026-10-20 的历史授权和实际读回名称保留原样。

设备名“华为p10002”实际为 iPhone 13，CoreDevice ID `EE7393FE-BF0D-522D-B365-11A10D5FF96B`，硬件 UDID `00008110-00186446263B801E`。每次运行都重新读回设备详情并核对；不回退到 p10001。

在该 worktree 完成提交后，用实际完整 SHA 和新建外部目录替换占位符：

```sh
bash scripts/deploy-ios-device.sh \
  --branch codex/ios-parity-20261019 --expected-head <full-sha> \
  --copy-id iosparity20261019 --team N3Z6DDSQCJ \
  --device EE7393FE-BF0D-522D-B365-11A10D5FF96B \
  --device-name 华为p10002 --udid 00008110-00186446263B801E \
  --output /private/tmp/xunju-device-<unique-run>
```

脚本遇到任何失败即停，保留回执，不声称后续步骤成功。如果仅启动因设备锁定失败，解锁后可使用同一安装回执里的设备和已核验 Bundle ID，再执行 `xcrun devicectl device process launch --device <same-device-id> <verified-bundle-id> --json-output <new-launch-json>`；不必重新签名或更换身份。重新构建时使用新目录。

工具保护的定向验证：`/usr/bin/python3 -m unittest discover -s scripts/ios-device -p 'test_*.py'`。这些测试不代表 App 业务或真实系统授权、短信、GPS、支付已通过。

## 开发副本名称与权限本地化（2026-11-02）

- 开发副本显示名带大写 copy-id，例如 `r001` 对应“看房搭子开发版 R001”。部署入口同时设置 Info.plist 名称与 `XUNJU_ISOLATED_DISPLAY_NAME`。
- XcodeGen 的构建后阶段在签名前只替换编译产物 `InfoPlist.strings` 的 `CFBundleDisplayName`，保留中英文相机、麦克风和定位用途说明；不排除本地化资源，也不改写仓库中的生成文案。
- 普通构建不传上述变量，保留原有本地化名称；同一 DerivedData 从开发副本切回普通构建时也会恢复原有名称。
- 部署入口在安装前执行 `localized-resources` 检查，将所有源 `InfoPlist.strings` 与打包结果逐键比较，只允许显示名变化。缺少语言、权限文案改变或副本名错误都会停止安装并保留日志。
- 相关测试入口：`cd scripts/ios-device && /usr/bin/python3 -B -m unittest -v test_deploy test_localize_copy_name`。实际产物检查：`/usr/bin/python3 scripts/ios-device/localize_copy_name.py --verify --app <Xunju.app> --display-name '看房搭子开发版 R001'`。

## 2026-10-20 实际部署结果

- 构建来源：worktree `/Volumes/mac2/projects/git_repo/run_self/rent_room/.worktrees/ios-parity-20261019`，分支 `codex/ios-parity-20261019`，完整 SHA `87e2383d10c8f895accab4bfcda54b19e5bfd619`。相对用户确认的 `4a3bb4d`，`ios/` 与 `apps/wechat/` 无源码差异。后续变更只修正部署 CLI 参数与补充本记录，不更改已安装 App 的业务源码。
- 使用正常 `Xunju` scheme / Release / Apple Development，团队 `N3Z6DDSQCJ`。XcodeGen2.45.4 生成检查、实际设备构建和 codesign 严格校验通过。已核对签名 App identifier、团队、独立 Keychain、Apple 登录 entitlement、profile 的准确 App ID、设备 UDID 及有效期。未降低原 App 的签名能力。
- “华为p10002”实际安装并读回“寻居开发版” `com.keeline.xunju.ios.dev.iosparity20261019`，版本0.1.0(1)。未安装 canonical 身份，未操作 p10001。
- 首次启动被 CLI 拒绝，退出64：`launch` 将 Bundle ID 后的选项当成 App 参数，因而报告缺少 `--device`。构建、签名、安装均已成功。已将所有选项移至 Bundle ID 之前，补充回归测试；8项部署保护测试通过。
- 按同一设备与同一已签名 Bundle ID 重试，启动回执 `outcome=success`，PID `67668`，App 参数为空；随后再次从设备进程列表读回相同 PID 与安装路径，确认进程仍在运行。未重装或清空数据。
- 本次证据位于外部目录 `/private/tmp/xunju-device-20261020-01/`：`build.xcresult`、各阶段日志与 JSON、初次失败的 `receipt.json`、成功的 `launch-retry.json`、`processes-after-launch.json`，以及保留失败经过并串联最终结果的 `completion.json`。原失败记录保留，不改写为全程通过。
- 未操作真实短信/Apple/微信登录、相机、GPS、文件取材、支付或退款；未进行新的真机 UI 视觉验收，也未宣称完整 iOS 功能对齐完成。既有 StoreKit 系统测试失败仍保留；本次没有运行不相关的旧模拟器全套或合并门禁。
