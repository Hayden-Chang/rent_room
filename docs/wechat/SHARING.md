# 小程序原生分享

## 用户操作与内容

- 任意页面点击微信右上角“…”→“转发给朋友”，由用户选择接收人或群。
- 首页另启用“分享到朋友圈”；其他页面不注册朋友圈回调并隐藏该入口。朋友圈接口只能分享当前页面，不能指定首页路径。
- 好友卡片固定打开 `/pages/home/index`，标题为“看房搭子｜看房清单，避坑指南”，封面使用包内 `/assets/share/inspection-cover-v2.jpg`。朋友圈使用相同标题和单独的 `/assets/share/inspection-cover-square-v2.jpg`，显式返回空 `query`。
- 好友5:4横版与朋友圈1:1方版分别排版，表现房间、检查清单、问题照片和房源对比，避免方形裁切截断文案。新资源路径避免沿用旧占位图的缓存；首页仍使用原来的空态图。
- 这是分享小程序入口，不传递房源 ID、地址、照片、备注、上班地点或账号信息；分享房源数据继续走用户主动选择的 ZIP 导出。

`withAppShare` 放在 `protectedPage` 外层，并包住首页最终的 `Page` 定义，确保账号验证中、访客和失效页面都能返回固定分享内容。每次 `onShow` 恢复对应菜单，保留原生命周期的上下文、参数和返回值；不自行打开微信选人面板，不依赖服务端或分享成功回调。

接口核对来源：[微信 Page 类型定义](https://github.com/wechat-miniprogram/api-typings/blob/master/types/wx/lib.wx.page.d.ts)；[微信分享菜单](https://developers.weixin.qq.com/miniprogram/dev/api/share/wx.showShareMenu.html)。微信客户端控制原生菜单样式及可用性。

## 2026-10-21 自动验证

执行代码提交：`105f8bec9fc68ff87b8a05ec575cd6ad71428422`。Node.js 24.19.0，先构建再运行构建产物级测试。隔离工具构建使用 `WECHAT_TEST_DATA_ROOT=xunju-test-share`，不改变正式构建默认值。

| 改动边界 | 增量测试 |
| --- | --- |
| 全部12页分享回调、无身份/旧身份、固定路径和图片、私有参数隔离、空朋友圈 query、生命周期转发与缺少菜单API | `tests/share.test.js`，16项 |
| 页面最外层包装后的共享 service、访客、账号切换与验证、首页覆盖生命周期 | `tests/runtime.test.js`、`tests/guest-runtime.test.js`、`tests/account-runtime.test.js` |
| 各页面原有生命周期与消费者 | `tests/capacity-runtime.test.js`、`tests/commute-page.test.js`、`tests/workplace-runtime.test.js`、`tests/speed-test-page.test.js`、`tests/transfer-page.test.js`、`tests/issue-editor.test.js`、`tests/detail-navigation.test.js` |

从 `apps/wechat` 执行：

```sh
npm run build
node node_modules/vitest/vitest.mjs run tests/share.test.js tests/runtime.test.js tests/guest-runtime.test.js tests/account-runtime.test.js tests/capacity-runtime.test.js tests/commute-page.test.js tests/workplace-runtime.test.js tests/speed-test-page.test.js tests/transfer-page.test.js tests/issue-editor.test.js tests/detail-navigation.test.js --reporter=verbose
npm run check
```

结果：11个文件、165项通过；官方 wcc 14个 WXML、wcsc 14个 WXSS 编译通过，12页。没有运行完整单测或完整 UI 套件。完整日志为本机 `/private/tmp/rent-room-sharing-final-105f8be-vitest.log`、`/private/tmp/rent-room-sharing-final-105f8be-compile.log`。

开发阶段第一次选中上述165项时，164项通过，旧 `workplace-runtime` 的“未登录禁止进入”断言失败。在基线 `6a07ecd` 重新打包该页面，同一前置条件也得到 `accountReady=true`；该断言早于主线免登录功能。将其前置条件改成 `service=null`，继续断言服务不可用时重定向且不能写入，没有修改生产账号守卫。访客可正常进入的覆盖由 `guest-runtime` 保留。首次失败日志：`/private/tmp/rent-room-sharing-vitest.log`。

## 开发者工具实际交互

固定三槽池独占槽1，复用进程12727，Stable 2.01.2510290 / 基础库3.17.3 / iPhone 12/13 (Pro)模拟器。没有身份或分享接口 mock，使用可丢弃的 `xunju-test-share` 数据目录。测试回调仅负责准备页面、检查真实服务和截图；菜单、转发、取消及切换“我的”由 CUA 实际点击，没有直接调用分享 handler 来替代点击。

- 代码 `4cbe016` 的运行 `ea83b09d9c904854a4072485c1c1c739`：首页两个分享入口可用，点击好友转发出现虚拟好友卡片；取消后切换“我的”，好友转发可用、朋友圈为灰色。
- 标题对齐实际小程序名称后，代码 `105f8be` 的运行 `9cd228f5bfd34858b2cca7cf20c2379c`：重新构建、重跑165项测试和官方编译，再次实际点击首页菜单和好友转发，确认标题“看房搭子｜看房记录，轻松对比”及静态封面，随后取消。两代码提交的生产差异仅为固定标题；非首页菜单的既有证据仍等价。
- 两次 receipt、SDK结果及原始日志位于本机 `/Volumes/mac2/codex-builds/wechat-instance-pool/runs/<runId>/`。最后一次冻结输入的 Git状态包含3份未提交说明文档，业务源码和测试与 `105f8be` 一致；说明文档不进入构建包。
- 可审查截图位于 `apps/wechat/artifacts/share-review/home-menu-final.png`、`friend-preview-final.png`、`settings-menu.png`；这是实际开发者工具画面。未点击 Send，没有向真实联系人发送消息，没有测试手机接收方或发布。

## 验收边界

上述 VM、菜单 API mock 和编译结果证明页面注册及返回内容，不能证明手机微信选人面板、卡片实际呈现、接收方打开或朋友圈单页模式。手机验收需分别完成：

1. 从首页、详情页打开“…”→“转发给朋友”，核对固定标题与封面，取消后原页面记录保持。
2. 用户自行选择接收方发送，接收方点击后进入首页，不携带发送方房源数据。
3. 首页“分享到朋友圈”，检查空参数及接收方打开状态；详情等页面朋友圈入口不可用。
4. iOS/Android分别核对实际客户端可用性。

UI确认、合入、体验版上传、提审和发布分别完成；这份记录不表示已上线。

## 2026-10-21 分享卡片视觉调整

按用户标注将当前标题改为“看房搭子｜看房清单，避坑指南”。原空态图保留给首页；分享使用新路径的专用插画，展示房间、检查清单、问题照片和房源对比，图内文字为“看房清单 / 避坑指南 / 逐项检查 / 记录问题 / 多房对比”。好友横版1000×800、249126字节，朋友圈单独排版的方版800×800、238950字节，避免方形裁切截断文字。两图由内置 imagegen 生成，成图仅做尺寸适配和JPEG编码；主 agent 已逐张查看编码后的像素并核对文字。

执行代码提交：`4befa68b59fc021e61d161755994cc31ee120c7b`。沿用上文11份增量测试，全部166项通过（分享测试17项，包含两种图片的JPEG格式、比例、尺寸、单张不超过256KiB和src/dist一致性）；官方wcc/wcsc各14文件通过。工具验收构建总计1996747字节，低于2MiB。结果位于 `apps/wechat/artifacts/share-cover-v2-vitest.log`、`share-cover-v2-compile.log`；生成提示词保存在本机 `apps/wechat/artifacts/share-cover-v2/prompt.md` 和 `prompt-square.md`。

固定工具池运行 `fe6e8187f59d4fab9f6ecfe97067d3b4` 确认真实访客首页就绪且已注册两个分享回调，SDK保存了首页截图。此结果仅证明初始化和注册；CUA两次获取App及一次截图均返回 `-10005 timeoutReached`，未执行新版原生菜单/卡片点击，不能复用旧封面的截图来证明新版效果。限制记录为 `apps/wechat/artifacts/share-cover-v2/native-limit.json`。未发送消息，实际卡片效果与接收方打开仍待手机预览验收，保持草稿。
