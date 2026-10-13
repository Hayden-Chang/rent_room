# 寻居 · 看房手记

微信小程序及必要的产品设计文档。HTML / Web 原型和设计导出资料仅保留本地，不纳入 Git。

## 目录

| 路径 | 用途 |
| --- | --- |
| [apps/wechat](apps/wechat/README.md) | 微信小程序源码、测试、构建脚本与清单源数据 |
| [docs/wechat](docs/wechat/VALIDATION.md) | 小程序验证记录、Figma 核对与交互审计 |
| [docs/product](docs/product/产品设计.md) | 产品设计文档 |
| [docs/research](docs/research/看房指南.md) | 看房研究、素材文字整理 |
| [design](design/README.md) | Figma 入口和必要设计说明 |
| [docs/repository](docs/repository/ORGANIZATION.md) | 目录迁移、忽略规则、导入记录与验证边界 |

## 微信小程序

需要 Node.js 24 与 npm。各子项目独立安装依赖，不在根目录共享 lockfile。

```sh
cd apps/wechat
npm ci
npm run build
npm test
npm run check
npm run package
```

微信开发者工具导入 `apps/wechat/dist`。`check` 需要本机官方 `wcc` / `wcsc`，可用 `WECHAT_COMPILER_DIR` 指定所在目录；其他命令不依赖微信开发者工具。产物位于 `dist/` 和 `artifacts/`，不提交到 Git。清单源数据和来源校验位于 `apps/wechat/data/`；说明与审计统一放在根目录 `docs/wechat/`。

AppID 属于公开工程标识；AppSecret、服务端 API 密钥和本地数据不进入仓库。小程序当前使用本地存储，GitHub 上传不等于小程序审核、发布或云同步。

## 本地参考资料

`prototypes/` 整体忽略；`design/` 只跟踪 `README.md`。原型、设计快照、截图及品牌备选素材保留在现有本地目录，新克隆不会包含这些文件。小程序构建所需的数据、资源和许可证完整保存在 `apps/wechat/`。

## 开发流程

在 `codex/*` 分支和独立 worktree 内修改，通过 PR 审查后合并。发布和部署单独执行。本次导入保留现有本地工程及 Git 历史，不把旧工程的 `.git` 当成子模块上传。
