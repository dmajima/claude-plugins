# Case 03: プロアクティブ検出（GitHub トークン）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "GitHub のトークン ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx を覚えておいて。あとで GitHub API を叩くときに使いたい。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `credentials.json` 不在 |

## 期待動作

### Phase 1: パターン検出

- 文字列 `ghp_...` を GitHub `token` パターンとして検出
- 文脈（"GitHub API"）から `domains` を `["api.github.com"]` と推定

### Phase 2: 識別名確定

- 識別名候補 `github-token` を提示し `AskUserQuestion` で確認 or そのまま採用

### Phase 3: 保存

- 種別: `token`
- `urls`: `["https://api.github.com/*"]`（推奨デフォルト）
- `domains`: `["api.github.com"]`
- `auth_method`: `header:Authorization:Bearer`（GitHub の場合 `token <value>` も慣用だが既定は Bearer）

### Phase 4: 確認

- マスク済み値で通知: `ghp_****xxxx`（実際の末尾 4 文字）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `credentials.json`（解決パスに応じてプロジェクト or ユーザースコープ） |
| 標準出力（要約） | "Saved credential 'github-token' (token): ghp_****xxxx — domains: api.github.com" |
| 終了状態 | 成功 |

## 分岐の根拠

このケースは「プロアクティブ検出」分岐に該当する。`ghp_` パターンが API キー風文字列として検出され、保存提案 → 保存フローへ遷移。

## 関連ケース

- `case-04_auto_match_single.md`（保存後の GitHub URL アクセスでの自動マッチ）
