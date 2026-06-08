# バージョン更新チェックリスト

プラグイン本体に変更があるレビュー対象（プラグイン / プラグイン同梱要素）に適用する。`common.md` の項目と併用すること。

## V-1. SemVer 形式

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| V-1-1 | High | `plugin.json` の `version` が `x.y.z` 形式（数字 + `.`） | [versioning.md](../../../references/policies/versioning.md) 節 1 / 10 |
| V-1-2 | High | `marketplace.json` に `version` が記載されていない（`plugin.json` のみが正典） | 同 節 7 |

## V-2. 1 コミット 1 バージョン更新原則

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| V-2-1 | High | プラグイン内ファイル変更を含むコミットで、`plugin.json` の `version` が **更新されている**（バグ修正・タイポでも z+1 必須） | [versioning.md](../../../references/policies/versioning.md) 節 6 |
| V-2-2 | High | 利用者環境の `/plugin update` がバージョン番号差分で更新を判定する点を踏まえ、据え置きコミットがない | 同上 |

## V-3. 桁繰り上がりルール

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| V-3-1 | Medium | メジャー（x）更新時、y / z が `0` にリセットされている（例: `1.2.3` → `2.0.0`） | [versioning.md](../../../references/policies/versioning.md) 節 3 |
| V-3-2 | Medium | マイナー（y）更新時、z が `0` にリセットされている（例: `1.2.3` → `1.3.0`） | 同上 |
| V-3-3 | Medium | パッチ（z）更新時、y / x は変更されていない（例: `1.2.3` → `1.2.4`） | 同上 |

## V-4. 更新基準の整合性

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| V-4-1 | Medium | 機能追加（新スキル / 新コマンド / 根本機能の刷新）の場合、メジャー（x）更新が選択されている | [versioning.md](../../../references/policies/versioning.md) 節 2 / 5 |
| V-4-2 | Medium | 機能改善（既存スキル拡張・新ルール・後方互換ある変更）の場合、マイナー（y）更新が選択されている | 同上 |
| V-4-3 | Medium | バグ修正・タイポ・ドキュメント整理の場合、パッチ（z）更新が選択されている | 同上 |
| V-4-4 | Medium | 複数種別が混在する場合、最も大きな更新を採用している | [versioning.md](../../../references/policies/versioning.md) 節 5 |

## V-5. ユーザ確認

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| V-5-1 | Medium | バージョン更新時に AskUserQuestion でユーザに確認している（変更内容と提案バージョンを提示） | [versioning.md](../../../references/policies/versioning.md) 節 8 |

## V-6. CHANGELOG / 履歴管理

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| V-6-1 | Medium | プラグイン内に `CHANGELOG.md` が存在しない（Git コミット履歴で代替） | [versioning.md](../../../references/policies/versioning.md) 節 9 |

## V-7. extension-toolkit 同梱フックとの連携

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| V-7-1 | Medium | Stop フック（ADR-026）の警告が無視されていない（更新漏れがあれば修正済み） | [architecture-decisions.md](../../../references/architecture/decisions-001-010.md) ADR-026 |
| V-7-2 | Medium | PreToolUse Bash（ADR-027）の `git commit` 直前検証で警告が出ていない | [architecture-decisions.md](../../../references/architecture/decisions-001-010.md) ADR-027 |
