# 寻居 · 看房手记

微信小程序、看房清单原型及产品设计资料。当前主要维护的是原生微信小程序；Web 项目保留为历史原型。

## 目录

| 路径 | 用途 |
| --- | --- |
| [apps/wechat](apps/wechat/README.md) | 微信小程序源码、测试、构建脚本与清单源数据 |
| [prototypes/checklist](prototypes/checklist/README.md) | 当前 HTML 清单和脑图原型，可独立本地运行 |
| [prototypes/web](prototypes/web/README.md) | 历史 React / Vite 看房原型 |
| [prototypes/assistant](prototypes/assistant/README.md) | 历史移动助手原型及独立服务端 |
| [docs/product](docs/product/产品设计.md) | 产品设计文档 |
| [docs/research](docs/research/看房指南.md) | 看房研究、素材文字整理 |
| [design](design/README.md) | Figma 入口、交付快照、视觉参考和品牌素材 |
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

微信开发者工具导入 `apps/wechat/dist`。`check` 需要本机官方 `wcc` / `wcsc`，可用 `WECHAT_COMPILER_DIR` 指定所在目录；其他命令不依赖微信开发者工具。产物位于 `dist/` 和 `artifacts/`，不提交到 Git。

AppID 属于公开工程标识；AppSecret、服务端 API 密钥和本地数据不进入仓库。小程序当前使用本地存储，GitHub 上传不等于小程序审核、发布或云同步。

## HTML 原型

```sh
cd prototypes/checklist
node build-recovered.mjs
python3 server.py --port 8876
```

打开 <http://127.0.0.1:8876/recovered-checklist.html>。脑图编辑会修改该工作副本中的 `recovered/current-tree.json`；测试使用隔离数据，修改设计前遵循该目录的 `AGENTS.md`。

## 开发流程

在 `codex/*` 分支和独立 worktree 内修改，通过 PR 审查后合并。发布和部署单独执行。本次导入保留现有本地工程及 Git 历史，不把旧工程的 `.git` 当成子模块上传。
