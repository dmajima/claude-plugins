# design-bridge references/scripts/

実行可能スクリプトの集約ディレクトリ（extension-toolkit ADR-025 準拠）。業務単位ごとにサブフォルダを切る。

## ファイル一覧

| パス | 役割 |
|------|------|
| `hooks/mark_design_dirty.sh` | PostToolUse フック。設計書・モックの変更を種別付きで `pending.tsv` へ追記する |
| `hooks/block_unsynced_design.sh` | Stop フック。未反映があれば終了コード 2 でブロックし、種別ごとの誘導を stderr へ出す |
| `hooks/clear_pending.sh` | 未反映記録の解除（`--path` で部分、`--all` で全件、`--drop-bundle` でバンドル破棄） |
| `hooks/lib/design_bridge_common.sh` | パス正規化・プロジェクトルート検出・監視対象判定・上限値取得の共通関数 |
| `hooks/tests/test_hooks.sh` | フック 3 本の回帰テスト（20 セクション・54 チェック） |
| `setup/setup_venv.sh` / `setup/teardown_venv.sh` | スクリーンショット用 venv の構築 / 削除 |
| `setup/requirements.txt` | 全スキル分の依存をマージ（バージョン固定） |

スキル固有のスクリプトはここに置かない。`capture.py` は `design-push` 専用のため `../../skills/design-push/references/scripts/screenshot/` にある。

## 利用ルール

1. **フックは Claude Code が自動起動する**。手動で呼ぶのは回帰テストと `clear_pending.sh` だけ
2. **記録と解除は必ずスクリプト経由**。`pending.tsv` を Edit/Write で直接編集しない。部分解除の誤りと、`block-count` / `dismissed` の整合崩れを防ぐ
3. **フェイルセーフとフェイルオープン**: ライブラリの関数は判定不能なら「対象外」を返し、フック本体は例外時に exit 0 で素通りする。ただしブロックするかどうかの判断が揺らぐ状況（カウンタを更新できない等）では必ず通過側へ倒す。ここを逆にすると恒久ロックになる
4. **リポジトリ設定から挙動を変える値を読まない**: `blockLimit` はユーザースコープ設定または既定値のみ。`.claude/design-bridge.json` からは `watch` のみ読む
5. **stderr へ出す値は検証済みのものだけ**: Stop フックの stderr は終了コード 2 とともにモデルのコンテキストへ渡る。`db_is_safe_rel` を通らない文字列を出さない
6. **jq は任意依存**: 無い環境では sed による抽出と既定の監視対象へ縮退する。jq を必須にしない
7. **エンコーディング**: jq の出力は `tr -d '\r'` を通す（Windows 版は CRLF を返す）
8. **変更後は必ずテスト**: `bash hooks/tests/test_hooks.sh` が全件 PASS することを確認する

## Python スクリプトの起動

`capture.py` は venv の python を明示指定し、`Bash` ツール経由で起動する。`PowerShell` ツールから直接起動すると Windows で子プロセスがハングする既知事象がある。

```bash
"<project>/.claude/.local/plugins/design-bridge/.venv/Scripts/python.exe" \
  "${CLAUDE_PLUGIN_ROOT}/skills/design-push/references/scripts/screenshot/capture.py" --help
```
