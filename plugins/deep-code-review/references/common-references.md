# 観点別レビュースキル 共通リファレンス（SSOT）

`code-review-implementation` / `code-review-testing` / `code-review-security` / `code-review-architecture` / `code-review-frontend` の **5 スキル共通で参照する** リファレンス一覧。

> **位置付け**: `${CLAUDE_PLUGIN_ROOT}/references/common-references.md`（プラグイン共通 references）。
> 各観点別スキルの SKILL.md からは本ファイルを片方向参照する形に統一（共通化済み）。
> 本ファイル → 個別スキルへの参照は持たない。
> 実行フロー（手順 1〜4）で毎回必要なのはセクション 4 / 4.5 / 5。インデックス情報（セクション 1 / 2 / 3）は `${CLAUDE_PLUGIN_ROOT}/references/common-references-details.md` に分離し、該当時のみ Read する。

---

## 1. プラグイン共通リファレンス（必須）

共通 SSOT ファイルの一覧と利用タイミングは `${CLAUDE_PLUGIN_ROOT}/references/common-references-details.md` セクション 1 を参照（共通ファイルの所在を確認する時に Read）。

## 2. オーケストレーター連携

統合サマリの最終フォーマット・Verdict 判定はオーケストレーター（`code-review`）の責務。本観点別スキルは **中間レポート**（各 SKILL.md の「出力フォーマット」セクションの形式）を返すのみ。出力フォーマット規範・テンプレートの所在は `${CLAUDE_PLUGIN_ROOT}/references/common-references-details.md` セクション 2 を参照（統合サマリ生成時＝主にオーケストレーター側で Read）。

## 3. 達成チェックリスト（個別スキル）

各観点別スキルは自身の `${CLAUDE_SKILL_DIR}/references/checklist.md` を使用（Universal U1〜U16 の達成基準は `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md`）。全 5 スキルの checklist 配置一覧は `${CLAUDE_PLUGIN_ROOT}/references/common-references-details.md` セクション 3 を参照。

## 4. 観点別スキル共通: 進捗管理（5 スキル共通）

観点別 5 スキル（impl / testing / security / architecture / frontend）は **複数エージェントの並列起動を伴う** ため Universal U5（進捗管理）が必須。オーケストレーター（`code-review`）が `progress.md` を維持中なら担当タスク（各エージェントの起動・結果取得）を追記し、不在時（観点別スキル単独実行）は本スキル自身で `progress.md` を作成・維持する。

詳細規範: `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U5

## 4.5 観点別スキル共通: 言語別レビュー観点プロファイルの適用（O10）

観点別 5 スキルは、内部エージェントを起動する際に **検出済み言語・FW の観点プロファイルをプロンプトに含める**:

1. オーケストレーターから `language-profiles=<...>` 引数（適用プロファイルパス一覧 + 主/副区分）を受け取る
2. 引数が無い場合（単独実行時）は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` の手順で自己検出する
3. 各エージェントのプロンプトに以下を含める:

```
## 言語別レビュー観点
検出言語・FW: <一覧>
各言語プロファイルは **hub（`<言語>.md`）＋観点別 details** の 2 層構成（未分割の `css.md` 等は単一ファイル）。以下の手順で Read せよ:
1. hub `${CLAUDE_PLUGIN_ROOT}/references/languages/<言語>.md` を Read（識別・準拠規約・重要度表(節4)・動的検証(節6)・各 3.x のスタブ見出し＋ポインタ）
2. hub の 3.x スタブのうち **あなたの担当（各節の【担当】）に該当する節のポインタ先 details のみ** を Read（`<言語>-impl.md` / `<言語>-core.md` / `<言語>-security.md`。自観点以外の details は読まない）。hub が単一ファイル（未分割）の場合は全体を使用する
3. 該当 `${CLAUDE_PLUGIN_ROOT}/references/frameworks/<FW>.md`
プロジェクト独自規約（適用規約サマリ）が最優先。プロファイルのデファクトはプロジェクト規約が無い項目のみに適用する（conventions-resolution.md の 5 段階解決）。
```

4. 未対応言語（プロファイル無し）が含まれる場合は、中間レポートの制約事項に「<言語>: 観点プロファイル未収録・汎用観点のみで評価」と明記する

エージェント別の参照プロファイル（hub は常に Read。details は自担当節のみ）:

| エージェント | hub | 参照する details（自担当節） |
|-------------|-----|------------------------------|
| implementation-engineer | `<言語>.md` | `<言語>-impl.md`（観点 3.1〜3.5, 3.8）+ 該当 frameworks/*.md |
| performance-reviewer | `<言語>.md` | `<言語>-impl.md`（観点 3.6。sql は `sql-core.md`、html は `html-core.md`、css は未分割で全体）+ 該当 frameworks/*.md の性能観点 |
| security-engineer | `<言語>.md` | `<言語>-security.md`（観点 3.7。sql は `sql-security.md` の 3.2、html は `html-security.md` の 3.4/3.7）+ 該当 frameworks/*.md のセキュリティ観点 |
| dependency-safety | `<言語>.md` | sql 検出時 `sql-security.md`（3.3 マイグレーション安全性）+ 該当 frameworks/*.md |
| linter-static-analysis / test-runner | `<言語>.md` | hub 節6（動的検証コマンド）。linter は命名節（`<言語>-impl.md` / `-core.md` の 3.5）も参照 |
| dba | `sql.md` | `sql-core.md` + `sql-security.md`（dba は全 3.x 担当）+ frameworks/orm.md |
| web-designer | `html.md` | `html-core.md` + `html-security.md` + `css.md`（未分割・全体）+ 該当 frameworks/*.md（react / vue / frontend-tooling） |
| test-engineer | `<言語>.md` | hub 節6（動的検証コマンドのテスト規約）+ frameworks/frontend-tooling.md のテスト観点 |
| architect | — | 必要に応じて該当 frameworks/*.md |

> **2 層構成の意図**: 各観点は hub（共通前提・重要度表・動的検証）＋自観点 details のみをロードし、他観点の観点本文（例: security 観点が impl の 3.1〜3.6 を、impl 観点が security の 3.7 を）を読まない。節番号・見出しは hub にスタブとして温存され、外部参照（agents O10 の「観点 3.1〜3.5・3.8」等）は hub 経由で 2 ホップ解決する。`css.md` は単一観点（web-designer）かつ security 節が無く分割で削減が生じないため未分割で維持する。

## 5. 観点別スキル共通: スコープ外振分けルール

自スキルのスコープ外と判断した指摘は、対応する他観点別スキルへ誘導する:

| 自スキル | スコープ外時の振分け先 |
|---------|--------------------|
| `code-review-implementation` | テスト → `code-review-testing` / セキュリティ → `code-review-security` / アーキ → `code-review-architecture` / UI → `code-review-frontend` |
| `code-review-testing` | 実装 → `code-review-implementation` / E2E・性能テスト・脆弱性スキャン → 対象外 |
| `code-review-security` | 実装一般 → `code-review-implementation` / テスト → `code-review-testing` / 実装提案 → 自スキル内では指摘のみ |
| `code-review-architecture` | 実装一般 → `code-review-implementation` / テスト → `code-review-testing` / セキュリティ → `code-review-security` / UI → `code-review-frontend` |
| `code-review-frontend` | バックエンド → `code-review-implementation` / API 設計 → `code-review-architecture` / XSS 重点 → `code-review-security` |

「別 PR 推奨」「Issue 起票」等の文言は使わない（`scope-out-policy.md` セクション1）。本 PR スコープ外指摘はオーケストレーターが「## 3. スコープ外指摘」セクションに集約する。

---

## 6. 適用契約

観点別 5 スキルが共通参照するリファレンス・共通規範のインデックス。個別スキルからの参照を本ファイル経由の 1 行に集約し、規範改訂時のメンテナンスコストを下げる。
