# case-12 pr-review 委譲時の内部データ返却（対話文なし）（C22）

`pr-review` スキルから `scope=pr-diff` で差分を受領して委譲実行された場合、統合結果をユーザー向けの対話文・整形なしの **フロー内部データ（構造化結果）** として返却するケース。単独実行時のユーザー向けテキスト返却（case-08）と対になる分岐。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `scope=pr-diff`（差分・コンテキスト・project-rules-summary・language-profiles は pr-review から受領）/ finding-thread-map.json は未生成（投稿は pr-review 側 Step 7 で後続実施） |
| モード | 委譲呼び出し（pr-review から Skill ツール経由・標準） |

## 分岐の根拠

references/flow/flow.md Step 8「pr-review から呼ばれた場合は構造化された結果をフロー内部データとして返却し、pr-review が PR にコメント追記。ユーザー向けメッセージとして整形したり『レビュー結果は以下の通りです』等の対話的な導入文を付けたりしてはならない（pr-review が受領後 Step 7 に自動進行するため）」、flow.md Step 1（`scope=pr-diff` は pr-review から渡される差分を使用・本スキルは gh pr を呼ばない）、SKILL.md「PR レビューとの関係」（依存は単方向 pr-review → code-review・本スキルから pr-review を呼ばない）、skill-rules-matrix.md C22（pr-review 委譲時の内部データ返却）/ C12（pr-review からの委譲のみ受領・PR 識別子を直接処理しない）。

## 期待動作

- Step 1: `scope=pr-diff` のため、pr-review から渡された差分・コンテキストを使用し、PR 識別子（URL/ID）を直接処理しない。`gh pr` / `az repos` コマンドを呼ばない（C12・flow.md Step 1）
- Step 2-6: 通常フロー（言語検出・規約統合・結果統合・重複排除・Finding ID 一括採番）を実行する
- Step 7: output-format.md セクション 3 のマトリクスで Verdict を判定する
- Step 8: 統合結果を **対話文なしの内部データ（構造化結果: Finding ID・重要度・カテゴリ・該当箇所・Verdict・件数集計等）** として返却する（C22・flow.md Step 8）
- Step 8: 「レビュー結果は以下の通りです」等の対話的な導入文・ユーザー向け整形を付けない（pr-review が受領後 Step 7〈PR コメント投稿〉に自動進行するため）
- Step 8.5: state.yaml を規定パス（`.claude/.local/plugins/deep-code-review/{branch}/{timestamp}/`）に出力する。finding-thread-map.json が未生成のため各 finding の `pr_thread_id` は null とし、pr-review 投稿後の Thread ID 転記は後続に委ねる（flow.md Step 8.5-4 の受渡しインターフェース）
- 本スキルから `pr-review` を呼び出さない（循環参照防止・C12・SKILL.md「PR レビューとの関係」）
- （以下は検出してはならない誤り）
    - 返却に「レビュー結果は以下の通りです」等の対話的導入文やユーザー向け整形を付ける（C22 違反）
    - PR 識別子を直接処理して `gh pr view` / `az repos pr` 等を実行する（C12 違反）
    - code-review から pr-review を呼び出す（循環参照）
    - 委譲実行なのに単独実行と同じユーザー向けテキストサマリをメインコンテキストへ返す

## 関連ケース

- case-08: 単独実行（マージ可否判断）でのユーザー向けテキスト返却との対比
- case-01: 標準モードの基本フロー（Step 5-8 の統合処理）
