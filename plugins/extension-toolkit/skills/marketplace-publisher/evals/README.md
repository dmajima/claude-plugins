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
