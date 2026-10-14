# 全层级节点左滑验收（2026-10-14）

## 行为

分类、结构分组、带选项/不涉及的分组、普通字段均使用 field-row 的整行左滑。标题、右侧选项和输入框在同一手势区域；轻点标题仍折叠，轻点选项仍选择，轻点输入框仍输入。沿用已在手机确认的短距离快速划动、按钮 touchend fallback 和备注键盘处理。地图增加可左滑标题行，地图画布保留自己的平移手势。

父级备注、问题标记和影像独立归属于父级：`node:category:<category>`、`node:group:<groupId>`。折叠后父级附件仍可见，备注全文显示。写入已有 answers / media 结构，不改存储版本、不级联改子项答案，也不把父级注释计入答题进度。父级可进入问题列表和备注/影像筛选；分组派生的问题与父级手动标记共用同一节点，避免重复计数。ZIP 保留完整内容，Excel 保留父级备注和标记及影像文件名。

## 验证与范围

工作树：`.worktrees/all-node-swipe`；基线：`6a86ae545be9cf7d13b6629812ac79408048fa77`。提交前最终代码对应下列证据；随后仅添加本验证文档，源文件、测试、构建输入及运行环境保持不变。

- 修复前 `artifacts/all-node-before/tests.log`：新增的 5 项初始用例全部失败，证明旧分类和分组没有左滑节点，也不能存父级注释。
- 最终增量单测：25 文件、337 用例通过，日志 `apps/wechat/artifacts/all-node-fixed/tests-final.log`。未运行全量本地测试。
- 最终新增/受影响浏览器组件几何验证：13 行类型 × 3 宽度 × 开/闭状态 = 78 状态通过；日志 `layout-final.log`、测量 `geometry/geometry.json`、截图 `geometry/{320,390,430}-{open,closed}.png`，均位于上述 artifacts 目录。这是实际 WXML 转换的浏览器组件证据，不是微信开发者工具或真机截图。
- 官方编译：wcc 11、wcsc 9 文件通过；9 页面，构建包 1,267,872 字节。日志 `check-final.log`。
- 主 agent 审查：标题与选项事件分流；父级操作路由、重载、ZIP/Excel 恢复及问题去重；地图画布隔离；未改变已验收的手势阈值、速度判断或键盘处理。git diff --check 通过。

增量选择与变更边界：

| 变更边界 | 测试文件（apps/wechat/tests） |
| --- | --- |
| 父级目标、统计、过滤、存储和文件往返 | all-node-swipe、model、files、platform、runtime、detail-filter |
| 统一组件的实际事件绑定、手势、标题/选项/输入及地图隔离 | field-row-events、field-row-swipe-scope、field-row-swipe、field-row-inline-actions、field-row-placeholder、address-bindings、inspection-wording |
| 分组可见性、根分组、默认折叠和宽带条件 | root-group-fold、root-group-runtime、unanswered-group-fold、unanswered-group-runtime、group-visibility-audit、broadband-installation |
| 页面消费者、备注和媒体编辑、导航及引导定位 | detail-navigation、note-keyboard、media-caption、speed-test-page、onboarding-target、issue-editor |

文件名均带 `.test.js`；选择整个文件以保留同一业务边界的 normal/boundary 用例，个别公共 fixture 用例附带运行。

重现：先在 apps/wechat 执行 npm run build；按上表传入 npm test -- tests/<name>.test.js；npm run check。组件布局：设置 NODE_PATH 为本机 bundled runtime 的 node_modules、PLAYWRIGHT_EXECUTABLE_PATH 为 Chrome，LAYOUT_OUTPUT=artifacts/all-node-fixed/geometry node tests/field-row-layout.cjs。

## 待验收

本轮未取得微信开发者工具真实页面交互截图。旧三槽实例池此前健康检查失败且维护中，未重启、接管或占用其他任务实例。预览上传与真机验证分别记录；生成 QR 不代表真机通过。

请在新预览检查：分类收起/展开时左滑；普通分组与带选项分组从标题和右侧开始划动；三个按钮分别生效；保存父级备注/影像后关闭重开；点标题折叠、点选项选择、点输入框弹键盘。新增 UI 范围尚待用户确认，PR 保持 draft，不能把前一轮叶子节点的验收当作本轮验收。
