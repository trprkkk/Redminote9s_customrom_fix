# ADB Keep Enabled

カスタム ROM で USB デバッグが起動後に自動でオフになる問題の修正です。

## 症状

- 開発者向けオプションで USB デバッグをオンにしても、再起動後にオフに戻る
- `adb devices` に端末が出てこない
- `settings get global adb_enabled` が `0` になっている

## 原因

ROM 側のセキュリティ設定や初期化処理が `adb_enabled` をリセットしているためです。
ROM によっては起動後に何度もオフに戻されます。

## 修正内容

起動完了後に次を実行します。

```sh
settings put global adb_enabled 1
```

Wi-Fi ADB を使いたい場合は `service.sh` のコメントを外してください。

```sh
setprop persist.adb.tcp.port 5555
setprop service.adb.tcp.port 5555
stop adbd
start adbd
```

## 検証結果

同等の `service.d` スクリプトで、再起動後も `adb_enabled=1` が維持され、
USB / Wi-Fi ADB で接続できることを確認済みです。

## インストール

1. `dist/adb_keep_enabled-v1.0.zip` を端末へコピー
2. Magisk / KernelSU アプリ → モジュール → ストレージからインストール
3. 再起動
4. `settings get global adb_enabled` が `1` になっていることを確認

## アンインストール

Magisk / KernelSU アプリでモジュールを削除（または無効化）して再起動してください。
`adb_enabled` の設定は残るため、必要に応じて開発者向けオプションからオフにしてください。

## 注意事項

- **ROM 依存性**: ROM が `adb_enabled` 以外の方法（独自のセキュリティアプリ、
  init サービス、プロパティなど）で USB デバッグを無効化している場合、
  この修正では効かないことがあります。
- USB デバッグを常時有効にすると、セキュリティ上のリスクが上がります。
  信頼できる端末とケーブルだけを使ってください。
- Wi-Fi ADB を有効にすると、同じネットワーク上の端末から接続できるようになります。
  必要なときだけ有効にしてください。
