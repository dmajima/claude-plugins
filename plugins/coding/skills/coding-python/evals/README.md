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
| [case-03_non-interactive.md](case-03_non-interactive.md) | 非対話モード（--non-interactive）での単独実行 |
| [case-04_convention-conflict.md](case-04_convention-conflict.md) | 対話モードで検出規約とユーザ指示が矛盾 → AskUserQuestion 発火 |
| [case-05_framework-detection.md](case-05_framework-detection.md) | 依存定義に Flask 検出 → python-web.md プロファイル併用 |

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。
