# Case 06: ORM モデル定義（言語側実装）→ 言語スキルへルーティング

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「SQLAlchemy の User モデルクラスを models.py に定義して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | Python + SQLAlchemy プロジェクト。依頼は ORM モデルクラス（Python コード）の定義であり、素の SQL / DDL / マイグレーション SQL の作成ではない |

## 期待動作

### 責務境界の判定（本ケースの分岐点）
- 依頼が **ORM モデル定義の言語側実装**（SQLAlchemy モデルクラス = Python コード）であることを認識する
- 責務外表「ORM モデル定義の言語側実装 → 各言語スキル（`coding-typescript` / `coding-csharp` / `coding-python` / `coding-php`）」および起動しないケースに従い、本スキル（`coding-sql`）は担当しないと判断する
- 対象言語（Python）の言語スキル `coding-python` にルーティングする（言語側のモデルクラス実装は言語スキル、ORM の横断知識は SSOT `../../../references/frameworks/orm.md` が担当）

### 本スキルが担当する範囲（対比）
- `coding-sql` が担当するのは素の SQL / DDL・クエリ最適化・マイグレーション SQL・方言固有構文である
- ORM が生成する SQL・DDL の命名や規約を確認する場合は実行フロー step3「ORM 確認」で SSOT `../../../references/frameworks/orm.md` を一次情報源として併用する（この場合も言語側のモデルクラス実装自体は言語スキルの担当）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ルーティング先 | `coding-python`（ORM モデル定義 = Python コードのため） |
| 生成ファイル | 本スキルからのコード変更なし（ルーティングのみ） |
| 標準出力（要約） | ORM モデル定義は言語側実装のため coding-python に委譲する旨。素の SQL / DDL / マイグレーションが必要なら coding-sql が担当する旨を併記 |
| 終了状態 | ルーティング（責務外のため本スキルでは実装しない） |

## 分岐の根拠

このケースが分岐するトリガーは 依頼対象 = ORM モデルの言語側実装（SQLAlchemy モデルクラス）である ことである。
責務外表「ORM モデル定義の言語側実装 → 各言語スキル」と起動しないケース「ORM モデル定義の言語側実装（→ 該当する言語スキル）」に従う。素の SQL / DDL を coding-sql が担当する case-01 とは担当が分かれる。

## 関連ケース

- [case-01_standalone-basic.md](case-01_standalone-basic.md)（素の SQL を coding-sql が担当する基本フローとの対比）
- [case-02_scope-escalation.md](case-02_scope-escalation.md)（スキーマ全体設計に波及する場合の orchestrator-coding 切替提案）
