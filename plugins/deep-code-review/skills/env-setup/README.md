# env-setup スキル

deep-code-review プラグインが利用する **Windows 標準以外の外部依存ツール** のインストール・確認を集約するスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 提供機能

- 外部ツール（gh / az / azure-devops 拡張 / csharp-ls / typescript-language-server / Node.js / Python / .NET SDK / PowerShell 7）の存在確認・インストール
- 他スキル（pr-review / code-review-* 等）からの「ツール不足を解消して」依頼への対応
- 管理対象ツールカタログの一元管理

## 使い方

### トリガーフレーズ例

- 「環境構築して」
- 「必要なツールをインストールして」
- 「gh をインストールして」
- 「Azure DevOps のセットアップをして」
- 「PR レビューに必要なツールを揃えて」

### 実行モード判定

| モード | トリガー | 動作 |
|--------|---------|------|
| 確認モード（既定） | ツール名のみ指定 | `where <tool>` で存在確認、不足時にユーザー確認 |
| インストールモード | 「インストールして」明示 | 確認後にユーザー承認を取り、`winget` 等で実行 |

### 他スキルからの依頼

`pr-review` スキル等が必要ツール不在を検知した場合は、本スキルへ Skill ツール経由で依頼する。

```
Skill(skill: "env-setup", args: "install gh,az,azure-devops")
```

## ファイル構成

```
plugins/deep-code-review/skills/env-setup/
├── SKILL.md                              # Claude が実行時に読むスキル定義
├── README.md                             # 本ファイル（人間向け）
├── evals/                                # 動作分岐検証ケース（case-01〜10 + README）
└── references/
    ├── checklist.md                      # ルール ID 達成チェックリスト（U/E 軸）
    └── tools-catalog.md                  # 管理対象ツールの詳細カタログ
```

## カスタマイズ

### 新しいツールを管理対象に追加する

1. `references/tools-catalog.md` に用途・インストール方法・確認コマンドを追加
2. `SKILL.md` の管理対象一覧表に追記
3. 利用元スキルから「不足時は env-setup を呼ぶ」と参照

### Windows 以外への対応

現状は Windows 環境を想定。macOS / Linux サポートが必要な場合は `tools-catalog.md` にプラットフォーム別カラムを追加する。

## スコープ外

- ツールの利用方法（各スキル側で文書化）
- プロジェクト固有の依存関係（`dotnet restore` / `npm install`）
- 認証情報の管理（登録・保存は credentials-manager プラグイン経由でユーザー側が実施。外部接続時の取得は connector が解決）
- 自動的な管理者権限昇格
