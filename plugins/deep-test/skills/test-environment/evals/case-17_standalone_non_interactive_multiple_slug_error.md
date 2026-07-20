<!-- TEST-ENV-EVAL-R2-17-SENTINEL-v1 -->
# case-17 単独起動 × 非対話 × 既存 target-slug 複数（自動選択せずエラー中断・明示指定を案内）

`target=` 未指定の単独・非対話起動で、基準ディレクトリ配下に既存 target-slug が**複数**存在する場合に、自動選択せず**エラーで中断**して `target=` の明示指定を案内する分岐を検証する（誤った対象への書き込みを防ぐ安全側解決）。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | `/deep-test:test-environment action=provision project=./ --non-interactive`（`target=` 未指定） |
| 起動形態 | 単独（コマンド → スキル・非対話） |
| 前提 | 基準ディレクトリ `{base}` 配下に既存 slug が複数（例: `orderapp-web/` と `static-site/`）存在する |

## 分岐の根拠

SKILL.md「前提」の引数表（`target=` 未指定の単独時は data-locations.md 4 章の解決フロー）・「実行モード判定」（非対話: target-slug は `data-locations.md` 4.2 章の非対話規則）、`${CLAUDE_SKILL_DIR}/references/environment-procedures.md` 2 章（単独起動: 非対話時は唯一の既存 slug 採用・複数はエラー中断）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.2 章（非対話時は唯一の既存 slug を採用・複数存在する場合はエラーで中断〔誤った対象への実績追記を防ぐ〕）・8 章禁止事項（非対話時に複数の既存 target-slug がある状態で処理を継続すること）。

## 期待動作

- 単独起動のため target-slug 解決を本スキルで実施し、既存 slug の一覧（複数件）を検出する
- 非対話のため AskUserQuestion による選択提示を行わない
- 既存 slug が複数のため**自動選択しない**（最初の 1 件・更新日時の新しい 1 件等の推定採用をしない）
- **エラーで中断**し、`target=`（別名 `target-slug=`）の明示指定による再実行を案内する（検出した既存 slug の一覧を案内に含めてよい）
- 中断は slug 解決の段階で確定し、資産検出・派生生成・environment.yaml の生成・docker コマンド実行のいずれも行わない
- 誤った対象の environment.yaml / `environment/` 配下への書き込み（誤爆）が発生しないことを保証する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（いずれの slug 配下へも書き込まない） |
| 標準出力（要約） | エラー中断の理由（既存 slug が複数）・検出した slug 一覧・`target=` 明示指定の再実行案内 |
| 終了状態 | エラー中断（処理を継続しない。非破壊） |

## 関連ケース

- case-09: 単独起動の正常系（`target=` 明示指定あり・down）
- case-10: 委譲時は解決済み slug を受領するため本分岐が発生しない対（解決はオーケストレータ済み）
- case-19: 同じ複数 slug 前提の対話対（AskUserQuestion で既存一覧 +「新規作成」を提示して選択に従う）
