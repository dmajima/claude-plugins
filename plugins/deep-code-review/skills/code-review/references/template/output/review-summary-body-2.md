# レビューサマリ テンプレート本体（後半 / セクション 6〜9）

> **これはテンプレート本体の分割断片であり、この見出し・本注記自体はサマリ本文に出力しない。**
> Step 8 のサマリ生成では、親 [`review-summary.md`](review-summary.md) のヘッダブロック → [`review-summary-body-1.md`](review-summary-body-1.md)（セクション 1〜5）→ 本ファイル（セクション 6〜9）の順に **逐語で** 連結して 1 つのサマリを構成する。
> `<details>`/`<summary>`/`<h2>` 構造・セクション番号・見出し文言は改変せずそのまま出力する。引用ブロック（`> ...`）による記入指示はサマリ本文に出力しない。
> 収録セクション: 6. 既存指摘の解消判定 ／ 7. 未確認事項・制約 ／ 8. 集計 ／ 9. レビュー実施環境

<details>
<summary>6. 既存指摘の解消判定 （<X> 件 ／ 再レビュー時のみ）</summary>
<h2>6. 既存指摘の解消判定 （<X> 件 ／ 再レビュー時のみ）</h2>

> `pr-review` の再レビュー（既存自著スレッド処理）の結果を一覧化する。
> 初回レビュー時は「該当なし（初回レビュー）」と 1 行のみ記載。
> 過去 Finding ID は **可能な範囲で参照**（同一スレッドが追跡できる場合）。
> 過去 Finding ID が不明な場合は「不明」と書く。

<table>
    <tr>
        <th>#</th>
        <th>過去 Finding ID</th>
        <th>スレッド</th>
        <th>指摘箇所</th>
        <th>パターン</th>
        <th>操作</th>
    </tr>
    <tr>
        <td>1</td>
        <td><code>CR-NNN</code>（前回）/ 不明</td>
        <td><スレッドID/タイトル></td>
        <td><code><file>:<line></code></td>
        <td>A: 解消 / C: 未解消・再観察</td>
        <td><status=fixed + reply / reply のみ></td>
    </tr>
</table>

</details>

---

<details>
<summary>7. 未確認事項・制約</summary>
<h2>7. 未確認事項・制約</h2>

> ビルド未実施・テスト SKIPPED・CVE 未スキャン等を **明示的に記載**。
> 「未実施」を「問題なし」と書き換えてはならない。
> 該当しない項目は「対象外」と書く（行を削除しない）。

<table>
    <tr>
        <th>項目</th>
        <th>状態</th>
        <th>理由</th>
        <th>影響</th>
    </tr>
    <tr>
        <td>ビルド</td>
        <td>実施済(PASS) / 実施済(FAIL) / SKIPPED / 対象外</td>
        <td><理由></td>
        <td><影響></td>
    </tr>
    <tr>
        <td>Linter / 整形チェッカ</td>
        <td>実施済(警告N件) / SKIPPED / 対象外</td>
        <td><理由></td>
        <td><影響></td>
    </tr>
    <tr>
        <td>ユニットテスト実行</td>
        <td>実施済(GREEN) / 実施済(RED) / SKIPPED / 対象外</td>
        <td><理由></td>
        <td><影響></td>
    </tr>
    <tr>
        <td>CVE スキャン</td>
        <td>実施済(検出N件) / SKIPPED / 対象外</td>
        <td><理由></td>
        <td><影響></td>
    </tr>
    <tr>
        <td>PR 差分取得</td>
        <td>取得済 / SKIPPED</td>
        <td><理由></td>
        <td><影響></td>
    </tr>
    <tr>
        <td>大規模差分の絞り込み</td>
        <td>あり / なし</td>
        <td><理由></td>
        <td><影響></td>
    </tr>
</table>

</details>

---

<details>
<summary>8. 集計</summary>
<h2>8. 集計</h2>

<table>
    <tr>
        <th>項目</th>
        <th>値</th>
    </tr>
    <tr>
        <td>実施日時</td>
        <td><YYYY-MM-DD HH:MM>（<タイムゾーン>）</td>
    </tr>
    <tr>
        <td>レビューモード</td>
        <td><標準 / 簡易></td>
    </tr>
    <tr>
        <td>参加観点別スキル</td>
        <td><X> 種（<観点別スキル一覧>）</td>
    </tr>
    <tr>
        <td>参加エージェント</td>
        <td><X> 名（<エージェント一覧>）</td>
    </tr>
    <tr>
        <td>比較ブランチ</td>
        <td><origin/develop（自動判定）/ master（CLAUDE.md指定）/ PR #<N> 等></td>
    </tr>
    <tr>
        <td>対象 head SHA</td>
        <td><code><sha7></code>（<full-sha>）</td>
    </tr>
    <tr>
        <td>参照規約ファイル</td>
        <td><CLAUDE.md, .claude/rules/.../*.md, .editorconfig 等のカンマ区切り></td>
    </tr>
    <tr>
        <td>検出言語・FW と適用観点プロファイル</td>
        <td><TypeScript（主・languages/typescript.md）, React（frameworks/react.md）, SQL: PostgreSQL（副・languages/sql.md） 等。観点プロファイル未収録の言語は「Go（観点プロファイル未収録）」のように明記></td>
    </tr>
    <tr>
        <td>参照仕様書</td>
        <td><docs/specs/*.md カンマ区切り。spec 引数未指定時は「（仕様書未指定）」></td>
    </tr>
    <tr>
        <td>Critical</td>
        <td><N> 件</td>
    </tr>
    <tr>
        <td>High</td>
        <td><N> 件</td>
    </tr>
    <tr>
        <td>Medium</td>
        <td><N> 件</td>
    </tr>
    <tr>
        <td>改善提案</td>
        <td><N> 件採用 / 全 <M> 件中（10 件超があれば併記）</td>
    </tr>
    <tr>
        <td>スコープ外指摘</td>
        <td><N> 件</td>
    </tr>
    <tr>
        <td>低信頼のため除外</td>
        <td><N> 件（信頼度 60 未満・C24。0 件時も「0 件」と記載）</td>
    </tr>
    <tr>
        <td>test-runner</td>
        <td><GREEN / RED / SKIPPED / 未実施></td>
    </tr>
    <tr>
        <td>Agent Teams 採用パターン</td>
        <td><quality-assurance / security-compliance / system-design / data-quality-extended / frontend-quality-extended / 不採用（サブエージェント方式）></td>
    </tr>
    <tr>
        <td>レビュー対象</td>
        <td><ベース>...<HEAD> または PR #<N> またはファイル指定</td>
    </tr>
</table>

</details>

---

<details>
<summary>9. レビュー実施環境（PR レビュー時のみ）</summary>
<h2>9. レビュー実施環境（PR レビュー時のみ）</h2>

> `pr-review` から起動された PR レビュー時のみ記載。ブランチレビュー・ファイル指定レビューでは「該当なし」と 1 行のみ。

<table>
    <tr>
        <th>項目</th>
        <th>値</th>
    </tr>
    <tr>
        <td>worktree</td>
        <td>作成済（パス） / 更新済（パス） / SKIPPED（理由）</td>
    </tr>
    <tr>
        <td>worktree 処理</td>
        <td>削除済（OK 判定） / 維持（NG 判定） / N/A（SKIPPED）</td>
    </tr>
    <tr>
        <td>PR ブランチ</td>
        <td><code><head-ref></code> @ <code><head-sha-7></code></td>
    </tr>
    <tr>
        <td>PR との同等性確認</td>
        <td>実施済（差分一致） / 実施済（差分相違あり：要再取得） / SKIPPED</td>
    </tr>
    <tr>
        <td>ビルド/起動確認</td>
        <td>実施済（成功） / 実施済（失敗：理由） / SKIPPED（理由）</td>
    </tr>
    <tr>
        <td>メインリポジトリ状態</td>
        <td>変更なし（worktree 分離） / N/A（SKIPPED）</td>
    </tr>
</table>

</details>

<!-- Verdict 判定ルール（Critical/High/Medium × test-runner → レビュー結果）は本テンプレートには出力しない。
     判定規範の SSOT は ${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/output/output-verdict.md セクション 3.1。
     統合サマリは 9 セクション + ヘッダブロックのみで構成する（C7 / output-format.md）。 -->
