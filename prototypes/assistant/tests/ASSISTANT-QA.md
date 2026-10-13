# 移动看房助手验证记录

- 日期：2026-09-22（Asia/Shanghai）。
- 范围：3 人同时试用的移动网页版；DeepSeek Harness 0.1.5-rc.1 + deepseek-flash。
- 在线入口：http://47.120.13.5/ 。不使用 OpenAI 托管。

## 自动验证

- `node --test tests/assistant.test.mjs tests/harness.test.mjs tests/server.test.mjs tests/model.test.mjs`：16 项通过。
- 选择上述文件覆盖清单落表、已有资料冲突、撤销、原始数据和备份、实际 Harness 图片序列化、HTTP 会话和任务队列；未扩展无关测试。
- `npm run build`：TypeScript 和 Vite 构建通过。约 620 KB 的 JS 产物仍有分块大小提示。
- `git diff --check`：通过。
- 前端构建产物不包含已配置的 DeepSeek API key。
- 回归证据：图片序列化测试修复前因缺少 user role 失败，改用 Harness 的 createUserMessage 后通过。
- 回归证据：HTTP 浏览器没有 randomUUID 时请求编号测试修复前失败；使用 getRandomValues 生成 UUID 后通过。

## 三会话真实调用

- `XUNJU_TEST_BASE_URL=http://47.120.13.5 node tests/live-assistant.mjs`：通过。
- 三个独立 Cookie 会话同时提交，两条文字、一张脚本生成的虚构房源图片。
- 分别提取租金 3200、3700、4200 元；图片还提取面积 55 平方米。
- 最近一轮完成耗时约 2200、2244、2263 毫秒；这是小样本功能验证，不是容量保证。
- 重复提交同一请求返回已完成结果；另一会话读取结果返回 404。
- 单元测试另验证第 4 条请求排队、最多 3 条活动任务，以及重启恢复。

## 浏览器验证

- Chromium，390 × 844；实际后端调用，没有在产品中使用模拟 AI 响应。
- 线上：房源详情打开助手，展示完整缺失项。
- 线上：输入独立厨卫、做饭、养猫、访客信息，18/24 更新为 20/24，准确列出剩余 4 项。
- 线上：补齐维修、退租押金、出租授权、交接信息，达到 24/24。
- 线上：完成提示继续保留 1 个待跟进问题；返回详情、刷新重开后仍为 24/24。
- 本地同版组件：上传测试图片，提取租金与面积；已有值先展示差异，确认后更新，刷新后保留。
- 本地同版组件：撤销自然语言录入后恢复原进度；断线、鉴权和错误响应由专项单元测试覆盖。
- 首轮线上 HTTP 测试发现编号不符合 UUID，已修复；最终流程使用新的独立测试浏览器复验。
- 截图和日志在 `output/playwright/`（不提交）：`live-assistant-opening.png`、`live-assistant-updated.png`、`live-assistant-complete.png`、`assistant-unit-tests.log`、`assistant-live-tests.log`。

## 发布与限制

- 前端版本：`/var/www/xunju/releases/20260921T190216Z`。
- 后端版本：`/opt/xunju-assistant/releases/20260921T185456Z`。
- systemd：`xunju-assistant`，监听 127.0.0.1:3188，经 Nginx `/assistant-api/` 转发。
- 独立 Node 24 运行时；没有替换服务器现有 Node 或模型 API 服务。
- 记录仍保存在本浏览器，没有账户同步。HTTP IP 入口不支持浏览器定位，需手动填写位置。
- 尚未在实体 iPhone 上验证键盘、相机和 Safari 行为；传感器指标仍为原型模拟。
