# 清单反馈音效

正向选择使用用户指定的铃音；问题选择使用原创双短音。播放条件、静音模式、连续选择替换上一段声音的行为保持原样。

## 正向铃音

- 打包文件：`ios/Xunju/Resources/ChecklistSounds/checklist-positive.wav`。
- 来源：用户于2026-10-30直接提供的`tukuppt_63c0e7764590034.mp3`，原文件保持不变。
- 授权记录：用户明确要求将此文件裁剪、加速并用作正向提示音。文件未附素材网站授权凭证，不能沿用此前候选素材的CC0标注。
- 原始SHA-256：`4d382785db7fa75954ff44970c8fed03dab2ea86320a4eba577381e108d54aad`。
- 处理后SHA-256：`49691766db58ec115cb02380b6a89c8dd802d16eeef19eb619ed8081e02d7b53`。
- 原始解码时长约1.149秒；按-40dB、持续10ms的静音阈值，去掉开头25.215ms和末尾169.932ms，保留0.0252154至0.978776秒。
- 使用`atempo=1.222513589744`保留音高加速；最终时长0.782771秒，小于用户要求的0.8秒。首尾分别添加1ms/8ms淡化以避免裁剪咔哒声。
- 输出48kHz单声道PCM16；未调整增益，无削波。

处理命令（常规构建直接使用已提交资源，无需FFmpeg或原始MP3）：

```sh
ffmpeg -v error -nostdin -i tukuppt_63c0e7764590034.mp3 \
  -af 'atrim=start=0.0252154:end=0.978776,asetpts=PTS-STARTPTS,atempo=1.222513589744' \
  -ar 48000 -ac 1 -c:a pcm_s16le trimmed-sped.wav
ffmpeg -v error -nostdin -i trimmed-sped.wav \
  -af 'afade=t=in:st=0:d=0.001,afade=t=out:st=0.774770833333:d=0.008' \
  -map_metadata -1 -fflags +bitexact -flags:a +bitexact \
  -ar 48000 -ac 1 -c:a pcm_s16le checklist-positive.wav
```

`ios/scripts/build-checklist-sounds.py`只校验所选音效的哈希，不覆盖为合成音。

## 问题双短音

`checklist-problem.wav`仍由`ios/scripts/build-checklist-sounds.py`生成，时长290ms，48kHz单声道PCM16。此次未改变文件字节。

校验命令：`python3 ios/scripts/build-checklist-sounds.py --check`。XCTest的`ChecklistSoundTests/testBundledSoundsDecodeAsDistinctShortMonoCues`验证实际打包资源能够解码，单声道、时长正确且不超过0.8秒、文件小于80KB且两段不同。

## 声音开关

房源页右上角铃铛点击切换声音，关闭时添加从右上到左下的斜线。默认开启；选择保存在本安装的 UserDefaults 中，跨房源、重启继续沿用。正向音和问题音统一遵循开关，关闭时停止正在播放的提示音；音效仍遵循系统静音模式，触觉反馈独立。DEBUG 业务测试使用 UUID 隔离的偏好域，不改变用户设置。
