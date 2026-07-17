# case-09 Verdict オーバーライド分岐（test-runner RED / エージェント強制評価）

severity 集計だけでは OK に見えるが、test-runner の RED やエージェントの強制評価語により Verdict がオーバーライドされるケース。output-format.md セクション 3.1 のマトリクスと 3.2 の強制オーバーライドを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをレビューして"（標準モード） |
| 想定シナリオ | (A) Critical/High/Medium = 0 だが test-runner が RED（失敗テスト 1 件）/ (B) severity 集計 0 件だが security-engineer が VULNERABLE |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/output/output-format.md` セクション 3.1（Critical/High/Medium 件数 × test-runner ステータスのマトリクス）・セクション 3.2（強制オーバーライド）、`${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` セクション 2（エージェント評価語マッピング: test-runner RED = 失敗 1 件ごとに最低 High / security-engineer VULNERABLE = High 以上）。

## 期待動作

- シナリオ (A): Issues 件数が 0 でも、test-runner が RED を返した場合は **強制 NG・再レビュー要（Needs Work）** と判定する（output-format.md セクション 3.1 の「test-runner RED → Needs Work」行）。失敗テストは severity-ranking.md セクション 2 に従い最低 High 指摘として Issues に計上する
- シナリオ (B): severity 集計が 0 でも、security-engineer が VULNERABLE を返した場合は、その指摘を High 以上として Issues に計上し **NG・再レビュー要（Needs Work）** と判定する（severity-ranking.md セクション 2 の security-engineer マッピング）
- 「判定は厳しい側を採用」原則（SKILL.md 基本原則 9）に従い、他エージェントが PASS でもオーバーライド側を採用する
- 集計セクションに test-runner ステータス（RED）を明記する（output-format.md セクション 1.4）
- 未確認事項ではなく **確定した失敗** として扱う（SKIPPED と RED を混同しない）

## 関連ケース

- case-01: 標準モード初回（Issues ありの通常判定）
- case-08: マージ可否判断（3 種の Verdict）
