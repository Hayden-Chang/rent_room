# 仓库整理与忽略策略

日期：2026-10-13。远程：Hayden-Chang/rent_room（私有）。

## 迁移映射

| 原本地路径 | 新仓库路径 |
| --- | --- |
| miniprogram-wechat/ | apps/wechat/ |
| prototype/ | prototypes/web/ |
| prototype-assistant/ | prototypes/assistant/ |
| outputs/.../html-checklist/ | prototypes/checklist/（当前源、模板、服务及隔离测试） |
| 产品设计文档 | docs/product/ |
| 图片文字提取、看房指南 | docs/research/ |
| style.md | design/reference-style.md |
| output/branding/ | design/branding/ |
| outputs/figma-checklist-handoff-20261011/ | design/figma-handoff-20261011/ |

原 README 与看房指南内容相同，研究内容只保留一份，根 README 改为项目导航。现有本地工程、运行中的预览、历史 Git 提交和备份均未删除或移动。新目录是当前工作文件的快照，包含最近尚未提交的上下级样式调整和设置/引导审计。原项目提交 SHA 与导入前 SHA-256 见 [import-manifest.json](import-manifest.json)。为了避免混入历史密钥和旧产物，本次不导入旧工程 Git 历史；历史仍保留在原本地仓库。

## 提交与忽略

**提交**：源码、测试、package.json、package-lock.json、依赖许可证、构建脚本、模板、清单设计数据、文档、必要静态设计资源。即使文件名含 backup/fixture，也按用途判断；测试夹具和原型设计源不能一律忽略。

**忽略**：node_modules、dist、artifacts、缓存、覆盖率、日志、截图测试输出、环境文件、私钥、微信开发者工具个人配置、服务端运行数据、自动保存历史、重复备份和 agent 本机状态。`.env.example` / `.env.sample` 可提交，但必须只有占位值。

**仅保留原本地**：约 434 MB 的 outputs 过程资料、rent_home 脑图历史、依赖与构建包、local-http-api.md 本机工具契约。必要的 HTML 原型和 Figma 交付资料已单独提取，不因为位于 outputs 就全部丢弃。忽略规则不会删除文件，也不是备份方案。

## 可移植调整

HTML 构建直接读取当前 `recovered/current-tree.json`，不再要求已忽略的旧恢复种子和历史导出。没有修改清单内容、节点或顺序。`backup-config.example.json` 使用相对目录，个人配置不提交。旧 Web 的部署脚本需要显式设置 `XUNJU_SSH_TARGET`，防止新机器直接部署到历史服务器。

所有新电脑安装使用各项目独立的 lockfile。微信编译器路径通过环境变量配置。旧助手真实 AI 调用仍需自行配置 `DEEPSEEK_API_KEY`；没有上传密钥，也未验证线上 AI 或部署。

根 `.nvmrc` 固定 Node.js 24；小程序 manifest 声明测试框架支持的 Node 范围。`.gitattributes` 统一文本换行，保留 Markdown 显式换行语义。
