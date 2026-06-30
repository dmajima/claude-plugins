---
name: render-check
description: 投稿本文が投稿先のレンダリング方式（Backlog 記法 / Markdown / Azure DevOps）で正しく表示されるか検証するスキル。「Backlog で正しく表示されるか確認」「レンダリングチェック」「TFS でどう見える？」等で起動。記法不一致・メンション暴発・機密情報を検出。Use when checking rendering without posting. SKIP when posting (use backlog / azure; they call this internally).
---

# Render Check

外部サービスへ投稿する本文が、投稿先のレンダリング方式で意図どおり表示されるかを **投稿前に** 検証するスキル。記法不一致・意図しない自動リンクやメンション・構造崩れ・機密情報を検出し、プレビューと修正案を提示する。connector プラグインの書き込み操作の必須ゲート。

## 責務

- 投稿本文のレンダリング検証（5 カテゴリ: NOTATION / AUTOLINK / STRUCTURE / SECRET / SIZE）
- 総合判定（PASS / WARN / FAIL）と修正案の提示
- 投稿プレビュー（レンダリング後の見え方の説明付き）の提示

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| Backlog への実際の投稿・更新 | `backlog` |
| Azure DevOps への実際の投稿・更新 | `azure` |
| 認証情報の管理 | credentials-manager プラグイン |

## トリガー条件

- `backlog` / `azure` スキルの書き込み操作前の **必須ゲート** として呼び出される
- 「このコメントが Backlog で正しく表示されるかチェックして」（単体起動）
- 「投稿前にレンダリング確認して」「この本文 TFS でどう見える？」（単体起動）

このスキルを起動しないケース:

- 実際に投稿・更新まで行いたい（→ `backlog` / `azure`。それらが本スキルを内部で呼ぶ）

## 前提

呼び出し前に以下が確定していること（不足時は対話で確認）:

1. 投稿予定のテキスト本文
2. レンダリングターゲット（下表の 4 種。単体起動で不明な場合は `AskUserQuestion` で確認）

## 入力

| 項目 | 必須 | 内容 |
|-----|------|------|
| 本文 | 必須 | 投稿予定のテキスト |
| ターゲット | 必須 | 下表のレンダリング方式。単体起動で不明な場合は `AskUserQuestion` で確認 |

### ターゲット種別

| ターゲット | 投稿先 | 参照ルール（プラグイン共通 references） |
|-----------|-------|--------------------------------------|
| `backlog-notation` | Backlog（textFormattingRule=`backlog`） | [rendering/backlog-notation.md](../../references/rendering/backlog-notation.md) |
| `backlog-markdown` | Backlog（textFormattingRule=`markdown`） | [rendering/backlog-markdown.md](../../references/rendering/backlog-markdown.md) |
| `ado-markdown` | Azure DevOps の PR 説明・PR コメント・クラウド作業項目コメント | [rendering/azure-devops-markdown.md](../../references/rendering/azure-devops-markdown.md) |
| `ado-workitem-html` | TFS 作業項目コメント（`System.History`、Markdown 非解釈） | 同上（セクション 1・5） |

Backlog の textFormattingRule は呼び出し元（`backlog` スキル）が API で判定済みの値を引き継ぐ。単体起動でターゲットが Backlog かつ記法不明の場合は、ユーザーにプロジェクトの記法設定を確認する（推測で決めない）。

### render-check 適用/非適用の判断基準

| サービス | render-check | 理由 |
|---------|-------------|------|
| Backlog | **適用** | Backlog 独自記法（`backlog`）と Markdown（`markdown`）の 2 方式が混在し、記法不一致による表示崩れが発生する |
| Azure DevOps（PR・作業項目コメント） | **適用** | ADO 独自の Markdown 拡張と TFS の HTML 記法（`System.History`）があり、記法不一致が発生する |
| GitHub | **非適用** | GitHub は標準 Markdown（GFM）をネイティブにレンダリングするため、記法不一致問題が構造的に発生しない |
| HUE ProjectBoard | **非適用** | タスクのタイトル・ステータス等の構造化フィールドを操作するため、記法レンダリングの対象外 |
| Slack | **非適用** | MCP 経由で送信され、Slack 独自の mrkdwn フォーマットは MCP 側で処理される |
| Google Workspace | **非適用** | ファイル操作（作成・コピー）が主でありテキスト記法の投稿は対象外 |
| ailead | **非適用** | 読み取り専用 |

**判断基準**: 投稿先が独自記法を使用し、記法不一致による表示崩れリスクがあるサービスに適用する。Markdown ネイティブなサービスや MCP 経由で記法を自動処理するサービスは非適用。新サービス追加時はこの基準に従い適用要否を判断する。

## 実行フロー

### 1. 入力確定

- 本文・ターゲットを確定する
- ターゲット未指定の単体起動時は `AskUserQuestion` で選択させる

### 2. チェック実行

[references/check-procedures.md](references/check-procedures.md) の手順で 5 カテゴリ全てを検査する（短文でも省略しない）:

| カテゴリ | 内容 | 主な判定 |
|---------|------|---------|
| NOTATION | ターゲット記法と本文構文の整合（Markdown / Backlog 記法の混入検出） | 不一致 = FAIL |
| AUTOLINK | 自動リンク・メンション暴発（`@` / `#` / `!` / 課題キー） | 通知発生・意図不明リンク = WARN |
| STRUCTURE | コードフェンス開閉・表の列数・ネスト崩れ | 崩れ = FAIL |
| SECRET | 機密情報パターン（トークン・キー・パスワード・秘密鍵） | 検出 = FAIL |
| SIZE | 文字数上限・長文 | 超過 = WARN |

### 3. 結果レポート

以下のフォーマットで提示する:

```markdown
## render-check 結果（ターゲット: backlog-notation）

| # | カテゴリ | 判定 | 内容 | 位置 |
|---|---------|------|------|------|
| 1 | NOTATION | FAIL | Markdown 見出し `##` は Backlog 記法では表示されません | 3 行目 |
| 2 | AUTOLINK | WARN | `@yamada` がメンションとして通知されます | 12 行目 |

総合判定: FAIL（投稿不可 — 修正案を提示します）
```

- 総合判定: FAIL（1 件でも FAIL）> WARN（FAIL なし・WARN あり）> PASS
- 投稿プレビュー: 本文をコードブロックで提示し、レンダリング後の見え方（リンク化・通知の発生箇所）を説明する

### 4. 修正提案（FAIL / WARN 時）

- 参照ルールの変換表に基づく **修正済み本文** を提示する
- 採用可否を `AskUserQuestion` で確認し、採用時は修正後本文で **再チェック**（Step 2 へ戻る）
- WARN のみの場合は「このまま投稿 / 修正する」をユーザーが選択できる

### 5. 引き渡し

- 呼び出し元スキル（`backlog` / `azure`）へ: 総合判定 + 確定本文（修正があれば修正後）を返す
- 単体起動時: 結果レポートを提示して終了（投稿は行わない）
- **FAIL のまま「投稿可」として返さない**（修正 or 中止のみ。FAIL 強行の選択肢は提示しない）

## 重要な制約

- FAIL を含む本文を投稿可として扱わない
- チェックの省略・簡略化をしない（短文でも 5 カテゴリ全て実施）
- 機密情報検出時は該当値をマスクして報告する（フル値を会話出力しない。マスク形式: 先頭 4 文字 + `***` + 末尾 4 文字）
- SECRET 検出パターンは既知形式のベストエフォートであり、PASS でも未知形式の機密が残存しうる（プレビュー提示時にユーザー自身の目視確認を促す一文を添える）
- 本文の文意を変える修正をしない（記法変換のみ自動提案。文意に関わる変更は提案にとどめユーザー判断）
- ユーザーに選択を求める場合は `AskUserQuestion` を使用する

## 参照

| 用途 | ファイル |
|-----|---------|
| チェック手順詳細 | [references/check-procedures.md](references/check-procedures.md) |
| Backlog 記法ルール | [../../references/rendering/backlog-notation.md](../../references/rendering/backlog-notation.md) |
| Backlog Markdown ルール | [../../references/rendering/backlog-markdown.md](../../references/rendering/backlog-markdown.md) |
| Azure DevOps ルール | [../../references/rendering/azure-devops-markdown.md](../../references/rendering/azure-devops-markdown.md) |
| 動作例 | [evals/](evals/) |
