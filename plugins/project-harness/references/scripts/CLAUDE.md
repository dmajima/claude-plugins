# scripts/ 索引

`project-harness` プラグインの実行スクリプト。業務単位ごとにサブフォルダで分類する。

## 原則

- スクリプトはフェイルオープン設計とする（いかなる失敗でも exit 0 で素通りし、Claude Code の動作をブロックしない）
- 外部依存を持ち込まない（git + POSIX 標準コマンドのみ。jq は存在時のみ使用しフォールバックを必ず用意する）
- 仕様変更時は `../sync-spec.md`（SSOT）を先に更新し、スクリプトを追随させる

## ファイル一覧

| パス | 用途 | 呼び出し元 |
|------|------|-----------|
| `hooks/freshness_check.sh` | SessionStart 鮮度検知（乖離コミット数が閾値以上で update 推奨を通知） | `hooks/hooks.json` |
