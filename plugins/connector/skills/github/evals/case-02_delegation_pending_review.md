# Case 02: 他プラグイン委譲による Pending Review 一括投稿（パターン B）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | `Skill(skill: "connector:github", args: "PR URL: https://github.com/contoso/webapp/pull/42 に Pending Review を投稿。サマリー: レビュー結果サマリ, コメント: [{\"path\":\"src/auth/login.ts\",\"line\":30,\"body\":\"[CR-001] パスワードハッシュ化不足\"}]。承認済み。")` |
| 引数 | PR URL + サマリー + コメント JSON 配列 + 「承認済み」 |
| 既存状態 | 呼び出し元は コードレビュー用プラグインの pr-review スキル。`gh auth status` 認証済み |

## 期待動作

### Phase 1: 呼び出し元判別

- args に「承認済み」が含まれるため **パターン B（他プラグイン委譲）** と判別

### Phase 2: 認証確認

- `gh auth status` で認証済みを確認

### Phase 3: 承認スキップ

- パターン B かつ「承認済み」明示 → `AskUserQuestion` 承認をスキップ

### Phase 4: 実行

- `jq -n --arg body ... --argjson comments ...` で JSON body を構築
- `gh api repos/contoso/webapp/pulls/42/reviews --input -` で Pending Review を投稿

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | 承認スキップ → Pending Review 投稿完了（レビュー ID を呼び出し元に返す） |
| 終了状態 | 成功 |

## 分岐の根拠

パターン B での Pending Review 一括投稿。承認がスキップされ、複数コメントがまとめて投稿される。
