# README.md 対象チェックリスト

`README.md`（プラグイン直下またはスキル直下）を対象とするチェック項目。`common.md` の項目と併用すること。

> **ファイル名注記**: 本来 `readme.md` としたいが、本ディレクトリの索引である `README.md`（大文字）と Windows のケース非依存ファイルシステムで衝突するため、`readme-doc.md` として配置している。索引（[`README.md`](README.md)）の節 2「適用するチェックリスト」の `readme.md` は本ファイルを指す。

## R-1. 必須化と冒頭セクション

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| R-1-1 | Critical | プラグイン直下 / スキル直下に `README.md` が存在する | [readme-policy.md](../../../references/readme-policy.md) 節 1 |
| R-1-2 | High | 冒頭にタイトル（プラグイン名 / スキル名）+ 概要（1〜3 文）が配置されている | 同 節 3 |
| R-1-3 | High | 「## このドキュメントについて」セクションが存在し、「人間向けリファレンス・Claude 動作で不参照」が明記されている | 同 節 4 |

## R-2. 「導入手順」セクション（プラグイン README 必須 4 要素・ADR-018）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| R-2-1 | High | (A) マーケットプレイス経由インストール手順（`/plugin marketplace add` + `/plugin install`）が記載されている | [readme-policy.md](../../../references/readme-policy.md) 節 5.1 / ADR-018 |
| R-2-2 | High | (B) ローカル複製インストール手順（`git clone` + `/plugin marketplace add <local-path>`）が記載されている | 同上 |
| R-2-3 | High | (C) 自動更新の有効化方法（`extraKnownMarketplaces` の `autoUpdate: true` 設定例）が記載されている | 同上 |
| R-2-4 | High | (D) 依存関係セクションが存在する（依存なしの場合も「依存関係なし」と明示する。セクション省略は不可） | 同上 |
| R-2-5 | Medium | 自動インストール不成立時の個別インストール手順が依存プラグインごとに明示されている | 同上 |
| R-2-6 | Medium | Python 等の外部ツール依存が「動作要件」に明記されている | 同 節 5.1 |
| R-2-7 | High | クロスマーケットプレイス依存（`plugin.json` の `dependencies` 配列に **自プラグインの所属マーケ名と異なる** `marketplace` フィールド値を含むエントリが 1 件以上）の場合、D セクションに D-1（依存マーケ `/plugin marketplace add`）/ D-2（依存マーケの `extraKnownMarketplaces` 登録 JSON）/ D-3（依存プラグイン `/plugin install`）の 3 ブロックが揃っている | [readme-policy.md](../../../references/readme-policy.md) 節 5.1 D / ADR-028 |

## R-3. 利用方法

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| R-3-1 | High | 「## 利用方法」セクションが存在し、最小例（ユーザ発話 → Claude 応答の要約）が記載されている | [readme-policy.md](../../../references/readme-policy.md) 節 6.1 |
| R-3-2 | Medium | 応用例が表形式で記載されている（任意） | 同 節 6.2 |

## R-4. 技術スタック・アーキテクチャ（後半配置）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| R-4-1 | Medium | 技術スタック・アーキテクチャは **README の後半（セクション 11 付近）** に配置されている（冒頭ではない） | [readme-policy.md](../../../references/readme-policy.md) 節 7 |

## R-5. 過去履歴・変更経緯の記載禁止（ADR-016）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| R-5-1 | Medium | 「## 変更履歴」「## Changelog」「## Release Notes」等のセクションが含まれない | [readme-policy.md](../../../references/readme-policy.md) 節 8 / ADR-016 |
| R-5-2 | Medium | 「v0.1 で追加」「v0.2 で変更」等のバージョン履歴記述がない | 同上 |
| R-5-3 | Medium | 「以前は」「廃止予定」「当初は」「改訂時点で」等の時系列記述がない | 同上 |

## R-6. 装飾・装飾記号

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| R-6-1 | Medium | 絵文字が含まれない（ユーザ明示指示なき限り） | [readme-policy.md](../../../references/readme-policy.md) 節 9 |
| R-6-2 | Medium | 見出しレベルが h1（タイトル）→ h2 → h3 までで、h4 以下が使われていない | 同上 |

## R-7. ファイル構成と整合

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| R-7-1 | High | 「## ファイル構成」セクションのディレクトリツリーが実構成と一致している | [validation-rules.md](../../../references/validation-rules.md) 節 2.7 |
| R-7-2 | High | プレースホルダ（`{...}` 等）が残存していない | 同上 |

## R-8. 一方向参照の原則

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| R-8-1 | Medium | `SKILL.md` / `references/` 配下から `README.md` を参照していない（一方向参照、README は読み物） | [readme-policy.md](../../../references/readme-policy.md) 節 11 |

## R-9. マーケットプレイス README 同期（マーケットプレイス README の場合）

詳細は [marketplace.md](marketplace.md) を参照。

## R-10. 検証フロー

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| R-10-1 | High | パスポータビリティ（`common.md` C-2 系）合格 | [common.md](common.md) C-2 |
| R-10-2 | High | プレースホルダ残存なし（`common.md` C-5 系）合格 | [common.md](common.md) C-5 |
| R-10-3 | High | 自己完結性（`common.md` C-9 系）合格 | [common.md](common.md) C-9 |
