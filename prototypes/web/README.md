# 寻居 · 看房手记

租房看房助手的交互式 Web 原型。面向手机优先，同时支持桌面多房对比。

## 启动

Node.js 22.13+；首次 `npm ci`，之后 `npm run dev`。
纯 React + Vite 静态应用，不依赖 OpenAI Sites、Cloudflare Workers 或托管账号。
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
- 规则式演示分析、可编辑沟通草稿、复制后自行发送。
- 模拟多指标测量，明确标记模拟来源。
- IndexedDB 本地保存，JSON 全量备份与校验后恢复。
- WebMCP 读取房源及打开房源，输入做校验。

## 原型边界

- 没有账号、云同步、AI API、照片识别或合同法律分析。
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
