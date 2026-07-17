# case-14 修正完了確認処理（ack-fixed）

引数 `ack-fixed=CR-002 commit=a1b2c3d` で修正完了確認を実行するケース。通常レビューフロー（Step 1〜8）はスキップ。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "ack-fixed=CR-002 commit=a1b2c3d" |
| モード | 非対話 |

## 分岐の根拠

SKILL.md Step 10「引数に ack-fixed が含まれる場合、Step 1〜8 を実行せず本ステップのみ実行」。

## 期待動作

- finding-thread-map.json から CR-002 の Thread ID を解決する
- commit=a1b2c3d から修正コミット SHA・URL を取得する
- Pattern E テンプレートに従い、修正コミットへの明示リンク付きで reply を投稿する
- Azure DevOps: status を fixed に変更 / GitHub: resolveReviewThread に変更
- PR の active なインラインスレッド残数を確認する
- 完了報告に処理した Finding ID 件数・対応コミット・PR 最終状態を出力する

## 関連ケース

- case-13: スコープ外了承（ack-scope-out、対になるフロー）
