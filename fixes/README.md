# 修正の追加方法

このリポジトリでは、1 つの修正を `fixes/<修正名>/` にまとめます。修正名は英小文字とハイフンにしてください。

## ROM 依存性

各修正は、特定の端末・ROM・vendor・カーネルの組み合わせで検証したものです。
同じ端末でも、ROM のバージョンや移植元、vendor の内容、カーネルによって
**使える場合と使えない場合があります**。修正が適用されないだけでなく、
起動不能・VoLTE 喪失・充電不良などを起こす可能性もあります。
README には、どの環境で検証したかと、どの条件で使えなくなるかを必ず書いてください。

## ディレクトリ構成

```
fixes/<修正名>/
├── README.md                      症状・原因・修正内容・検証結果
├── <任意の差分ファイル>.patch     参考用の diff（任意）
├── module/                        Magisk / KernelSU モジュールのソース
│   ├── module.prop                id / name / version / versionCode / author / description
│   ├── post-fs-data.sh            起動前の実行時パッチ（任意）
│   ├── service.sh                 起動後の処理（任意）
│   ├── action.sh                  アクションボタンの処理（任意）
│   ├── uninstall.sh               アンインストール時の処理（任意）
│   └── system/...                 置き換えるファイル
└── dist/                          ビルド済み zip（リポジトリにコミットする）
    └── <id>-v<version>.zip
```

## 追加手順

1. `fixes/<修正名>/module/module.prop` を作成する
2. 必要なファイルを `module/` に配置する
   - system ファイルを置き換える場合: `module/system/...` または `module/system_ext/...`
   - 起動時にパッチする場合: `module/post-fs-data.sh` / `module/service.sh`
   - アクションボタンを使う場合: `module/action.sh`
   - アンインストール時の処理: `module/uninstall.sh`
3. `fixes/<修正名>/README.md` を書く
   - 症状
   - 動作確認環境（端末・ROM・vendor）
   - 原因（ログ抜粋を添える）
   - 修正内容
   - 検証結果（修正前 / 修正後）
   - インストール・アンインストール
   - 注意事項
4. zip をビルドする

```powershell
pwsh -File tools/build-module.ps1 -Fix <修正名>
```

5. ビルドされた `fixes/<修正名>/dist/<id>-v<version>.zip` をコミットする

## 注意

- zip 内のパスは必ず `/` 区切りにしてください。Windows の `Compress-Archive` は `\` 区切りで zip を作るため、Magisk / KernelSU 側で「`system\vendor\...` という名前のファイル」として展開され、モジュールが機能しません。このリポジトリのビルドスクリプトは `/` 区切りで出力します。
- 修正を更新したら `module.prop` の `versionCode` を必ず上げてください。
- 端末固有の情報（シリアル、MAC アドレス、Google アカウント、ローカルパスなど）を含めないでください。
