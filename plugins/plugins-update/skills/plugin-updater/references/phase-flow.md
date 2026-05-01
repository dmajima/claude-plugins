# Phase Flow (plugin-updater)

`plugin-updater` スキルの Phase A-0〜G の実行手順詳細。
横断ルールは [`cross-cutting-rules.md`](cross-cutting-rules.md)、設計判断は
[`architecture-decisions.md`](architecture-decisions.md)、出力フォーマットは
[`output-formats.md`](output-formats.md) を参照。

実行順は **A-0-1 → A-0-2 → A → A-1 → A-2 → B → C → D → E → F → G** の固定順
（ADR-PU-003 に準拠、変更不可）。

---

## Phase A-0: 事前検証

A-0 は Phase A の前に **以下の順序** で必ず実行する。

### A-0-1. 引数バリデーション

呼び出し元コマンドから受け取った `scope` 値を XR-1（[cross-cutting-rules.md](cross-cutting-rules.md)）の
ホワイトリスト `user` / `project` / `local` / `all` と照合する。
不正値の場合は以下のエラーで処理を中断する（後続フェーズには進まない）:

```text
エラー: 不正な scope 値 "<value>" が指定されました。有効な値は user / project / local / all です。
```

### A-0-2. Claude Code CLI 存在チェック

`claude plugin --help` を実行し以下をすべて満たすことを確認する（`claude plugin --help` を選んだ
理由: `claude plugin` サブツリー全体の存在確認と必要サブコマンド存在確認を 1 回の呼び出しで
最小コストで行えるため）:

- exit code が 0
- 出力に正規表現 `^\s+marketplace\s+update\b` または `^\s+update\b` のいずれかが
  サブコマンド一覧行として現れる（行頭インデント + サブコマンド名 + 単語境界）。
  **OR 条件の意図**: 本プラグインは `claude plugin marketplace update` と `claude plugin update` の
  両方を使うが、CLI ヘルプではこれらがサブツリー別に列挙される（`marketplace` グループ配下に
  `update`、トップレベルに `update`）。両方の存在を厳密に AND 検証するとヘルプ出力フォーマットの
  CLI バージョン差に脆弱になるため、**いずれか一方が検出できれば `claude plugin` サブツリー自体は
  実装されていると判定し、欠落サブコマンドの不在は実行時の exit code で検知する** 二段防御戦略を採用

サブコマンド一覧形式の正規表現は **行頭が空白で始まり、サブコマンド名が単語境界で終わる**
パターンを採用。これにより、ヘルプ末尾の説明文中に `marketplace update` という単語が含まれる
だけのシムは **この照合をすり抜けてしまう可能性がある** が、説明文は通常インデントなしで
開始されるため、行頭空白パターンには通常ヒットしない。**精巧に偽装したシム**（行頭に空白を
入れて偽のサブコマンド一覧行を捏造する等）はこの照合では検出できない点に留意する。

いずれも満たさない場合は以下のエラーで処理を中断する:

```text
エラー: claude plugin CLI に必要なサブコマンドが見つかりません（または不正な実装の可能性）。
Claude Code のインストール状況と PATH を確認してください。
```

> ⚠️ **重要（CLI 真正性検証）**: 上記 A-0-2 の出力照合は **ヒューリスティックな補助** に
> 過ぎず、PATH 改変によるシムや精巧な偽装ヘルプには脆弱。CLI バイナリ自体の真正性検証は
> OS のパッケージマネージャ署名検証に依存する。具体的な検証コマンド例（`codesign -v` /
> `Get-AuthenticodeSignature` / `dpkg -V`）は [`architecture-decisions.md`](architecture-decisions.md)
> の **ADR-PU-002 Trade-offs 表（Linux/macOS/Windows 別の検証コマンド）** を参照。
> ユーザは利用前に `which claude` / `Get-Command claude` で実行バイナリの絶対パスを確認し、
> OS パッケージマネージャ管理下にあることを必ず確認すること（README「動作要件」参照）。

#### A-0-2 検証成功時の INFO（毎回必須提示）

A-0-2 が exit 0 + 必要サブコマンド検出の両条件を満たした場合、Phase A 開始前に **以下の手順で**
INFO を **毎回** 提示する（CLI バイナリ真正性が自動検証されていない事実をユーザに思い出させるため）:

1. **実行バイナリの絶対パス取得**: 以下のいずれかを環境に応じて実行する:
   - POSIX: `command -v claude` または `which claude`
   - PowerShell: `Get-Command claude | Select-Object -ExpandProperty Source`
2. 取得した絶対パスを INFO 文言に **埋め込んで** 提示する:

```text
INFO: claude plugin CLI の存在を確認しました（実行バイナリ: <絶対パス>）。
   バイナリ真正性は本コマンドでは検証していません。
   このパスが想定の場所（OS パッケージマネージャ管理下）にあるか必ず確認してください。
   PATH 改変・シム差し替え攻撃を防ぐ追加手段として、ADR-PU-002 Trade-offs の検証コマンド
   （`codesign -v` / `Get-AuthenticodeSignature` / `dpkg -V`）の実行を推奨します。
```

絶対パス取得自体が失敗した場合（PATH 不整合等）はその旨を INFO に含めて続行する（A-0-2 自体は
exit 0 で通過しているため処理は中断しない）。

---

## Phase A: 対象収集（読み取りのみ）

| 項目 | 取得元 | 取得方法 |
|-----|-------|---------|
| マーケットプレイス一覧 | Claude Code CLI | `claude plugin marketplace list` |
| User プラグイン | `~/.claude/settings.json` の `enabledPlugins` | **Grep で `enabledPlugins` ブロックを抽出**（A-Sec 手順に従う） |
| Project プラグイン | `<repo>/.claude/settings.json` の `enabledPlugins` | 同上 |
| Local プラグイン | `<repo>/.claude/settings.local.json` の `enabledPlugins` | 同上 |

`settings.json` 系の読み取りは **必ず A-Sec 手順（Grep + ブロック終端検出）** で行う。
**全文 Read ツールでの読み込みは禁止**（`mcpServers` / `extraKnownMarketplaces` / `hooks` /
`apiKeyHelper` / `env` / `permissions` / `customApiKeyResponses` 等の機密キーがコンテキストに
混入するため）。`jq` など外部ツールも使用しない。

### A-Sec. シークレット二次経路の遮断（必須手順）

読み取った JSON の **`enabledPlugins` キー以外（`mcpServers` / `extraKnownMarketplaces` / `hooks` /
`apiKeyHelper` / `env` / `permissions` / `awsAuthRefresh` / `customApiKeyResponses` 等の機密キー）は
メインコンテキストに一切載せない**。以下の手順を **必ず順守**する:

1. **第一手順（必須）**: `Grep` で `enabledPlugins` の開始ブロックを抽出（暫定範囲 500 行）:
   ```text
   Grep(pattern: '"enabledPlugins"', path: '<settings.json>', output_mode: 'content', -A: 500)
   ```
2. **第二手順（必須）— 型ガード**: 抽出結果から `"enabledPlugins"` キーに続く `:` の **直後の
   非空白文字** が `{` であることを確認する（行単位ではなく、JSON 値の先頭文字での判定）。
   以下のいずれかであれば当該スコープを「対象なし（不正なスキーマ）」として扱い、Phase F に
   その旨を備考付きで報告する（後続の Phase A-Sec 第三手順以降には進まない）:
   - `[`（配列型）
   - `"`（文字列型）
   - 数字 / `-` / `+`（数値型）
   - `t` / `f` / `n`（true / false / null リテラル先頭。**`enabledPlugins: null` 自体は「スキーマ不正」**
     扱いであり、後段の `enabledPlugins.{plugin}: null`（要素値の null = 「無効と同等扱い」）とは
     **粒度が異なる** ことに注意）
   - `enabledPlugins` キー自体が存在しない（Grep が空結果を返した場合）

   `{` が確認できた場合のみ **第三手順へ進む**（明示的な順序制約）。
3. **第三手順（必須）— ブロック終端検出（構造解析）**: 抽出結果を Claude が走査し、`enabledPlugins`
   の値である `{` の対応する `}` を検出した時点で **それ以降のテキストを破棄** する。具体的には:
   - 値の `{` 位置から開始し、`{` でネストレベル +1、`}` でネストレベル -1 を計上
   - ネストレベルが 0 に戻った位置までを `enabledPlugins` ブロックとして保持し、それ以降は破棄
   - **文字列リテラル内の `{` `}` は計上対象外（必須）**: `"..."` で囲まれた範囲内の波括弧は
     カウントしない。文字列リテラルの境界判定は以下を厳密に守る:
     - `\"`（バックスラッシュ + ダブルクォート）は文字列終端とみなさない（`"a\"b{c"` は文字列内）
     - `\\` は「バックスラッシュ自身のエスケープ」であり、直後の `"` は文字列終端として扱う
       （`"a\\"` は文字列終端 = `\\"` の手前で閉じる）
     - **Unicode エスケープ `\u00XX` は文字列リテラル内の通常文字** として扱う。
       特に `}`（`}`）/ `{`（`{`）/ `"`（`"`）の Unicode エスケープを **値**
       として展開して計上対象に含めることは禁止（フェイルクローズ：Unicode エスケープを含む
       `enabledPlugins` ブロックは安全側に倒して即エラー終了）:
       ```text
       エラー: enabledPlugins ブロック内に Unicode エスケープが含まれています。
       境界判定の安全性確保のため処理を中断します。
       ```
     - サロゲートペア（`😀` 等）は同様に「文字列内の通常文字」として扱い、
       上記 Unicode エスケープと同様にエラー終了
   - **簡略実装（文字列リテラル考慮なし）は禁止**: プラグイン名キーに `"plugin}@mp"` のような
     `}` を含む値が存在すると終端を誤検出し、後続の `mcpServers` / `apiKeyHelper` 等の機密キーが
     `enabledPlugins` ブロックに混入するリスクがあるため、文字列リテラル考慮は必須とする

4. **第四手順（必須）— 事後検証ガード（フェイルクローズ二重化・パターン検証）**: 第三手順の
   ブロック終端検出後、**保持テキスト** に対して **`enabledPlugins` 以外のトップレベル相当キーが
   1 件でも検出されたらフェイルクローズ** とする（**ホワイトリスト方式**を採用）:

   ```text
   # 保持テキスト内に以下の正規表現でトップレベル相当のキー（インデント 0〜2 段で出現）を全列挙
   ^\s{0,2}"([A-Za-z_][A-Za-z0-9_]*)"\s*:
   # 検出キー名のうち "enabledPlugins" 以外が 1 件でもあれば即エラー終了
   ```

   ホワイトリスト方式を採用する理由: Claude Code の `settings.json` には今後新規の機密キー
   （`anthropicApiKey` / `awsCredentials` / `oauthAccount` / `proxy` / `httpsProxy` 等）が追加される
   可能性があり、列挙方式（ブラックリスト）では未知キーに対して未防御となる。`enabledPlugins`
   配下の値はオブジェクト型でありキー部分は `"<plugin>@<mp>":` 形式のため、ホワイトリスト方式でも
   誤検出は起きない（プラグイン識別子は `@` を含むため `[A-Za-z_][A-Za-z0-9_]*` パターンに
   合致しない）。

   検出時のエラー:

   ```text
   エラー: enabledPlugins ブロック内にトップレベル相当キー（<検出キー名>）が混入しています。
   A-Sec 第三手順のブロック終端検出に異常がある可能性があります。settings.json の構造を
   確認し、再実行してください。
   ```

   本ガードは「Claude（LLM）が長文走査でステート（文字列内/外、エスケープ直後）を取りこぼす」
   ケースに対する事後検証であり、第三手順（構造解析）と第四手順（パターン検証によるバックストップ）
   が二段防御を成す。

5. **第五手順（必須）— ブロック終端未検出時の倍々再 Grep**: 500 行内でネストレベルが 0 に戻らない
   場合、`-A` を倍にして再実行する（500 → 1000 → 2000 → 4000）。最大 4 回まで拡張し、それでも
   未検出ならエラーで処理を中断する（フェイルクローズ。**全文 Read は禁止**）:
   ```text
   エラー: <scope> スコープの enabledPlugins ブロックが 4000 行を超えるため、
   情報漏洩防止のため処理を中断します。settings.json の構造を確認してください。
   ```

#### A-Sec 補足事項（番号外）

- **抽出失敗時のフォールバック**: `enabledPlugins` キーが見つからない場合は当該スコープを
  「対象なし」として扱い、Phase F に空テーブルで報告（エラー扱いにはしない）。
  **全文 Read は禁止**（`mcpServers` 等が直接コンテキストに乗るリスクがあるため）。
- **メインコンテキストの最終状態**: `enabledPlugins` 配下のキー・値のみが残ること。
  プラグイン名・MP 名・備考の自然言語に偶発的に含まれる単語（例: プラグイン名 `git-hooks-runner`
  の `hooks`、`mcp-config` の `mcp`）は本フィルタの対象外（第四手順は **JSON キー構造
  クォート + コロン** で判定し、単語照合では行わない）。

### A-Repo. `<repo>` の決定と検証

`<repo>` は `git rev-parse --show-toplevel` の結果。検証ルールは XR-1 の「パス検証」セクション
（[cross-cutting-rules.md](cross-cutting-rules.md)）を参照。

> ⚠️ **検証順序の規範**（必須）: XR-1 の「シェル特殊文字検証」「シンボリックリンク検出」等の
> パス検証は **必ず以下の順序** で実施する:
> 1. `<repo>` 文字列に対する正規表現ベース検証（`..` / 改行 / null 文字 / シェル特殊文字 /
>    UNC パス等）→ XR-1 で全件パスしたもののみ次へ
> 2. PowerShell `Get-Item -LiteralPath '<repo>'` 等の **外部コマンド呼び出しを伴う** 検証
> （順序を逆にすると未検証の `<repo>` が PowerShell の文字列展開を経由して攻撃面を広げるため）

検証失敗時は Project / Local 処理をスキップして INFO で理由を表示する（フェイルクローズ）。

git リポジトリ外で実行され、かつ `--scope project` または `--scope local` が **明示指定** された場合は
エラーを返して中断する。`--scope` 未指定時は Project / Local を省略するが、その旨を以下の INFO で明示する:

```text
INFO: git リポジトリ外で実行されたため Project / Local スコープを対象から除外しました。
```

各プラグインエントリは **(scope, plugin-name, marketplace-name)** の 3 つ組として記録。
スコープが異なれば同一 (plugin-name, marketplace-name) でも別エントリとして扱う。

### `enabledPlugins` のスキーマ例

Claude Code の `enabledPlugins` は **キーがプラグイン識別子（`<plugin-name>@<marketplace-name>` 形式）、
値がブール（または null）** のオブジェクト。`@` の左側が plugin-name、右側が marketplace-name。

```json
{
  "enabledPlugins": {
    "convert-doc@dmajima-claude-plugins": true,
    "extension-toolkit@dmajima-claude-plugins": true,
    "credentials-manager@dmajima-claude-plugins": false
  }
}
```

| 値 | 扱い | 備考 |
|----|------|------|
| `true` | 有効として処理対象に含める | — |
| `false` | 明示的に無効化されているのでスキップ | — |
| `null` | スキップ（無効と同等扱い） | Claude Code CLI が `null` を「未設定 = 無効」と解釈する仕様に倣う。フェイルセーフとして無効扱いを採用（CLI 仕様変更時は要再評価） |
| 文字列 / オブジェクト等の異常値 | Skipped（不明な値型）として記録 | Phase F 備考列には値そのものを表示せず「(不明な値型: \<型名のみ\>)」固定文言に置換 |

---

## Phase A-1: 入力検証（XR-1 を適用）

抽出した各エントリについて XR-1（[cross-cutting-rules.md](cross-cutting-rules.md)）を適用。
具体手順:

1. `enabledPlugins` の各キー文字列（例: `convert-doc@dmajima-claude-plugins`）を取得
2. `@` の出現回数を数え、**正確に 1 個でなければ即座に Skipped（不正な名前）として除外**
3. `@` で文字列を split し、左側を plugin-name、右側を marketplace-name とする
4. plugin-name / marketplace-name それぞれを **XR-1 の正規表現
   `^[A-Za-z0-9]([A-Za-z0-9_.-]{0,62}[A-Za-z0-9])?$`** に **個別に** 照合
5. scope 値（A-1 内部表現）を XR-1 の scope ホワイトリスト `user` / `project` / `local` に照合
   （`all` はここでは現れない: A-0-1 でユーザー入力として受理されたあと、A-1 到達前に
   `user` / `project` / `local` のループ展開済み）
6. いずれかが合致しないエントリは Phase F のサマリで「Skipped（不正な名前）」として除外し、
   CLI コマンドには絶対に渡さない

---

## Phase A-2: マーケットプレイス整合性検証

`enabledPlugins` 内の `marketplace-name` のうち、Phase A で取得した `claude plugin marketplace list`
の結果に **存在しないもの** を Skipped（マーケットプレイス未登録）として除外する。

### 二重実施の挙動と A→B 間ドリフト

A-2 は **Phase A 直後に 1 回のみ実施** する。Phase B 後の再実施は行わない（ADR-PU-003 / ADR-PU-002 参照）。

**ドリフト影響**: Phase B でマーケットプレイスが新規追加された場合、当該 MP 配下の `enabledPlugins`
エントリは A-2 時点で「未登録」と判定されているため Skipped 扱いのまま当該セッションでは更新されない。
このケースを検知したら Phase F-4 の前に以下の INFO を表示する:

```text
INFO: Phase B でマーケットプレイス <name> が新規登録されましたが、当該 MP 配下のプラグインは
A-2 時点で未登録判定により Skipped 扱いのため、本セッションでは更新されません。
次回 /update-all 実行時に反映されます。
```

### A-2 と XR-2 の役割分担

A-2 は **Phase B 実行前の静的検証**（marketplace list と enabledPlugins の差集合チェック）。
B 実行後の MP 失敗による配下プラグインの動的制御は **XR-2 サーキットブレーカー** が担う。

---

## Phase B: マーケットプレイス更新（最初に必ず実行・XR-1/XR-2/XR-3 を適用・dry-run 時はコマンド表示のみ）

呼び出し元の `scope` の値にかかわらず、本フェーズは常に実行する。

```bash
claude plugin marketplace update
```

### B-1. 結果判定

結果分類テーブル（マーケットプレイス更新用）は ADR-PU-005 の「結果分類テーブル — マーケットプレイス更新（B-1）」
セクション（[architecture-decisions.md](architecture-decisions.md)）を参照。
例外行抽出パターン・Unknown 区分の扱いも ADR-PU-005 に集約されている。

> **SSOT 注記（サーキットブレーカー）**: 本 Phase B / B-1 における Failed カウントが XR-2
> サーキットブレーカー（MP 単位累計 3 件）に集計される際の集計対象（B-1 部分失敗のみ・全体失敗
> およびUnknown は対象外）と、G-3 リトライ時に Phase B 全件再実行へサーキットブレーカーが
> **適用されない設計上の許容事項** は、**ADR-PU-006 が SSOT**。本ファイルは再定義しない。

---

## Phase C / D / E: スコープ別プラグイン更新（XR-1/XR-2/XR-3 を適用・dry-run 時はコマンド表示のみ）

各スコープの (plugin-name, marketplace-name) ごとに以下を実行する:

```bash
# Phase C: User スコープ（scope が user または all のとき）
claude plugin update <plugin-name>@<marketplace-name> --scope user

# Phase D: Project スコープ（scope が project または all、かつ git リポジトリ配下のとき）
claude plugin update <plugin-name>@<marketplace-name> --scope project

# Phase E: Local スコープ（scope が local または all、かつ git リポジトリ配下のとき）
claude plugin update <plugin-name>@<marketplace-name> --scope local
```

### B-1 結果に応じた C/D/E の対象除外ルール

Phase B-1 で各 MP に付与された分類（OK / 部分失敗（Failed） / Unknown / 全体失敗）に応じて、
C/D/E での対象エントリを以下のとおり扱う:

| B-1 分類 | C/D/E での扱い |
|---------|--------------|
| OK | 通常実行 |
| 部分失敗（Failed として記録された MP） | **C/D/E でも継続して更新を試行する**（XR-2 サーキットブレーカーが累計 3 件 Failed で作動するまで除外しない）。失敗根本原因が一過性の場合に正常更新を阻害しないための方針 |
| Unknown（MP 名抽出不能） | **C/D/E から除外**（Skipped: MP Unknown）。MP 整合性が確認できないため安全側に倒す |
| 全体失敗（exit 非 0） | **C/D/E は警告付き継続**（CLI が古いインデックスでプラグイン更新を試みる可能性のため停止しない。Phase B 全体失敗は ADR-PU-005 の B-1 分類テーブル参照） |

詳細な分類判定ロジックは [`architecture-decisions.md`](architecture-decisions.md) ADR-PU-005 を参照。

### C-1 / D-1 / E-1. 結果分類（ADR-PU-005 に基づく）

結果分類テーブル（プラグイン更新用）は ADR-PU-005 の「結果分類テーブル — プラグイン更新（C-1 / D-1 / E-1 共通）」
セクションを参照（Updated / No change / Missing / Failed / Unknown の 5 区分）。
3 スコープすべてで同一テーブルを適用する。

---

## Phase F: 結果報告（dry-run 時は output-formats.md の Phase F(dry-run) フォーマットに差し替え）

すべての更新処理を完了した時点で、必ず結果報告を提示する。
出力フォーマット（サマリ表 / 詳細テーブル / 警告メッセージ / 次のアクション）は
[`output-formats.md`](output-formats.md) を SSOT として参照する。

> **NOTE（サニタイズ適用タイミング）**: F-2 / F-3 / G-2 / B-1（例外行抽出時）で備考列・質問文・
> 抽出 MP 名を生成する **直前** に XR-3（[cross-cutting-rules.md](cross-cutting-rules.md)）の
> サニタイズを必ず適用する。**F-1 サマリ表は件数（整数）のみを表示するためサニタイズ対象外**。
> 規則本体・列単位の例外・「文脈外」判定の具体ルール・テストケース・適用順序はすべて XR-3 SSOT を
> 参照のこと。本ファイルは XR-3 を再定義しない。

---

## Phase G: 失敗対応の確認（失敗ありの場合のみ・dry-run 時はスキップ）

Phase F の結果報告後、**Failed が 1 件以上ある場合** に実行。
失敗総数 `<N>` の定義は **「Failed のみ」**（ADR-PU-007 参照）:

- `<M>`: Phase B-1 で Failed と判定されたマーケットプレイスの件数（Missing は CLI が MP 単位で
  返さないため存在しない）
- `<P>`: Phase C/D/E で Failed と判定されたプラグインの件数（Missing は除外）
- `<N> = <M> + <P>`

Missing エントリは Phase G の対象としない。Phase F-4 で「`enabledPlugins` から除外を検討」と
ユーザに案内する。Unknown も対象外（要手動確認）。

### G-1. 全体方針の確認（疑似コード）

質問文の AskUserQuestion フォーマットは [`output-formats.md`](output-formats.md) の
「Phase G-1 質問文」セクションを SSOT として参照。

**G-1 の選択肢に応じた分岐**:
- 「全件リトライ」 → G-3 を全失敗エントリに対して実行
- 「個別に判断」 → G-2 へ進む（失敗 5 件以下の場合のみ。6 件以上は G-1 のみで打ち切り）
- 「全件スキップ」 → G-3 / G-4 をスキップして終了

### G-2. 個別判断モード（G-1 で「個別に判断」が選択された場合のみ実行）

失敗エントリ数（G-1 で定義した N、つまり Failed のみ）が **5 件以下の場合のみ** 各エントリについて確認する。
6 件以上の場合は G-1 で本モードは選択肢から除外する（実装側で制御）。

質問文フォーマットは [`output-formats.md`](output-formats.md) の「Phase G-2 質問文」セクション
を SSOT として参照。

### G-3. リトライ実行（XR-1/XR-2/XR-3/XR-4 を適用）

リトライは失敗種別に応じて **必要最小限のフェーズのみ** 再実行する。
XR-2 のサーキットブレーカー作動中の MP には適用しない。

| 失敗種別 | 再実行範囲 |
|---------|-----------|
| マーケットプレイス Failed | **Phase B を引数なしで再度実行**（`claude plugin marketplace update` = 全マーケットプレイス対象）。`--scope` 指定の有無によらず Phase B は常に全 MP 対象（ADR-PU-003「Phase B を常に実行する理由」参照）。**サーキットブレーカー作動中の MP も Phase B 全件リトライでは再試行され得る**: Phase B は MP 単位個別指定をサポートしないため、XR-2 「サーキットブレーカー作動中の MP は G-3 のリトライ対象から除外」原則は **プラグイン単位（C/D/E）のリトライにのみ適用** され、MP 単位の Phase B 全件リトライには適用されない（設計上の許容事項）。CLI が `claude plugin marketplace update <name>` の引数指定をサポートしたら個別 MP リトライに切り替えてサーキットブレーカー除外を厳密化する（ADR-PU-002 Future Direction 参照） |
| プラグイン Failed（C/D/E 由来） | `claude plugin update <plugin>@<marketplace> --scope <scope>` を当該エントリのみ実行 |

XR-4 によりリトライは元の失敗集合に対し最大 1 回。リトライ中の新規失敗は記録のみ。

### G-4. リトライ完了後の最終報告（追記出力）

リトライ完了後、Phase F のサマリ・詳細テーブルを **同一フォーマットで再度出力** する
（チャット UI では前の出力を上書きできないため、新たなセクションとして追記）。

各エントリの **備考列** にリトライ前後の状態変化を記載する:
- `Failed → Updated（リトライ成功）`
- `Failed → Failed（リトライ失敗）`
- `Failed → No change（既に最新版に到達）`

Missing は Phase G の対象としないため、リトライ後も Missing のまま F-4 アクションでユーザに
`enabledPlugins` 除外を促す。

---

## --dry-run モード時の挙動

呼び出し元から `mode = dry-run` で起動された場合、**「マーケットプレイス／プラグインを変更する CLI
（`claude plugin marketplace update` / `claude plugin update`）」のみを実行せず**、以下を提示する。
**読み取り専用 CLI（`claude plugin --help` / `claude plugin marketplace list`）は対象収集のため
通常通り実行する** 点に注意（dry-run の対象は破壊的操作 CLI のみ）。

- Phase A-0-1 / A-0-2（読み取り専用）は通常実行
- Phase A の対象収集は通常通り実行（A-Sec **全手順（第一〜第五手順を含む）** による Grep +
  ブロック終端検出で `settings.json` 系を読み取り、`claude plugin marketplace list` を実行。
  事後検証ガード（第四手順）も dry-run 時に省略しない。`marketplace list` はキャッシュ参照のみで
  更新通信を行わないことが期待されるが、CLI バージョンにより異なる場合がある）
- Phase A-1 / A-2 の検証も実行
- Phase B / C / D / E（**変更系 CLI**）の代わりに、実行予定の CLI コマンド一覧を表示。フォーマットは
  [`output-formats.md`](output-formats.md) の **「Phase F（dry-run モード）」セクション**
  （F-1 / F-2 / F-3 dry-run 専用テーブル）を SSOT として参照する
- **XR-3 サニタイズは Phase B/C/D/E の更新ログに対しては適用不要**: dry-run 時は変更系 CLI 出力が
  発生しないため。ただし **Phase A の `claude plugin marketplace list` 出力** は通常モードでも
  サニタイズ対象外（出力フォーマットが MP 名・URL 主体で機密性が低い）であり、dry-run でも同様の
  扱い（output-formats.md Phase F(dry-run) 末尾の注記参照）
- Phase F-4 / G はスキップ

**重要な制約**: `--dry-run` は **実行予定のコマンド一覧** のみを提示します。
**各プラグインの変更内容（新規 hooks / MCP / agents の追加）は確認しません**。
変更内容の確認には実行後 `claude plugin show <plugin>@<marketplace>` を別途実行する必要があります。

`scope` と組み合わせた場合（例: `mode=dry-run, scope=user`）は、指定スコープに限定したプレビューを表示。

---

## 注意事項（ユーザー向け）

ユーザー向け注意事項（サプライチェーンリスク・ロールバック手順・破壊操作回避・autoUpdate 同時実行）は
プラグイン README に集約されている。本スキルでは実行手順のみを記述し、ユーザー向け注意事項の
重複は避ける。
