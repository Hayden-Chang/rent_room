# 仓库结构与忽略策略

日期：2026-10-13。远程：Hayden-Chang/rent_room（私有）。

## 版本管理范围

| 路径 | 内容与策略 |
| --- | --- |
| apps/wechat/ | 原 miniprogram-wechat 的源码、测试、锁文件、构建脚本、清单源和运行资源 |
| services/wechat-auth/ | 自有服务器微信身份核验、独立容器配置和测试；不保存看房业务数据 |
| docs/wechat/ | 小程序验证、Figma 核对与交互审计文档 |
| docs/product/ | 产品设计文档 |
| docs/research/ | 研究资料；原 README 与看房指南重复，保留单份 |
| docs/repository/ | 目录说明、导入来源和验证记录 |
| design/README.md | Figma 入口与必要设计说明 |
| prototypes/ | 本地原型，整个目录忽略 |
| design/ 其他内容 | 本地截图、设计导出、交付快照、视觉参考和品牌素材，全部忽略 |

现有本地工程和 Git 历史未删除或移动。移出 Git 索引的原型与设计文件仍保留在本地；新克隆不会包含它们。小程序构建不依赖这些目录。文档统一放在根目录 `docs/`，构建读取的清单源和来源校验文件放在 `apps/wechat/data/`，不再保留 `apps/wechat/docs/`。来源校验清单见 [import-manifest.json](import-manifest.json)，只列当前纳入版本管理的导入文件。

## 忽略规则

除上述目录外，忽略 node_modules、dist、artifacts、缓存、日志、覆盖率、截图测试输出、环境文件、私钥、微信开发者工具个人配置、服务端数据、自动保存历史、重复备份与 agent 本机状态。`.env.example` / `.env.sample` 可提交，但必须只有占位值。

源码、测试、package-lock.json、清单设计源、应用资源与依赖许可证仍需提交。不要按扩展名忽略全部 JSON、图片或 Markdown，以免漏掉构建依赖。

原本地 outputs、rent_home 脑图历史、local-http-api.md 等过程和机器资料不纳入仓库。忽略不等于删除，也不等于备份。

## 历史与开发

本次从工作文件导入，未迁移旧工程 Git 历史。此前已上传到此仓库的原型和设计文件仍存在于早期提交中；本次仅停止跟踪，不改写已推送历史。

根 `.nvmrc` 使用 Node.js 24。微信编译器可通过 `WECHAT_COMPILER_DIR` 配置。源码修改在 `codex/*` 分支和隔离 worktree 中完成，通过 PR 审查；小程序发布与服务器部署单独执行。
