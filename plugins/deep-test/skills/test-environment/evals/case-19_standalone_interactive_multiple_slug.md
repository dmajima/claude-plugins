<!-- TEST-ENV-EVAL-R2-19-SENTINEL-v1 -->
# case-19 単独起動 × 対話 × 既存 target-slug 複数（AskUserQuestion で既存一覧 +「新規作成」を提示して選択に従う）

`target=` 未指定の単独・対話起動で、基準ディレクトリ配下に既存 target-slug が**複数**存在する場合に、エラー中断せず **AskUserQuestion で既存一覧と「新規作成」を提示**し、ユーザーの選択に従って解決する分岐を検証する（case-17〔非対話 = 自動選択せずエラー中断〕の対話対）。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | `/deep-test:test-environment action=provision project=./`（`target=` 未指定・`--non-interactive` なし） |
| 起動形態 | 単独（コマンド → スキル・対話） |
| 前提 | 基準ディレクトリ `{base}` 配下に既存 slug が複数（例: `orderapp-web/` と `static-site/`）存在する |

## 分岐の根拠

SKILL.md「前提」の引数表（`target=` 未指定の単独時は data-locations.md 4 章の解決フロー）・「実行モード判定」（対話: 不足情報〔target-slug・project〕をユーザーに確認する）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 2 章（単独起動は `data-locations.md` 4 章の解決フローに従う）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.2 章（対話時は既存 `{target-slug}/` の一覧を提示〔AskUserQuestion〕し、選択 or 新規作成とする。既存を選択 → その slug を採用・新規作成 → 新規 slug 名を確認して作成）・4.1 章（新規作成時の kebab-case 命名規約）。

## 期待動作

- 単独起動のため target-slug 解決を本スキルで実施し、既存 slug の一覧（複数件）を検出する
- 対話のため **AskUserQuestion で既存 slug の一覧と「新規作成」を提示**する（エラー中断しない。自動選択・推定採用もしない〔case-17 の非対話規則を対話に適用しない〕）
- 既存 slug が選択された場合はその slug を採用し、「新規作成」が選択された場合は新規 slug 名（kebab-case）を確認して作成する
- 選択確定前に environment.yaml / `environment/` 配下への書き込み・docker コマンド実行を行わない（誤った対象への書き込み〔誤爆〕を防ぐ保証は case-17 と同じ）
- 選択確定後は通常の provision フロー（資産検出 → analysis.yaml 消費 or 軽量補完 → 要否判定 → 派生生成 → config 検証 → environment.yaml 出力 → 自己チェック）へ進む

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 選択（または新規作成）された slug 配下の `environment.yaml`・`environment/` 派生成果物のみ（他の slug 配下へは書き込まない） |
| 標準出力（要約） | AskUserQuestion の提示内容（既存一覧 +「新規作成」）→ 選択結果 → 以降は provision の通常返却（環境構築結果サマリ） |
| 終了状態 | 選択された slug で provision 続行（エラー中断しない） |

## 関連ケース

- case-17: 同じ複数 slug 前提の非対話対（自動選択せずエラー中断・`target=` 明示指定を案内）
- case-09: 単独起動の正常系（`target=` 明示指定あり・down）
- case-10: 選択確定後に合流する provision 主成功経路
