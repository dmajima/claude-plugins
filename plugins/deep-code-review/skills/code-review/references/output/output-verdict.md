# レビュー結果・未確認事項・ファイル出力・出力例

親（索引・セクションマップ）: [`output-format.md`](output-format.md)

本ファイルは出力フォーマットの詳細のうち、以下のセクションを収録する。

- セクション 3（レビュー結果）: 3.1 判定マトリクス / 3.2 例外 / 3.3 推奨アクション
- セクション 4（未確認事項・制約セクション）: 4.1 状態語彙 / 4.2 SKIPPED 時の必須記載項目
- セクション 5（ファイル出力）
- セクション 6（出力例・Ready to Merge / 簡略・折り畳み形式）

出力フォーマット構成（セクション 1）・Finding ID 採番（セクション 1.5）・指摘/改善提案ごとの必須項目（セクション 2）は [`output-format-details.md`](output-format-details.md) を参照。

---

## 3. レビュー結果

### 3.1 判定マトリクス

| Critical | High | Medium | test-runner | レビュー結果（統合フィールド） |
|---------|------|--------|------------|------------------------------|
| ≥1 | * | * | * | **NG・再レビュー要（Needs Work）** |
| 0 | ≥1 | * | * | **NG・再レビュー要（Needs Work）** |
| * | * | * | RED（失敗あり） | **NG・再レビュー要（Needs Work）** |
| 0 | 0 | ≥1 | GREEN/SKIPPED/未実施 | **NG・再レビュー不要（Needs Attention）** |
| 0 | 0 | 0 | GREEN/SKIPPED/未実施 | **OK（Ready to Merge）** |

### 3.2 例外（より厳しい側を採用）

エージェントの総合評価が以下のいずれかを返した場合、Issues の重要度集計に関わらず **NG・再レビュー要（Needs Work）** とする。

- security-engineer が `VULNERABLE`
- architect が `RETHINK REQUIRED`
- linter-static-analysis が `FAIL`（コンパイルエラー等）
- dependency-safety が `UNSAFE`
- test-runner が `RED`
- 任意エージェントが `NEEDS REVISION`（High 相当の指摘を伴う場合）

### 3.3 レビュー結果ごとの推奨アクション（1 文で添える）

| レビュー結果 | 推奨アクション |
|------------|---------------|
| **OK（Ready to Merge）** | 必須修正なし。改善提案は任意検討の上、マージ可。 |
| **NG・再レビュー不要（Needs Attention）** | Medium 指摘を確認・対応の判断後、マージ可否を決定する。 |
| **NG・再レビュー要（Needs Work）** | Critical/High 指摘の修正と再レビューが必要。 |

---

## 4. 未確認事項・制約セクション（必須）

ビルド未実施・テスト SKIPPED・CVE 未スキャン等を **明示的に記載** し、「問題なし」と誤認されないようにする。
**該当しない項目は行を削除せず「対象外」と書く**（読み手が「未記載なのか・未実施なのか・対象外なのか」を判別できるようにする）。

### 4.1 状態語彙（SSOT・全プラグイン共通）

すべての観点別スキル・オーケストレーターが返す中間レポート / 統合サマリで **以下の語彙を統一して使用する**。表記揺れ禁止。

| 状態語 | 意味 | 使う場面 |
|--------|------|--------|
| `EXECUTED` | 実施済み（成功） | 動的検証エージェントが実行成功時 |
| `EXECUTED(警告N件)` / `EXECUTED(検出N件)` | 実施済み（警告/検出あり）| 数値があれば併記 |
| `PASS` | 実施済み・合格 | ビルド成功 / テスト全件 GREEN 等 |
| `FAIL` | 実施済み・失敗 | ビルド失敗 / テスト RED |
| `GREEN` / `RED` | テスト合否（test-runner 専用） | test-runner ステータスのみ |
| `SKIPPED（理由: <内訳>）` | 未実施（実施可能だが意図的にスキップ） | 権限なし / コマンド未導入 / タイムアウト / 依存差分なし |
| `未実施` | 実施していない（理由なし or 別手段で確認済み） | 該当検証コマンドが本セッションで動作不能 |
| `対象外` | そもそも適用対象外 | 該当しない項目（DB 変更なしの dba 等） |

### 4.2 SKIPPED 時の必須記載項目

`SKIPPED` を出力する場合、**理由を必ずカッコ書きで併記** する。理由は以下の語彙から選ぶ:

| 理由語 | 意味 |
|--------|------|
| `権限なし` | `allowed-tools` に必要な Bash 権限が未追加 |
| `コマンド未導入` | プロジェクトに Linter / テストランナー等が未インストール |
| `テスト基盤なし` | テストプロジェクト自体が存在しない |
| `タイムアウト` | 実行したが規定時間内に完了せず |
| `依存差分なし` | CVE スキャン対象の依存定義ファイルに変更なし |
| `本スキルのスコープ外` | レビュースキル本体ではなく観点別スキルでのみ実施 |

例:
- `SKIPPED（理由: 権限なし）`
- `SKIPPED（理由: コマンド未導入: dotnet）`
- `SKIPPED（理由: 依存差分なし）`

```markdown
## 7. 未確認事項・制約

| 項目 | 状態 | 理由 | 影響 |
|------|------|------|------|
| ビルド | 実施済(PASS) / 実施済(FAIL) / SKIPPED / 対象外 | 実行コマンド・所要時間 / SKIP の場合は権限なし・コマンド未導入・タイムアウト等を明記 | コンパイル可否・警告検出の状況 |
| Linter / 整形チェッカ | 実施済(警告N件) / SKIPPED / 対象外 | 実行コマンド / SKIP 理由 | 規約違反検出の状況 |
| ユニットテスト実行 | 実施済(GREEN) / 実施済(RED) / SKIPPED / 対象外 | 実行コマンド・pass/fail 件数 / SKIP 理由 | 回帰確認の状況 |
| CVE スキャン | 実施済(検出N件) / SKIPPED / 対象外 | 実行コマンド（例: `dotnet list package --vulnerable` / `npm audit` / `pip-audit` / `govulncheck` 等）/ SKIP 理由（依存差分なし・コマンド未導入・権限なし等） | 既知脆弱性の評価状況 |
| PR 差分取得 | 取得済 / SKIPPED | `gh` 未導入時は SKIPPED | PR レビュー範囲の制約 |
| 大規模差分の絞り込み | あり / なし | 50 ファイル超等で部分レビューに限定 | レビュー対象範囲の制約 |
```

**「未実施」の項目を「問題なし」と書き換えてはならない**。

---

## 5. ファイル出力

review-summary.md は Step 8.5 でプラグインデータ領域に自動出力される。ユーザーが「ファイルに保存」「レポートを出して」等と要求した場合は、出力済みの以下のパスを案内する。

```
.claude/.local/plugins/deep-code-review/{branch_name}/{yyyyMMdd_HHmmss}/review-summary.md
```

> **禁止**: `.claude/.local/work/` 配下に review-summary.md を保存すること。
> review-summary.md は state.yaml と同一のレビュー実施フォルダに配置し、ブランチ単位で永続化する。

---

## 6. 出力例（Ready to Merge / 簡略・折り畳み形式）

タイトル行 + ヘッダブロックは Markdown のまま、各 H2 セクションは `<details><summary>` 折り畳み + 内部 HTML 記法で出力する。完全な実体は `template/review-summary.md` を参照（template が常に優先）。

````markdown
# 🤖 [deep-code-review-plugin] PR レビューサマリー （第 1 回）

> **レビュー結果**: OK（Ready to Merge）
> **対応必須**: Critical 0 件 / High 0 件 / Medium 0 件
> **改善提案**: 2 件 ／ **スコープ外**: 0 件
> **実施日時**: 2026-04-27 14:30 (JST) ／ **対象 head SHA**: `a3c4d5e`
> **レビュー対象**: PR \#45
> **レビューモード**: 標準

<details>
<summary>1. 対応が必要な指摘 （0 件 ✓ 指摘なし）</summary>
<h2>1. 対応が必要な指摘 （0 件）</h2>

<p>指摘なし</p>

</details>

---

<details>
<summary>2. 改善提案 （2 件 ⚠）</summary>
<h2>2. 改善提案 （2 件）</h2>

<h3>2-A. 提案サマリー（表形式・必須）</h3>

<table>
    <tr>
        <th>ID</th>
        <th>Impact</th>
        <th>Effort</th>
        <th>カテゴリ</th>
        <th>タイトル</th>
        <th>該当箇所</th>
        <th>担当</th>
    </tr>
    <tr>
        <td>CR-001</td>
        <td>MED</td>
        <td>LOW</td>
        <td>可読性</td>
        <td>OrderService の早期 return リファクタ</td>
        <td><code>src/order/OrderService.cs:120-145</code></td>
        <td>impl</td>
    </tr>
</table>

<h3>2-B. 詳細補足（インライン未投稿の提案のみ）</h3>

<h4>CR-001: OrderService の早期 return リファクタ</h4>

<strong>該当コード</strong>

<pre><code class="language-csharp">if (order != null) {
    if (order.IsValid) {
        // 処理...
    }
}
</code></pre>

<strong>提案内容</strong>

<p>ネスト 3 段の if を早期 return に書き換えると可読性が向上する。</p>

<strong>理由・根拠</strong>

<p>プロジェクト規約（Clean Code 原則）に基づく。</p>

</details>

---

<details>
<summary>3. スコープ外指摘 （0 件 ✓ 該当なし）</summary>
<h2>3. スコープ外指摘 （0 件）</h2>

<p>該当なし。</p>

</details>

（以下、セクション 4〜9 も同形式の `<details>` ブロックで続ける。各セクションの内部構造は `template/review-summary.md` を参照）
````

> **注 1**: ヘッダブロックの `PR \#45` のように `\#` と書くのは Markdown 文脈での自動リンク化回避のため。`<details>` 内の HTML タグ間テキストでは `\#` エスケープを使わず「件数表記の言い換え」または `<a href>` 明示リンクを使う（詳細: `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` セクション 5.5 / 5.5.7）。
> **注 2**: `<details>` 内で Markdown のテーブル・見出し・コードフェンスがレンダリングされない制約は主に Azure DevOps / TFS のもの（GitHub は一部レンダリング可能なホスト依存挙動）。両ホスト対応のため内部 HTML 記法に統一している。
