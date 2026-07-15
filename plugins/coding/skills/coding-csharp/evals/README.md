# coding-csharp スキル evals

`coding-csharp` スキルの動作分岐ごとの期待挙動を定義するケース集。
各ケースは仕様書として機能する（対話型フローのため自動実行フロントマターは付与しない）。

参照モード（`orchestrator-coding` / `orchestrator-design` からの受動的参照）は
規約・FW プロファイルを判定基準として提供するのみで分岐ロジックを持たないため evals 対象外。
本 evals は単独実行モード（ユーザの直接依頼）の分岐を扱う。

## ケース一覧

| ケース | 分岐トリガー |
|-------|-------------|
| [case-01_standalone-basic.md](case-01_standalone-basic.md) | 小規模・言語明確 → 単独実行モードの軽量フロー |
| [case-02_scope-escalation.md](case-02_scope-escalation.md) | 変更見込み 4 ファイル以上 → orchestrator-coding 切替提案 |
