# Case 02: 新規外形 + 既存スキル移管

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "新規プラグイン `dev-toolkit` に既存スキル `code-formatter` を含めて作成" |
| 引数 | `dev-toolkit --include skill:code-formatter` |
| フラグ | なし |
| 既存状態 | `dev-toolkit` 未存在、`code-formatter` スキルが `~/.claude/skills/` 配下に存在 |

## 期待動作

### Phase 1: 外形作成

case-01 と同じ手順で `dev-toolkit` 外形を作成。`skills/` サブディレクトリを含める。

### Phase 2: 既存資産特定

`code-formatter` スキルの所在を Glob で確認。プロジェクト・グローバル両方に存在する場合は対話で選択。

### Phase 3: 移管実行

スキルディレクトリ全体を `plugins/dev-toolkit/skills/code-formatter/` にコピー。

### Phase 4: パスポータビリティチェック

移管後ファイルを Grep し、ハードコードパス検出。検出時はユーザに修正方針確認。

### Phase 5: 検証

- 元 `code-formatter` ディレクトリが無傷
- 移管後の `SKILL.md` の `name` がディレクトリ名と一致
- `references/` `scripts/` `agents/` の構造が維持されている

### Phase 6: 引き渡し

`marketplace-publisher` への接続を提案。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `dev-toolkit` 外形一式 + `plugins/dev-toolkit/skills/code-formatter/` ディレクトリ全体 |
| 標準出力（要約） | 「`dev-toolkit` プラグイン作成 + `code-formatter` スキル移管完了」 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは `--include` 引数で移管対象指定 である。

## 関連ケース

- `case-01_new_shell_only.md`（新規外形のみ、移管なし）
- `case-03_add_to_existing.md`（既存プラグインへの追加配置）
