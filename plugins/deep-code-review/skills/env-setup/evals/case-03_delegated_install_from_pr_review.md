# case-03 他スキル委譲（カテゴリ A・ツール固有サブコマンド）

pr-review が必要ツールの不在を検知して env-setup へインストールを委譲するケース。カテゴリ A（pr-review 必須）を一次責務として扱い、azure-devops 拡張はツール固有サブコマンドで導入する。委譲経由でもユーザー承認は省略しない。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | 操作 `install` / 対象ツール `gh,az,azure-devops` / 呼び出し元 `pr-review` |
| モード | 委譲呼び出し（インストール承認は対話で実施） |

## 分岐の根拠

SKILL.md「実行モード判定」2「…または他スキルからインストール依頼を受けた場合のみ、対象ツールを順にインストールする」、SKILL.md「入力（呼び出し時の引数）」表（操作 `verify` / `install`、対象ツールはカンマ区切り、呼び出し元）、references/tools-catalog.md セクション 0 のカテゴリ表「A: pr-review 必須」（gh / az / azure-devops 拡張 / jq / curl）と「カテゴリ別管理方針」（カテゴリ A は env-setup の一次責務）、同 1.3（azure-devops 拡張: インストール `az extension add --name azure-devops`・前提 `az` CLI 必須）、SKILL.md「Windows でのインストール優先順位」2（ツール固有のサブコマンド）、SKILL.md「重要な制約」（ユーザー承認なしでのインストール実行の禁止）と references/checklist.md セクション B の E2。

## 期待動作

- 委譲 args から操作 `install`・対象 3 ツール・呼び出し元 `pr-review` を解釈する（SKILL.md「実行フロー」1）
- 他スキルからの委譲でもインストールモードに入るが、AskUserQuestion によるユーザー承認は省略しない（E2、SKILL.md「重要な制約」）
- gh / az は winget（優先順位 1）、azure-devops 拡張は `az extension add --name azure-devops`（優先順位 2: ツール固有サブコマンド）でインストールする（E4）
- azure-devops 拡張は az CLI を前提とするため、az の導入成功を確認してから実行する（tools-catalog.md 1.3 の前提）
- az が導入できなかった場合は azure-devops 拡張を「### インストール失敗・要対応」に前提不足として記載し、「### 推奨アクション」に対処方針を示す（SKILL.md「出力フォーマット」、checklist C-Auto-2）
- インストール後に `gh --version` / `az --version` / `az devops --help` で再確認する（実行フロー 6、SKILL.md「管理対象ツール一覧」の確認コマンド）
- `gh auth login` / `az login` 等の認証はユーザー実施として案内のみ行う（SKILL.md「責務外」、tools-catalog.md セクション 5）

## 関連ケース

- case-02: ユーザー直接指示によるインストールモード
- case-01: 確認モード（インストールを伴わない対比）
