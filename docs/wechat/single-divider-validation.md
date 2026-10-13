# 清单分组双线修复 · 2026-10-13

## 行为与范围

展开的分组末尾同时显示最后一个字段的底边框和下一分组的顶边框，两者之间还有 8px 分组间距。清单按当前可见行顺序判断：字段后紧邻分组时，通过 field-row 的可选 hideDivider 属性将字段底边框变为透明。下一分组的长分隔线保留；连续字段、分类末尾及问题列表沿用默认底边框。

保留边框宽度，不改变行高、左滑操作区、备注和影像布局。判断直接依赖渲染中的 section.rows，因此展开、折叠、搜索与筛选重建可见行后同步更新，不修改答案或存储数据。

## 验证

基线：main `cb03d73`。环境：macOS、Node.js v25.9.0、Vitest v5.0.3；依赖复制自已有工程到独立 worktree，未更改锁文件或安装共享运行时。仓库推荐 Node.js 24，本次实际使用 25。

在 `apps/wechat` 执行：

```sh
npm run build
npm test -- tests/field-row-placeholder.test.js tests/field-row-swipe.test.js tests/runtime.test.js
npm run check
```

- 构建成功，13 分类、76 topics、303 字段、9 个 JS 入口。
- 3 个测试文件共 10 项通过：字段组件输入与焦点、左滑与事件，以及打包后的页面/共享 service。选择依据为组件新增可选属性和根节点 class，不涉及模型、持久化或文件接口。
- 官方 wcc 8 个 WXML、wcsc 6 个 WXSS 编译通过；7 页面，990980 字节。
- `git diff --check` 通过。
- 本次为低影响的分隔线显示修正，未新增复述样式实现的静态测试，也未运行全量测试。上述结果不构成双线消失的自动化视觉证据。

原始日志：`apps/wechat/artifacts/single-divider/{build,tests,check}.log`。

## UI 验收边界

开发者工具初始打开另一个任务的 `inline-address-map/apps/wechat/dist`，且有正在填写的新房源弹窗。尝试从 Project 菜单进入独立工程导入入口后，工具报告外部用户改变了应用；未继续切换工程、编译其他任务或修改业务记录。本次没有取得修复版本的开发者工具截图，也未完成实际展开/折叠及带附件字段的视觉验收。未上传、发布或合并。

待验收工程：本 worktree 的 `apps/wechat/dist`。使用隔离测试记录，展开家具分类的书桌、椅子，检查椅子稳固与沙发正常之间只剩一条长分隔线；折叠/重新展开、筛选后再次核对，普通字段之间保持单线，备注、影像和左滑保持原样。UI 效果按 AGENTS.md 要求由用户确认后合入。
