# Case 01: 正常な docx 生成

## 入力

| 項目 | 値 |
|-----|---|
| 起動条件 | `minutes-composer` + `minutes-reviewer` の完了後に起動される |
| 前提ファイル | `workspace/minutes.json`（`references/schema/minutes-schema.md` に準拠した有効な JSON） |
| テンプレート | `${CLAUDE_SKILL_DIR}/assets/template/minutes-template.docx`（同梱テンプレート） |
| venv 状態 | プラグイン共有の `references/scripts/setup/requirements.txt` で構築済み（`python-docx` を含む） |

## 期待動作

1. `workspace/minutes.json` の存在を確認する
2. venv が構築済みであることを確認する（未構築の場合は `setup_venv.sh` で構築する）
3. 同梱テンプレート `assets/template/minutes-template.docx` の存在を確認する
4. Python スクリプト `${CLAUDE_SKILL_DIR}/scripts/output/generate_docx.py` を venv 経由で実行する:
   ```
   & $venvPy generate_docx.py --input workspace/minutes.json --template <template-path> --output $SESSION_DIR/minutes.docx
   ```
5. テンプレートのスタイル定義（Title: Meiryo/18pt、Heading 1: Meiryo/14pt 等）に従って Word ファイルを生成する
6. 生成された `minutes.docx` をセッション直下（成果物領域）に配置する
7. ユーザーに生成完了を報告し、ファイルパスを提示する

**python-docx ハング対策**: Windows + PowerShell 環境では `python-docx` の `Document()` 相当の処理でハングする既知事象があるため、必要に応じて `Start-Job` 経由ラッパー（`references/scripts/output/run_docx_via_job.sh`）で起動する。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `$SESSION_DIR/minutes.docx` | 会議タイトル（Title スタイル）・参加者表（Table Grid）・議事内容（Heading 1/2 + Normal + List Bullet）・決定事項・アクションアイテム・次回予定を含む Word ファイル |
| スタイル | 同梱テンプレートのスタイル定義に準拠（Meiryo フォント、見出し階層、表スタイル） |
| 終了状態 | 成功 |

## 分岐の根拠

SKILL.md「実行フロー」ステップ1-4の正常パス: 「minutes.json を workspace/ から読み込む → テンプレートを読み込む → Python スクリプトを実行する → 生成された minutes.docx をセッション直下に配置する」。`references/procedures.md` ステップ2の正常実行パス。

## 関連ケース

- `case-02_missing_input.md`（minutes.json が存在しない場合のエラーパス）
