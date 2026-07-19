# case-04 非対話モード（委譲・target-slug / base / project 付与での自動進行）

`--non-interactive` でのオーケストレータ委譲ケース。曖昧確認をせず、付与された target-slug / base / project を用いてフィクスチャ基盤構築を自動進行し、`.gitignore` 追記は実行せず提案に留めることを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=orderapp-web project=./ base=<base> --non-interactive` |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由・非対話） |
| 前提 | `analysis.yaml` 存在（web-app・認証 EP / 外部依存あり）/ 既存 Playwright 基盤なし / target-slug / base / project はオーケストレータが付与済み |

## 分岐の根拠

SKILL.md「実行モード判定」（非対話: 曖昧確認をせず進行・target-slug は data-locations.md 4.2 章の非対話規則・`.gitignore` 追記は提案に留める）・「前提」の引数表（委譲時に target-slug / base / project を受領）、`${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` 2 章（委譲時は受領値を使用）・6.1 章（`.gitignore` は追記の提案のみ）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.2 章（非対話は唯一の既存 slug 採用・複数はエラー中断）、同 `execution-policy.md` 9 章（非対話既定値表: target-slug 複数はエラー中断・自動選択しない）、同 `agents.md` 4.3 章（共通注入事項）。

## 期待動作

- AskUserQuestion を一切呼ばない / ユーザーへの対話確認を行わない（非対話モード）
- 委譲で `target-slug=orderapp-web` / `base=` / `project=./` を受領しているため、slug の解決フロー・確認を行わず受領値を使用する
- `analysis.yaml` を消費し、既存基盤検出（無）→ 生成に自動進行する（対話確認を挟まない）
- 認証情報は環境変数経由のコードにし、storageState 出力先の `.gitignore` 追記は**実行せず提案として返却に残す**（非対話では破壊的 / 確認要の操作を自動実行しない）
- `{base}/{target-slug}/fixtures.yaml` と SUT テストコードを生成する
- `deep-test:fixture-architect` を単独起動して自己チェックし、重大指摘を反映してから返却する（非対話でも自己チェックを省略しない）
- target-slug が未付与かつ既存複数の場合の非対話規則（唯一採用 / 複数はエラー中断・自動選択しない）を遵守する（本ケースは付与済みのため中断しない）
- read-only 境界に加え SUT テストディレクトリのみへの書き込みに徹し、test-results.yaml / test-cases.yaml / analysis.yaml へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{base}/{target-slug}/fixtures.yaml`・SUT テストコード（受領 project 配下のテストディレクトリ）。`.gitignore` は自動追記せず提案に留める。test-results.yaml / test-cases.yaml / analysis.yaml へは書き込まない |
| 標準出力（要約） | 委譲元（オーケストレータ）へ返すフィクスチャ構築結果サマリ（判定・type 別件数・fixture-architect 所見・.gitignore 追記提案・次フェーズは test-design が決定する旨） |
| 終了状態 | 対話確認をせず自動進行で fixtures.yaml + SUT テストコードを生成し委譲元へ返却。自己チェックは非対話でも省略しない |

## 関連ケース

- case-01: 対話モードでの確認フロー（新規 slug 解決・対話確認）
- case-03: no-op 判定（本ケースも非対話だが fixture 有効側）
- case-06: 書き込み境界・認証情報の安全性（非対話でも同じ不変条件）
