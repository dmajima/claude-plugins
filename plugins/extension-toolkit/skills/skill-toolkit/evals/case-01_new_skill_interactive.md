# Case 01: 新規スキル作成（対話モード）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "新しいスキル `code-formatter` を作って" |
| 引数 | `code-formatter`（スキル名のみ） |
| フラグ | なし |
| 既存状態 | `code-formatter` スキルが未存在 |

## 期待動作

### Phase 1: パラメータ確認

ユーザに以下を順次確認:

- 1 行説明（主目的）
- 主なトリガーフレーズ（3 つ以上）
- 配置先（スタンドアロン or 既存プラグイン名）
- Python 利用の有無
- 外部依存スキル利用の有無
- 動作分岐の有無

### Phase 2: テンプレート展開

`${CLAUDE_PLUGIN_ROOT}/references/templates/skill/` を配置先にコピーし、プレースホルダを置換。

### Phase 3: 検証

- SKILL.md 200 行以内
- name とディレクトリ名一致
- パスポータビリティ合格

### Phase 4: 引き渡し

生成ファイル一覧を提示し、`extension-reviewer` への接続を提案。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `{配置先}/{skill-name}/SKILL.md` `README.md` `references/procedures.md` |
| 標準出力（要約） | 「`code-formatter` スキルを作成しました（{配置先}）」+ 次のステップ案内 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは引数 = スキル名のみ・フラグなし である。非対話モードフラグなしのため、対話で不足を確認する。

## 関連ケース

- `case-02_new_skill_non_interactive.md`（同じ新規だが非対話）
- `case-03_existing_skill_update.md`（既存スキルが対象）
