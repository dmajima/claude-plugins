# coding-python スキル evals

`coding-python` スキルの動作分岐ごとの期待挙動を定義するケース集。
各ケースは仕様書として機能する（対話型フローのため自動実行フロントマターは付与しない）。

参照モード（オーケストレーターからの受動的参照）は分岐ロジックを持たないため evals 対象外。
本 evals は単独実行モードの分岐を扱う。

## ケース一覧

| ケース | 分岐トリガー |
|-------|-------------|
| [case-01_standalone-basic.md](case-01_standalone-basic.md) | 単独実行モードの基本フロー（小規模・言語明確） |
| [case-02_scope-escalation.md](case-02_scope-escalation.md) | 変更見込み 4 ファイル以上 → orchestrator-coding への切替提案 |
