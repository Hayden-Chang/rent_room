# 微信 CI 机器人编号租约

所有本机任务从此入口生成预览码。预览自动分配 **2～30**，同一任务在租约内复用编号，**首次分配后 24 小时到期，重复预览不续期**。1 号永久保留给用户明确授权的正式版更新，不在预览池内。

这是微信云端 CI 上传身份，与本地开发者工具三个实例槽位无关。只依赖 Python 3.9+、Node.js 24 和锁定的 `miniprogram-ci@2.1.48`；不启动、切换或关闭开发者工具。

## 预览

```sh
npm ci --ignore-scripts --prefix scripts/wechat-ci
# 在本任务 worktree 中先构建 apps/wechat/dist。
python3 scripts/wechat-ci/ci.py preview \
  --project "$PWD/apps/wechat/dist" \
  --key /本机私密目录/private.APPID.key \
  --owner 稳定的任务ID --desc '本次验收内容'

python3 scripts/wechat-ci/ci.py status --appid wxf43c7f280c98efca
```

`--owner` 默认使用 `CODEX_THREAD_ID`，非 Codex 环境回退为工程绝对路径。不同任务不能使用同一个 owner；同任务重试不能换 owner 逃避占用。`--node` 可指定 Node 24 绝对路径；`--page-path` 可选。不提供 `--robot`、提前释放或调整 TTL 的入口。

本机同一用户的所有仓库和 worktree 共用 `~/Library/Application Support/rent-room/wechat-ci/<appid>/leases.json`。锁文件不得删除或替换，不能为不同任务另设根目录。其他电脑/系统用户不共享此记录，不能独立使用同一 AppID 编号池而声称隔离。

返回 JSON 包含机器人编号、Unix 秒格式的 `expiresAt`、二维码和 receipt 绝对路径。过期在下一次分配时处理，不需要后台定时任务；过期后编号可能分配给其他任务，旧二维码不能再视为受保护。24 小时是**本机编号租约**，不承诺微信二维码也有效 24 小时。到期重试会拿新租约，不保证原编号。

全局文件锁串行化分配；机器人独立锁覆盖整个上传过程并由 SDK 子进程继承。即使租约到期或监督进程退出，仍运行的上传不会被接管。同任务并发立即失败；29 个号均占用时明确失败，不抢占、不退回 1 号。失败保留编号到原到期时间，避免不确定的上传结果被另一任务覆盖。注册表损坏时拒绝分配，保留原文件供人工恢复，不自动重置。

工程从构建产物冻结到独立 run 目录，上传前后核对哈希，排除个人工具配置，拒绝符号链接和密钥文件。密钥始终从外部路径读取，不复制进工程、receipt 或仓库。每次运行保留独立 receipt 和权限受限的 SDK 日志，日志可能包含私有微信请求信息，不公开上传整个目录。receipt 记录源提交背景、工作区状态、实际构建文件哈希和编号租约；脏构建不能冒充干净提交。失败可能已到达微信端，不能把本地失败直接解释成没有上传。

## 保留的 1 号

只有**用户本次明确要求更新正式版**时才能调用下面的独立入口。普通“生成预览码”“合入 PR”“修复完成”都不构成授权。`--approval-note` 记录用户原话，不能由 Agent 自行编造；确认参数只防误操作，无法替代对真实用户授权的核对。

```sh
python3 scripts/wechat-ci/ci.py production-upload \
  --project "$PWD/apps/wechat/dist" --key /本机私密目录/private.APPID.key \
  --version 版本号 --confirm-production-update \
  --approval-note '用户本次明确要求更新正式版的原话'
```

该入口固定使用机器人 1，必须有确认参数、授权记录和版本号；仅调用官方 `ci.upload` 上传开发版本，**不会自动设体验版、提交审核或正式发布**。后续正式发布继续遵守仓库已有授权与发布门禁。1 号不使用 24 小时预览租约。

## 验证

```sh
python3 -m unittest discover -s scripts/wechat-ci -p 'test_leases.py' -v
node --test scripts/wechat-ci/sdk.test.cjs
```

仅运行本功能测试：真实多进程分配/文件锁、固定到期、满额、重复任务、在途保护、子进程锁继承、损坏状态/原子写失败、冻结工程、失败证据和正式版授权门禁。SDK 调用的测试使用替身，不调用 1 号或发布。现场与真机证据见 [验证记录](../../docs/wechat/CI_ROBOT_LEASES.md)。

所有任务必须使用统一入口。旧临时脚本、直接厂商 CLI 或直接 SDK 仍可绕过本机分配器，因此应停用；工具不能约束持有同一上传密钥的其他程序。
