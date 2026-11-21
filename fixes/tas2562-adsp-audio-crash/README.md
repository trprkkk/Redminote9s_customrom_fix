# TAS2562 / ADSP 音声クラッシュ修正

HyperOS ベースのカスタムROMを導入した Redmi Note 9S (curtana) で、動画再生が「少し動く → 止まる」を繰り返す問題の修正です。

## 症状

- YouTube、X、MX Player の HW デコーダーなど、動画再生全般で発生
- 解像度に依存しない
- 再生開始から数秒おきに映像と音声が止まり、また再開する
- MX Player の SW デコーダー / HW+ デコーダーでは症状が出ないことがある

## 動作確認環境

| 項目 | 内容 |
| --- | --- |
| 端末 | Redmi Note 9S (curtana / miatoll) |
| ROM | HyperOS ベース カスタムROM (Android 14, OS1.0.24.3.25.DEV) |
| vendor | V14.0.4.0.SJWMIXM (Android 12 ベース) |
| root | Magisk / KernelSU |
| 音声 | TAS2562 SmartPA (TERT_MI2S_RX) |

## 原因

動画デコーダーではなく、**ADSP (audio DSP) の繰り返しクラッシュ**が原因です。

1. `/vendor/etc/audio_platform_info_intcodec.xml` で、スピーカーに `acdb_id="10011"` が指定されている
2. この ACDB ID が、TI SmartPA 向けの AFE トポロジ `0x112fc` と、スピーカー保護用の VI フィードバックポート `0x1005` (TERT_MI2S_TX) を要求する
3. この端末の ACDB データには VI フィードバック用の cal がなく、ポート `0x1005` の AFE 開始が失敗する

```
afe_send_custom_topology_block: AFE SVC cal has invalid size: 0!
afe_send_cmd_port_start: AFE enable for port 0x1005 failed -131
afe_apr_send_pkt: DSP returned error[ADSP_EFAILED]
```

4. 続けてスピーカーポート `0x1004` を開始すると、ADSP の `audio_process` がクラッシュし、サブシステム再起動 (SSR) が走る

```
Fatal error on adsp!
adsp subsystem failure reason: err_qdi.c:1040:EX:audio_process:0x2:CC09:0x7b:PC=0xb0616874.
subsys-restart: subsystem_restart_dev(): Restart sequence requested for adsp, restart_level = RELATED.
```

5. SSR 中は音声出力が止まり、AudioFlinger の write が約 1.3 秒ブロックされる

```
Blocked in write: yes  (最大 1326 ms)
audio_hw_primary: out_write: error -102
```

6. その結果、MediaCodec の入力・描画が周期的に途切れ、動画が「少し動いて止まる」を繰り返す

```
MediaCodec: video-debug queueInputBuffer: Input time interval reaches 1258ms
MediaCodec: video-debug onReleaseOutputBuffer: Render time interval reaches 1302ms
```

### 原因ではなかったもの

- **`/mnt/vendor/persist/audio/tas25xx_calib.bin` の不在**
  - `get_calibrated_re_tcalib: file ... open failed` と `ADSP_EBADPARAM` は出るが、修正後もこのログは残り、クラッシュにはつながらない
- **`TAS25XX_ALGO_BYPASS` による SmartPA アルゴリズムの無効化**
  - `tinymix` で `TRUE` にしてもクラッシュは止まらなかった

## 修正内容

`/vendor/etc/audio_platform_info_intcodec.xml` のスピーカー ACDB ID を、SmartPA 保護トポロジを引く `10011` から、通常のスピーカー経路である `15` に変更します。

```diff
--- a/vendor/etc/audio_platform_info_intcodec.xml
+++ b/vendor/etc/audio_platform_info_intcodec.xml
@@
-        <device name="SND_DEVICE_OUT_SPEAKER" acdb_id="10011"/>
-        <device name="SND_DEVICE_OUT_SPEAKER_REVERSE" acdb_id="10011"/>
+        <device name="SND_DEVICE_OUT_SPEAKER" acdb_id="15"/>
+        <device name="SND_DEVICE_OUT_SPEAKER_REVERSE" acdb_id="15"/>
```

同梱の `module/` がそのままモジュールの中身です。`audio_platform_info_intcodec.patch` は差分の参考用です。

## 検証結果

修正前（再生開始のたびに約 2 秒周期で発生）:

```
Fatal error on adsp!   … 繰り返し
subsys-restart: Restart sequence requested for adsp
MediaCodec: Input time interval reaches 1258ms
```

修正後（同一端末・同一動画で 40 秒以上再生）:

```
Fatal error on adsp!   0 件
MediaCodec: video-debug Avg Input Interval: 33ms, Avg Render Interval: 33ms
MediaCodec: video-debug Render: 151, Drop: 0
```

AudioFlinger の `write blocked` も解消し、再生の途切れは発生しません。

## インストール

1. `dist/tas2562-speaker-acdb-fix-v1.1.zip` を端末へコピー
2. Magisk / KernelSU アプリ → モジュール → ストレージからインストール
3. 再起動

モジュールは `/vendor/etc/audio_platform_info_intcodec.xml` を置き換えるだけです。vendor パーティションへの直接書き込みは行いません。

## アンインストール

Magisk / KernelSU アプリでモジュールを削除（または無効化）して再起動してください。

## 確認コマンド

```sh
# 適用確認（acdb_id が 15 になっていること）
adb shell su -c 'grep -n "SND_DEVICE_OUT_SPEAKER\" acdb" /vendor/etc/audio_platform_info_intcodec.xml'

# ADSP クラッシュが発生していないこと
adb shell su -c 'dmesg | grep -c "Fatal error on adsp"'

# MediaCodec の間隔が安定していること
adb logcat -d -s MediaCodec:V | grep 'Avg Render Interval'
```

## 注意事項

- この修正ではスピーカー保護（SmartPA の保護アルゴリズム）を通らない経路になります。最大音量での長時間再生は避けてください。
- 通話・録音・Bluetooth 音声は未検証です。スピーカー出力の動画再生で確認しています。
- 根本原因は vendor 側の ACDB と設定の不整合です。ROM 側で ACDB ごと修正するのが本来の解決策で、このモジュールはその場しのぎの回避策です。
- ROM アップデートで `/vendor/etc/audio_platform_info_intcodec.xml` が変わった場合、このモジュールが古い設定で上書きしてしまう可能性があります。アップデート後は再確認してください。
