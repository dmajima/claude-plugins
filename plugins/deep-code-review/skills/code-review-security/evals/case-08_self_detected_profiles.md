# case-08 language-profiles 未受領時の自己検出（O10）

オーケストレーターから `language-profiles` 引数を受け取らず単独起動したケース。差分から言語・FW を自己検出して観点プロファイルをエージェントプロンプトに反映する分岐を検証する（受領あり = case-06 との対）。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "この変更のセキュリティをレビューして" |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動・language-profiles 引数なし） |
| 差分内容 | Python / Django の変更（`.py` + `requirements.txt` に `django`）。ORM クエリ・認証ビューを含む |

## 分岐の根拠

references/skill-rules-matrix.md O10（`language-profiles` 引数は未受領時に自己検出）、SKILL.md「入力」の言語プロファイル行「未受領時は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` で自己検出する（O10）」および「実行フロー」手順 1.5、`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5 手順 2（引数が無い場合は language-detection.md で自己検出）、`${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` セクション 2〜4。委譲で引数を受領する case-06 との差は、自己検出を本スキルが行う点。

## 期待動作

- `language-profiles` 引数が無いため、language-detection.md の手順で差分の拡張子（`.py`）とマーカーファイル（`requirements.txt` の `django`）から言語・FW を自己検出する（O10 / common-references.md 4.5 手順 2）
- 検出結果（主: Python / `languages/python.md`、FW: Django / `frameworks/python-web.md`）を確定し、security-engineer / dependency-safety のプロンプトに common-references.md セクション 4.5 のテンプレートで言語プロファイル参照指示を含める
- security-engineer は python.md 観点 3.7（SQL インジェクション / XSS / `eval` / コマンド実行 / CSRF 等）と python-web.md の Django 観点（ORM の生 SQL・mass assignment・認証/認可）を評価に使用する
- dependency-safety は python.md セクション 6（`pip-audit` 等）と python-web.md の依存追加観点を参照する（動的検証の EXECUTED / SKIPPED は O3 に従う）
- 未対応言語が差分に含まれる場合は中間レポートの制約事項に「観点プロファイル未収録・汎用観点のみで評価」と明記する（language-detection.md セクション 4）
- 単独起動のため本スキル自身で progress.md を作成・維持する（checklist.md O8）

## 関連ケース

- case-06: language-profiles 受領（委譲経由・受領ありの対）
- case-04: セキュリティレビューフレーズでの起動（自己検出の簡略言及元）
