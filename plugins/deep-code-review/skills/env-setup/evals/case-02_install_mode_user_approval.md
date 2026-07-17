# case-02 インストールモード（明示指示・AskUserQuestion 承認・winget 最優先）

ユーザーが「インストールして」と明示するケース。AskUserQuestion でまとめて承認を取得してから winget 最優先でインストールし、管理者権限へは自動昇格しない。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "gh と jq をインストールして" |
| モード | 対話 |

## 分岐の根拠

SKILL.md「実行モード判定」2（インストールモード）「ユーザーが『インストールして』『セットアップして』と明示した場合…対象ツールを順にインストールする」、同「Windows でのインストール優先順位」（1. winget 最優先 → 2. ツール固有サブコマンド → 3. MSI/EXE）、同「管理者権限が必要な場合」「自動で昇格しない。代わりにユーザーに以下を表示する」、SKILL.md「実行フロー」4「インストール承認の取得: AskUserQuestion で確認（不足ツールを一覧で提示し、まとめて承認を取る）」、references/checklist.md セクション B の E2 / E3 / E4。

## 期待動作

- 「インストールして」の明示によりインストールモードと判定する
- インストール前に存在確認（実行フロー 2）を行い、既にインストール済みのツールは「### 既にインストール済み」として報告し再インストールしない
- 不足ツールを一覧提示し、AskUserQuestion でまとめて承認を取得してからインストールを実行する（実行フロー 3〜4、E2）
- gh は `winget install --id GitHub.cli --accept-package-agreements --accept-source-agreements`、jq は `winget install --id jqlang.jq --accept-package-agreements --accept-source-agreements` を使用する（SKILL.md「管理対象ツール一覧」、references/tools-catalog.md 1.1 / 1.4。優先順位 1: winget）
- 管理者昇格が必要な場合は自動昇格せず、管理者 PowerShell で実行すべきコマンドをユーザーに提示する（E3、checklist C-Auto-4）
- インストール後に `gh --version` / `jq --version` で再確認し、結果を報告する（実行フロー 6）
- 完了報告は「## env-setup 結果」フォーマットに従い「### インストール実行」に成否を記載する（checklist C-Auto-1）
- `gh auth login` 等の認証はユーザー実施として案内のみ行う（SKILL.md「責務外」、references/tools-catalog.md セクション 5「認証情報入力は本スキルで自動化しない」）

## 関連ケース

- case-01: 確認モード（既定・インストール明示なし）
- case-03: 他スキルからの委譲によるインストール
