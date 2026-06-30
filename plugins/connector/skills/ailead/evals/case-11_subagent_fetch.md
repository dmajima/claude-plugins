# Case 11: サブエージェント呼び出しによる会議データ取得（Agent + ファイルコピー）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 他プラグイン（meeting-minutes）が `Agent()` ツールで起動。プロンプトに `Skill(skill: "connector:ailead", args: "https://dashboard.ailead.app/share/xxx")` + ファイルコピー指示 + マニフェスト返却指示を含む |
| 引数 | ailead 共有 URL + 出力ディレクトリ `.claude/.local/work/{session}/workspace/connector/` |
| フラグ | なし |
| 既存状態 | 共有リンクが有効（期限内）。Python 3.9+ 利用可能 |

## 期待動作

1. サブエージェント内で `Skill(skill: "connector:ailead")` を実行
2. ailead スキルが独自セッションフォルダを作成し、venv 構築・データ取得を実行
3. スキル完了後、結果報告から保存先パスを読み取る
4. `transcript.txt`, `summary.md`, `metadata.json`, `response.json` を `{output-dir}` にコピー
5. マニフェスト JSON を返却

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `{output-dir}/transcript.txt`, `{output-dir}/summary.md`, `{output-dir}/metadata.json`, `{output-dir}/response.json` |
| 返却値 | `{"status":"success","outputDir":"...","files":{"transcript":"transcript.txt","summary":"summary.md","metadata":"metadata.json","response":"response.json"},"summary":"<会議タイトル>"}` |
| 終了状態 | 成功。呼び出し元（meeting-minutes）が後続パイプライン続行可能 |

## 分岐の根拠

subagent-protocol.md セクション 5.4 の ailead 専用テンプレートに基づく。他スキルと異なり、ailead は内部でファイル出力するため、サブエージェントが出力ファイルを caller の output-dir にコピーする追加ステップがある。

## 関連ケース

- `case-01_share_fetch_success.md`（ユーザー直接の正常取得）
