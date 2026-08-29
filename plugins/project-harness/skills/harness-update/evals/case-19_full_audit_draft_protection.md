# case-19: 全量監査での未実装仕様の保護

## 入力

```text
/project-harness:update --full
```

前提: ハーネス構築済み。`harness-define` で先行作成した `specs/order-entry.md`（`status: agreed` / `sources: []`）と `specs/inventory-alert.md`（`status: draft` / `sources: []`）が存在する。前者に対応する実装 `src/features/order/` 配下は既に存在するが `sources` は未設定のまま。後者に対応する実装は未着手。`glossary.md` は `sources: []` かつ `status` 不在。

## 期待動作

1. Phase 2F で差分検出をスキップし、`references/` 配下の全ドキュメントを対象とする
2. 各ドキュメントの `sources` が指すソースの実在を確認する。ただし **`status: draft` / `agreed` のドキュメントと `sources: []` のドキュメントは整理候補の対象外** とする（sync-spec.md 節 4 の保護・procedures.md Phase 2F 手順 1）
3. `sources: []` のドキュメントは記載内容とコード実態を突合する。未実装仕様は実装が無いことが前提のため、記載の自己整合と索引整合のみを確認する（Phase 2F 手順 2）
4. `status: draft` / `agreed` のドキュメントに対応する実装が既に存在しないかを確認し、`specs/order-entry.md` を実装追随候補として提示する（Phase 2F 手順 3・sync-spec.md 節 2.1）
5. `specs/inventory-alert.md` は対応実装が存在しないため据え置く（整理候補にも実装追随候補にもしない）
6. `glossary.md` は `sources: []` のため整理候補にはせず、記載内容とコード実態の突合のみ行う
7. 検出結果を Phase 3 の反映計画として提示し、実装追随はユーザ承認のうえ実施する（以降は case-16 と同じ）
8. 完了時に `.sync-state.json` を HEAD で更新する

## 期待出力

- 全量監査の対象件数と、保護対象（未実装仕様・`sources: []` ドキュメント）として整理候補から除外した件数
- 実装追随候補の一覧（`specs/order-entry.md` と対応が推定される実装パス）
- 据え置いたドキュメント（`specs/inventory-alert.md`）とその理由

## 禁止事項（このケースで起きてはならないこと）

- `status: draft` / `agreed` のドキュメントを「対応ソース 0 件」として削除・アーカイブ提案すること（未実装仕様では 0 件が正常）
- `sources: []` のドキュメント（用語集・規約・根拠ファイルのない ADR）を整理候補にすること
- 未実装仕様に対し「実装が存在しない」ことを乖離として扱い、記載を書き換えること
- 対応実装が既に存在する `agreed` ドキュメントを実装追随候補として提示せず素通りすること
- 保護対象ドキュメントの `status` を無確認で変更すること

## 分岐の根拠

sync-spec.md 節 4「保護」と procedures.md Phase 2F 手順 1〜3。全量監査は `sources` の実在確認を全ドキュメントへ広げるため、対応ソースが 0 件である未実装仕様が整理候補へ誤混入しやすい経路であり、保護（削除提案の禁止）と実装追随候補の検出を独立に検証する必要がある。

## 関連ケース

- [case-14](case-14_full_audit.md): 全量監査モードの基本形
- [case-05](case-05_deleted_sources.md): 実際に対応ソースが削除された整理候補（保護対象との対比）
- [case-16](case-16_impl_followup_standard.md): 差分検出経路での実装追随
- [case-18](case-18_impl_followup_non_interactive.md): 非対話モードで実装追随が提案止まりとなるケース
