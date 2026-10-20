# 寻居真机开发版部署

用户于2026-10-20明确选择开发分支 `codex/ios-parity-20261019` 的 `4a3bb4d`，允许新增本项目部署入口，并安装隔离“寻居开发版”到“华为p10002”。本次仅新增部署工具和文档，App 业务源码保持该提交的内容。三个登录入口及现有账号逻辑保持不变。

## 项目契约

- 入口：`bash scripts/deploy-ios-device.sh --help`；只支持隔离副本，不提供 canonical 安装开关。
- 工程真源：`ios/project.yml`；通过 `scripts/run-xcodebuild.sh` 检查 XcodeGen 并构建。使用正常 `Xunju` scheme、Release 配置，不使用 StoreKit 测试 scheme 或 DEBUG 启动参数。
- 正式身份：`com.keeline.xunju.ios` / 寻居。本入口禁止安装该身份。
- 开发副本：`com.keeline.xunju.ios.dev.<copy-id>` / 寻居开发版。copy-id 为3至32位小写 ASCII 字母和数字，以字母开头。本任务固定复用 `iosparity20261019`，后续更新沿用此副本及其本机数据。
- 显式输入当前分支、完整 SHA、设备 CoreDevice ID、设备名、硬件 UDID 和签名团队。拒绝脏 worktree、来源改变、设备不匹配、错误签名或共享 Keychain / App Group；不自动切换设备、身份或团队。
- 此次从本机 Apple Development 公共证书 OU 核实团队为 `N3Z6DDSQCJ`。不将证书 CN 中的个人后缀当成团队。开发签名允许 Xcode 为该副本更新 provisioning 并注册指定设备。
- 输出必须在 worktree 外的唯一新目录；保存生成检查/构建日志、xcresult、签名校验、安装、安装后读回和启动 JSON 及总回执。不会卸载、清空、删除或导入房源数据。
- 本机记录与媒体保存在独立 App 容器；签名检查拒绝共享 Keychain / App Group。隔离副本的 Apple / 微信回调、服务端 audience 和 StoreKit 正式商品需单独配置，不能据本次部署宣称真实登录或购买完成。

## 本次目标与命令

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
