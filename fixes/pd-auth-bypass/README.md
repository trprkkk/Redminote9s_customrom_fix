# PD Authentication Bypass (curtana / CN-port ROM)

Anker などの **サードパーティ製 USB PD 充電器** を接続したとき、
PD ネゴシエーションが 5V/1.8A（約10W）で止まり、
9V/2A（約18W）にならない問題の回避モジュールです。

## 症状

- Anker 30W USB PD 充電器を挿しても 5V/1.8A 程度のまま
- `pd_active=0` または `pd_active=1` でも電圧が 5V
- `usbpd0/contract=implicit`、または explicit でも 5V
- `usbpd0/usbpd_verifed=0`
- `power_supply/bms/authentic=0`
- logcat に次のようなログが出る

```
batterysecret: Unable to write: 'host'
usbpd usbpd0: incorrect state (ufp) after data_role swap
batterysecret: pd not in ready state:SNK_Transition_Sink
usbpd usbpd0: batterysecret set usbpd verifed :0
```

## 原因

Xiaomi の `batterysecret`（`/vendor/bin/batterysecret`）が、
PD の data role swap を使って電池/充電器の認証を試みます。
この CN ポート ROM とサードパーティ充電器の組み合わせでは
data role swap が失敗し、`usbpd_verifed=0` になります。
その後、PD は PDO 1（5V）にフォールバックし、
充電器ドライバも PD 電流を制限します。

熱制限（`system_temp_level`）や SMB1398 の CP 不具合ではありません。
`thermal-cp-panic` モジュールとは独立した問題です。

## 修正内容

Magisk/KernelSU の `service.sh` で、次を行います。

1. 起動後に `setprop ctl.stop batterysecret` で認証サービスを停止
   （2秒ごとに再起動していないか確認し、再開していれば再度停止）
2. USB 接続中は `/sys/class/power_supply/usb/pd_authentication` に `1` を書く
3. `pd_active=1` かつ電圧が 7V 未満なら、PDO 1〜7 から
   9V の PDO を探し、その番号を
   `/sys/class/usbpd/usbpd0/select_pdo` に書く
4. 電池温度 45°C 以上、`system_temp_level != 0`、
   電池残量 90% 以上では何もしない

## 実機での確認結果

- 端末: Redmi Note 9S (curtana, Japan model)
- ROM: ResurrectedOS Neuve CN V1.0.24.3.25
- 充電器: Anker 30W USB PD
- 修正前: 5V / 1.8A（約9W）
- 修正後: 8.66V / 1.98A（入力約17W）
- `pd_active=1`、`contract=explicit`、`pdo2=9V`、`select_pdo=2`
- 充電器を挿した直後は 5V（PDO 1）でも、約2〜6秒で 9V（PDO 2）へ自動遷移
- PD ハードリセット後も 8 秒以内に 9V へ自動復帰
- `batterysecret` は `stopped`、`pd_authentication=1` を維持

## 注意事項

- **ROM 依存**: `/sys/class/usbpd/usbpd0/` と
  `/sys/class/power_supply/usb/pd_authentication` が存在する ROM
  でのみ動作します。パスや実装が違う ROM では使えません。
- **Xiaomi の PD 認証をバイパスします**。`bms/authentic=0` や
  `batterysecret` の data role swap 失敗そのものは修正しません。
  非純正電池・非純正充電器での急速充電を許可することになるため、
  自己責任で使用してください。
- 電池の JEITA、温度、残量による保護は残りますが、
  高温環境での連続充電には注意してください。
- PD PHY が `UNKNOWN` のまま固まった場合は、一度充電器を抜き挿しするか
  再起動してください。
- 30W 化する修正ではありません。この端末の通常の PD 18W/20W を
  サードパーティ充電器でも使えるようにするものです。

## インストール

1. `dist/pd_auth_bypass-v1.0.zip` を Magisk / KernelSU でインストール
2. 再起動
3. 充電器を接続し、`/data/local/tmp/pd_auth_bypass.log` を確認

SHA256: `0827669F8C4DE6D9A34998C398A047D576ADBE0D9C30FCEFFA4549DC923C8AB4`

## アンインストール

Magisk / KernelSU アプリでモジュールを削除し、再起動してください。
