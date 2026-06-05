# Output Formats (plugin-updater)

`plugin-updater` スキルが Phase F / G で出力するテーブル・警告・質問文のフォーマット集約 SSOT。
変数表記の `<count>` 等は実行時に実際の値に置き換える。

サニタイズ規則は [`cross-cutting-rules.md`](cross-cutting-rules.md) の XR-3 を、結果分類は
[`architecture-decisions.md`](architecture-decisions.md) の ADR-PU-005 を参照。

> **`<...>` 表記の 2 種類区別（重要）**: 本ファイルおよび関連ドキュメント中で `<...>` 表記が
> 2 種類の意味で使われる。混同を避けるため新規追加・編集時は必ず以下を確認すること:
>
> 1. **テンプレート変数**（実行時に実値に置換）: `<plugin>` / `<marketplace>` / `<scope>` / `<error>` /
>    `<count>` / `<name>` / `<value>` / `<M>` / `<P>` / `<N>` / `<bn>` 等。出力フォーマットの
>    プレースホルダ。
> 2. **XR-3 マスクトークン**（出力サニタイズ後の固定文言）: `<scheme>` / `<user-home>` /
>    `<netrc-credential>` / `<ssh-key-path>` 等。`cross-cutting-rules.md` XR-3 規則本体で定義され、
>    G-2 切り詰めアルゴリズムの `KNOWN_ANGLE_MASKS` ホワイトリストに登録される。
>
> **絶対に混同しない**: テンプレート変数を `KNOWN_ANGLE_MASKS` に追加するとプラグイン名等が
> 誤マスクされる事故が発生する。新規 `<...>` 表記を導入する際は、上記いずれのカテゴリかを
> 必ず明確にする。

---

## Phase F-1. サマリ

`Missing` 列は B-1（マーケットプレイス更新）では現在の CLI が MP 単位の Missing を返さないため `-` 固定
（将来 CLI が MP レベルで `not found` を返すようになった場合は仕様改訂）。
**列名定義**: 「成功」= Updated（実際に更新が走ったエントリ）、「変更なし」= No change（既に最新版）、
「Missing」= マーケットプレイスから消失（リトライ対象外）、「スキップ」= XR-1 不正値 / XR-2 サーキットブレーカー作動 /
A-2 MP 未登録 / **A-3 由来（projectPath ディレクトリ不在（target=all の場合）/ 現在のプロジェクト外（target=current-project の場合）/ 未インストール / disabled / enabledPlugins 未登録 /
projectPath 欠落）** 等で対象外、「失敗」= Failed（リトライ対象）、「Unknown」= exit code と出力解析で分類できなかった
要手動確認エントリ。**「スキップ」の内訳は F-3 備考列で区別** する。

```markdown
## 更新結果サマリ

| 区分 | 成功 | 変更なし | Missing | スキップ | 失敗 | Unknown |
|-----|-----|---------|---------|---------|-----|---------|
| マーケットプレイス | <count> | <count> | -（CLI 非対応）| <count> | <count> | <count> |
| User プラグイン | <count> | <count> | <count> | <count> | <count> | <count> |
| Project プラグイン | <count> | <count> | <count> | <count> | <count> | <count> |
| Local プラグイン | <count> | <count> | <count> | <count> | <count> | <count> |
```

### F-1.1. Unknown 警告（XR-5 を参照）

XR-5 の閾値（試行済み件数の 20%）を超える場合、cross-cutting-rules.md XR-5 セクションのフォーマットで
警告を併記する。閾値の根拠と全体件数の定義は同セクションを参照。

---

## Phase F-2. マーケットプレイス詳細

```markdown
### マーケットプレイス

| マーケットプレイス | 結果 | 備考 |
|-----------------|-----|-----|
| <name> | OK / Skipped / Failed / Unknown | <サニタイズ後の CLI 出力要約 or エラー> |
```

---

## Phase F-3. スコープ別詳細

```markdown
### User プラグイン

| プラグイン | マーケットプレイス | 結果 | 備考 |
|----------|-----------------|-----|-----|
| <plugin> | <marketplace> | Updated / No change / Missing / Skipped / Failed / Unknown | <サニタイズ後の備考> |

### Project プラグイン

`target=all` の場合は projectPath ごとにグルーピングして表示する:

#### <projectPath（XR-3 サニタイズ済み）>

| プラグイン | マーケットプレイス | 結果 | 備考 |
|----------|-----------------|-----|-----|
| <plugin> | <marketplace> | Updated / No change / Missing / Skipped / Failed / Unknown | <サニタイズ後の備考> |

`target=current-project` の場合は従来通り（projectPath ヘッダなし）:
（User と同形式。`target=current-project` + git リポジトリ外の場合はエラー終了するため本テーブルには到達しない）

### Local プラグイン
（Project と同形式。`target=all` 時は projectPath ごとにグルーピング、`target=current-project` 時はヘッダなし）
```

### F-3 備考列の Skipped 区分定型文（ADR-PU-009 / Phase A-3 由来）

「結果」列が `Skipped` の場合、**備考列に以下の定型文** を表示してユーザがスキップ理由を一目で判別できるようにする
（XR-3 サニタイズ後の文字列に含めて出力する）:

| Skipped 区分 | 備考列定型文 |
|--------------|------------|
| projectPath ディレクトリ不在 | `projectPath のディレクトリが存在しないためスキップしました` |
| 現在のプロジェクト外 | `現在のプロジェクト外にインストールされたプラグインをスキップしました` |
| 未インストール | `installed_plugins.json に該当エントリがありません` |
| disabled | `enabledPlugins で false / null のため対象外` |
| enabledPlugins 未登録 | `当該スコープの enabledPlugins に未登録` |
| projectPath 欠落 | `project / local スコープに projectPath が記録されていません` |
| MP 未登録（A-2 由来） | `marketplace list に未登録のマーケットプレイスです` |
| MP Unknown（B-1 由来） | `マーケットプレイス更新で MP 名抽出不能` |
| サーキットブレーカー作動 | `同一マーケットプレイスで Failed が累積したためスキップ（XR-2）` |
| 不正な名前（XR-1 由来） | `プラグイン名 / マーケットプレイス名が XR-1 の入力検証に不合致` |

**いずれの Skipped 区分も Phase G リトライ対象から除外** する（A-3 由来 5 区分は ADR-PU-009、
A-2 / B-1 / XR-1 由来は既存仕様に基づく）。

---

## Phase F（dry-run モード）

`mode = dry-run` 時は Phase B / C / D / E を実行せず、以下フォーマットで「実行予定コマンド一覧」のみを
提示する。F-4 / G はスキップ。

### F-1（dry-run）. 実行予定サマリ

```markdown
## 実行予定サマリ（dry-run）

| 区分 | 実行予定件数 | スキップ | （備考）|
|-----|------------|---------|--------|
| マーケットプレイス | <count> | - | 全 MP 対象 |
| User プラグイン | <count> | <count> | target に応じて対象を決定 |
| Project プラグイン | <count> | <count> | target=all: 全 projectPath 対象 / target=current-project: 現在の git リポジトリのみ |
| Local プラグイン | <count> | <count> | 同上 |
```

### F-2（dry-run）. マーケットプレイス実行予定詳細

```markdown
### マーケットプレイス（実行予定コマンド）

| マーケットプレイス | 実行予定コマンド |
|-----------------|---------------|
| <name> | `claude plugin marketplace update` |
```

（CLI が個別 MP 指定をサポートした際は `claude plugin marketplace update <name>` 形式に切替）

### F-3（dry-run）. スコープ別実行予定詳細

```markdown
### User プラグイン（実行予定コマンド）

| プラグイン | マーケットプレイス | 実行予定コマンド |
|----------|-----------------|---------------|
| <plugin> | <marketplace> | `claude plugin update <plugin>@<marketplace> --scope user` |

### Project プラグイン（実行予定コマンド）

`target=all` の場合は projectPath ごとにグルーピングして表示する:

#### <projectPath（XR-3 サニタイズ済み）>

| プラグイン | マーケットプレイス | 実行予定コマンド |
|----------|-----------------|---------------|
| <plugin> | <marketplace> | `claude plugin update <plugin>@<marketplace> --scope project` |

`target=current-project` の場合はヘッダなし（User と同形式）

### Local プラグイン（実行予定コマンド）
（Project と同形式）
```

dry-run 時の備考列は「（実行予定）」固定文言を入れ、サニタイズ対象の実エラー出力は発生しないため
XR-3 適用は不要。

---

## Phase F-4. 次のアクション提示

`mode = dry-run` の場合は本セクションを **省略** する（実際の更新がないため）。

```markdown
### 次のアクション

- Claude Code を再起動するか `/reload-plugins` を実行して更新をセッションに反映する
- **重要**: 更新によって新しい hooks / MCP サーバ / commands / agents が追加された可能性があります。
  再起動前に以下を **必ず** 実施してください:

  ```text
  claude plugin show <plugin>@<marketplace>
  ```

  特に `hooks` セクションが新規追加・変更されている場合、次回起動時に自動実行されます。
- Missing と判定されたエントリは `enabledPlugins` から除外することを検討（マーケットプレイスから消失）
- **Skipped（現在のプロジェクト外）が 1 件以上**（`target=current-project` の場合のみ表示）:
  `/update-all` を実行すれば全プロジェクトのプラグインを更新できます
- **Skipped（projectPath ディレクトリ不在）が 1 件以上**: 該当 projectPath のディレクトリが存在しません。
  ディレクトリを復元するか、`enabledPlugins` から除外してください
- **Skipped（未インストール）が 1 件以上**: 該当エントリを `enabledPlugins` から除外するか、
  `claude plugin install <plugin>@<marketplace>` でインストールしてください
- **Skipped（disabled / enabledPlugins 未登録）が 1 件以上**: 該当プラグインを有効化したい場合は
  `/plugin` で有効化してください
- 更新後に問題が発覚した場合のロールバックは README の「ロールバック手順」セクションを参照
- （失敗があれば）次のリトライ・スキップ確認に応答する
```

---

## Phase G-1 質問文（疑似コード）

### 変数定義（SSOT）

質問文で使用する変数:

| 変数 | 定義 | 集計タイミング | 出典 |
|------|------|--------------|------|
| `<N>` | 失敗総数（Failed のみ。Missing / Unknown / **Skipped 全区分** は含まない） | Phase F-1 集計時点 | ADR-PU-007 / ADR-PU-009 |
| `<M>` | Phase B-1 で Failed と判定されたマーケットプレイスの件数 | Phase B-1 完了時点 | ADR-PU-007 |
| `<P>` | Phase C/D/E で Failed と判定されたプラグインの件数 | Phase C/D/E 完了時点 | ADR-PU-007 |
| `<bn>` | **サーキットブレーカー作動 MP 件数**（同一 MP 累計 3 件以上 Failed で作動済みの MP の数。`<M>` とは別カウント。`<M>` は B-1 単独の Failed、`<bn>` は B-1/C/D/E 横断累計が閾値到達したもの） | Phase F-1 集計時点で確定（Phase G-1 直前まで保持） | ADR-PU-006 |

> **Skipped 区分のリトライ対象外性（再掲）**: Phase A-3 由来 5 区分（現在のプロジェクト外 /
> 未インストール / disabled / enabledPlugins 未登録 / projectPath 欠落）および A-2 / B-1 / XR-1 由来の
> 各 Skipped 区分はいずれも `<N>` / `<M>` / `<P>` のカウントに含まれず、Phase G-1 / G-2 の選択肢にも
> 現れない。これらは「設定変更でしか解消しない永続的状態」であり CLI リトライで回復しないため
> （ADR-PU-007 の Missing と同等の扱い）。Phase F-4 の「次のアクション」でユーザに設定変更を促す。

`<N> = <M> + <P>`。`<bn>` は `<M>` の部分集合ではなく、**B-1 / C/D/E すべての Failed を MP 単位で
横断集計した結果として 3 件以上に達した MP の件数**であり、独立した変数。

### `<warn_breaker>` 発火条件と文言（SSOT）

| 項目 | 定義 |
|------|------|
| **発火条件** | `<M> >= 1`（MP 単位 Failed が 1 件以上） |
| **発火文言** | 「⚠️ マーケットプレイス Failed が `<M>` 件あります。Phase B 全件再実行となるため、悪意ある MP の応答遅延が累積し全体タイムアウト（30 分・XR-2）を消費する DoS リスクがあります。**特にサーキットブレーカー作動中の MP（`<bn>` 件）も再試行されます**。サーキットブレーカー作動 MP がある場合（`<bn> > 0`）は『個別に判断』または『全件スキップ』を強く推奨（5 件以下の場合のみ個別判断利用可）」 |
| **UI 制御** | `<bn> > 0` の場合、UI が対応するなら「全件リトライ」をデフォルト非選択にする（実装側で制御） |

`<M> >= 1` を採用するのは、サーキットブレーカー作動前（3 件未満の Failed MP が複数）状態でも
Phase B 全件リトライの DoS リスクは存在するため。ADR-PU-006 Trade-offs から本箇所を SSOT として
参照する。

```text
# pseudocode: Claude が AskUserQuestion ツールを呼び出すパターン
# N > 5 の場合は options から「個別に判断」を除外する（連続質問による UX 劣化防止）
AskUserQuestion({
  questions: [{
    question: "<N> 件の更新失敗があります（マーケットプレイス: <M> 件 Failed / プラグイン: <P> 件 Failed）。どう対応しますか？",
    header: "更新失敗対応",
    options: [
      { label: "全件リトライ", description: "Failed エントリをもう一度更新する。<warn_breaker>" },
      // <warn_breaker> の発火条件・文言・UI 制御は本ファイル「`<warn_breaker>` 発火条件と文言（SSOT）」表を参照
      // N <= 5 のときのみ次の選択肢を含める
      { label: "個別に判断", description: "Failed エントリごとにリトライ / スキップを選択" },
      { label: "全件スキップ", description: "Failed エントリは諦めて完了する" }
    ],
    multiSelect: false
  }]
})
```

---

## Phase G-2 質問文（疑似コード）

質問テキストの `<error>` は XR-3 サニタイズ後の値。500 字を超える場合は「...（省略）」で切り詰める
（マスクトークン `***...***` の途中で切らない）。

> **識別子文脈の扱い**: 質問文中の `<plugin>@<marketplace>` は **プラグイン識別子内文脈**
> （cross-cutting-rules.md XR-3「文脈内」判定）として扱い、デフォルトマスクの対象外とする。
> XR-1 で各部 64 字以下に制限済みのため、識別子全体が 40 字超でも誤マスクされない。
> 規則ベースの GitHub PAT 等のパターンが識別子に偶然合致する場合のみマスクされるが、
> プラグイン名命名規則（XR-1）と PAT パターンは構造的に重複しない。

### 切り詰めアルゴリズム（疑似コード）

```text
function truncate_with_mask_safety(text, limit=500):
    if len(text) <= limit:
        return text

    cut = text[:limit]

    # 1. 末尾から走査して、未閉鎖の `***` ペア境界に到達するまで後退
    # `***...***` パターンは固定マーカーで両端が `***` のため、
    # cut 内の `***` 出現回数が **奇数** であれば最後の `***` ブロックが未完結
    # count_occurrences は **重複なしの非貪欲マッチ数**（Python の `re.findall(r'\*\*\*', cut)` と同等）
    star_count = count_occurrences_nonoverlapping(cut, "***")
    if star_count % 2 == 1:
        # 最後の `***` 出現位置の手前まで切り戻す
        last_star_pos = rfind(cut, "***")
        cut = cut[:last_star_pos]

    # 2. 山括弧マスク `<...>` の途中切断回避（UX 改善・ホワイトリスト方式必須）
    # CLI 自由形式テキスト中の `<n>` `<branch>` 等を誤切り戻ししないよう、
    # **既知マスク文言のみ** をホワイトリスト判定する
    # 各エントリは XR-3 規則本体テーブルの「置換後」列に出現する固定マスク文言。
    # `<scheme>` は単独ではなく `<scheme>://***@` 形式で出力されるが、登録対象は
    # **`<scheme>` 部分の前方一致切り戻しのみ**（例: 切断が `<sc` `<sch` `<schem` で起きた場合に
    # 前方一致で `<` の手前まで戻す）。`://***@` 部分の切断（例: `<scheme>://`）は機密性を
    # 持たない（`***` 自体がマスク済み文言で `@` も区切り記号のみ）ため対象外。これは意図的な
    # 設計選択。
    KNOWN_ANGLE_MASKS = ["<netrc-credential>", "<scheme>", "<ssh-key-path>", "<user-home>"]
    for mask in KNOWN_ANGLE_MASKS:
        # cut の末尾が mask の前方一致部分文字列（例: "<netrc-cred"）であれば切り戻す
        for i in range(1, len(mask)):
            prefix = mask[:i]
            if cut.endswith(prefix):
                cut = cut[:-i]
                break
        else:
            continue
        break

    return cut + "...（省略）"
```

**設計意図**:
- 既知マスクトークン（`***GITHUB_TOKEN***` / `***POSSIBLE_SECRET***` 等）は両端が `***` で固定。
  `***` の出現回数が偶数なら全ペアが完結している。奇数なら最後の `***` ブロックが切れているため、
  その手前まで戻すことで「機密が部分露出する事故」を回避する。
- `count_occurrences_nonoverlapping` は **重複なしの非貪欲マッチ**（`***A******B***` のような
  連続出現は 4 回として正しくカウント）。Python では `len(re.findall(r'\*\*\*', text))` 相当。
- 山括弧マスク（`<netrc-credential>` / `<scheme>://***@` / `<ssh-key-path>` / `<user-home>` 等）は
  部分露出しても秘匿性を破らないが、UX 改善のため山括弧途中切断も回避する。
- **将来マスク文言を変更する際の注意**: 本アルゴリズムは「マスクトークン両端が `***` 3 連で固定」
  「山括弧マスクは `<...>` 1 ペアで完結」を前提とする。`****` 4 連や `<<...>>` 2 重山括弧などの
  新フォーマットを追加する場合、本切り詰めロジックの偶奇判定 / 山括弧マッチングを更新する必要が
  ある。
- **山括弧マッチングのホワイトリスト化（v1.0.0 で必須）**: CLI 出力の自由形式テキストに `<` `>` が
  混入する場合（例: `Failed: parse error at line <30>`）、未限定の `last_lt_pos > last_gt_pos` 判定は
  誤動作する。上記疑似コードの **`KNOWN_ANGLE_MASKS` ホワイトリスト方式が SSOT**。
- **同期義務（XR-3 と `KNOWN_ANGLE_MASKS`）**: cross-cutting-rules.md XR-3 規則本体テーブルに
  山括弧マスク文言（`<...>` の置換後）を追加する際は、**同一コミットで** 本ファイルの
  `KNOWN_ANGLE_MASKS` リストにも追記する。ADR-PU-004 SSOT 配置原則の運用拡張として、XR-3
  追加変更時のチェックリストに本同期作業を含める。
- **登録判定基準**:
  - **登録すべき**（XR-3 マスクトークン）: `<netrc-credential>` / `<scheme>` / `<ssh-key-path>` /
    `<user-home>` 等の **XR-3 規則本体テーブルの「置換後」列に固定文言として出現するもの**。これらは
    実行時に値が変わらない静的マスク文言。
  - **登録してはならない**（テンプレート変数）: `<plugin>` / `<scope>` / `<error>` / `<count>` /
    `<name>` / `<value>` / `<M>` / `<P>` / `<N>` / `<bn>` 等の **実行時に実値（プラグイン名等）に
    置換されるプレースホルダ**。`KNOWN_ANGLE_MASKS` に登録すると実値が誤マスクされる事故が発生する。
  - 判定が曖昧な場合は本ファイル冒頭の「`<...>` 表記の 2 種類区別」セクションを参照。

```text
# pseudocode: Claude が AskUserQuestion ツールを呼び出すパターン
AskUserQuestion({
  questions: [{
    question: "[<scope>] <plugin>@<marketplace> の更新に失敗しました（理由: <サニタイズ後のerror>）。リトライしますか？",
    header: "個別失敗対応",
    options: [
      { label: "リトライ", description: "もう一度更新を試行" },
      { label: "スキップ", description: "このエントリは諦める" }
    ],
    multiSelect: false
  }]
})
```

---

## エラーメッセージ集約

> **SSOT 注記**: 本セクションが本プラグインの全エラー文言の **唯一の正典**。
> `commands/update-all.md` および `skills/plugin-updater/` 配下の `SKILL.md` / `references/`
> 各ファイルは本セクションを参照し、独自にエラー文言を再定義しない。
> 文言を変更する際は本セクションのみを編集し、他箇所は参照を維持する（ADR-PU-004 SSOT 配置原則準拠）。

### 不正な target 値

```text
エラー: 不正な target 値 "<value>" が指定されました。有効な値は all / current-project です。
```

### CLI 不在 / 不正実装

```text
エラー: claude plugin CLI に必要なサブコマンドが見つかりません（または不正な実装の可能性）。
Claude Code のインストール状況と PATH を確認してください。
```

### enabledPlugins ブロック過大

```text
エラー: <scope> スコープの enabledPlugins ブロックが 4000 行を超えるため、
情報漏洩防止のため処理を中断します。settings.json の構造を確認してください。
```

### enabledPlugins ブロック内 Unicode エスケープ検出（A-Sec 第三手順フェイルクローズ）

```text
エラー: enabledPlugins ブロック内に Unicode エスケープ（\u00XX 形式）が含まれています。
境界判定の安全性確保のため処理を中断します。
対処方法: settings.json の enabledPlugins 内の文字列リテラルから Unicode エスケープを
除去し、直接対応する文字（例: - → -）に変換してから再実行してください。
プラグイン名・マーケットプレイス名は ASCII 範囲のみで構成されることが推奨されます。
```

### enabledPlugins ブロック内に他キー混入（A-Sec 第四手順フェイルクローズ）

```text
エラー: enabledPlugins ブロック内にトップレベル相当キー（<検出キー名>）が混入しています。
原因の可能性: (1) A-Sec 第三手順のブロック終端検出に異常がある、または
(2) Claude Code が enabledPlugins スキーマをネスト型に拡張した（サブキー <enabled> / <config>
等を含む）場合、本手順がそれを混入として誤検知している可能性。settings.json の構造を確認し、
スキーマ拡張が原因の場合はプラグインの A-Sec 第四手順正規表現の更新を待ってください。
```

### enabledPlugins キーが Unicode エスケープで難読化されている（A-Sec 第一手順フェイルクローズ）

```text
エラー: settings.json の enabledPlugins キーが Unicode エスケープ（\u00XX 形式）で
難読化されています。意図しない検出回避を防ぐため処理を中断します。
対処方法: settings.json の enabledPlugins キー名を ASCII 文字列リテラル（"enabledPlugins"）で
記述してください。
```

### A-Sec 第三手順 [ ] カウンタ異常検知

```text
エラー: enabledPlugins ブロックの構造解析で配列ネスト [ ] のカウンタ異常を検出しました
（{ } ネストレベルが 0 に戻った時点で [ ] カウンタが 1 以上）。境界判定の安全性確保のため
処理を中断します。settings.json の構造を確認してください。
```

### git リポジトリ外で target=current-project 指定時

```text
エラー: target=current-project が指定されましたが、git リポジトリ外のため Project / Local スコープを処理できません。
全プロジェクトのプラグインを更新したい場合は /update-all を使用してください。
```

### git リポジトリ外で target=all の場合の INFO

```text
INFO: git リポジトリ外で実行されたため、target=all でも現在のプロジェクトの Project / Local スコープはありません。
他プロジェクトの Project / Local プラグインは installed_plugins.json の projectPath に基づいて更新されます。
```

### Phase B 後新規 MP 追加時の INFO

```text
INFO: Phase B でマーケットプレイス <name> が新規登録されましたが、当該 MP 配下のプラグインは
A-2 時点で未登録判定により Skipped 扱いのため、本セッションでは更新されません。
次回 /update-all 実行時に反映されます。
```
