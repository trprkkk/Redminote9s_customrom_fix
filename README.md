# Redmi Note 9S / Note 9 Pro (miatoll) カスタムROM 修正集

Redmi Note 9S (curtana) / Note 9 Pro (miatoll) 系のカスタムROMで発生する不具合の修正と、その調査メモをまとめたリポジトリです。

## 修正一覧

| 修正 | 対象 | 症状 | 状態 |
| --- | --- | --- | --- |
| [TAS2562 / ADSP 音声クラッシュ修正](fixes/tas2562-adsp-audio-crash/) | curtana (miatoll) | 動画再生が「少し動く → 止まる」を繰り返す | 検証済み |
| [SoftAP 5GHz 修正 (日本向け制限解除)](fixes/softap-5ghz-jp/) | curtana (miatoll) | Wi-Fi未接続時にテザリングが2.4GHz固定になる / 5GHz親機を切ると2.4GHzへ戻る | 検証済み |
| [Thermal CP パニック修正](fixes/thermal-cp-panic/) | curtana (Japan) + CNポートROM | QC/PD (PPS/QC3) 充電中にカーネルパニックで再起動 | 検証済み |
| [PD 認証バイパス (サードパーティ PD 充電器)](fixes/pd-auth-bypass/) | curtana + CNポートROM | Anker 等の PD 充電器が 5V/1.8A (約10W) 止まり | 検証済み（PD認証バイパス） |
| [IMS / SMS 復帰](fixes/ims-sms-restore/) | curtana / KDDI povo・au | IMS無効化後にSMSが届かない | 検証済み（手動コマンド） |
| [ADB 常時有効化](fixes/adb-keep-enabled/) | 共通 | USBデバッグが起動後に自動でオフになる | 検証済み |
| [WFD seccomp ループ修正](fixes/wfd-seccomp-loop/) | 共通 | `wfdvndservice` が約5秒ごとにクラッシュ | 未検証（実験的） |

## 関連リポジトリ

- [Magisk Wi-Fi Band Preference](https://github.com/trprkkk/magisk-wifi-band-preference) — Android 13+ で 2.4GHz / 5GHz を優先・強制する独立モジュール（ホテル等の同一 SSID 環境向け）

## ROM 依存性について

各修正は、特定の端末・ROM・vendor・カーネルの組み合わせで確認したものです。
同じ curtana でも、ROM のバージョンや移植元、vendor の内容、カーネル、
Android のバージョンによって **使える場合と使えない場合があります**。
修正が適用されないだけでなく、起動不能・VoLTE 喪失・充電不良などを
起こす可能性もあります。必ずバックアップを取り、自己責任で使用してください。

## 使い方

1. 各修正ディレクトリの `dist/` にある zip を端末へコピー
2. Magisk / KernelSU アプリ → モジュール → ストレージからインストール
3. 再起動

詳細・注意事項・検証方法は、各修正の README を参照してください。

## リポジトリ構成

```
fixes/
  <修正名>/
    README.md          … 症状・原因・修正内容・検証結果
    patches/           … バイナリ/ソースの差分（任意）
    tools/             … 再パッチ・設定用スクリプト（任意）
    module/            … Magisk / KernelSU モジュールのソース
      module.prop
      post-fs-data.sh  … 起動前の実行時パッチ（任意）
      service.sh       … 起動後の処理（任意）
      system/...       … /system 配下を置き換える場合
      system_ext/...   … /system_ext 配下を置き換える場合
    dist/              … ビルド済みモジュール zip
tools/
  build-module.ps1     … モジュール zip のビルドスクリプト
```

## 修正を追加する場合

1. `fixes/<修正名>/` を作成する
2. `module/module.prop` と必要なファイルを `module/` に配置する
   - system ファイルを置き換える場合: `module/system/...` または `module/system_ext/...`
   - 起動時にパッチする場合: `module/post-fs-data.sh` / `module/service.sh`
3. `fixes/<修正名>/README.md` に症状・原因・検証結果を書く
4. モジュール zip をビルドする

```powershell
pwsh -File tools/build-module.ps1 -Fix <修正名>
```

ビルドスクリプトは zip 内のパス区切りを必ず `/` にし、META-INF のインストーラを同梱します（Windows の `Compress-Archive` は `\` 区切りで zip を作るため、Magisk 側で正しく展開されません）。

## 免責事項

- 本リポジトリの内容は無保証です。導入は自己責任で行ってください。
- **各修正は特定の環境で検証したものであり、すべての ROM で動作する保証はありません。ROM によって使える場合と使えない場合があります。**
- 端末の故障・データ損失・動作不良について、作者は責任を負いません。
- 各ファイルのライセンスは、ファイル内のライセンス表記に従います（vendor 由来の XML は BSD 3-Clause など）。
