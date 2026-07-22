# case-13 非対話モード × 既存 target-slug 単一（自動採用とフィクスチャ構築続行）

`--non-interactive` でのフィクスチャ基盤構築委譲で、target-slug 未受領かつ唯一の既存 target-slug が存在する場合に、その slug を自動採用して構築を続行することを検証する。採用根拠（唯一の既存 slug）を返却に明記する。既存 slug 複数のエラー中断（case-11）と対になる。target-slug（データ配置領域）の解決分岐であり、フィクスチャ対象そのものの不在（case-07 / 08）とは別軸である。test-analyze case-08 の対応ケース様式に倣う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=./ project=./ --non-interactive`（`target-slug=` の指定なし） |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 1.6・非対話）/ 単独起動でも同一挙動 |
| 前提 | 基準ディレクトリ配下の既存 `{target-slug}/` は **1 件のみ**（`orderapp-web/`）/ SUT ソース・`analysis.yaml` は取得可 / `spec=` 等の他分岐要因なし |

## 分岐の根拠

SKILL.md「実行モード判定」（非対話: target-slug は data-locations.md 4.2 章の非対話規則〔唯一の既存 slug 採用・複数はエラー中断〕）・「前提」の引数表（`target-slug=` 未指定時は data-locations.md 4 章の解決フロー）、SKILL.md「実行フロー」1（入力解決・target-slug 確定）、`${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` 2 章（target-slug 未受領時は data-locations.md 4 章の解決フロー）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.1 章（1 対象 1 slug・再テスト / 追加テストでは既存 slug を再利用）・4.2 章（非対話時は唯一の既存 slug を採用）、同 `execution-policy.md` 9 章（非対話既定値表: target-slug は複数のみエラー中断・唯一の既存は採用）。

## 期待動作

- AskUserQuestion を一切呼ばない（非対話モード）
- target-slug が未受領のため data-locations.md 4 章の解決フローに入り、唯一の既存 slug（`orderapp-web`）を自動採用する（新規 slug を作らない・確認も挟まない）
- 採用根拠（唯一の既存 slug のため）を返却に明記する
- 採用した slug の `analysis.yaml` を消費してフィクスチャ要否を判定し、必要ならフィクスチャ基盤（認証 storageState / API モック / シード / base）と fixtures.yaml・SUT テストコードを生成する。**同一 slug への再構築 / 拡充**であり、1 対象 1 slug の再利用に沿う（data-locations.md 4.1 章）。生成内容そのものは case-01 / case-02 と同等で、本ケースは slug 解決分岐の検証が主眼
- no-op 条件（非 web / unit のみ / 材料なし）に該当する場合は SUT へ書かず空 fixtures.yaml + 理由で正常終了する（case-03 の不変条件は維持）
- 生成後に `fixture-architect` を単独起動して自己チェックし、重大指摘を反映してから返却する（非対話でも省略しない）
- 書き込み境界を維持: SUT のテストディレクトリ以外（`test-results.yaml` / `test-cases.yaml` / `analysis.yaml`）へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `orderapp-web/` 配下（＝唯一の既存 slug を自動採用）の fixtures.yaml と SUT テストコード（fixture 有効時。no-op 時は空 fixtures.yaml + 理由）。test-results.yaml / test-cases.yaml / analysis.yaml へは書き込まない |
| 標準出力（要約） | 自動採用の根拠（slug = 唯一の既存）を明記した構築結果サマリ（採用 slug・消費した analysis.yaml・生成 / 拡充した fixture 種別・status・fixture-architect 所見・次フェーズは test-design がケースの `fixtures:` 参照を決める旨） |
| 終了状態 | AskUserQuestion を呼ばず唯一の既存 slug を自動採用してフィクスチャ基盤を構築し委譲元へ返却。自己チェックは非対話でも省略しない |

## 関連ケース

- case-11: 同じ非対話で既存 slug が複数の場合（自動選択せずエラー中断する側。本ケースの対）
- case-14: 同じ非対話で既存 slug が 0 件の場合（対象名から新規自動生成する側。本ケースは既存 1 件の再利用）
- case-04: 非対話で target-slug / base / project が付与済みの自動進行（slug 解決が不要な側）
- case-12: 対話モードでの既存 slug 選択（AskUserQuestion 使用）
- case-07 / 08: フィクスチャ対象・材料の不在（本ケースとは別軸。slug 解決ではなく対象の不在）
