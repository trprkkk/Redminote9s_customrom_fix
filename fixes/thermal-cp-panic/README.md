# Thermal CP Panic Fix (curtana JP / CN-port)

日本向け curtana に CN ポート系の HyperOS ROM を組み合わせた環境で、
QC/PD（PPS / QC3）充電中にカーネルパニックで再起動する問題の回避策です。

## 症状

- QC/PD 複合充電器で充電中、数秒〜数十秒後に突然再起動する
- 固定電圧の PD 充電では発生しないことが多い
- `sys.boot.reason` が `kernel_panic,null` になる
- pstore に次のようなログが残る

```
Unable to handle kernel NULL pointer dereference at virtual address 00000004
Internal error: Oops: 96000005 [#1] PREEMPT SMP
Process thermal-engine (pid: ...)
pc : smblib_set_prop_system_temp_level+0x230/0x5e0
Call trace:
 smblib_set_prop_system_temp_level
 smb5_batt_set_prop
 ps_set_cur_charge_cntl_limit
 thermal_cooling_device_cur_state_store
```

## 動作確認環境

| 項目 | 内容 |
| --- | --- |
| 端末 | Redmi Note 9S (curtana / miatoll, Japan model) |
| ROM | HyperOS ベースの CN ポート ROM (Android 14) |
| kernel | 4.14.357-openela-kinesis-omega-r7.9 |
| root | Magisk / KernelSU |
| 充電IC | PM6150 SMB5 + SMB1398 (2:1 charge pump) |

## 原因

パニックは `smblib_set_prop_system_temp_level()` の中で発生します。

1. 日本向け curtana は bootloader から `androidboot.hwc=Japan` /
   `androidboot.hwversion=5.90.0` を渡される
2. `lct_check_hwversion()` が `JAPAN_HWVERSION (4)` を返す
3. QC3 / QC3+ / PD PPS で SMB1398 チャージポンプ (CP) が選択されると
   `chg->cp_reason != POWER_SUPPLY_CP_NONE` になる
4. この条件で次の分岐に入る

```c
else if ((chg->cp_reason != POWER_SUPPLY_CP_NONE) &&
         (lct_check_hwversion() == JAPAN_HWVERSION)) {
    vote(chg->fcc_votable, THERMAL_DAEMON_VOTER, true,
         chg->thermal_mitigation_cp[chg->system_temp_level]);
    pr_err("fcc_thermal_cp=%d",
           chg->thermal_mitigation_cp[chg->system_temp_level]);
}
```

5. CN ポート ROM の device tree には `qcom,thermal-mitigation`（通常用）しかなく、
   日本向けの `qcom,thermal-mitigation-cp` が存在しない
6. `qpnp-smb5.c` はこのプロパティがある場合だけ
   `thermal_mitigation_cp` を確保するため **NULL のまま**
7. thermal-engine が battery cooling device の level を 0→1 に変えると
   `NULL + 1×4 = 0x4` を読み、パニックする

逆アセンブルでも、CP 分岐だけが `chg+0xF78`（`thermal_mitigation_cp`）を
参照していることを確認しています。

```
ldr x9, [x8, #0xf78]       ; thermal_mitigation_cp = NULL
ldr w3, [x9, x19, lsl #2]  ; level=1 -> address 0x4
```

## 修正内容

thermal-engine の設定から `[BATTERY_CHARGING_STL]` セクションを削除し、
battery cooling device への非ゼロ書込み自体を止めます。

- `/vendor/etc/thermal-engine-normal.conf`
- `/vendor/etc/thermal-engine-camera.conf`

モジュールは ROM の設定ファイルを実行時にコピーし、
セクションを削除して bind mount します。vendor ファイルは同梱しません。

```sh
awk '
    /^\[/ { in_batt = ($0 ~ /^\[BATTERY_CHARGING_STL\]/) }
    in_batt { next }
    { print }
' "$src" > "$dst"
mount -o bind "$dst" "$src"
```

## 検証結果

実機で以下を確認済みです。

```
mount | grep thermal-engine              -> 2 件 (normal / camera)
grep -c 'actions battery'                -> 0 / 0
getprop init.svc.thermal-engine          -> running
/sys/class/thermal/cooling_device13/...  -> cur_state=0
dmesg | grep 'system temp level:[1-9]'   -> 0 件
```

修正後、QC/PD 充電で再起動は発生していません。

補足: リポジトリ版 v2.0 は実行時パッチ方式です。実機では同内容の設定を
bind mount する静的版で確認済みで、v2.0 は起動時に同じ出力を生成することを
確認しています。

## インストール

1. `dist/thermal_cp_panic_fix-v2.0.zip` を端末へコピー
2. Magisk / KernelSU アプリ → モジュール → ストレージからインストール
3. 再起動
4. `post-fs-data.log` に `patched ...` と出ていることを確認

## アンインストール

Magisk / KernelSU アプリでモジュールを削除（または無効化）して再起動してください。

## 注意事項

- **ROM 依存性**: この修正は
  `/vendor/etc/thermal-engine-normal.conf` と `-camera.conf` に
  `[BATTERY_CHARGING_STL]` がある ROM を前提にしています。ROM によっては
  設定パス・セクション名・thermal-engine の実装が異なり、
  **使える場合と使えない場合があります**。
- セクションが見つからない場合、モジュールは何もせず終了します
  （`post-fs-data.log` を確認してください）。
- `[BATTERY_CHARGING_STL]` を削除すると、`quiet-therm-usr`（基板・皮膚温度）に
  よる充電電流の段階的制限が失われます。JEITA（電池温度）・充電器IC温度上限・
  ACC など別の保護は残りますが、高温環境での連続充電は注意してください。
- 別の経路（thermal-engine 以外）が battery cooling device の `cur_state` を
  非ゼロに書き換える場合、この修正では防げません。
- 根本原因は ROM 側の device tree に `qcom,thermal-mitigation-cp` が無いことです。
  恒久対策は ROM/カーネル側で次のどちらかを行うことです。
  - charger node に `qcom,thermal-mitigation-cp` を追加する
  - カーネル側で `thermal_mitigation_cp` の NULL ガードを入れる
- 参考: kinesis-omega-r7.9 では、CP 分岐を通常配列にフォールバックさせる
  1 分岐パッチ（`b.ne` → `b`）でも回避できます。カーネル更新時は
  オフセットが変わるため再解析が必要です。
