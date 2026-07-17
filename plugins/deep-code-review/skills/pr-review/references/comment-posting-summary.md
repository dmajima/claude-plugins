# Step 7 詳細: サマリースレッド投稿・投稿順序・署名（セクション 7.5〜7.7）

`pr-review` スキル Step 7 のサマリースレッド投稿に関する詳細実装。統一フォーマット・投稿順序・署名を扱う。

> **親ファイル**: [`comment-posting.md`](comment-posting.md)（Step 7 の概要・セクションマップ）。インラインコメント投稿（セクション 7.0〜7.4）は [`comment-posting-inline.md`](comment-posting-inline.md) を参照。

---

## 7.5 サマリースレッドの仕様（必須・統一フォーマット）

レビュー終了時には PR 全体宛の **サマリースレッド** を投稿する（`threadContext.filePath == null` の thread）。**毎回同一のレイアウトで** 投稿し、読み手が同じ位置で同じ情報を見つけられるようにする。

> **位置付け**: サマリー本文は **`${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/template/output/review-summary.md` の統一テンプレート** をそのまま投稿する。本ファイルは「投稿時の運用ルール」のみを記述する。
> テンプレートと本ファイルの記述に差分が出た場合は **テンプレートが優先**。

### 7.5.0 投稿方式の必須原則（新規スレッド限定・最終投稿位置・必須）

PR レビューサマリーは **各回のレビューが完了した最終投稿** として **新規のスレッドに投稿する**。
**前回（過去回）のサマリースレッドの配下（reply）には投稿しない**。

| 区分 | 必須 / 禁止 | 内容 |
|------|------------|------|
| **新規スレッドへの投稿** | **必須** | 毎回のレビューサマリーは独立した新規スレッドとして起こす（`threadContext == null` の新スレッドを POST する）。第 1 回・第 2 回…と回を重ねても、回ごとに別の新規スレッドを作成する |
| **既存サマリースレッドへの reply 投稿** | **禁止** | 前回（過去回）のサマリースレッドへ `comments` を追加する形でサマリーを投稿してはならない。読み手が「最新サマリー」を識別できなくなり、CI / Bot 通知の宛先も曖昧になるため |
| **投稿タイミング（順序）** | **必須** | 各回のレビューで、インラインコメント（指摘ごと）を全件投稿し終えた **後** に、最終投稿としてサマリースレッドを新規作成する。サマリー本文に Finding ID リンクが正しく埋まることを保証する（インラインの thread_id が確定後にサマリーを生成するため） |
| **旧サマリースレッドの扱い** | **必須** | 新サマリー投稿の直前に、前回までの自著サマリースレッドを `status=closed` に更新する（7.5.5 参照）。**reply を投稿するのではなく、旧スレッドはクローズし、新スレッドを別途立てる** という運用 |
| **対象スレッドの抽出** | **対象外** | 再レビュー時の既存スレッド処理（Pattern A/C）から **PR 全体宛サマリースレッドは対象外**（`re-review-flow.md` セクション 4）。reply / status 変更どちらも行わない |

#### 投稿フロー（標準・必須順序）

```
1. インラインコメント（CR-001 〜 CR-NNN）を 1 件ずつ POST
   → 各 thread_id を控える
2. サマリー本文に Finding ID リンクを埋め込み（7.0.4 の URL 形式で）
3. 旧自著サマリースレッド（過去回のサマリー・自著限定）を status=closed に更新
   ※ 自著判定（author-identity.md）で他者起票のスレッドは触らない
   ※ auto-resolve=false 指定時 / MD 出力モードでは実 PATCH せず、
     完了報告に「実投稿時の closed 化アクション」を含める（7.5.5.1）
4. サマリースレッドを **新規スレッドとして** POST（threadContext == null）
5. 完了報告（Step 8）に新サマリー Thread ID と旧サマリー closed 件数を明記
```

#### よくある誤実装と是正

| 誤実装 | 是正 |
|--------|------|
| 前回サマリースレッドへ `threads/<旧サマリーID>/comments` で reply を POST する | 旧サマリーは `status=closed` に PATCH し、サマリーは別の新規スレッドとして `threads` に POST する |
| サマリーをインラインコメントより先に投稿し、ID リンクが空のままにする | インラインコメント投稿後に新サマリーを生成・投稿する |
| サマリー投稿後に追加のレビューコメントをサマリースレッドにぶら下げる | サマリーは各回のレビュー **最終投稿**。追加コメントが必要なら次回レビューの新規サマリーで扱う |

### 7.5.1 必須レイアウト（テンプレート準拠）

サマリースレッド本文は **必ず以下のセクション順** で構成する（`template/review-summary.md` を参照）。
各 H2 セクションは `<details><summary><見出し></summary>` + `<h2>` 再掲の折り畳み形式・内部 HTML 記法で出力する（タイトル行・ヘッダブロックは折り畳み対象外）:

1. **タイトル行**: `# 🤖 [deep-code-review-plugin] PR レビューサマリー （第 <N> 回）`
2. **ヘッダブロック** (`> ...` 引用): レビュー結果（統合フィールド）/ 件数 / 実施日時 / 対象 head SHA / レビュー対象 / レビューモード
3. `<details><summary>1. 対応が必要な指摘 （<X> 件 <状態記号>）</summary>...`
4. `<details><summary>2. 改善提案 （<X> 件 <状態記号>）</summary>...`
5. `<details><summary>3. スコープ外指摘 （<X> 件 <状態記号>）</summary>...`
6. `<details><summary>4. 観点別の指摘なし</summary>...`
7. `<details><summary>5. 観点間の見解の差異</summary>...`
8. `<details><summary>6. 既存指摘の解消判定 （<X> 件 ／ 再レビュー時のみ）</summary>...`
9. `<details><summary>7. 未確認事項・制約</summary>...`
10. `<details><summary>8. 集計</summary>...`
11. `<details><summary>9. レビュー実施環境（PR レビュー時のみ）</summary>...`

各セクションは「該当なし」のときも `<details>` ブロックを残し本文に「該当なし」と記載する（ブロックを削除しない）。
`<状態記号>`（セクション 1〜3 の `<summary>` のみ）: 件数 >0 は「⚠」、件数 0 は「✓ + 状態語」（セクション 1 は `0 件 ✓ 指摘なし`、セクション 2・3 は `0 件 ✓ 該当なし`）。規範は `template/review-summary.md` 冒頭を参照。

### 7.5.2 ヘッダブロックの必須項目

```markdown
> **レビュー結果**: <OK（Ready to Merge） | NG・再レビュー不要（Needs Attention） | NG・再レビュー要（Needs Work）>
> **対応必須**: Critical <X> 件 / High <X> 件 / Medium <X> 件
> **改善提案**: <X> 件 ／ **スコープ外**: <X> 件
> **実施日時**: <YYYY-MM-DD HH:MM>（<タイムゾーン>） ／ **対象 head SHA**: `<sha7>`
> **レビュー対象**: <PR #<N> | branch-diff (<base>...HEAD) | file-list: ...>
> **レビューモード**: <標準 | 簡易>
```

> **注**: ヘッダ内で PR 番号を書く際は **`PR \#<N>` のように `\#` でエスケープ**するか、明示リンク `[PR #<N>](<URL>)` を使うこと。詳細は `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` セクション 5.5。

### 7.5.3 レビュー結果の判定ルール

| Critical | High | Medium | test-runner | レビュー結果（統合フィールド） |
|---------|------|--------|------------|------------------------------|
| ≥1 | * | * | * | **NG・再レビュー要（Needs Work）** |
| 0 | ≥1 | * | * | **NG・再レビュー要（Needs Work）** |
| * | * | * | RED（失敗あり） | **NG・再レビュー要（Needs Work）** |
| 0 | 0 | ≥1 | GREEN/SKIPPED/未実施 | **NG・再レビュー不要（Needs Attention）** |
| 0 | 0 | 0 | GREEN/SKIPPED/未実施 | **OK（Ready to Merge）** |

判定の根拠:
- Critical / High は **本番品質・セキュリティ・SSOT 規範違反** 等、修正なしではマージ不可
- Medium 以下は **設計上の改善余地・命名・ドキュメント整備** 等、軽微で次バージョンへの持ち越しが許容される

> **Verdict に関わらずサマリー投稿は必須（MANDATORY）**: 上記のいずれの判定結果においても、
> サマリースレッドの投稿は **省略しない**。Verdict = OK（Ready to Merge）の場合でも、
> レビュー実施の証跡として「セクション 1: 0 件 ✓ 指摘なし」のサマリーを投稿する。
> OK 判定でサマリーを省略すると、「レビュー未実施」と「レビュー済み・OK」の区別がつかなくなる。

### 7.5.4 既存指摘の解消判定との関係（再レビュー時）

再レビュー時、**既存指摘の解消判定** は以下のように扱う:

- 既存スレッドが「未解消」に判定された場合、その指摘の元の重要度で判定に含める
- 既存スレッドがすべて「解消」かつ新規発見が Medium 以下なら **Needs Attention 以下** に下がる
- 新規発見が High 以上の場合、既存指摘の解消状況に関わらず **Needs Work**

詳細は `re-review-flow.md` を参照。

### 7.5.5 旧サマリーの扱い

新サマリー投稿時は、**旧サマリースレッドを `status=closed`** に更新する（複数の active なサマリーが残らないようにする）。
**新サマリーは「新規スレッド」として POST する**（旧サマリースレッドへの reply としては投稿しない・7.5.0 参照）。
旧サマリースレッドの操作は **`status=closed` への PATCH のみ**（`comments` への追加は行わない）。

Azure DevOps の場合は connector:azure に委譲する:

```text
Skill(skill: "connector:azure", args: "PR URL: <PR_URL> のスレッド <旧サマリーID> のステータスを closed に変更。承認済み。")
```

GitHub の場合は connector:github に委譲する:

```text
Skill(skill: "connector:github", args: "PR URL: <PR_URL> のスレッド <旧サマリーID> を resolve。承認済み。")
```

### 7.5.5.1 auto-resolve=false / MD 出力モード時の旧サマリー扱い（必須）

`auto-resolve=false` 指定時 / MD 出力モード（API 投稿せず MD ファイルへのみ書き出すモード）では、旧サマリーへの実 PATCH は行わない。
ただし完了報告（Step 8）に **「実投稿時に必要な旧サマリー closed 化アクション」を必ず含める**:

```markdown
## 旧サマリー closed 化推奨アクション（実投稿時に必要）

| 旧サマリー Thread ID | 投稿日時 | 推奨アクション |
|---------------------|---------|--------------|
| 127109 | 2026-04-25 09:30 | `status=closed` に更新（新サマリー投稿前） |
| 127115 | 2026-04-26 14:00 | 同上 |
| 127117 | 2026-04-27 11:00 | 同上 |

実投稿時のフロー:
1. 上記の旧サマリー Thread ID を `status=closed` に PATCH（自著限定 + 1 件ずつ確認）
2. 新サマリースレッドを投稿
3. 完了前チェックリスト B-1.7-5（active なサマリースレッド 1 件のみ）を再検証
```

これにより、`auto-resolve=false` 指定時や MD 出力モードでもユーザーが「実投稿時に何をすべきか」をその場で把握でき、手作業や次回フルラン時の手順が明確になる。

### 7.5.6 複数 active サマリーが残った場合の収束手順

旧サマリーの `status=closed` 化が部分失敗すると、PR 上に複数の active なサマリースレッドが残り得る。完了前チェックリスト B-1.7-5 で検出された場合、以下の手順で収束する:

Azure DevOps の場合は connector:azure に委譲する:

```text
# 1. スレッド一覧を取得
Skill(skill: "connector:azure", args: "読み取りのみ。PR URL: <PR_URL> のスレッド一覧を取得して")

# 2. 取得結果から active かつ threadContext == null のスレッドを抽出し、最新 1 件以外を closed
# （抽出・ソートは pr-review 側で行い、各スレッドの closed 化を connector に委譲）
Skill(skill: "connector:azure", args: "PR URL: <PR_URL> のスレッド <OLD_ID> のステータスを closed に変更。承認済み。")
```

GitHub の場合は connector:github に委譲する:

```text
# スレッド一覧を取得し、最新以外を resolve
Skill(skill: "connector:github", args: "読み取りのみ。PR URL: <PR_URL> のレビュースレッド一覧を取得して")
Skill(skill: "connector:github", args: "PR URL: <PR_URL> のスレッド <OLD_ID> を resolve。承認済み。")
```

**注意**: 自動収束は **自著サマリーのみ対象**。他者起票のサマリーは触らない。
収束後、最新 1 件のみが active であることを再確認。

### 7.5.7 投稿前の必須チェックリスト

サマリー / インラインコメントを問わず、PR にコメントを投稿する前に **`${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` セクション 5.6（投稿前チェックリスト）** を全項目通過すること。
チェックリスト未通過の本文を API 投稿してはならない。

---

## 7.6 投稿順序（必須）

1. **インラインコメント**（CR-001, CR-002, ... の順に個別投稿）
2. **旧自著サマリースレッドを `status=closed` に更新**（7.5.5 参照）
3. **サマリースレッド**（全インラインコメント投稿完了後に最後に新規スレッドとして投稿）

この順序を逆転させてはならない。理由:

- サマリースレッド内の Finding ID リンク URL に threadId が必要（インラインコメント投稿後に API レスポンスから取得）
- PR 上の表示順序がインライン→サマリーとなり、閲覧者が自然に確認できる
- 旧サマリーを closed にしてから新サマリーを投稿することで、active なサマリーが常に 1 件のみになる

---

## 7.7 署名（connector 自動付加・pr-review は関与しない）

署名の付加は **connector が投稿直前に自動実行** する。pr-review は署名を本文に含めない。

**SSOT**: connector プラグインの `references/signatures.md`（別プラグインのためパス直接参照はしない。connector インストール環境で自動適用される）

### pr-review の責務

- 投稿本文に署名を **含めない**（connector が自動付加する）
- 投稿前バリデーションの `[SIGNATURE]` 項目は **廃止**（connector 側で検証）
- 操作マーカーが必要な場合は connector 呼び出し時の args に `marker: <マーカー文字列>` を指定する

### connector が付加する署名の形式

マーカーなし: `🤖 Generated with [Claude Code](https://claude.ai/claude-code)`
マーカーあり: `🤖 Generated with [Claude Code](https://claude.ai/claude-code)（[{マーカー文字列}]）`

署名は常に 1 行。詳細は `signatures.md` を参照。
