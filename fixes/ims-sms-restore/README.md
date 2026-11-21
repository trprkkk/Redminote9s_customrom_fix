# IMS / SMS Restore (KDDI povo / au)

povo / au（KDDI）回線で SMS が届かなくなったときに、IMS スタックを復帰させる修正です。

## 症状

- povo / au の番号に SMS を送っても届かない
- `dumpsys isms` に受信履歴が増えない
- `logcat -b radio` に次のようなログが繰り返し出る

```
ImsManagerIM [0]: ImsService not up yet - timeout waiting for connection.
ImsSmsDispatcher [0]: isAvailable: up=false, reg=false, cap=false
```

- `pm list packages -d` に `org.codeaurora.ims` が出る
- `dumpsys package com.qti.phone` で `installed=false` になっている

## 原因

IMS クラッシュ（`telephony service is null`）の回避策として
`org.codeaurora.ims` を無効化し、`com.qti.phone` を user 0 から
アンインストールすると、KDDI の **SMS over IMS (SMSoIP)** が使えなくなります。

povo / au は LTE 上で IMS 登録して SMS を扱うため、IMS サービスが上がらないと
SMS が受信できません。固定電圧 PD やデータ通信が動いていても、
SMS だけ落ちるのが特徴です。

## 修正内容

起動完了後に次の 2 つを実行します。

```sh
pm enable org.codeaurora.ims
pm install-existing com.qti.phone
```

`service.sh` が `sys.boot_completed=1` を待ってから実行します。

## 検証結果

手動で同じコマンドを実行した環境で確認済みです。

```
ImsSmsDispatcher [0]: ImsManager: connection ready.
ImsSmsDispatcher [0]: onImsConnected imsRadioTech=1
SST [0]: setImsRegistrationState: {registered=true}
SST [1]: setImsRegistrationState: {registered=true}
```

povo / au の両回線が IMS 登録され、SMS の受信を確認しました。

## インストール

1. `dist/ims_sms_restore-v1.0.zip` を端末へコピー
2. Magisk / KernelSU アプリ → モジュール → ストレージからインストール
3. 再起動
4. 設定 → アプリ → デフォルトの SMS アプリ が意図したアプリになっていることを確認
5. 必要なら「デフォルトの SMS SIM」を povo 側に設定

## アンインストール

Magisk / KernelSU アプリでモジュールを削除（または無効化）して再起動してください。
`org.codeaurora.ims` の有効化状態と `com.qti.phone` のインストール状態は
そのまま残ります。元に戻す場合は手動で無効化・アンインストールしてください。

## 注意事項

- **ROM 依存性**: この修正は `org.codeaurora.ims` と `com.qti.phone` という
  パッケージ名を前提にしています。ROM によっては IMS アプリのパッケージ名や
  構成が異なり、**使える場合と使えない場合があります**。
- IMS アプリは起動時に一度だけ
  `IllegalStateException: telephony service is null` で落ちることがあります。
  これは persistent プロセスとして再起動し、その後に IMS 登録されます。
  このモジュールはクラッシュ自体を修正するものではなく、機能を復帰させるものです。
- クラッシュダイアログを消したい場合は
  `settings put global hide_error_dialogs 1` を設定できます。
  ただし全アプリのクラッシュダイアログが非表示になります。
- IMS を有効に戻すと、VoLTE / VoWiFi / RCS の挙動が変わります。
  通話・SMS・データを一通り確認してください。
- デフォルトの SMS アプリとデフォルトの SMS SIM はユーザー設定です。
  モジュールでは変更しません。
- キャリア側の SMS オプション契約や APN 設定が原因の場合は、この修正では解決しません。
