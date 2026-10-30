# iOS 触摸轨迹

「我的」底部、版本信息上方提供「显示触摸轨迹」，默认关闭，保存在本机 UserDefaults，不进入账号、房源或备份。开启时在 AppRoot 所属窗口绘制触点和滑动尾迹；松开后 0.7 秒淡出，关闭时移除观察器，失去活动状态时清空残留。

组件外观与位置已于 2026-10-30 经用户确认。正式接入复用已批准组件，临时 TouchTrailReviewHost 和启动入口已移除。测试使用现有 `--business-test <UUID>` 沙箱；仅 DEBUG 会将该测试的偏好写入独立 suite，普通 Debug 和 Release 使用 standard。AppRoot 通过 defaultAppStorage 向开关和观察层传递同一存储实例，避免分别创建 suite 对象后遗漏实时状态通知。

## 定向测试映射

| 变更边界 | 精确 selector（前缀 XunjuTests/） |
| --- | --- |
| 默认关闭、持久化 | TouchTrailTests/testPreferenceDefaultsOffAndPersistsBothChoices |
| 点数上限、独立触点 | TouchTrailTests/testCanvasBoundsHistoryAndKeepsTouchesIndependent |
| 不阻止、取消或延迟原有手势 | TouchTrailTests/testRecognizerCannotCancelDelayOrPreventNativeGestures |
| 关闭清理、只移除自身监听 | TouchTrailTests/testTurningOffImmediatelyDetachesAndClearsOnlyOwnedLayers |
| 重复开启、窗口切换与拆卸 | TouchTrailTests/testRepeatedEnableAndWindowMigrationDoNotDuplicateObservers |
| 失去活动状态时清理 | TouchTrailTests/testLosingActivityClearsHeldAndFadingTouches |
| 重复采样与淡出 | TouchTrailTests/testDuplicateSamplesDoNotGrowAndFinishClearsActiveTouches |
| 明确 UUID 才隔离偏好，旧临时入口无效 | TouchTrailTests/testOnlyExplicitBusinessUUIDIsolatesPreferences |
| 真实 SwiftUI 挂载后偏好变更会添加/移除画布 | TouchTrailTests/testInheritedPreferenceStoreEnablesAndDisablesMountedPresentation |
| 与既有业务测试数据隔离边界一致 | BusinessIntegrationTests/testOnlyExplicitUUIDArgumentEnablesIsolatedBusinessDirectory |

UI 风险按最终 diff 的直接关系和用户影响排序，以下三项均为新增业务回归，用于开发与 final-pr-head 的精确选择（前缀 `XunjuUITests/TouchTrailBusinessTests/`）：

1. `testSettingsFooterDefaultsOffAndPersistsBothChoices`：正式页面位置、默认值、开启与关闭的重启记忆。
2. `testEnabledTrailsPreserveChecklistGesturesAndSavedNote`：全局监听下的真实清单选择、左右滑、长按、备注编辑/保存、导航和重启后记录保留。
3. `testEnabledTrailsPreserveFeedbackFullScreenAndNavigation`：全屏反馈弹层可交互并关闭、返回设置后偏好仍开启、切回房源。

通过仓库 `scripts/run-xcodebuild.sh` 和共享 Simulator Management runner 运行，计划显式填写 XunjuTests / XunjuUITests，仅选择上述方法。工程真源为 ios/project.yml，生成的 Xunju.xcodeproj 不提交。

## 验收范围

每次结果记录准确 SHA、runner run ID、设备、日志、计划、.xcresult 和导出的原始图片。独立组件证据来自 72e6e2f4b4ff7acc6478164f79d205cc09f3e620；不能将其当作正式页面接入证据，接入后重跑上述选择。

截图和录屏仅包含本应用窗口。系统键盘等独立窗口、真实双指/地图缩放、真机和其他尺寸不由这些定向用例证明；不声称完成全量测试。部署及合并仍需相应授权。
