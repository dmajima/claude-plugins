# case-14 プロファイルアンカー照合による過小評価の是正（C25）

観点別スキルのエージェントが、適用プロファイルのアンカー下限が Medium 以上の指摘を Low（改善提案相当）に過小評価して返したケース。オーケストレーターが Step 5 のプロファイルアンカー照合でアンカー下限まで引き上げ、Issues（対応が必要な指摘）へ再配置する分岐を検証する。信頼度足切りの case-07 と同じ Step 5 の重要度整合メカニズムの別分岐。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをコードレビューして"（差分: `batch/*.py` 4 ファイル。リポジトリルートに `pyproject.toml` あり・`tsconfig.json` なし） |
| モード | 標準 |
| 観点別スキルからの返却（想定） | code-review-implementation が「`open()` の `encoding` 未指定（Windows で cp932 文字化け・UnicodeDecodeError 懸念）」を **Low（改善提案相当）** として返却（内部エージェントの過小評価） |

## 分岐の根拠

references/flow/flow.md Step 5「プロファイルアンカー照合（必須・C25）」の手順 1〜4、skill-rules-matrix.md C25、`${CLAUDE_PLUGIN_ROOT}/references/languages/python.md` セクション 4「典型的な指摘パターン（重要度の目安）」（`open()` の encoding 未指定 = Medium〜High）。

## 期待動作

- Step 2: `pyproject.toml` があり `tsconfig.json` がないため、`languages/python.md` を適用プロファイルとして確定する（language-detection.md / C23）
- Step 5: 三分（Issues / Suggestions / Scope-out）の **前に**、各 finding の重要度を適用プロファイルのセクション 4 アンカーと照合する（flow.md Step 5 手順 1）
- Step 5: 当該 finding のパターン（`open()` の encoding 未指定）を python.md セクション 4 の該当行（アンカー下限 = Medium）と突き合わせ、**アンカー下限が Medium 以上**であることを確認する
- Step 5: エージェントが Low に分類した当該 finding を、**アンカー下限（Medium）まで引き上げて Issues（対応が必要な指摘・セクション 1）へ再配置する**（flow.md Step 5 手順 2）
- Step 5: 逆にプロファイルにアンカーが無いパターン（設計所見等）は引き上げず、根拠の弱さを踏まえ信頼度を控えめに付与する（flow.md Step 5 手順 3 / severity-ranking.md セクション 7）
- Step 6-8: 最終的な Issues / Suggestions 件数はアンカー照合後の値で採番・集計する（flow.md Step 5 手順 4）。再配置された finding は Finding ID を採番され Issues のサマリー表に現れる
- Step 7: 再配置後の Issues に Medium が計上され、Critical/High が無ければ Verdict は Needs Attention 側になる（output-format.md セクション 3.1）
- （以下は検出してはならない誤り）
    - アンカー下限が Medium 以上の指摘を、エージェントが Low に分類したまま Suggestions に残置する（C25 違反・ユーザーが未対応でマージするリスク）
    - プロファイルにアンカーが無い設計所見を根拠なく Medium 以上へ引き上げる（過剰な引き上げ）
    - 再配置後も Issues / Suggestions 件数を照合前の値のまま集計する

## 関連ケース

- case-06: 言語・FW 検出とプロファイル適用の正常系（アンカー照合の前提）
- case-07: 信頼度足切り（同じ Step 5 の重要度整合の別分岐）
