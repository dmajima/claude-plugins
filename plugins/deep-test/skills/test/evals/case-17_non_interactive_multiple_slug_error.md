# case-17 非対話モードで既存 target-slug が複数（エラー中断）

`--non-interactive` 時に基準ディレクトリの既存 target-slug が複数存在する場合、自動選択せずエラーで中断し、slug の明示指定を案内することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「--non-interactive でこのアプリをテストして」（フルフロー） |
| 前提 | 基準ディレクトリ配下に既存 `{target-slug}/` が 2 件存在する（`orderapp-web/` と `inventory-app/`） |

## 分岐の根拠

SKILL.md「Phase 別の要点」Phase 0（非対話: 唯一の既存 slug、複数はエラー中断）、プラグイン共通 references/execution-policy.md 9 章（非対話既定値表: target-slug が複数存在 → エラー中断・自動選択しない）、references/data-locations.md 4.2（非対話時は唯一の既存 slug を採用する。複数存在する場合はエラーで中断する〔誤った対象への実績追記を防ぐため〕・slug の明示指定を案内）・8 章（禁止事項: 非対話時に複数の既存 target-slug がある状態で処理を継続すること）。

## 期待動作

- AskUserQuestion を発行しない（非対話モード）
- 既存 slug が 2 件あることを検出したら、どちらかを自動選択せず・新規 slug の自動生成もせず、**エラーで中断**する
- 中断の返却に「複数の既存 target-slug が存在するため中断した」旨・検出した slug 一覧・`target-slug=`（または対象名）の明示指定による再実行の案内を含める
- Phase 0 で中断するため、`init` 以降のスクリプト実行・設計フェーズ（test-design の Skill 起動）・run へ進まない
- 中断までに test-plan.md / test-cases.yaml / test-results.yaml を生成・変更しない（誤った対象への書き込み防止）
- この既定値を execution-policy.md 9 章（SSOT）に基づいて適用する（SKILL.md 側の複製記述からの独自判断をしない）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（Phase 0 で中断。既存 2 slug のデータにも一切書き込まない） |
| 標準出力（要約） | 「複数の既存 target-slug が存在するため中断した」旨・検出 slug 一覧・`target-slug=` 明示指定による再実行の案内 |
| 終了状態 | Phase 0 でエラー中断（自動選択・新規作成・後続フェーズへの進行のいずれもしない） |

## 関連ケース

- case-15: 同じ前提（既存 slug 複数）の対話版（AskUserQuestion で一覧 + 新規作成を提示する側）
- case-05: 非対話で既存 slug が 1 件のみの場合（自動採用して進行する主系）
