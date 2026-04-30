# Evals: extension-reviewer

`extension-reviewer` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | スキルレビュー（`skill-review-team` 起動） | 対象 = スキル |
| case-02 | プラグインレビュー（`plugin-review-team` 起動） | 対象 = プラグイン |
| case-03 | フックレビュー（`hook-security-team` 起動） | 対象 = フック |
| case-04 | 自動修正モード | `--auto-fix` フラグ |
| case-05 | Critical 検出時の REJECT | パスポータビリティ NG |
| case-06 | CONDITIONAL_APPROVE（High あり Critical なし） | High 指摘 1 件以上 + Critical 0 件 |
| case-07 | コマンドレビュー（専用チームなし、個別エージェント並列） | 対象 = コマンド単体 |
| case-08 | エージェント定義レビュー（個別 3 名並列） | 対象 = `agents/{name}.md` |
| case-09 | チーム定義レビュー（個別 4 名並列） | 対象 = `references/teams/{name}.md` |
| case-10 | APPROVE（指摘なし正常完了） | Critical / High = 0（Medium は不問） |
| case-11 | チーム機能不可環境でのフォールバック起動 | `TeamCreate` 利用不可（ADR-017） |
| case-12 | `--non-interactive` モード（自動レビュー） | `--non-interactive` フラグ |
| case-13 | プラグイン全体レビュー（フック未含有・5 名構成） | プラグイン対象 + フック非含有 |
| case-14 | マーケットプレイス本体レビュー（個別 3 名並列） | 対象 = マーケットプレイス（marketplace.json） |
| case-15 | `--non-interactive` + `--auto-fix` 同時指定（CI 自動修正） | 両フラグ検出 |

## 実行確認方法

各ケースは `extension-reviewer` の動作分岐を例示する仕様書である。実装側で本ケースを満たすか確認する手順:

1. ケースの「入力」を再現する状態（前提ファイル・フラグ）を整える
2. `extension-reviewer` を起動（自然言語フレーズ or `/extension review`）
3. ケースの「期待動作」「期待出力」と実動作が一致することを確認
4. 不整合があれば指摘として記録

## ケース追加ルール

新しい分岐ロジックを追加した時は、対応するケースファイルを必ず追加し、本 README のケース一覧に登録する。詳細は [`../../../references/eval-guide.md`](../../../references/eval-guide.md) を参照。
