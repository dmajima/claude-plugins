# case-04 非対話 → Markdown 既定

`--non-interactive` 併用の委譲時に、形式確認（AskUserQuestion）を行わず Markdown 既定で
報告書を生成することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=<確定値> --non-interactive`（オーケストレータの report-only モード等） |
| 起動 | オーケストレータ `test` から Skill ツール経由 |
| 前提 | 実績 YAML は完全（バリデーション通過可能） |

## 分岐の根拠

SKILL.md「実行モード判定」（非対話 = AskUserQuestion を使わず Markdown 既定）・「実行フロー」ステップ 4、
`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章 非対話既定値表（報告形式 = Markdown、target-slug 複数はエラー中断）、
`${CLAUDE_PLUGIN_ROOT}/references/report-format.md` 1 章（非対話時: Markdown 既定）。

## 期待動作

- AskUserQuestion を一切呼ばない（形式選択・target-slug 選択とも）
- 最終バリデーション（validate）と evidence-auditor 監査は非対話でも**省略しない**（SKILL.md 実行フロー。ゲートはモード非依存）
- `generate_markdown.py` を venv で実行し、`test-report_{target-slug}_{yyyyMMdd}.md` をセッション作業領域直下へ出力する
- target-slug が引数で未確定かつ基準ディレクトリ配下に複数存在する場合は、自動選択せずエラーで中断する（execution-policy.md 9 章 / data-locations.md 4 章）
- 返却は SKILL.md「引き渡し」の正常時フォーマット（形式: Markdown を明記）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 報告書 1 ファイル `test-report_{target-slug}_{yyyyMMdd}.md`（セッション作業領域直下）。test-results.yaml は読み取りのみ |
| 標準出力（要約） | SKILL.md「引き渡し」正常フォーマット（形式 = Markdown を明記。報告書パス・総合判定・集計・NG 件数・未確認事項） |
| 終了状態 | 生成完了（target-slug 未確定かつ複数存在時はエラー中断） |

## 関連ケース

- case-02: 対話時に Markdown を明示選択する分岐（同じ生成スクリプトに至る）
- case-03: 非対話でもバリデーション違反なら生成中断（ゲートがモード非依存であることの対）
