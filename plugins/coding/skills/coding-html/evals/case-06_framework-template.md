# Case 06: Vue SFC 検出 → テンプレート素 HTML のみ担当・FW 構文は vue.md 参照

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「この UserCard.vue のテンプレートに見出しと alt 付き画像を追加して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | Vue プロジェクト。対象は単一ファイルコンポーネント `UserCard.vue`（`<template>` / `<script>` / `<style>` を含む）。変更見込みは 1 ファイル |

## 期待動作

### ステップ1: 規約解決
- SSOT `../../../references/conventions-resolution.md` に従いプロジェクト独自規約（`.editorconfig`・`.prettierrc*`・`.htmlvalidate.json`・`CLAUDE.md`・既存慣習）を走査し、無い項目は [references/conventions.md](../references/conventions.md) のデファクト規約（Google HTML/CSS Style Guide / セマンティクス / アクセシビリティ）を適用する

### ステップ2: FW 確認（本ケースの分岐点）
- 実行フロー step2「FW 確認」に従い、対象がテンプレート（`.vue`）であることを検出する
- 本スキルは `<template>` 内の **素の HTML 部分（要素構造・見出し階層・`img` の `alt` / `label` 関連付け等のアクセシビリティ）のみ** を担当する
- Vue SFC 固有の構文（ディレクティブ `v-if` / `v-for` / `:bind` / `@event`・`<script setup>` 等）は SSOT `../../../references/frameworks/vue.md` を参照し、本スキルの担当外とする
- コンポーネントロジック（`<script>` 部）は `coding-javascript` / `coding-typescript` の担当（責務外表）

### ステップ3以降: 実装・検証・報告
- 素の HTML 部分をセマンティクス・アクセシビリティ規約に沿って実装する（`img` の `alt`・見出し階層など [references/conventions.md](../references/conventions.md) の必須事項を維持）
- 利用可能な範囲でブラウザ表示確認・アクセシビリティ基本チェックを行う（テンプレート断片に適用不能な検証は SKIPPED として報告）
- 変更ファイル・担当範囲（テンプレートの素 HTML 部）と Vue 固有構文の委譲先（vue.md）を報告する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 担当範囲 | `<template>` 内の素の HTML 部のみ。Vue 固有構文は vue.md 参照・`<script>` は JS/TS スキル |
| 生成ファイル | セマンティック HTML 準拠のテンプレート変更 |
| 終了状態 | 成功（単独実行モードの軽量フロー） |

## 分岐の根拠

このケースが分岐するトリガーは 対象がテンプレート形式（`.vue` = Vue SFC）である ことである。
実行フロー step2「対象がテンプレート（`.jsx` / `.tsx` / `.vue` / `.blade.php` 等）の場合は素の HTML 部分のみを担当し、FW 固有構文は react.md / vue.md / php-web.md を参照する」と責務外表（Vue SFC 固有構文 → vue.md、SFC スクリプト部 → coding-javascript / coding-typescript）に従う。

## 関連ケース

- [case-01_standalone-basic.md](case-01_standalone-basic.md)（素の `.html` ファイル・FW 非依存の基本フローとの対比）
- [case-05_language-boundary.md](case-05_language-boundary.md)（スタイル変更 → coding-css へのルーティング。本ケースはテンプレート形式による FW 参照分岐）
