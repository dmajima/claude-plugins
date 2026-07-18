# case-03 ランナー不在・テストコード不在 → skipped

対象プロジェクトにテストランナー（またはテストコード）が存在しないケース。実行を偽装せず scope 全ケースを skipped + reason で返すことを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260717-160000 / 対象ケース TC-UNIT-001〜002 / 対象プロジェクト情報 |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由） |
| 前提 | 構成ファイル（pyproject.toml / package.json 等）にテスト設定がなく、テストコードも存在しない |

## 分岐の根拠

SKILL.md「実行フロー」手順 2・「重要な制約」（偽装禁止・導入を試みない）、references/unit-execution.md 1.4（検出不能時の判定）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（条件付き動的検証: テストランナー検出不可 → skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 3 章（skipped の reason 必須）。

## 期待動作

- 構成ファイルの Glob / Grep 探索でランナーを特定できないことを確認したうえで、scope 全ケース（TC-UNIT-001〜002）を skipped と判定する
- 各エントリの reason に実際の原因を記載する（例: 「テストランナー未検出（pyproject.toml / package.json 等にテスト設定なし）」「テストコード不在（tests/ 配下に対象テストなし）」）
- テストランナー・依存パッケージの導入（pip install / npm install 等）を試みない（環境構築は test-setup の責務）
- skipped を「テスト成功」「問題なし」と書き換えない（未実施を問題なしと書かない）
- scope 全件について 1 エントリずつ返却する（skipped でも欠落させない。finish-run 突合の前提）
- 中間結果 JSON を返却し、test-results.yaml への書き込みを行わない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（実行手段不在のため実行せず、エビデンス移送も発生しない）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-unit" / 受領 run_id / results 2 件・各エントリに実際の原因を記した reason 付き）を 1 コードブロックで返却。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件（TC-UNIT-001〜002）を 1 エントリずつ skipped で返却（欠落させず、pass への書き換えもしない） |

## 関連ケース

- case-01: ランナーあり（実行の分岐）
- case-05: ランナーはあるが対応付け不能（blocked / skipped の使い分け）
