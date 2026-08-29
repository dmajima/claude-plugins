# case-16: 実装追随の標準（未実装仕様への実装の紐付け）

## 入力

```text
実装を仕様に紐付けて
```

前提: ハーネス構築済み。`harness-define` で先行作成した `specs/order-entry.md`（`status: agreed` / `sources: []` / 本文冒頭に合意ベースの定型注記あり）が存在する。最終同期コミット以降に `src/features/order/` 配下の実装ファイル群が追加され（A 群）、どのドキュメントの `sources` にもマッチしない。

## 期待動作

1. Phase 2 手順 1〜3 で既存更新・ソース移動を仕分けたのち、どの `sources` にもマッチしない追加ファイル群を **新規候補とする前に** Phase 2 手順 4 の実装追随の照合へ回す（sync-spec.md 節 2.1）
2. `status: draft` / `agreed` を **明示している** ドキュメントのみを照合対象として抽出する（`status` 不在 = `implemented` のため、用語集・ADR 等の `sources: []` ドキュメントは対象外）
3. 一次シグナル（パス・命名の類似性）、二次シグナル（実装内容と仕様記載の一致）の順で照合し、`specs/order-entry.md` への対応が一意に推定できると判定して実装追随候補とする
4. Phase 3 の反映計画に「実装追随」行として提示する（対象ドキュメントと `status`・起因する追加ファイル群・「`sources` 設定 + 記載と実装の突合 + `implemented` 昇格」）
5. AskUserQuestion で紐付け実施の可否を **必ず** 確認する（sync-spec.md 節 2.1 手順 5）
6. 承認後、Phase 4「実装追随の反映」を実施する:
   - 手順 1: `sources` へ実装パスのグロブ `src/features/order/**` を設定する（記法は structure-spec.md 節 5.1）
   - 手順 2: 記載内容と実装を突合する（本ケースは乖離なし）
   - 手順 3: `status` を `agreed` から `implemented` へ書き換え、合意ベースの定型注記（authoring-spec.md 節 1.1）を本文冒頭から除去する
   - 手順 5: 実装で確定した `TODO(未確定事項)` を解消する
7. Phase 5 で索引 `CLAUDE.md`・frontmatter `updated`・`.sync-state.json` を更新する
8. Phase 6 の検証スクリプトで、`status: implemented` のドキュメントの `sources` が `[]` のままでないこと（authoring-spec.md 節 6 の項目 11）を確認する

## 期待出力

- 反映結果表の「実装追随」件数と対象ドキュメント一覧
- 設定した `sources` の値と `status` の遷移（`agreed` → `implemented`）
- 記載と実装の突合結果（本ケースは乖離なし）
- 定型注記の除去と `TODO:` の解消数

## 禁止事項（このケースで起きてはならないこと）

- 実装追随の照合を行わず追加ファイル群を新規ドキュメント候補として扱い、同内容の仕様書を二重生成すること
- ユーザ承認なしでの `sources` 設定・`implemented` 昇格（誤設定は以後の差分検出を恒久的に歪める）
- `status` フィールドを削除して昇格を表すこと（`implemented` へ書き換える。structure-spec.md 節 5.2）
- 合意ベースの定型注記を残したまま `implemented` へ昇格すること
- 対象プロジェクトのソースコードの変更（反映はコード → ドキュメントの一方向）

## 分岐の根拠

sync-spec.md 節 2.1「実装追随」と procedures.md Phase 2 手順 4 / Phase 4「実装追随の反映」。spec-first で作成した未実装仕様を通常の同期サイクルへ合流させる経路であり、「新規ドキュメント候補」分類の処理前フィルタとして動作する（5 分類自体は増やさない）。

## 関連ケース

- [case-17](case-17_impl_followup_ambiguous.md): 対応が一意に推定できず候補提示・フォールバックとなるケース
- [case-18](case-18_impl_followup_non_interactive.md): 非対話モード（提案のみ）
- [case-20](case-20_impl_followup_divergence.md): 突合で記載と実装の乖離を検出するケース
- [case-19](case-19_full_audit_draft_protection.md): 全量監査での未実装仕様の保護と実装追随候補の提示
- [case-01](case-01_standard_update.md): 実装追随を伴わない標準の差分反映
