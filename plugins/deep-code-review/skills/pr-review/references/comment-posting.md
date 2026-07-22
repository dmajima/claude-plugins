# Step 7: PR への範囲指定コメント追記（詳細実装）

`pr-review` スキル Step 7 の詳細実装。レビュー指摘ごとに該当範囲を指定しインラインコメントを追加する。

> **位置付け**: 旧 SKILL.md Step 7 / 7.5 / 7.6 から分離した詳細実装。SKILL.md 本体には要点のみ残し、詳細手順は本ファイル群に集約。

> **本ファイルは索引（薄い親）**: Step 7 の概要とセクションマップのみ保持。各セクション詳細は以下 2 サブファイルにある（外部からの `comment-posting.md セクション 7.x` 参照は本ファイルのセクションマップで解決）。
>
> - [`comment-posting-inline.md`](comment-posting-inline.md) — インラインコメント投稿（セクション 7.0〜7.4）
> - [`comment-posting-summary.md`](comment-posting-summary.md) — サマリースレッド投稿・投稿順序・署名（セクション 7.5〜7.7）

### 投稿の自動実行（MANDATORY）

> **SSOT**: `${CLAUDE_SKILL_DIR}/SKILL.md` の「code-review 結果返却後の自動進行（MANDATORY）」。本ファイルは Step 7 詳細手順としての再掲。

Step 7 の PR コメント投稿は、code-review 結果受領直後に **自動で** 実行する。ユーザーの「投稿」「実行」等の明示指示を待たない。

PR コメント投稿は pr-review フローの不可分な一部であり、レビュー実施 → 結果投稿 → 完了報告 が一連の自動フローとして完結する。

---

## セクションマップ

全セクション識別子（`7.x` / `7.x.y`）を保持。各行「詳細」列のサブファイルに本文がある。

| セクション | 詳細サブファイル |
|---|---|
| **7.0** PR コメント本文の Finding ID 表示（必須） | [inline](comment-posting-inline.md#70-pr-コメント本文の-finding-id-表示必須) |
| **7.0.1** インラインコメント本文の冒頭フォーマット | [inline](comment-posting-inline.md#701-インラインコメント本文の冒頭フォーマット) |
| **7.0.2** サマリースレッドの目次 | [inline](comment-posting-inline.md#702-サマリースレッドの目次) |
| **7.0.3** ID と PR コメントの紐付け | [inline](comment-posting-inline.md#703-id-と-pr-コメントの紐付け) |
| **7.0.4** サマリースレッドの ID リンク URL（必須形式） | [inline](comment-posting-inline.md#704-サマリースレッドの-id-リンク-url必須形式) |
| **7.1** GitHub のインラインコメント（connector:github 委譲） | [inline](comment-posting-inline.md#71-github-のインラインコメントconnectorgithub-委譲) |
| **7.1.1** インラインコメント投稿（connector 委譲） | [inline](comment-posting-inline.md#711-インラインコメント投稿connector-委譲) |
| **7.1.2** Pending Review 一括投稿（connector 委譲） | [inline](comment-posting-inline.md#712-pending-review-一括投稿connector-委譲) |
| **7.1.3** PR 全体コメント投稿（connector 委譲） | [inline](comment-posting-inline.md#713-pr-全体コメント投稿connector-委譲) |
| **7.1.4** スレッド resolve（connector 委譲） | [inline](comment-posting-inline.md#714-スレッド-resolveconnector-委譲) |
| **7.1.5** 既存コメントへの返信（connector 委譲） | [inline](comment-posting-inline.md#715-既存コメントへの返信connector-委譲) |
| **7.2** Azure DevOps のインラインコメント（connector:azure 委譲） | [inline](comment-posting-inline.md#72-azure-devops-のインラインコメントconnectorazure-委譲) |
| **7.2.1** インラインコメント投稿（connector 委譲） | [inline](comment-posting-inline.md#721-インラインコメント投稿connector-委譲) |
| **7.2.2** サマリースレッド投稿（connector 委譲） | [inline](comment-posting-inline.md#722-サマリースレッド投稿connector-委譲) |
| **7.2.3** 既存スレッドへの返信（connector 委譲） | [inline](comment-posting-inline.md#723-既存スレッドへの返信connector-委譲) |
| **7.2.4** スレッドステータス変更（connector 委譲） | [inline](comment-posting-inline.md#724-スレッドステータス変更connector-委譲) |
| **7.3** コメント本文のサニタイズ（必須） | [inline](comment-posting-inline.md#73-コメント本文のサニタイズ必須) |
| **7.4** HTTP ステータス分岐とレート制限・エラー時のロールバック | [inline](comment-posting-inline.md#74-http-ステータス分岐とレート制限エラー時のロールバック) |
| **7.5** サマリースレッドの仕様（必須・統一フォーマット） | [summary](comment-posting-summary.md#75-サマリースレッドの仕様必須統一フォーマット) |
| **7.5.0** 投稿方式の必須原則（新規スレッド限定・最終投稿位置・必須） | [summary](comment-posting-summary.md#750-投稿方式の必須原則新規スレッド限定最終投稿位置必須) |
| **7.5.1** 必須レイアウト（テンプレート準拠） | [summary](comment-posting-summary.md#751-必須レイアウトテンプレート準拠) |
| **7.5.2** ヘッダブロックの必須項目 | [summary](comment-posting-summary.md#752-ヘッダブロックの必須項目) |
| **7.5.3** レビュー結果の判定ルール | [summary](comment-posting-summary.md#753-レビュー結果の判定ルール) |
| **7.5.4** 既存指摘の解消判定との関係（再レビュー時） | [summary](comment-posting-summary.md#754-既存指摘の解消判定との関係再レビュー時) |
| **7.5.5** 旧サマリーの扱い | [summary](comment-posting-summary.md#755-旧サマリーの扱い) |
| **7.5.5.1** auto-resolve=false / MD 出力モード時の旧サマリー扱い（必須） | [summary](comment-posting-summary.md#7551-auto-resolvefalse--md-出力モード時の旧サマリー扱い必須) |
| **7.5.6** 複数 active サマリーが残った場合の収束手順 | [summary](comment-posting-summary.md#756-複数-active-サマリーが残った場合の収束手順) |
| **7.5.7** 投稿前の必須チェックリスト | [summary](comment-posting-summary.md#757-投稿前の必須チェックリスト) |
| **7.6** 投稿順序（必須） | [summary](comment-posting-summary.md#76-投稿順序必須) |
| **7.7** 署名（connector 自動付加・pr-review は関与しない） | [summary](comment-posting-summary.md#77-署名connector-自動付加pr-review-は関与しない) |

---

## 関連リファレンス

- `comment-templates.md` — コメントテンプレート定義（署名・インライン冒頭フォーマット・組み立てフロー）
- `azure-devops-tfs-ntlm.md` — TFS NTLM での REST API 詳細
- `azure-devops-cloud.md` — クラウド ADO の az 経路
- `github.md` — GitHub PR 操作の詳細
- `comment-status.md` — Bot 識別子付き返信の必須要件（Step 7 の reply 投稿時）
