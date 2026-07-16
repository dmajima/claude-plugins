# coding-sql スキル evals

`coding-sql` スキルの動作分岐ごとの期待挙動を定義するケース集。
各ケースは仕様書として機能する（対話型フローのため自動実行フロントマターは付与しない）。

参照モード（オーケストレーターからの受動的参照）は分岐ロジックを持たないため evals 対象外。
本 evals は単独実行モードの分岐を扱う（実行フロー先頭に方言判定を含む）。

## ケース一覧

| ケース | 分岐トリガー |
|-------|-------------|
| [case-01_standalone-basic.md](case-01_standalone-basic.md) | 方言判定可能 → 単独実行モードの基本フロー |
| [case-02_scope-escalation.md](case-02_scope-escalation.md) | 変更見込み 4 ファイル以上／スキーマ全体設計に波及 → orchestrator-coding への切替提案 |
| [case-03_dialect-unknown-standalone.md](case-03_dialect-unknown-standalone.md) | 単独実行モードで方言判定材料なし → 共通規約のみで進行 |
