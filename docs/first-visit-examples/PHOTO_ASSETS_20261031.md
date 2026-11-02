# 示例房源照片

用户确认所缺内容是示例房源卡片中的室内照片。本次使用内置 image_gen 生成虚构示例室内图，不代表真实在租房源。媒体说明为“示例室内图（AI 生成）”。

两端共享 `apps/wechat/src/assets/examples/example-metro-v1.jpg` 与 `example-sunny-v1.jpg`，首次创建示例时复制到本地房源媒体目录，沿用普通照片的封面、预览、导出与删除行为。已有安装不会补写照片或改动存档。

原始生成图为 1448 × 1086 PNG。为满足微信现有 2 MiB 主包检查，使用 macOS sips 编码为 480 × 360 JPEG，质量参数 25；内容未裁切或重绘。两张运行时资源合计 31,465 字节。

## 生成提示词

### 地铁一居

Use case: photorealistic-natural. Asset type: built-in sample property cover for a rental comparison app, one single landscape 4:3 interior photograph. Show a modest, tidy 38-square-metre one-bedroom Chinese urban rental apartment near a metro station: compact living room viewed naturally from the doorway, simple light-grey two-seat sofa, small wood coffee table, practical dining corner, a doorway hinting at the separate bedroom. Ordinary affordable furnishings, slightly subdued indirect daylight from a modest window, realistic materials and lived-in imperfections. Eye-level real-estate photography, natural perspective without fisheye, no luxury styling or artificial showroom gloss. Centre important furniture so the image also works cropped to a square card. No people, no text, no branding, no watermark, no collage, no UI. This is fictional example housing, not a real listing.

### 阳光两居

Use case: photorealistic-natural. Asset type: built-in sample property cover for a rental comparison app, one single landscape 4:3 interior photograph. Show a tidy, ordinary 58-square-metre two-bedroom Chinese rental apartment in a garden residential compound: a comfortably larger living room, warm beige fabric sofa, simple pale wood coffee table and dining furniture, large bright windows looking onto leafy greenery, one potted plant, natural afternoon daylight and soft shadows. Affordable and welcoming rather than luxurious; realistic slightly lived-in furnishings. Eye-level real-estate photograph with natural perspective, no fisheye and no showroom rendering. Centre important furniture so the image also works cropped to a square card. No people, no text, no branding, no watermark, no collage, no UI. This is fictional example housing, not a real listing.
