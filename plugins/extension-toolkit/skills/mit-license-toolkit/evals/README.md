# Evals: mit-license-toolkit

`mit-license-toolkit` の動作分岐の期待挙動を例示する。`eval-guide.md` 節 2 / 6 のディレクトリ構造に準拠する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 | 関連ケース |
|-------|-----|-------------|-----------|
| [case-01](case-01_apply_single_entry.md) | `license-info.json` 1 件のみ → 自動適用 | `licenses[]` が 1 件のとき AskUserQuestion を呼ばずに即適用 | case-02（複数時の選択UI） |
| [case-02](case-02_select_among_multiple.md) | 複数エントリから AskUserQuestion で選択 | `licenses[]` が 2 件以上のとき選択 UI 必須 | case-01 / case-03 |
| [case-03](case-03_collect_when_absent.md) | 不在時の新規収集 + 保存可否確認 | ストア不在 / `licenses[]` 空 → テキスト対話で収集、保存可否は AskUserQuestion | case-02（既存複数時）/ case-04（非対話時の保存） |
| [case-04](case-04_non_interactive.md) | 非対話モード（`--non-interactive` + 引数直接適用 + エラーシナリオ） | フラグありで AskUserQuestion を呼ばず引数値で確定 | case-01（対話自動適用）/ case-03（対話新規収集） |

## 主要分岐とカバレッジマップ

| procedures.md フェーズ / 分岐 | カバー先 |
|------------------------------|--------|
| 節 2.2 ストア不在 → 新規収集 | case-03 |
| 節 2.2 `licenses[]` 1 件 → 自動適用 | case-01 |
| 節 2.2 `licenses[]` 複数 → 選択 UI | case-02 |
| 節 3 `--license-id` 直接適用（正常 / 不一致エラー） | case-04 |
| 節 4 新規収集 + 保存可否（保存する） | case-03 |
| 節 4.3 非対話・引数不足エラー | case-04 |

## ケースファイル命名

`case-{2 桁番号}_{snake_case 名}.md` 形式（`conventions.md` 節 1 準拠）。

## 関連 SSOT

| 用途 | ファイル |
|-----|---------|
| ライセンスポリシー（SSOT） | [`../../../references/policies/license-policy.md`](../../../references/policies/license-policy.md) |
| evals 設計ガイド | [`../../../references/guides/eval-guide.md`](../../../references/guides/eval-guide.md) |
| スキル本体 | [`../SKILL.md`](../SKILL.md) |
| 詳細手順 | [`../references/procedures.md`](../references/procedures.md) |
