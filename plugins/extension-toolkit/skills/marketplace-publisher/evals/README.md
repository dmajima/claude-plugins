# Evals: marketplace-publisher

`marketplace-publisher` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | 新規登録（ハンドオフ） | 重複なし + ハンドオフモード |
| case-02 | 既存更新（description 変更） | 既存エントリあり |
| case-03 | 重複検出（マージ提案） | 既存と類似度高 |
| case-04 | フルオートモード | `--full-auto` フラグ |
| case-05 | 削除（明示確認） | 削除指示 |
| case-06 | フルオート時の保護ブランチ阻止 | `--full-auto` + 現在ブランチが main/master |
| case-07 | フルオート + シークレット検出時の fail-closed | `--full-auto` + `.env` / API キー等の検出 |
| case-08 | 非対話ハンドオフ + シークレット検出時の fail-closed | `--non-interactive` 単独 + シークレット検出 |
| case-09 | 対話モードでのシークレット検出（4 択 + 二重確認）| 対話モード（フラグなし）+ シークレット検出 |
| case-10 | 公開モード選択前のデモ + AskUserQuestion 承認取得 (A-1 / ADR-032) | 通常公開フロー全体に必須 |

## 実行確認方法

各ケースは `marketplace-publisher` の動作分岐を例示する仕様書である。実装側で本ケースを満たすか確認する手順:

1. ケースの「入力」を再現する状態（前提ファイル・フラグ）を整える
2. `marketplace-publisher` を起動（自然言語フレーズ or `/extension publish`）
3. ケースの「期待動作」「期待出力」と実動作が一致することを確認
4. 不整合があれば指摘として記録
