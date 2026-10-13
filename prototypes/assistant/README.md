# 寻居 · 看房手记

租房看房助手的交互式 Web 原型。当前仅围绕移动端迭代，后续目标为 iPhone App。

## 启动

Node.js 22.13+；首次 `npm ci`，之后 `npm run dev`。
React + Vite 移动网页，AI 由自有服务器的 DeepSeek Harness 服务提供，不依赖 OpenAI 托管。
原型路径 `/`，内部页面使用 hash 路由。

## 已实现

- 候选房源：新增、编辑、收藏、搜索、筛选、预约与状态。
- 硬性要求：预算、通勤、可自定义的必须条件与偏好。
- 每套房独立检查清单：位置固定第一项，手填地址、浏览器定位、可修正坐标。
- 清单模板与单套清单编辑、顺序调整；已有房源不随模板改变。
- 问题分级、房东回复、承诺日期、处理状态；承诺不等于解决。
- 复看时保留上次清单快照，照片和问题继续保留。
- 图片附件、备注、关联检查项；合同图片/PDF、最终版本与原件下载。
- OpenStreetMap 地图：拖动、缩放、选点、房源与工作/商家等地点标记。
- 最多四套房比较；未知费用不按零计算，硬性条件冲突单独展示。
- 每套房源右下角看房助手：DeepSeek Harness + deepseek-flash，文字和最多三张所选图片。
- 完整缺失项、自然语言落表、问题与照片关联、差异确认、撤销、断线重试和本地对话恢复。
- 规则式摘要与可编辑沟通草稿仍可独立使用。
- 模拟多指标测量，明确标记模拟来源。
- IndexedDB 本地保存，JSON 全量备份与校验后恢复。
- WebMCP 读取房源及打开房源，输入做校验。

## 原型边界

- 没有账号、跨设备云同步、实时语音通话或 PDF 内容解析；可用手机键盘语音输入。
- 使用助手时提交房源文字、最近对话和本次选中的图片到自有服务及 DeepSeek。只有用户选中的图片参与本次分析。
- 原始图片在任务临时目录处理，结束后清理；服务端暂存分析结果以支持断线恢复，超过一天的结果在服务启动时清理。
- 合同图片可以选择分析，但不提供专业法律审查。
- 测量全部为模拟数据，不是手机传感器实测。
- 通勤由用户输入，尚无路径规划或地理编码。
- 照片支持 JPEG/PNG/WebP；合同另支持 PDF；单文件 8 MB，单房附件约 45 MB。
- 数据保存在当前浏览器，清理站点数据会丢失；使用导出备份保留资料。
- 服务器 IP、域名和 localhost 各自使用独立的浏览器存储空间，可用备份迁移。
- 浏览器定位需要 HTTPS 或 localhost；HTTP IP 访问使用手动地址录入。

## 验证

- `npx tsc --noEmit`
- `node --test tests/model.test.mjs`（Node 22.18+ 原生 TypeScript 支持）
- `npm run build`
- 浏览器验证记录见 `tests/QA.md`。

## 图片来源

示例图片仅用于界面展示，不代表标记位置的真实房源。
- Deborah Cortelazzi / Unsplash: https://unsplash.com/photos/gREquCUXQLI
- Zuoranyi / Unsplash: https://unsplash.com/photos/5WR0q562X8Q
- Dương Nhân / Pexels: https://www.pexels.com/photo/4389960/
- 地图 © OpenStreetMap contributors: https://www.openstreetmap.org/copyright

## 自有服务器部署

- 服务器：`47.120.13.5`
- 当前入口：`http://47.120.13.5/`
- Nginx 域名已配置 `keeline.xyz`；DNS 根域 A 记录应指向 `47.120.13.5`。
- 执行 `./deploy/deploy-static.sh` 构建、测试、上传独立版本并原子切换。
- 发布目录：`/var/www/xunju/releases/`，当前版本软链 `/var/www/xunju/current`。
- 站点配置：`/etc/nginx/sites-available/xunju`。
- 保留原服务器的 HTTP `/api/` 转发和 ACME 验证路径；不改动 443 上的现有 API 服务。
- 回滚：将 `current` 软链切回之前的版本目录。
- 域名解析生效后再为该域名单独配置 HTTPS；不借用现有 API 域名证书。

## AI 服务（3 人试用版）

- 前端开发：`npm run dev -- --port 5174`，通过 Vite 代理 `/assistant-api/`。
- 后端：Node.js 24+，`npm ci --prefix server`。
- 将 `DEEPSEEK_API_KEY` 放入 `server/.env.local`（不提交，权限 600）。
- 启动：`node --env-file=server/.env.local server/index.mjs`。
- 服务监听 `127.0.0.1:3188`，正式服务由 `xunju-assistant.service` 管理。
- 首次部署准备 Node 24.21.0 Linux x64 官方安装包至服务器 `/tmp/xunju-node.tar.xz`；部署脚本校验固定 SHA256。
- 部署顺序：`./deploy/deploy-assistant.sh`，构建验证后 `./deploy/deploy-static.sh --use-existing-build`。
- 密钥只在 `/etc/xunju-assistant.env`，前端不包含密钥；现有 API 的路由与服务保持独立。
- 每个任务创建独立、内存中的 Harness 上下文，结束后释放；只加载一个 `record_viewing` 业务工具，没有 shell 或文件读写工具。
- 后端最多 3 个活动任务、6 个排队任务；每个匿名浏览器同时 1 个任务。试用保护为每浏览器每日 100 次、整个进程每日 300 次；计数重启会重置，不是付费账户配额系统。
- 匿名 HttpOnly Cookie 隔离任务结果；没有共享用户账号。房源档案和对话以本机 IndexedDB 为准。
- 同一请求 ID 与相同内容的重试复用结果；客户端以请求 ID 防重复落表。服务重启时未完成任务返回可重试状态。
- 当基本资料已有值时，AI 提出的不同值需在卡片上明确确认；更新地址会清除旧地图坐标。
- “均正常”只更新界面明确列出的适用检查项，不填地址、费用或合同约定，不关闭已有问题。
- 完成统计来自实际清单数据，用户自定义清单会参与统计。

### 专项验证

`node --test tests/assistant.test.mjs tests/harness.test.mjs tests/server.test.mjs tests/model.test.mjs`

线上三会话真实调用（会产生 API 用量，需显式执行）：
`XUNJU_TEST_BASE_URL=http://47.120.13.5 node tests/live-assistant.mjs`
脚本自动生成虚构的租金 / 面积图片，仅发送测试数据。
实际验证记录见 `tests/ASSISTANT-QA.md`。
