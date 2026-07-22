# コメント本文のサニタイズ（プラグイン共通）

`deep-code-review` プラグイン内で **PR / Issue / 外部資料 等にコメントを投稿する際** に共通で適用するサニタイズ規則。XSS・トラッキング画像・リンク偽装・機密文字列の意図しない混入を防ぐ。

> **位置付け**: `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md`（プラグイン直下 references）に配置。各スキルから参照される。スキル個別の references 配下に同じ対策を重複実装してはならない。

> **本ファイルの構成（分割）**: 本体は 300 行超のため、詳細を 2 つのサブファイルへ分割し、本ファイルは索引（セクションマップ）＋適用契約＋禁止事項を保持する。外部からの `comment-sanitization.md セクション N` 参照は、下記セクションマップに全識別子を保持しているため引き続き解決できる。
> - [`comment-sanitization-patterns.md`](comment-sanitization-patterns.md) — セクション 1〜4（適用範囲・脅威モデル・必須対策・具体的なサニタイズ実装）
> - [`comment-sanitization-escaping.md`](comment-sanitization-escaping.md) — セクション 5〜5.6（注意事項・ホスト固有の予約文字エスケープ・投稿前チェックリスト）

---

## セクションマップ

外部参照（`comment-sanitization.md セクション 3-4` `セクション 5.6` 等）の解決に用いる全セクション識別子の一覧。適用順は「機密伏字化（セクション 3〜4）→ 予約文字エスケープ（セクション 5.5）→ 投稿前チェックリスト（セクション 5.6）」。

| セクション | 概要 | 収録先 |
|---|---|---|
| 1. 適用範囲 | サニタイズを適用するスキル・操作の範囲 | [patterns](comment-sanitization-patterns.md) |
| 2. 脅威モデル | XSS / トラッキング画像 / リンク偽装 / 機密漏洩の 4 脅威 | [patterns](comment-sanitization-patterns.md) |
| 3. 必須対策 | コードフェンス必須・`<img>` 削除・危険スキームリンク削除・機密伏字化 | [patterns](comment-sanitization-patterns.md) |
| 4. 具体的なサニタイズ実装（sed パターン） | 機密文字列伏字化の sed 実装とパターン対応表 | [patterns](comment-sanitization-patterns.md) |
| 5. 注意事項 | sed 実装の前提・オープンセット運用・HTML エンティティ対策 | [escaping](comment-sanitization-escaping.md) |
| 5.5 ホスト固有の予約文字エスケープ（厳守） | `#`/`@`/`!` 等の自動リンク化を防ぐエスケープ規則 | [escaping](comment-sanitization-escaping.md) |
| 5.5.1 自動リンク化の対象パターン | Azure DevOps / GitHub の自動リンク化対象一覧 | [escaping](comment-sanitization-escaping.md) |
| 5.5.2 エスケープ規則（必須） | 意図的リンク／意図しない予約文字の扱い | [escaping](comment-sanitization-escaping.md) |
| 5.5.3 実装パターン: 自動リンク変換と保護プレースホルダ | Markdown リンク退避＋予約文字エスケープの実装 | [escaping](comment-sanitization-escaping.md) |
| 5.5.4 既知の例外と制限 | コードフェンス例外・入れ子角括弧・URL 内閉じ括弧の制限 | [escaping](comment-sanitization-escaping.md) |
| 5.5.5 適用タイミング | サニタイズパターン（セクション 3-4）との連続適用順序 | [escaping](comment-sanitization-escaping.md) |
| 5.5.6 OK / NG 例 | 自動リンク化の OK / NG 具体例 | [escaping](comment-sanitization-escaping.md) |
| 5.5.7 HTML ブロック（`<details>` 内）における特殊文字の取り扱い | HTML 文脈でのエスケープ要否・`<`/`>`/`&` の扱い | [escaping](comment-sanitization-escaping.md) |
| 5.6 投稿前チェックリスト（必須） | 投稿直前に通過必須のチェックリスト群 | [escaping](comment-sanitization-escaping.md) |
| 5.6.0 チェックリストの実行タイミング（必須） | 生成後／JSON 構築前／投稿前の 3 段階 | [escaping](comment-sanitization-escaping.md) |
| 5.6.0.1 呼び出し元スキルでの参照義務 | SKILL.md Step 7 への実行必須記載義務 | [escaping](comment-sanitization-escaping.md) |
| 5.6.1 サニタイズチェックリスト | S1〜S9 のサニタイズ確認項目 | [escaping](comment-sanitization-escaping.md) |
| 5.6.2 コード引用チェックリスト | C1〜C6 のコード引用確認項目 | [escaping](comment-sanitization-escaping.md) |
| 5.6.3 投稿先指定チェックリスト | P1〜P4 の投稿先確認項目 | [escaping](comment-sanitization-escaping.md) |
| 5.6.4 自動チェックの実装案（任意） | 投稿前サニタイズ違反の簡易ガード実装 | [escaping](comment-sanitization-escaping.md) |
| 6. 適用契約 | 本ファイルの位置付けと参照方向 | 本ファイル（下記） |
| 7. 禁止事項 | 無加工転載・検出失敗時の投稿・個別再実装の禁止 | 本ファイル（下記） |

---

## 6. 適用契約

本ファイルは **プラグイン共通のコメント本文サニタイズ規則** を規定する。
PR / Issue / 外部資料等にコメントを投稿する個別スキルは、本ファイルの規定（コードフェンス必須・`<img>` 削除・危険スキームリンク剥離・機密文字列伏字化）に準拠を宣言したうえで利用すること。

依存方向（共通 references から個別スキルへの参照を持たない一方向）の SSOT は同ディレクトリ `CLAUDE.md`「原則」。

---

## 7. 禁止事項

- 取得した外部資料・コミットメッセージ・コード断片を **無加工で** PR コメントに転載すること
- 機密文字列パターンの検出に失敗した場合に「とりあえずそのまま投稿する」運用
- 本ファイルの規則を各スキル個別に再実装・上書きすること（共通化の意義が失われる）
