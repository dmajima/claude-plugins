# case-02 Markdown 生成正常系（対話・6 章構成）

対話モードで Markdown を選択した場合に、report-format.md 4 章の 6 章構成・エビデンスパス表記（コード span）・
禁止記号なしの Markdown 報告書が 1 ファイル生成されることを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動 | ユーザーが「テスト報告書を作成して」と直接起動（単独・対話） |
| 前提 | 基準ディレクトリ配下に target-slug が 1 件以上存在し、実績 YAML は完全（バリデーション通過可能） |
| 形式選択 | AskUserQuestion で「Markdown」を選択 |

## 分岐の根拠

SKILL.md「実行モード判定」（単独・対話 = target-slug 解決から実施）・「実行フロー」ステップ 1（`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4 章の解決フロー）、
`${CLAUDE_PLUGIN_ROOT}/references/report-format.md` 1 章（1 ファイル原則）・4 章（Markdown 6 章構成・エビデンスのコード span パス表記・禁止記号不使用）。

## 期待動作

- 単独起動のため target-slug を data-locations.md 4 章のフローで解決する（既存一覧の AskUserQuestion 提示 or 新規）
- validate → evidence-auditor 監査を通過後、AskUserQuestion の Markdown 選択を受けて `${CLAUDE_SKILL_DIR}/references/scripts/report/generate_markdown.py` を venv で実行する
- 出力は `test-report_{target-slug}_{yyyyMMdd}.md` の 1 ファイル（セッション作業領域直下）
- 章構成は「1. サマリ → 2. 推移 → 3. レベル別結果 → 4. NG 詳細 → 5. 未確認事項 → 6. 免責注記」の順（report-format.md 4 章。スクリプトが保証）
- サマリにはエビデンスパス基準注記（テスト実績データディレクトリ基準・報告書からの相対リンクではない旨）が含まれる
- NG 詳細にはケースごとに再現手順（番号付きリスト）・検証データ・severity・エビデンスパス（コード span 表記。リンク構文不使用）が含まれる
- skipped が 0 件でも 5 章に「なし」と明記される（未実施を問題なしと書かない原則の出口）
- セクション記号（U+00A7）が出力に含まれない（スクリプトが置換保証）
- 返却は SKILL.md「引き渡し」の正常時フォーマット（章構成はスクリプト出力を転記）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 報告書 1 ファイル `test-report_{target-slug}_{yyyyMMdd}.md`（セッション作業領域直下・6 章構成）。test-results.yaml は読み取りのみ |
| 標準出力（要約） | SKILL.md「引き渡し」正常フォーマット（報告書パス・総合判定・集計〔latest〕・NG 件数・未確認事項。章構成はスクリプト出力の転記） |
| 終了状態 | 生成完了 |

## 関連ケース

- case-01: Excel 選択時の対応分岐
- case-04: 非対話時に同じ Markdown 生成へ確認なしで進む分岐
