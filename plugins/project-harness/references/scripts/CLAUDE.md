# references/scripts/

## 目的

`project-harness` プラグインの実行スクリプト。業務単位ごとにサブフォルダで分類する。

## ファイル一覧

| パス | 用途 | 呼び出し元 |
|------|------|-----------|
| [hooks/freshness_check.sh](hooks/freshness_check.sh) | SessionStart 鮮度検知（乖離コミット数が閾値に達したとき `/project-harness:update` の実行を推奨通知） | `hooks/hooks.json` |
| [validate/validate_harness.sh](validate/validate_harness.sh) | 生成済みハーネスの健全性検証（索引一致・frontmatter・行数・プレースホルダ・秘匿値・到達性・state） | harness-init / harness-update の検証フェーズ |

## 利用ルール

1. **フックはフェイルオープン**: `hooks/` 配下はいかなる失敗でも exit 0 で素通りし、セッション開始をブロックしない
2. **検証はフェイルクローズ**: `validate/` 配下は検証結果を終了コードで返す（0 = 合格 / 1 = 違反あり / 2 = 検査不能）。フックとは設計方針が異なる
3. **外部依存を持ち込まない**: git と POSIX 標準コマンドのみを使う。jq は存在時のみ使用し、必ず sed 等のフォールバックを用意する
4. **状態ファイルの値を信頼しない**: `.sync-state.json` の値はシェルで評価せず、形式検証（SHA は 7〜40 桁の 16 進、閾値は 1 以上 9 桁以内の整数）を経てから使う
5. **cwd を信頼しない**: 対象リポジトリの基準は `CLAUDE_PROJECT_DIR`（未設定時は cwd）から解決する
6. **対象プロジェクトを汚染しない**: 検査目的のスクリプトは一時ファイルを対象リポジトリ内に作らない
7. **仕様変更は sync-spec.md が先**: 判定ロジック・出力仕様を変える場合は [../sync-spec.md](../sync-spec.md) 節 3、検証項目を変える場合は [../authoring-spec.md](../authoring-spec.md) 節 6 を先に更新し、スクリプトを追随させる

## 関連フォルダ

| フォルダ | 関係 |
|---------|------|
| [../](../) | スクリプトが実装する仕様（`sync-spec.md` 節 3 / `authoring-spec.md` 節 6）の格納元 |
