# WFD Seccomp Loop Fix (experimental)

Wi-Fi Display 関連の `wfdvndservice` / `wfdhdcphalservice` が
約5秒ごとにクラッシュ・再起動を繰り返す問題の修正です。

**この修正は未検証（実験的）です。** 実機で動作確認した上で使用してください。

## 症状

- `wfdvndservice` / `wfdhdcphalservice` が起動直後に落ち、init が再起動する
- `flags_health_check` が繰り返し実行され、ログと電池消費が増える
- `logcat` に次のようなログが出る

```
E wfdvndservice: libminijail[...]: blocked syscall: gettimeofday
E wfdhdcphalservice: libminijail[...]: blocked syscall: gettimeofday
```

## 原因

Android 14 の vendor seccomp ポリシーが `gettimeofday` を許可していないため、
サービスが起動直後に終了します。終了すると init が再起動し、
約5秒周期のループになります。

## 修正内容

`/vendor/etc/seccomp_policy/`（または `/system/etc/seccomp_policy/`）にある
`*wfd*` ポリシーをコピーし、`gettimeofday: 1` を追記して bind mount します。

```sh
echo 'gettimeofday: 1' >> "$dst"
mount -o bind "$dst" "$src"
```

## 検証結果

**未検証（実験的）** です。ログから原因を特定して修正スクリプトを用意した段階で、
実機での適用確認はできていません。

確認する場合:

```sh
getprop init.svc.wfdvndservice
getprop init.svc.wfdhdcphalservice
logcat -b all -d | grep -E 'wfdvndservice|wfdhdcphalservice|blocked syscall'
```

サービスが `running` のまま安定し、`blocked syscall: gettimeofday` が
出なくなれば成功です。

## インストール

1. `dist/wfd_seccomp_fix-v1.0.zip` を端末へコピー
2. Magisk / KernelSU アプリ → モジュール → ストレージからインストール
3. 再起動
4. 上のコマンドで確認

## アンインストール

Magisk / KernelSU アプリでモジュールを削除（または無効化）して再起動してください。

## 注意事項

- **ROM 依存性**: seccomp ポリシーのパス・ファイル名・形式は ROM によって異なります。
  この修正は `/vendor/etc/seccomp_policy/*wfd*` または
  `/system/etc/seccomp_policy/*wfd*` が存在する ROM を前提にしています。
  **使える場合と使えない場合があります**。
- ポリシーがバイナリ形式の場合、テキストの追記はできません。
- `gettimeofday` 以外の syscall もブロックされている場合、追加が必要です。
  その場合はログの `blocked syscall:` を見て、同じ形式で追記してください。
- Wi-Fi Display（キャスト）を使わない場合、サービスを停止・無効化する方が
  確実で簡単です。
- この修正は Wi-Fi Display の機能自体を保証するものではありません。
  キャストの動作確認は別途行ってください。
