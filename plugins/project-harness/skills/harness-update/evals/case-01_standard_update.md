# case-01: 標準の差分反映（対話モード）

## 入力

```text
/project-harness:update
```

前提: ハーネス構築済み。最終同期コミットから 12 コミット進行（`src/auth/` の修正 + `src/report/` の新機能追加を含む）。

## 期待動作

1. `.sync-state.json` から最終同期コミットを読み、`git diff --name-status` で変更ファイル一覧を取得する
2. 全ドキュメントの frontmatter `sources` と照合し、4 分類の反映計画を作成する
3. 反映計画（更新 / 新規 / 整理候補の表）が提示され、AskUserQuestion で対象を確定する
4. 更新は diff を読んで乖離箇所のみ修正（全体書き直しなし）。新規はテンプレートから生成し `sources` を設定する
5. 影響フォルダの `CLAUDE.md` 索引・frontmatter `updated` が同期される
6. `.sync-state.json` が HEAD へ更新される

## 期待出力

- 反映結果表（更新 / 新規 / 整理提案の件数と一覧）
- `TODO:` の解消数・新規発生数
- 未コミット変更の有無

## 禁止事項（このケースで起きてはならないこと）

- 対象プロジェクトのソースコード変更（反映はコード → ドキュメントの一方向）
- 確認できない内容の推測記載（`TODO:` 明示なしの捏造）
- 索引 `CLAUDE.md` の同期漏れ
- 反映に伴う `.claude/CLAUDE.md` の 100 行超過（超過しそうな場合は `references/` へ委譲）

## 分岐の根拠

SKILL.md 実行フロー 1〜7 の正常系。Phase 1 の全検査が通過し、「更新」「新規」分類を対話確認しながら反映する基本経路。

## 関連ケース

- [case-04](case-04_non_interactive.md): 同フローの非対話版
- [case-02](case-02_no_drift.md) / [case-03](case-03_harness_missing.md) / [case-06](case-06_state_corrupted.md) / [case-07](case-07_unreachable_sha.md): Phase 1 検査で分岐するケース群
- [case-05](case-05_deleted_sources.md) / [case-08](case-08_harness_direct_edit.md): 他の影響分類（整理候補 / ハーネス直接編集）
- [case-09](case-09_bulk_reflection_delegation.md): 反映対象が多くエージェント委譲となるケース
