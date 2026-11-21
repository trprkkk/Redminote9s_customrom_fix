# Redmi Note 9S / Note 9 Pro (miatoll) カスタムROM 修正集

Redmi Note 9S (curtana) / Note 9 Pro (miatoll) 系のカスタムROMで発生する不具合の修正と、その調査メモをまとめたリポジトリです。

## 修正一覧

| 修正 | 対象 | 症状 | 状態 |
| --- | --- | --- | --- |
| [TAS2562 / ADSP 音声クラッシュ修正](fixes/tas2562-adsp-audio-crash/) | curtana (miatoll) | 動画再生が「少し動く → 止まる」を繰り返す | 検証済み |

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
    module/            … Magisk / KernelSU モジュールのソース
      module.prop
      system/vendor/etc/...
    dist/              … ビルド済みモジュール zip
tools/
  build-module.ps1     … モジュール zip のビルドスクリプト
```

## 修正を追加する場合

1. `fixes/<修正名>/` を作成する
2. `module/module.prop` と、置き換えるファイルを `module/system/...` に配置する
3. `fixes/<修正名>/README.md` に症状・原因・検証結果を書く
4. モジュール zip をビルドする

```powershell
pwsh -File tools/build-module.ps1 -Fix <修正名>
```

ビルドスクリプトは zip 内のパス区切りを必ず `/` にし、META-INF のインストーラを同梱します（Windows の `Compress-Archive` は `\` 区切りで zip を作るため、Magisk 側で正しく展開されません）。

## 免責事項

- 本リポジトリの内容は無保証です。導入は自己責任で行ってください。
- 端末の故障・データ損失・動作不良について、作者は責任を負いません。
- 各ファイルのライセンスは、ファイル内のライセンス表記に従います（vendor 由来の XML は BSD 3-Clause など）。
