# research/ 利用ガイド

## 目的

設計時に Claude Code の実挙動を実測・検証したスクリプトの記録。仕様の裏付けを再確認したいときに手動で実行する調査用資産であり、フック・コマンド・テストの実行経路には含まれない。

## ファイル一覧

| ファイル | 説明 |
|---------|------|
| `s1_session_id.py` | `UserPromptSubmit` の stdin JSON が `session_id` を提供するかを確認する |
| `s2_hook_concat.py` | 複数のフックが返す `additionalContext` を Claude Code がどう結合するかを観察する（`--role` で送信側・観測側を切り替える） |
| `s3_plugin_data_var.py` | 実行環境で `${CLAUDE_PLUGIN_DATA}` が提供されるかを調べる |
| `s4_session_start_clear.py` | `SessionStart` の matcher `clear` が `/clear` で実際に発火するかを検証する |
| `s5_python_startup_latency.py` | Python の cold / warm 起動時間と skill-router モジュールの import レイテンシを計測する |

## 利用ルール

- 実行方法は各スクリプトの docstring 冒頭に記載されている。手動実行を前提とし、フック登録して常用しない
- `../scripts/` 配下のモジュールから本フォルダのスクリプトを import してはならない（調査記録であり実行経路ではない）
- 調査結果に基づく仕様は `../scripts/routing/` の各 docstring および `../../skills/skill-router/SKILL.md` に反映する。本フォルダに仕様を記述しない
- 新たな調査を追加した場合は本ファイルのファイル一覧に追記する

## 関連フォルダ

| フォルダ | 関係 |
|---------|------|
| `../scripts/hooks/` | s1 / s2 / s3 / s4 の調査対象となったフック実行環境の実装 |
| `../scripts/routing/` | s5 が計測対象とする import コストの発生元 |
