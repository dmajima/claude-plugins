# 実行手順詳細

`skill-toolkit` の詳細実行手順。

## モード判定

### 入力

ユーザの発話・引数・既存ファイル状態。

### 判定ルール

| 条件 | モード |
|-----|-------|
| 引数のスキル名がプラグイン内に既存（`SKILL.md` あり） | 既存改修 |
| 引数のスキル名が既存しない | 新規作成 |
| ユーザが「更新」「改修」「機能追加」と明示 | 既存改修（既存スキル特定が前提） |

## 新規生成手順

### 1. パラメータ確定

| パラメータ | 必須 | 例 | 確認方法 |
|----------|------|---|---------|
| スキル名（kebab-case） | 必須 | `code-formatter` | 引数 or 対話 |
| 1 行説明（主目的） | 必須 | `コード整形を支援する` | 引数 or 対話 |
| 主なトリガーフレーズ | 必須（3 つ以上） | `「コード整形して」` | 引数 or 対話 |
| 配置先 | 必須 | スタンドアロン or 既存プラグイン名 | 引数 or 対話 |
| Python 利用 | 任意 | true / false | 引数 or デフォルト false |
| 外部依存スキル | 任意 | example-skills 等 | 引数 or デフォルトなし |
| 動作分岐の有無 | 任意 | true / false | 引数 or デフォルト true |

### 2. 配置先決定

| 配置先 | 配置パス |
|-------|---------|
| スタンドアロン（ユーザのスキル領域） | `<repo>/.claude/skills/{skill-name}/` または `~/.claude/skills/{skill-name}/` |
| 既存プラグイン内 | `plugins/{plugin-name}/skills/{skill-name}/` |

既存プラグインに配置する場合、外形が未存在なら `plugin-toolkit` を先に呼ぶようユーザに案内する。

### 3. テンプレートコピー

`${CLAUDE_PLUGIN_ROOT}/references/templates/skill/` を配置先にコピーする。コピー対象:

```text
SKILL.md
README.md
references/procedures.md
references/setup.md          ← Python 利用時のみ（依存リスト + environment-setup-toolkit への委譲記述）
evals/README.md              ← 動作分岐ありの時のみ
evals/case-template.md       ← 動作分岐ありの時のみ
```

スキル固有の実行スクリプトが必要な場合は `references/scripts/{業務単位}/` に配置する（ADR-025）。スキル直下に `scripts/` ディレクトリを作成してはならない。

**venv 構築・撤去スクリプト・依存リスト（requirements.txt）はスキル内に置かない**（ADR-024）。プラグイン直下 `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/` に集約され、新規依存はその `requirements.txt` に追加する。

### 4. プレースホルダ置換

| プレースホルダ | 置換値 |
|--------------|-------|
| `{skill-name}` | スキル名 |
| `{Skill Title}` | タイトルケースの表示名 |
| `{主目的の 1 文}` | 1 行説明 |
| `{トリガーフレーズ例 N}` | 主なトリガーフレーズ |
| `{english trigger condition}` | 英語のトリガー条件 |
| `{related-skill}` `{他スキル名}` | 関連スキル名 |

### 5. references の充実化

スキル固有の詳細を `references/` に追加する。最低限以下:

- `procedures.md` — 詳細手順（必須）
- `setup.md` — 環境構築（Python 利用時のみ）
- `rules.md` — 詳細ルール（複雑なロジックがある時のみ）
- `template/` — スキルが生成するテンプレート（テンプレート出力スキルのみ）

### 6. evals 作成（動作分岐ありの時）

`evals/case-template.md` をベースに、各分岐ケースを 1 ファイル 1 ケースで作成する。詳細は [`../../../references/eval-guide.md`](../../../references/eval-guide.md) を参照。

最低カバレッジ:

- 対話モード × 主要分岐
- 非対話モード × 主要分岐
- 既知のエラー系（ある場合）

### 7. 検証

`SKILL.md` の「実行フロー」 → 「6. 検証」に列挙した項目を全て確認する。

## 既存改修手順

### 1. 改修対象の特定

ユーザの指定からスキルディレクトリを Glob で検索し特定する。複数候補がある場合は対話で確認する。

### 2. 差分内容の整理

| 改修種別 | 動作 |
|---------|------|
| 機能追加 | references に新ファイル追加、SKILL.md にエントリ追加 |
| ロジック変更 | 該当 references の該当セクションを編集 |
| リネーム・分割 | 既存ファイル分割、参照更新 |
| 動作分岐の追加 | evals に新ケース追加 |

### 3. SKILL.md 200 行制約の維持

改修により SKILL.md が 200 行を超える見込みなら、詳細を `references/{topic}.md` に分離する。

### 4. 既存ファイル編集時の注意

- エンコーディング・改行コード維持（`~/.claude/rules/common/file-encoding.md`）
- 既存 frontmatter の `name` を変えない（変える場合はディレクトリ名と同期）
- 既存の `references/` 構造を尊重し、勝手に再構成しない

### 5. evals の同期

ロジックを変更した場合、対応する `evals/case-*.md` を必ず更新する。

### 6. 検証

新規生成と同じチェックリストを適用する。

## 失敗時のリカバリ

| 失敗 | リカバリ |
|-----|---------|
| プレースホルダ置換漏れ | `{` 残存を Grep し再置換 |
| パスポータビリティ NG 検出 | 該当箇所を `${CLAUDE_SKILL_DIR}` 等に置換 |
| 200 行超過 | `references/{topic}.md` に分離 |
| 必須セクション欠落 | テンプレートと比較し追加 |
