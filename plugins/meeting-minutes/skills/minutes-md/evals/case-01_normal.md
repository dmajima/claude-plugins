# Case 01: 正常な Markdown 生成

## 入力

| 項目 | 値 |
|-----|---|
| 起動条件 | `minutes-composer` + `minutes-reviewer` の完了後に起動される |
| 前提ファイル | `workspace/minutes.json`（`references/schema/minutes-schema.md` に準拠した有効な JSON） |
| venv 状態 | プラグイン共有の `references/scripts/setup/requirements.txt` で構築済み |

## 期待動作

1. `workspace/minutes.json` の存在を確認する
2. venv が構築済みであることを確認する（未構築の場合は `setup_venv.sh` で構築する）
3. Python スクリプト `${CLAUDE_SKILL_DIR}/scripts/output/generate_md.py` を venv 経由で実行する:
   ```
   & $venvPy generate_md.py --input workspace/minutes.json --output $SESSION_DIR/minutes.md
   ```
4. `minutes-composer/references/template/minutes-template.md` と同一のフォーマットで Markdown を生成する
5. 生成された `minutes.md` をセッション直下（成果物領域）に配置する
6. ユーザーに生成完了を報告し、ファイルパスを提示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `$SESSION_DIR/minutes.md` | 会議タイトル・参加者・日時・議事内容・決定事項・アクションアイテム・次回予定を含む Markdown ファイル |
| Markdown 構造 | 見出し階層（`#` 会議タイトル、`##` セクション見出し）、箇条書き、表形式のメタデータ |
| 文字コード | UTF-8（BOM なし） |
| 終了状態 | 成功 |

## 分岐の根拠

SKILL.md「実行フロー」ステップ1-3の正常パス: 「minutes.json を workspace/ から読み込む → Python スクリプトを実行する → 生成された minutes.md をセッション直下に配置する」。`references/procedures.md` ステップ2の正常実行パス。

## 関連ケース

- `case-02_missing_input.md`（minutes.json が存在しない場合のエラーパス）
