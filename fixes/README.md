# 修正の追加方法

このリポジトリでは、1 つの修正を `fixes/<修正名>/` にまとめます。修正名は英小文字とハイフンにしてください。

## ディレクトリ構成

```
fixes/<修正名>/
├── README.md                      症状・原因・修正内容・検証結果
├── <任意の差分ファイル>.patch     参考用の diff（任意）
├── module/                        Magisk / KernelSU モジュールのソース
│   ├── module.prop                id / name / version / versionCode / author / description
│   └── system/...                 置き換えるファイル
└── dist/                          ビルド済み zip（リポジトリにコミットする）
    └── <id>-v<version>.zip
```

## 追加手順

1. `fixes/<修正名>/module/module.prop` を作成する
2. 置き換えるファイルを `fixes/<修正名>/module/system/...` に配置する
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
