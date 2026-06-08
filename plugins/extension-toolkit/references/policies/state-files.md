# 状態ファイル形式ルール（SSOT）

スキル・プラグインが生成・管理する状態ファイル（メタデータ・進捗・設定・キャッシュ等）の形式を選択するルール。**Markdown に固執せず、適した形式を選ぶ**。

## 1. 形式選択の基準

| 用途 | 推奨形式 | 理由 |
|-----|---------|------|
| プログラム読み書き主体（人間も時々読む） | JSON | パース容易・型保持 |
| 人間編集主体（コメント可） | YAML | 人間可読・コメント可 |
| 構造化データ + 表 + 説明文 | Markdown | 表現力高・人間最優先 |
| 大量データ（行指向） | JSONL / CSV / TSV | ストリーミング処理 |
| 設定・スキーマ厳格 | JSON Schema 付き JSON | バリデーション可 |
| ログ | JSONL | 追記容易・パース可 |

## 2. 形式別の用途マッピング

### 2.1 JSON

| 用途 | ファイル例 |
|-----|----------|
| プラグインメタデータ | `plugin.json` |
| マーケットプレイス定義 | `marketplace.json` |
| フック設定 | `hooks/hooks.json` |
| 構造化キャッシュ | `cache/{name}.json` |
| API レスポンスのスキャッフォルド | `data/{name}.json` |
| 状態スナップショット | `state/snapshot.json` |

### 2.2 YAML

| 用途 | ファイル例 |
|-----|----------|
| 人間が編集する設定 | `config.yaml` |
| マニフェスト | `manifest.yaml` |
| パイプライン定義 | `pipeline.yaml` |
| エージェントチーム定義（YAML 化を選ぶ場合の例。本プラグインは MD で運用中） | `references/teams/{name}.yaml`（任意・将来選択肢） |

### 2.3 Markdown

| 用途 | ファイル例 |
|-----|----------|
| ドキュメント全般 | `*.md` |
| 進捗管理（人間とAIが共同編集） | `progress.md` |
| 議事録・レビュー結果 | `review.md` |
| 規約・ガイドライン | `references/*.md` |

### 2.4 JSONL（JSON Lines）

| 用途 | ファイル例 |
|-----|----------|
| イベントログ | `logs/events.jsonl` |
| 会話履歴 | `history/{date}.jsonl` |
| 大量レコード | `data/{name}.jsonl` |

### 2.5 CSV / TSV

| 用途 | ファイル例 |
|-----|----------|
| 表形式データ（人間が表計算で扱う） | `data/{name}.csv` |
| 複数フィールドの単純データ | `dataset.tsv` |

## 3. 形式選択の判断フロー

```
状態を保存したい
  ├─ 主にプログラムが読み書きする？
  │   ├─ Yes → 構造が複雑？
  │   │   ├─ Yes → JSON or YAML（コメント要なら YAML）
  │   │   └─ No  → JSON
  │   └─ No → 主に人間が読む？
  │       ├─ 編集も人間 → Markdown or YAML
  │       └─ 読むだけ → Markdown
  │
  ├─ 大量レコードを追記する？
  │   └─ Yes → JSONL or CSV/TSV
  │
  └─ ログ？
      └─ Yes → JSONL
```

## 4. 命名規則

| 拡張子 | 推奨ファイル名 |
|-------|------------|
| `.json` | kebab-case（例: `plugin.json`、`marketplace.json`） |
| `.yaml` / `.yml` | kebab-case、両拡張子可（プロジェクト統一推奨） |
| `.md` | kebab-case、用途ベース（例: `procedures.md`、`progress.md`） |
| `.jsonl` | kebab-case + 日付（例: `events-2026-04.jsonl`） |
| `.csv` / `.tsv` | kebab-case + データ名（例: `users.csv`） |

## 5. アンチパターン

| パターン | 問題 | 代替 |
|---------|------|------|
| 構造化データを Markdown 表で保存 | プログラムでパースしにくい、表が崩れやすい | JSON / YAML |
| 大量データを JSON 1 ファイルに | 読み書きが重い、追記不可 | JSONL |
| 設定にコメントが必要なのに JSON | コメント書けない | YAML（コメント可） |
| 人間が編集する設定に JSON | カンマ・引用符のミス頻発 | YAML |
| 進捗管理を JSON で | 自然文の追記が難しい | Markdown |

## 6. エンコーディング・改行コード

| 形式 | 推奨エンコーディング | 改行コード |
|-----|------------------|----------|
| JSON | UTF-8（BOM なし） | LF（Unix）or CRLF（Windows プロジェクト規約に従う） |
| YAML | UTF-8（BOM なし） | LF |
| Markdown | UTF-8（BOM なし） | LF or CRLF（プロジェクト規約） |
| JSONL | UTF-8（BOM なし） | LF |
| CSV | UTF-8 with BOM（Excel 互換）or UTF-8 | CRLF（Excel 互換）or LF |

既存ファイルを更新する場合は **元ファイルのエンコーディング・改行コードを維持** する（`~/.claude/rules/common/file-encoding.md` 参照）。

## 7. JSON / YAML のスキーマ管理

複雑な構造を持つ JSON / YAML には JSON Schema を併設することを推奨:

```
config/
├── settings.yaml
└── settings.schema.json    # JSON Schema
```

スキーマがあると:
- バリデーション可能
- IDE 補完対応
- 仕様の明示

## 8. 既存ファイルとの整合

| 既存形式 | 新規追加時の方針 |
|---------|---------------|
| `plugin.json` (JSON) | プラグインメタデータは JSON 維持 |
| `marketplace.json` (JSON) | マーケットプレイス定義は JSON 維持 |
| `progress.md` (Markdown) | 進捗管理は Markdown 維持 |
| `SKILL.md` / `README.md` (Markdown) | ドキュメントは Markdown 維持 |

新たな状態ファイルを追加する際、既存ファイルと同じ用途なら同じ形式に揃える。

## 9. 例: スキル状態の保存

スキルが何かの状態をローカルに保存する場合（`~/.claude/.local/{category}/{name}/`）:

```
.claude/.local/skills/{skill-name}/
├── state.json              # プログラム読み書き用
├── settings.yaml           # 人間が編集する設定
├── cache.jsonl             # 大量データ・追記
└── notes.md                # 人間用メモ
```

用途を分けて適切な形式を選ぶ。

## 9.5 既存 Markdown 状態ファイルの移行ガイド

既存スキル/プラグインで状態ファイルを Markdown に格納している場合、本ルールに従って適切な形式に移行する。

### 移行判断フロー

```
既存 Markdown 状態ファイル
  ├─ 主にプログラムが読む？
  │   ├─ Yes → JSON / YAML に移行
  │   └─ No  → そのまま Markdown でよい
  │
  ├─ 表形式データだけで自然文ほぼなし？
  │   └─ Yes → CSV / TSV / JSON 配列 に移行
  │
  └─ 大量レコードを追記？
      └─ Yes → JSONL に移行
```

### 移行手順

| ステップ | 内容 |
|---------|------|
| 1 | 移行先形式の選択（節 1〜2 の判定基準を参照） |
| 2 | 旧 Markdown ファイルを `inputs/` 等にバックアップ |
| 3 | スクリプト or 手動でデータを変換（既存表形式 → JSON/YAML） |
| 4 | 旧 Markdown を削除し、新ファイルに参照を切り替える |
| 5 | スキル/プラグインのドキュメントから旧ファイル参照を撤去 |
| 6 | エンコーディング・改行コード維持を確認（`~/.claude/rules/common/file-encoding.md`） |

### 移行例

```text
# Before
state.md（Markdown 表で 100 件のレコードを管理）

# After
state.json（プログラム読み書き用、構造保持）
state-history.jsonl（追記ログ、必要時のみ）
```

### 移行を急がない場合

人間の編集頻度が高く・件数が少ない（< 50 件）状態ファイルは、Markdown のまま維持してよい。形式選択の判断は **保守コストと表現力** のバランスで決める。

## 10. 禁止事項

- 構造化データを Markdown 表で長期保存すること
- 設定ファイルにバージョン情報を JSON で書きながら、別ファイルにも YAML で重複記載すること
- 大量データを単一の Markdown ファイルに格納すること
- 形式を選定せず慣習だけで Markdown を使うこと
