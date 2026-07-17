# レビューサマリ テンプレート本体（前半 / セクション 1〜5）

> **これはテンプレート本体の分割断片であり、この見出し・本注記自体はサマリ本文に出力しない。**
> Step 8 のサマリ生成では、親 [`review-summary.md`](review-summary.md) のヘッダブロックに続けて本ファイルの `<details>` セクション（1〜5）を **逐語で** 連結し、その後 [`review-summary-body-2.md`](review-summary-body-2.md)（セクション 6〜9）を連結する。
> `<details>`/`<summary>`/`<h2>` 構造・セクション番号・見出し文言は改変せずそのまま出力する。引用ブロック（`> ...`）による記入指示はサマリ本文に出力しない（親テンプレート冒頭の規約に従う）。
> 収録セクション: 1. 対応が必要な指摘 ／ 2. 改善提案 ／ 3. スコープ外指摘 ／ 4. 観点別の指摘なし ／ 5. 観点間の見解の差異

<details>
<summary>1. 対応が必要な指摘 （<X> 件 <状態記号>）</summary>
<!-- <状態記号> の差し替え: 件数 >0 → 「⚠」（例: （2 件 ⚠））／ 0 件 → 「✓ 指摘なし」（例: （0 件 ✓ 指摘なし）） -->
<h2>1. 対応が必要な指摘 （<X> 件）</h2>

> 重要度（Critical → High → Medium）の高い順に、漏れなく **全件** 記載する。
> Critical/High が 1 件以上ある場合は **NG・再レビュー要（Needs Work）**。
> 件数 0 のときは「指摘なし」と 1 行のみ記載してサブセクション本体は省略。

<h3>1-A. 指摘サマリー（表形式・必須）</h3>

<table>
    <tr>
        <th>ID</th>
        <th>致命度</th>
        <th>信頼度</th>
        <th>カテゴリ</th>
        <th>タイトル</th>
        <th>該当箇所</th>
        <th>規約・根拠</th>
        <th>担当</th>
    </tr>
    <tr>
        <td><a href="<inline-comment-url>">CR-001</a></td>
        <td>Critical</td>
        <td>95</td>
        <td>セキュリティ</td>
        <td>SQL インジェクション可能性</td>
        <td><code>src/web/admin/OrderSearch.cs:140-148</code></td>
        <td>OWASP A03 / sql-xml.md</td>
        <td>sec, impl</td>
    </tr>
    <tr>
        <td><a href="<inline-comment-url>">CR-002</a></td>
        <td>High</td>
        <td>80</td>
        <td>機能停止</td>
        <td>Null ハンドリング不足</td>
        <td><code>src/order/OrderProcessor.cs:85-92</code></td>
        <td>impact-analysis.md セクション4.1</td>
        <td>impl, test</td>
    </tr>
</table>

> **信頼度列**: `severity-ranking.md` セクション 7 の 0〜100 値。統合時に 60 未満は足切り済みのため通常この表には現れない（除外件数はセクション 8 の集計に記載）。

> **ID 列のリンク方針**:
> - PR インラインコメントが投稿されている指摘は、ID を **PR 上のコメントへのリンク** にする
>   - **TFS / Azure DevOps**: `https://<tfs-host>/.../pullrequest/<N>?_a=files&path=<file-path>&discussionId=<thread-id>`
>     - **`path=` パラメータが必須**（省略すると正しいインラインコメントへ遷移しない・サーバ側でファイルが特定できない）
>     - `<file-path>` は `/` 始まりのリポジトリルート相対パス（例: `/plugins/deep-code-review/skills/pr-review/SKILL.md`）
>     - URL エンコードが必要な文字（空白・日本語・特殊記号）はエンコードする
>   - **GitHub**: `https://github.com/<owner>/<repo>/pull/<N>#discussion_r<comment-id>` 形式
> - インラインコメント未投稿（サマリーのみで指摘する場合）は、リンクを張らずプレーンテキストにし、後述「1-B. 詳細補足（インライン未投稿の指摘のみ）」で詳細を記述する
> - リンクテキストは `<a href="<URL>">CR-NNN</a>` 形式の HTML リンクにする（`<details>` 内では Markdown リンクがレンダリングされないため）

<h3>1-B. 詳細補足（インライン未投稿の指摘のみ）</h3>

> インラインコメントを投稿していない指摘について、以下の詳細を記載する。投稿済みのものは PR コメント側に詳細があるため、ここでは記載しない（重複防止）。

<h4>CR-NNN: <タイトル></h4>

<strong>該当コード</strong>

<pre><code class="language-<lang>"><該当行のコードスニペット。前後 2〜3 行のコンテキストを含めることを推奨></code></pre>

<strong>指摘内容</strong>

<p><何が問題か。1〜3 行で具体的に。></p>

<strong>求める修正</strong>

<p><どう直すべきか。具体的な修正方針・コード例があれば併記。></p>

<pre><code class="language-<lang>"><修正後コードの例（任意）></code></pre>

<strong>理由・根拠</strong>

<p><なぜ修正が必要か。OWASP / CWE / プロジェクト規約 / 過去事例 / データ破損リスク等を引用して説明。></p>

<strong>仕様検討（必要な場合のみ）</strong>

<ul>
    <li>論点: <仕様判断が必要な事項></li>
    <li>候補 A: <案 A の概要・メリット・デメリット></li>
    <li>候補 B: <案 B の概要・メリット・デメリット></li>
    <li>推奨: <推奨候補と理由></li>
    <li>確認先: <ユーザー / プロダクトマネージャー / 顧客 等></li>
</ul>

> インラインコメント投稿済みの指摘は、サマリー表の ID リンクから PR コメントを参照すれば詳細が読める設計（重複記述を避けるため）。

</details>

---

<details>
<summary>2. 改善提案 （<X> 件 <状態記号>）</summary>
<!-- <状態記号> の差し替え: 件数 >0 → 「⚠」（例: （2 件 ⚠））／ 0 件 → 「✓ 該当なし」（例: （0 件 ✓ 該当なし）） -->
<h2>2. 改善提案 （<X> 件）</h2>

> 任意改善（Low 指摘）は **最大 10 件** まで記載。並び順は Impact × Effort の降順。
> 同一カテゴリ（命名・可読性・コメント等）はグルーピングしてまとめる。
> 10 件超は集計セクションに「全 N 件中」として件数のみ残す。
> 件数 0 のときは「該当なし」と 1 行のみ記載。

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
        <td><a href="<inline-comment-url>">CR-NNN</a></td>
        <td>HIGH</td>
        <td>MED</td>
        <td>パフォーマンス</td>
        <td>N+1 クエリ最適化</td>
        <td><code>src/cart/CartService.cs:200-220</code></td>
        <td>perf</td>
    </tr>
    <tr>
        <td><a href="<inline-comment-url>">CR-NNN</a></td>
        <td>MED</td>
        <td>LOW</td>
        <td>可読性</td>
        <td>早期 return リファクタ</td>
        <td><code>src/order/OrderService.cs:120-145</code></td>
        <td>impl</td>
    </tr>
</table>

<h3>2-B. 詳細補足（インライン未投稿の提案のみ）</h3>

> インラインコメントを投稿していない提案について、以下の詳細を記載する。

<h4>CR-NNN: <提案タイトル></h4>

<strong>該当コード</strong>

<pre><code class="language-<lang>"><該当コードスニペット></code></pre>

<strong>提案内容</strong>

<p><どう変えると良くなるか。1〜3 行で具体的に。></p>

<strong>修正案</strong>

<pre><code class="language-<lang>"><改善後コードの例（任意）></code></pre>

<strong>理由・根拠</strong>

<p><なぜ改善が望ましいか。プロジェクト慣例・可読性向上・将来の保守性 等を説明。></p>

</details>

---

<details>
<summary>3. スコープ外指摘 （<X> 件 <状態記号>）</summary>
<!-- <状態記号> の差し替え: 件数 >0 → 「⚠」（例: （2 件 ⚠））／ 0 件 → 「✓ 該当なし」（例: （0 件 ✓ 該当なし）） -->
<h2>3. スコープ外指摘 （<X> 件）</h2>

> **本 PR の仕様・当初スコープから外れる** が指摘として価値がある事項を記載する。
> ここに記載した項目は **本 PR で修正を求めない**（指摘者・閲覧者のノイズになるため別 PR 起票を推奨しない）。
> 必要があれば PR 作成者・PdM の判断で別チケット化される。
> 件数 0 のときは「該当なし」と 1 行のみ記載。

<h3>3-A. スコープ外サマリー（表形式・必須）</h3>

<table>
    <tr>
        <th>ID</th>
        <th>カテゴリ</th>
        <th>タイトル</th>
        <th>該当箇所</th>
        <th>スコープ外と判断した理由</th>
    </tr>
    <tr>
        <td><a href="<inline-comment-url>">CR-NNN</a></td>
        <td>既存技術的負債</td>
        <td>Repository パターン移行</td>
        <td><code>src/order/OrderService.cs</code></td>
        <td>PR の目的（注文確定機能追加）と独立した既存設計の課題</td>
    </tr>
    <tr>
        <td><a href="<inline-comment-url>">CR-NNN</a></td>
        <td>仕様の余地</td>
        <td>QueryString 値運用ルール</td>
        <td><code>src/api/Search.cs:42</code></td>
        <td>仕様書 docs/api-spec.md セクション3.2 の範囲外</td>
    </tr>
</table>

<h3>3-B. 詳細補足（インライン未投稿のスコープ外指摘のみ）</h3>

> インラインコメントを投稿していないスコープ外指摘について、以下の詳細を記載する。

<h4>CR-NNN: <スコープ外項目タイトル></h4>

<strong>該当コード（参考）</strong>

<pre><code class="language-<lang>"><該当コードスニペット></code></pre>

<strong>所見</strong>

<p><本 PR では対応しないが、将来的に検討すると良い理由・対応指針を 1〜3 行で。></p>

<strong>関連コミット（履歴参照が必要な場合のみ）</strong>

<ul>
    <li><a href="<commit-url>"><sha7></a> — <コミットメッセージ要約></li>
    <li><a href="<commit-url>"><sha7></a> — <コミットメッセージ要約></li>
</ul>

> コミット参照は `<a href="<commit-url>"><sha7></a>` 形式の HTML リンクで **明示リンク化**。コミット URL 例:<br>
> - TFS: `https://<tfs-host>/tfs/<collection>/<project>/_git/<repo>/commit/<full-sha>`<br>
> - GitHub: `https://github.com/<owner>/<repo>/commit/<full-sha>`

</details>

---

<details>
<summary>4. 観点別の指摘なし</summary>
<h2>4. 観点別の指摘なし</h2>

> 担当エージェント単位で 1 行に集約。指摘・提案を返さなかったエージェントを列挙。

<p><エージェント A>, <エージェント B>, <エージェント C></p>

該当なしのときは「該当なし（全エージェントから指摘あり）」と記載する。

</details>

---

<details>
<summary>5. 観点間の見解の差異</summary>
<h2>5. 観点間の見解の差異</h2>

> エージェント間で意見が衝突した場合のみ記載。なければ「該当なし」と 1 行のみ。

<h3>5-1. <テーマ></h3>

<ul>
    <li><エージェント X> の見解: <X の主張></li>
    <li><エージェント Y> の見解: <Y の主張></li>
    <li>採用判断: <本サマリで採用した側と理由></li>
</ul>

</details>

---
