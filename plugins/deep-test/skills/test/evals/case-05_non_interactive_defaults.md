# case-05 非対話モードの既定値動作

`--non-interactive` 併用時に、確認をスキップして既定値表どおりに進行することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「--non-interactive でこのアプリをテストして」 |
| 前提 | フルフロー。scope に `automation: manual-assist` のケース 1 件を含む。基準ディレクトリの既存 target-slug は 1 件のみ |

## 分岐の根拠

SKILL.md「実行モード判定」（非対話: 確認をスキップし既定値で進行）、プラグイン共通 references/execution-policy.md 9 章（非対話既定値表: 報告形式 Markdown / 人間承認ゲートスキップ / NEEDS REVISION は修正ループ後エラー中断 / manual-assist は skipped / MCP 未ロードはハンドオフ停止）、references/data-locations.md 4.2（非対話時の slug 解決: 唯一の既存 slug を採用）。

## 期待動作

- 既存 slug が 1 件のみのため、AskUserQuestion を発行せずその slug を採用して進行する
- 人間承認ゲートは AskUserQuestion を発行せずスキップ（自動進行）する
- `automation: manual-assist` のケースは実行せず、skipped + reason（非対話モードのため人手介在ケースは未実施）として record させる
- 設計レビューが NEEDS REVISION の場合は修正ループ（上限 3 回）を自動で回し、超過時はユーザー判断を挟まず**エラー中断**する
- MCP 未ロード時は非対話でも自動続行せず、再起動ハンドオフを出力して停止する
- 報告形式は確認なしで Markdown を既定とする（test-report への引き渡しに反映）
- 上記の既定値を SKILL.md に複製された値からではなく execution-policy.md 9 章（SSOT）に基づいて適用する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 通常フローどおり test-results.yaml（results_manager.py 経由で更新。manual-assist は skipped + reason で record。Edit / Write の直接編集なし）と Markdown 既定の報告書 |
| 標準出力（要約） | AskUserQuestion なしで進行し、SKILL.md「引き渡し」の正常フォーマット（run_id・レベル別集計・報告書パス・未確認事項）。NEEDS REVISION 超過はエラー中断、MCP 未ロードは再起動ハンドオフ |
| 終了状態 | 確認スキップのまま run status=completed。ループ超過はエラー中断・MCP 未ロードはハンドオフ停止（いずれも自動続行しない） |

## 関連ケース

- case-01: 対話モードでの同フロー（AskUserQuestion を発行する側）
- case-17: 非対話で既存 target-slug が複数の場合（エラー中断する側）
- case-03: MCP 未ロード時のハンドオフ（対話・非対話で同一挙動）
- case-04 / case-16: NEEDS REVISION ループの対話版（超過時にユーザー判断を挟む側）
