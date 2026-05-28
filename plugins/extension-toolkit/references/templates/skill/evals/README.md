# Evals: {skill-name}

このディレクトリは `{skill-name}` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | {内容} | {分岐根拠} |
| case-02 | {内容} | {分岐根拠} |

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

## デモ実行スクリプト（B-3、推奨）

スキル新規作成・改修時の動作デモ用に [`demo.sh`](demo.sh) を同梱している。
A-1 (動作デモ + 承認フロー必須化、ADR-032) で求められる「再現可能なデモ実施」を担保する標準テンプレート。

```bash
# 計画のみ表示（副作用ゼロ、既定）
bash evals/demo.sh

# 実コマンド実行（dry-run のみ含むため副作用なし）
bash evals/demo.sh --execute
```

<details><summary>PowerShell フォールバック</summary>

```powershell
# 計画のみ表示（副作用ゼロ、既定）
pwsh -NoProfile -File evals/demo.ps1

# 実コマンド実行（dry-run のみ含むため副作用なし）
pwsh -NoProfile -File evals/demo.ps1 -WhatIf:$false
```

</details>

`demo.sh` は以下の 4 ステップを順次実行する:

1. 代表的な正常系（dry-run）
2. 主要分岐の動作確認
3. 対話モード誘導（AskUserQuestion 含有時）
4. エラーパス確認（引数不正等）

新規スキル作成時はテンプレ（`references/templates/skill/evals/demo.sh`）をコピーし、`{...}` プレースホルダを実際のコマンド・期待値で埋める。

## 自動実行 evals（B-2、オプトイン）

`case-*.md` 冒頭にフロントマター `runnable: true` を付与すると、`run_evals.py` で並列自動実行・diff 検証の対象になる。詳細は [`../../../references/eval-guide.md`](../../../references/eval-guide.md) 節 10 を参照。

## ケース追加ルール

新しい分岐ロジックを追加した時は、対応するケースファイルを必ず追加する。詳細は [`../../../references/eval-guide.md`](../../../references/eval-guide.md) を参照。
