# case-05 非対話モード（委譲・target-slug / base 付与での自動進行）

`--non-interactive` でのオーケストレータ委譲ケース。曖昧確認（AskUserQuestion）をせず、付与された target-slug / base を用いて解析を自動進行することを検証する。target-slug 未付与・複数既存時の非対話規則も対比で確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=orderapp-web 対象説明=./ base=<base> --non-interactive` |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由・非対話） |
| 前提 | リポジトリソースは full で取得可 / `spec=` `diff=` 指定なし / target-slug / base はオーケストレータが付与済み |

## 分岐の根拠

SKILL.md「実行モード判定」（非対話: 曖昧確認をせず進行・target-slug は data-locations.md 4.2 章の非対話規則）・「前提」の引数表（委譲時に target-slug / base を受領）、references/procedures.md 2 章（委譲時は受領値を使用・単独時のみ解決フロー）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.2 章（非対話は唯一の既存 slug 採用・複数はエラー中断）、同 `execution-policy.md` 9 章（非対話既定値表: target-slug 複数はエラー中断・自動選択しない）、同 `agents.md` 4.3 章（共通注入事項）。

## 期待動作

- AskUserQuestion を一切呼ばない（非対話モード）
- 委譲で `target-slug=orderapp-web` / `base=` を受領しているため、slug の解決フロー・確認を行わず受領値を使用する
- source_availability を full と判定し、責務 1〜12 の全解析を自動進行する（対話確認を挟まない）
- `spec=` `diff=` 未指定のため `spec_divergence` / `change_impact` を出力しない
- `{target-slug}/analysis.yaml` / `{target-slug}/target-analysis.md` を生成する（`suggested_focus` は hint に留め、決定はしない = 決定は test-design）
- `deep-test:source-analyst` を単独起動して自己チェックし、重大指摘を反映してから返却する（非対話でも自己チェックを省略しない）
- 対象説明・target-slug のいずれも確定できない場合の非対話規則（唯一の既存 slug 採用 / 複数はエラー中断・自動選択しない）を遵守する（本ケースは付与済みのため中断しない）
- read-only に徹し test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{target-slug}/analysis.yaml`・`{target-slug}/target-analysis.md`（受領 target-slug 配下）。spec_divergence / change_impact は出力しない。test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない |
| 標準出力（要約） | 委譲元（オーケストレータ）へ返す解析結果サマリ（対象種別・source_availability・件数表・source-analyst 所見・open_questions・次フェーズは test-design がレベル / 技法 / 優先度 / ケースを決定する旨） |
| 終了状態 | AskUserQuestion を呼ばず自動進行で材料 2 ファイルを生成し委譲元へ返却。自己チェックは非対話でも省略しない |

## 関連ケース

- case-01: 対話モードでの確認フロー（新規 slug 解決・AskUserQuestion 使用）
- case-04: 縮退判定（非対話でも判定ロジックは同じ）
