# SoftAP 5GHz Fix (Japanese region / HyperOS-based custom ROM)

Wi-Fi未接続のままテザリングを有効にすると、必ず2.4GHzで起動してしまう問題を修正します。

## 症状

- Wi-Fiに接続していない状態でテザリングをオンにすると、2.4GHzでしか起動しない
- 5GHzの親機に接続しているときだけ、テザリングも5GHzになる
- 5GHz親機との接続が切れると、テザリングが自動的に2.4GHzへ戻る
- 純正ROMではそもそも5GHzテザリングができない
- AOSP系ROMでは問題なく5GHzテザリングができる

## 動作確認環境

| 項目 | 内容 |
| --- | --- |
| 端末 | Redmi Note 9S (curtana / miatoll) |
| ROM | HyperOS V816 ベースのカスタムROM（phh Treble GSI ベース） |
| Android | 14 |
| Root | Magisk 系（SUSFS / KernelSU 系モジュール併用環境） |
| 地域 | 日本（システムロケール ja-JP） |

## 原因

`/system_ext/framework/miui-wifi-service.jar` 内の MIUI 独自クラスが、日本向けに5GHzテザリングを禁止しています。

### 1. 国コードによる強制2.4GHz

`com.android.server.wifi.sap.MiuiWifiApManager` は、MIUI リソース
`android.miui:array/country_codes_hid_sap_5GHz_band` のリストと
「Wi-Fiの国コード」または「システムロケールの国」を照合し、一致すると
`Force SAP band to 2.4GHz.` を実行します。日本ロケールでは常に `JP` が返ります。

```
D MiuiWifiApManager: isSapSameBandAsWifi =false
V MiuiWifiApManager: Force SAP band to 2.4GHz.
D SoftApManager[wlan1]: startSoftAp: channels {1=0} iface wlan1 country JP
```

### 2. 5GHz帯の禁止判定

`com.android.server.wifi.MiuiWifiService#isSapSupportedBand`（および
`AmlMiuiWifiServiceImp#isSapSupportedBand`）は、SoftAP の対応5GHzチャンネルが
すべて DFS / 屋内専用チャンネルだった場合に `false` を返します。

日本の5GHz帯は W52（屋内専用）と W56（DFS）しか AP に使えないため、
この判定は常に `false` となり、次のログとともに2.4GHzへ強制されます。

```
D MiuiWifiApManager: force to use 2.4G soft AP in regions where 5G bands are banned
D SoftApManager[wlan1]: startSoftAp: channels {1=0} iface wlan1 country JP
```

### 3. hostapd の規制テーブル

JP 国コードの hostapd では 36〜48ch が `NO-IR`（AP送信開始不可）です。

```
hostapd: Regulatory information - country=JP (DFS-JP)
hostapd: Frequency 5180 (primary) not allowed for AP mode, flags: 0x10853 NO-IR
hostapd: Primary frequency not allowed
hostapd: Could not select hw_mode and channel. (-3)
```

このため、日本で AP を立てられる5GHzチャンネルは **DFS の 100〜140ch**
（W56・屋内用）になります。149ch 以降は日本の電波法では使用できません。

## 修正内容

### jar パッチ（3箇所）

`patches/softap-5ghz-jp.patch` を `miui-wifi-service.jar` の smali に適用します。

1. `MiuiWifiApManager#updateCurrentCountryCode()` が常に `"INVALID"` を返すように変更
   → JP 判定による強制2.4GHzと、Wi-Fi状態変化時の再強制を無効化
2. `MiuiWifiService#isSapSupportedBand(int)` が常に `true` を返すように変更
   → 「全5GHzチャンネルがDFS/屋内」でも5GHzを許可
3. `AmlMiuiWifiServiceImp#isSapSupportedBand(int)` も常に `true` に変更（実装違いの保険）

### モジュール

- `system_ext/framework/miui-wifi-service.jar` を `post-fs-data.sh` で bind mount
  （`/system_ext` は dm-verity 保護のため、直接書き換えず Magisk の bind mount を使用）
- `service.sh` で起動完了後に `cmd wifi force-country-code enabled JP` を実行
  （別途 `wifi-force-country-au` などの国コード固定モジュールを使っている場合は無効化してください）

### SoftAP設定

テザリング設定（`/data/misc/apexdata/com.android.wifi/WifiConfigStoreSoftAp.xml`）を
Band=2（5GHz）・Channel=100 に固定します。

```xml
<BandChannelMap>
<BandChannel>
<int name="Band" value="2" />
<int name="Channel" value="100" />
</BandChannel>
</BandChannelMap>
```

`tools/set-softap-channel.sh` で変更できます（要 root・テザリングOFF・変更後再起動）。

| チャンネル | 帯域 | 日本での扱い | 備考 |
| --- | --- | --- | --- |
| 36〜48 | W52 | 屋内利用可 | hostapd が `NO-IR` として AP 起動を拒否するため使用不可 |
| 52〜64 | W53 | 屋内利用可（DFS） | CAC が必要 |
| 100〜140 | W56 | 屋内利用可（DFS） | **推奨（100ch で検証）** |
| 144 | W56 | 屋内利用可（DFS） | hostapd の JP テーブル外（5490〜5710）で起動不可 |
| 149〜165 | W58相当 | 日本では使用不可 | 設定しないこと |

## 検証結果

Wi-Fiを無効にした状態でテザリングをオンにし、`dumpsys wifi` で確認。

```
mCurrentSoftApInfoMap {wlan1=SoftApInfo{bandwidth= 2, frequency= 5500, ...}}
```

- `frequency=5500` = 5GHz ch100（W56・屋内用）
- `bandwidth=2` = 40MHz幅
- Wi-Fi未接続でも5GHzで起動することを確認
- 5GHz親機との接続/切断による2.4GHzへのフォールバックが発生しないことを確認

DFS のため、テザリング開始から実際にAPが使えるようになるまで約60秒の
CAC（チャンネル可用性確認）が入ります。

## インストール

1. `dist/softap_5g_fix-v1.0.zip` を端末へコピー
2. Magisk / KernelSU アプリ → モジュール → ストレージからインストール
3. 再起動
4. Wi-Fiをオフにし、テザリングをオン
5. 60〜90秒待ってから接続確認

## アンインストール

1. Magisk / KernelSU アプリで `softap_5g_fix` を削除
2. 再起動
3. 必要に応じて `tools/set-softap-channel.sh` で設定を戻す

## ROMアップデート後に再適用する場合

ROMアップデートで `miui-wifi-service.jar` が更新されると、パッチが
適用されていない jar に戻ります。その場合は、端末から取り出した
新しい jar に対して再パッチしてください。

### Windows (PowerShell)

```powershell
# 端末から jar を取得（要 root）
adb exec-out "su -c 'cat /system_ext/framework/miui-wifi-service.jar'" > miui-wifi-service.jar

# 再パッチ（baksmali.jar / smali.jar が必要）
powershell -ExecutionPolicy Bypass -File tools/apply-patch.ps1 `
  -Orig miui-wifi-service.jar `
  -Baksmali baksmali-2.5.2.jar `
  -Smali smali-2.5.2.jar `
  -Out miui-wifi-service-patched.jar
```

### Linux / macOS / Git Bash

`zip` コマンドが必要です。

```bash
bash tools/apply-patch.sh \
  --orig miui-wifi-service.jar \
  --baksmali baksmali-2.5.2.jar \
  --smali smali-2.5.2.jar \
  --out miui-wifi-service-patched.jar
```

baksmali / smali は以下から取得できます。

- https://github.com/JesusFreke/smali/releases/tag/v2.5.2

## 注意事項

- **DFS / CAC**: 100〜140ch はレーダー探知対象です。起動時の待機や、
  レーダー検知による一時的なチャンネル変更・停止が発生します。
- **電波法**: 5GHz帯（W52/W53/W56）は屋内利用が基本です。屋外で使う場合は
  法令を確認してください。149ch 以降は日本では使用できません。
- **ブートループ**: jar の差し替えに失敗すると起動不能になる可能性があります。
  Magisk のセーフモード、またはリカバリからのモジュール無効化手順を
  事前に確認してください。
- **他モジュールとの競合**: `wifi-force-country-au` など国コードを固定する
  モジュールが有効な場合、`service.sh` の JP 強制と競合します。無効化してください。
- **ROM依存**: 本パッチは MIUI/HyperOS ベースの特定バージョンの
  `miui-wifi-service.jar` を対象にしています。クラス構成が変わった場合は
  パッチが失敗します。
- **ライセンス**: `module/system_ext/framework/miui-wifi-service.jar` は
  端末のROM由来のファイルを改変したものです。再配布は個人的な修正目的の範囲で
  行ってください。ROMのライセンス・利用規約に従ってください。
