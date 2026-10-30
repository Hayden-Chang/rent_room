# 清单反馈音效

正向选择使用短促的单次铃音；问题选择使用原创双短音。播放条件、静音模式、连续选择替换上一段声音的行为保持原样。

## 正向铃音

- 打包文件：`ios/Xunju/Resources/ChecklistSounds/checklist-positive.wav`。
- 作者：PWL；作品：Bell dings/chimes，`bell_ding1.wav`。
- 来源：https://opengameart.org/content/bell-dingschimes
- 原文件：https://opengameart.org/sites/default/files/bell_ding1.wav
- 授权：CC0 1.0 Universal。来源页明确标注 CC0 / public domain，允许商业使用和修改；作者无需署名，本项目保留来源以便追溯。
- 授权全文：https://creativecommons.org/publicdomain/zero/1.0/legalcode
- 原始 SHA-256：`8ce40f49cd211125303df59db0da4fe911e8b2f34d3847011b15137c6b5850de`。
- 处理后 SHA-256：`9b7fd96cd0165e27007ff3c78ad258eb02d23bb66b311e401d865015068e47fc`。
- 处理：移除起始19ms，保留600ms，调整增益，起音1ms淡入和末尾120ms淡出，转换为48kHz单声道PCM16。没有加入第二声或旋律。

重建命令（先下载原文件并核对原始哈希，常规构建无需下载或安装FFmpeg）：

```sh
ffmpeg -v error -nostdin -i bell_ding1.wav \
  -af 'atrim=start=0.019:duration=0.6,asetpts=PTS-STARTPTS,volume=0.8,afade=t=in:st=0:d=0.001,afade=t=out:st=0.48:d=0.12' \
  -ar 48000 -ac 1 -c:a pcm_s16le checklist-positive.wav
```

正向铃音作为有授权来源的资源直接提交；`ios/scripts/build-checklist-sounds.py`只校验它的哈希，不覆盖为合成音。

## 问题双短音

`checklist-problem.wav`仍由`ios/scripts/build-checklist-sounds.py`生成，时长290ms，48kHz单声道PCM16。此次未改变文件字节。

校验命令：`python3 ios/scripts/build-checklist-sounds.py --check`。XCTest的`ChecklistSoundTests/testBundledSoundsDecodeAsDistinctShortMonoCues`验证实际打包资源能够解码，单声道、时长正确、文件小于64KB且两段不同。
