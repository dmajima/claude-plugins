# case-06 language-profiles 未受領時の自己検出（O10）

オーケストレーターから `language-profiles` 引数を受け取らず単独起動したケース。差分から言語・FW を自己検出して web-designer のプロンプトに観点プロファイルを反映する分岐を検証する（受領あり = case-05 との対）。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "この画面まわりの変更を見て" |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動・language-profiles 引数なし） |
| 差分内容 | Vue 3 SFC + SCSS の変更（`.vue` + `.scss`、`package.json` に `vue`）。テンプレートは SFC の `<template>` |

## 分岐の根拠

references/skill-rules-matrix.md O10（`language-profiles` 引数は未受領時に自己検出）、SKILL.md「入力」の言語プロファイル行および「実行フロー」手順 1.5（未受領時は language-detection.md で自己検出）、`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5 手順 2、`${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` セクション 2〜4。委譲で引数を受領する case-05（React + CSS）との差は、自己検出を本スキルが行う点。

## 期待動作

- `language-profiles` 引数が無いため、language-detection.md の手順で差分の拡張子（`.vue` / `.scss`）とマーカーファイル（`package.json` の `vue`）から言語・FW を自己検出する（O10 / common-references.md 4.5 手順 2）
- 検出結果（Vue 3 / `frameworks/vue.md`、マークアップ部は `languages/html.md`、スタイルは `languages/css.md`）を確定し、web-designer のプロンプトに common-references.md セクション 4.5 のテンプレートで言語プロファイル参照指示を含める
- web-designer は html.md 観点（`.vue` の `<template>` 内マークアップのセマンティクス・a11y）・css.md 観点（`.scss` のネスト深度・詳細度・レスポンシブ・a11y）・vue.md 観点（`v-html` の XSS・key 欠落・リアクティビティ）を評価に使用する
- 未対応言語が差分に含まれる場合は中間レポートの制約事項に「観点プロファイル未収録・汎用観点のみで評価」と明記する（language-detection.md セクション 4）
- 単独起動のため本スキル自身で progress.md を作成・維持する（checklist.md O8）

## 関連ケース

- case-05: language-profiles 受領（委譲経由・React + CSS・受領ありの対）
- case-02: 単独実行 + スコープ外観点の混在（単独起動の別分岐）
