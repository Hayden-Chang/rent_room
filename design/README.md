# 设计入口与说明

- [Figma 主稿](https://www.figma.com/design/IcJzmxGcnzi4icPgrdBjYA/Untitled?node-id=106-155)：可编辑页面、组件和交互。
- [小程序设计核对记录](../docs/wechat/figma-audit.json)。
- [清单设计源](../apps/wechat/data/source-tree.json)与[来源记录](../apps/wechat/data/source-provenance.json)：小程序构建使用的版本。
- [验证说明](../docs/wechat/VALIDATION.md)：区分代码检查、编译、界面核对与真机验收。

## 维护约定

正式设计在 Figma 维护；代码仓库保留必要设计链接、说明和应用本身需要的资源。修改时在 PR 中记录对应 Figma 页面以及有意保留的差异。

本目录仅跟踪此 README。Figma 导出、交付快照、截图、视觉参考和品牌备选素材仅保留本地；`prototypes/` 同样不纳入 Git。新克隆无需这些文件即可构建小程序。

Figma 结构校验、云端同步、运行截图和真机实测是不同证据，不能相互替代。
