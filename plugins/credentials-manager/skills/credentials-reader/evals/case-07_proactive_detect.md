# Case 07: プロアクティブ検出（GitHub トークン → 引き継ぎ）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "GitHub のトークン ghp_<github-pat-sample> を覚えておいて。あとで GitHub API を叩くときに使いたい。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `credentials.json` 不在 |

## 期待動作

### Phase 1: パターン検出

- 文字列 `ghp_...` を GitHub `token` パターンとして検出
- 文脈（"GitHub API"）から `domains` を `["api.github.com"]` と推定
- マスクして通知（フル値を復唱しない）: "I noticed a credential pattern: `ghp_****xxxx`."

### Phase 2: 保存提案

- 識別名候補 `github-token` を提示し `AskUserQuestion` で「保存しますか／保存しない」を確認

### Phase 3: 引き継ぎ

- ユーザ承諾 → **`credentials-manager` を起動** して保存フローを実施
  - 種別: `token`
  - `urls`: `["https://api.github.com/*"]`（推奨デフォルト）
  - `domains`: `["api.github.com"]`
  - `auth_method`: `header:Authorization:Bearer`
- 引き継ぎ時はマスク済み値・候補名・推定ドメインのみを渡し、フル値はメインコンテキストに残さない

### Phase 4: 確認

- `credentials-manager` がマスク済み値で完了通知: `ghp_****xxxx`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `credentials.json`（解決パスに応じてプロジェクト or ユーザースコープ） |
| 標準出力（要約） | "Saved credential 'github-token' (token): ghp_****xxxx — domains: api.github.com" |
| 終了状態 | 成功 |

## 分岐の根拠

「プロアクティブ検出 → 引き継ぎ」分岐。`ghp_` パターンが API キー風文字列として検出され、reader が保存提案 → manager に引き継ぐ流れを検証する。reader 単体で書き込みを行わないこと、フル値を通知に含めないことが主要観点。

## 関連ケース

- `case-01_auto_match_single.md`（保存後の GitHub URL アクセスでの自動マッチ）
