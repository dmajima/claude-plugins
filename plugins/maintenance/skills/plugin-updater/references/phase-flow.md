# Phase Flow (plugin-updater)

`plugin-updater` スキルの Phase A-0〜G の実行手順詳細。
横断ルールは [`cross-cutting-rules.md`](cross-cutting-rules.md)、設計判断は
[`architecture-decisions.md`](architecture-decisions.md)、出力フォーマットは
[`output-formats.md`](output-formats.md) を参照。

> **エラー文言の SSOT 注記**: 本ファイル内のコードブロックで提示するエラー文言は、
> [`output-formats.md`](output-formats.md) の「エラーメッセージ集約」セクションを
> **SSOT** として参照しているもの。可読性のため本ファイルにも再掲しているが、文言を変更する際は
> output-formats.md のみを編集し、本ファイルは参照を維持する（ADR-PU-004 SSOT 配置原則準拠）。

実行順は **A-0-1 → A-0-2 → A → A-1 → A-2 → A-3 → B → C → D → E → F → G** の固定順
（ADR-PU-003 / ADR-PU-009 / ADR-PU-015 に準拠、変更不可）。

ただし `target=current-project` の場合、Phase B（マーケットプレイス更新）と Phase C（User スコープ更新）
はスキップされる（ADR-PU-015）。

---

## Phase A-0: 事前検証

A-0 は Phase A の前に **以下の順序** で必ず実行する。

### A-0-1. 引数バリデーション

呼び出し元コマンドから受け取った `target` 値を XR-1（[cross-cutting-rules.md](cross-cutting-rules.md)）の
ホワイトリスト `all` / `current-project` と照合する。
不正値の場合は以下のエラーで処理を中断する（後続フェーズには進まない）:

```text
エラー: 不正な target 値 "<value>" が指定されました。有効な値は all / current-project です。
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
  実装されていると判定し、欠落サブコマンドの不在は実行時の exit code で検知する** 二段防御戦略を採用。
  **片方のみが検出される場合の障害診断**: A-0-2 通過後に Phase B（`claude plugin marketplace update`）
  または Phase C/D/E（`claude plugin update`）で連続失敗が発生したら、当該サブコマンドの
  存在を個別確認する診断パスとして以下を実行することをユーザに推奨する INFO を Phase F-4 に
  併記する:
  - `claude plugin --help` で `update` 行を確認
  - `claude plugin marketplace --help` で `update` 行を確認

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
2. 取得した絶対パスに **XR-3 サニタイズを適用**（特に `<user-home>` マスクで Windows の
   `C:\Users\<USER>\AppData\...\claude.exe` 等のユーザー名を伏字化）してから INFO 文言に
   **埋め込んで** 提示する:

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

## Phase A: 対象収集（読み取りのみ・dry-run 時も全手順通常実行・変更系 CLI のみ省略）

### target による収集範囲

| target | 収集対象 |
|--------|---------|
| `all` | マーケットプレイス一覧 + User / Project / Local の全 `enabledPlugins` |
| `current-project` | Project / Local の `enabledPlugins` のみ（`<repo>` 配下の settings のみ） |

### 収集項目

| 項目 | 取得元 | 取得方法 | target=current-project |
|-----|-------|---------|----------------------|
| マーケットプレイス一覧 | Claude Code CLI | `claude plugin marketplace list` | スキップ |
| User プラグイン | `~/.claude/settings.json` の `enabledPlugins` | **Grep で `enabledPlugins` ブロックを抽出**（A-Sec 手順に従う） | スキップ |
| Project プラグイン | `<repo>/.claude/settings.json` の `enabledPlugins` | 同上 | 実行 |
| Local プラグイン | `<repo>/.claude/settings.local.json` の `enabledPlugins` | 同上 | 実行 |

> **NOTE（A-3 連携）**: Phase A は「`enabledPlugins` の有効/無効フラグ集合」を抽出するに留まり、
> **スコープ判定は Phase A-3 が `~/.claude/plugins/installed_plugins.json`
> から取得する**（ADR-PU-009 / ADR-PU-015）。Phase A の `User / Project / Local` 区分は settings.json の
> 所在に基づく暫定区分であり、最終的な C/D/E への振り分けは A-3 結果が確定する。

`settings.json` 系の読み取りは **必ず A-Sec 手順（Grep + ブロック終端検出）** で行う。
**全文 Read ツールでの読み込みは禁止**（`mcpServers` / `extraKnownMarketplaces` / `hooks` /
`apiKeyHelper` / `env` / `permissions` / `customApiKeyResponses` 等の機密キーがコンテキストに
混入するため）。`jq` など外部ツールも使用しない。

> **`marketplace list` 出力の取り扱い禁止事項**: `claude plugin marketplace list` の出力には
> ユーザが `https://<TOKEN>@github.com/...` 形式で MP 登録した場合に URL 埋め込みトークンが
> 含まれる可能性がある。以下を厳守する:
> 1. **MP 名のみを抽出**して内部処理に使用する（URL 列はメインコンテキストに保持しない）
> 2. **Phase F-2 の備考列に URL 列の生出力を流用しない**（`marketplace list` の生 URL 行は
>    決して備考に貼り付けない）
> 3. **A-0-2 INFO や Phase F の任意の出力に URL 列を含めない**（`marketplace list` 出力は
>    Phase A 内部の MP 名抽出処理のみで利用）

### A-Sec. シークレット二次経路の遮断（必須手順・dry-run 時も省略不可）

読み取った JSON の **`enabledPlugins` キー以外**（`mcpServers` / `extraKnownMarketplaces` / `hooks` /
`apiKeyHelper` / `env` / `permissions` / `customApiKeyResponses` 等および将来追加されうる任意の機密
キー）はメインコンテキストに一切載せない。

> **重要な概念**: 上記キー名は実例示であり「機密キー一覧」ではない。本プラグインは
> **「`enabledPlugins` のみを通すホワイトリスト構造」** を採用しており、機密キー一覧を網羅する
> 必要はない（第四手順の `enabledPlugins` 単独ホワイトリストが構造的検出を担う）。Claude Code の
> 公式 settings.json スキーマに対応する正確な機密キー名は公式リリースノートを参照。
> **本ファイル / SKILL.md / cross-cutting-rules.md の機密キー列挙は説明用の代表例**。

以下の手順を **必ず順守**する（dry-run モードでも全手順を省略しない）:

1. **第一手順（必須）**: `Grep` で `enabledPlugins` の開始ブロックを抽出（暫定範囲 500 行）:
   ```text
   Grep(pattern: '"enabledPlugins"', path: '<settings.json>', output_mode: 'content', -A: 500)
   ```

   **Unicode エスケープによる回避防止（必須補助 Grep・早期警告ベストエフォート）**: 攻撃者が
   `"enabledPlugins"`（`e` を `e` で表現）等の Unicode エスケープでキーを難読化するケースに
   備え、以下の追加 Grep を実行する。`enabledPlugins` を構成する全文字
   （`e/n/a/b/l/E/d/P/i/g/s` の各 ASCII コードポイント `a-s` 範囲）を網羅的に検出する:

   ```text
   # JSON キーリテラル `"..."` 内に Unicode エスケープが 1 個でも含まれる候補行を抽出
   Grep(pattern: '"[^"]*\\\\u00[0-9a-fA-F]{2}[^"]*[Pp]lugins"', path: '<settings.json>', output_mode: 'count')
   ```

   上記汎用パターンは `enabledPlugins` のサフィックス `Plugins`/`plugins` を含む任意のキー名で
   Unicode エスケープを検出する。検出件数が 1 件以上の場合、当該スコープを **「不正なスキーマ
   （Unicode エスケープによるキー難読化）」** としてエラー終了する（DoS サイレント発生防止のため
   早期失敗。エラー文言は output-formats.md「エラーメッセージ集約」を参照）。

   > **責務範囲**: 第一手順の補助 Grep は **早期警告のベストエフォート**。以下のケースは本補助
   > Grep ですり抜けるが、第二手順の正規表現照合（リテラル `"enabledPlugins"\s*:\s*\{` の厳密
   > マッチ）が **構造的フェイルクローズの本体** として機能し、機密キーがメインコンテキストに
   > 混入するシナリオは構造的に排除される（第二手順を通過しないため Phase A-Sec 全体が
   > 「対象なし（不正なスキーマ）」で終わる）:
   >
   > - キー全体が Unicode エスケープで書かれた場合（`ena...ns` のように
   >   サフィックス `Plugins` 部分まで完全難読化された場合）→ 補助 Grep のサフィックス
   >   `[Pp]lugins"` リテラル部分にマッチしないが、第二手順の `"enabledPlugins"` リテラル
   >   照合が同様に失敗するためシークレット混入は防がれる
   > - 想定外の Unicode 形式（`\u{xxxx}` 等の JSON 標準外拡張表記）→ 同様に第二手順で弾かれる
   >
   > **エラー経路の差**: 補助 Grep が **検出に成功した場合** は output-formats.md「enabledPlugins
   > キーが Unicode エスケープで難読化されている」エラーで終了する（ユーザに難読化検出の警告が届く）。
   > 補助 Grep が **すり抜けた場合**（完全難読化等）は当該エラーは発火せず、第二手順で
   > **「対象なし（不正なスキーマ）」** 扱いとなり Phase F に空テーブルで報告される
   > （シークレット混入は防がれるが、「Unicode エスケープによる難読化があった」という警告は届かない）。
   > この差は第一手順がベストエフォートであることに由来する仕様上の限界。
2. **第二手順（必須）— 型ガード**: 抽出結果から `"enabledPlugins"` キーに続く `:` の **直後の
   非空白文字** を **正規表現 `"enabledPlugins"\s*:\s*\{` の事前マッチ** で厳密に判定する
   （LLM 自由解釈ではなく正規表現照合で実装する）。マッチしない場合は当該スコープを
   「対象なし（不正なスキーマ）」として扱い、Phase F にその旨を備考付きで報告する（後続の
   Phase A-Sec 第三手順以降には進まない）。具体的に弾かれる例:
   - `[`（配列型）/ `"`（文字列型）/ 数字 / `-` / `+`（数値型）
   - `t` / `f` / `n`（true / false / null リテラル先頭。**`enabledPlugins: null` 自体は「スキーマ不正」**
     扱いであり、後段の `enabledPlugins.{plugin}: null`（要素値の null = 「無効と同等扱い」）とは
     **粒度が異なる** ことに注意）
   - **`{` 等の Unicode エスケープ表現の `{`**: リテラルな `{` 文字とは別物として扱い、
     型ガード非通過とする（Unicode エスケープを含む JSON は第三手順でもフェイルクローズ対象であり、
     ここで先行的に弾く方が安全。フェイルクローズで即エラー終了）
   - `enabledPlugins` キー自体が存在しない（Grep が空結果を返した場合）

   リテラル `{` が確認できた場合のみ **第三手順へ進む**（明示的な順序制約）。
3. **第三手順（必須）— ブロック終端検出（構造解析）**: 抽出結果を Claude が走査し、`enabledPlugins`
   の値である `{` の対応する `}` を検出した時点で **それ以降のテキストを破棄** する。具体的には:
   - 値の `{` 位置から開始し、`{` でネストレベル +1、`}` でネストレベル -1 を計上
   - **`[` `]` は別カウンタとして並行追跡** し、`[` でレベル +1、`]` でレベル -1。`enabledPlugins`
     値はオブジェクト（`{...}`）であるため `[` `]` は将来サブ値が配列化された場合にのみ出現する。
     **異常検知の判定条件**:
     - `{` `}` ネストレベルが 0 に戻った時点で **`[` カウンタが 1 以上のまま** であれば、
       `{...}` ブロック終端が `[...]` の外側で起きた構造異常 = 即エラー終了
     - **`]` カウンタが負（`-1` 以下）になった時点で即エラー終了** （`[` 開始なしの `]` が出現 =
       構造異常）
     - 同様に **`}` カウンタが負になった時点で即エラー終了** （`{` 開始なしの `}` が出現）
     - エラー文言は output-formats.md「エラーメッセージ集約 → A-Sec 第三手順 [ ] カウンタ異常」を参照。
     **正常系**: `[` カウンタが 0 に戻ってから `{` `}` ネストレベルが 0 に戻る順序であれば
     現スキーマ（フラット）でも将来の配列拡張スキーマでも合法。
   - ネストレベルが 0 に戻った位置までを `enabledPlugins` ブロックとして保持し、それ以降は破棄
   - **保持範囲の定義（厳密）**: 保持テキストは値の `{` から対応する `}` まで（**両端の波括弧を含む**）。
     **`"enabledPlugins":` キー文字列自体は保持テキストに含めない**（保持範囲の起点は `{` 開始位置）。
     これにより、第四手順のホワイトリスト検証で `enabledPlugins` 自身を「混入キー」と誤検出する
     事故を構造的に排除する。
   - **文字列リテラル内の `{` `}` は計上対象外（必須）**: `"..."` で囲まれた範囲内の波括弧は
     カウントしない。文字列リテラルの境界判定は以下を厳密に守る:
     - `\"`（バックスラッシュ + ダブルクォート）は文字列終端とみなさない（`"a\"b{c"` は文字列内）
     - `\\` は「バックスラッシュ自身のエスケープ」であり、直後の `"` は文字列終端として扱う
       （`"a\\"` は文字列終端 = `\\"` の手前で閉じる）
     - **Unicode エスケープ `\u00XX` は文字列リテラル内の通常文字** として扱う。
       特に `}`（`}`）/ `{`（`{`）/ `"`（`"`）の Unicode エスケープを **値**
       として展開して計上対象に含めることは禁止（フェイルクローズ：Unicode エスケープを含む
       `enabledPlugins` ブロックは安全側に倒して即エラー終了。エラー文言の SSOT は
       output-formats.md「エラーメッセージ集約 → enabledPlugins Unicode エスケープ検出」を参照）:
       ```text
       エラー: enabledPlugins ブロック内に Unicode エスケープ（\u00XX 形式）が含まれています。
       境界判定の安全性確保のため処理を中断します。
       対処方法: settings.json の enabledPlugins 内の文字列リテラルから Unicode エスケープを
       除去し、直接対応する文字（例: - → -）に変換してから再実行してください。
       プラグイン名・マーケットプレイス名は ASCII 範囲のみで構成されることが推奨されます。
       ```
     - サロゲートペア（`😀` 等）は同様に「文字列内の通常文字」として扱い、
       上記 Unicode エスケープと同様にエラー終了
   - **簡略実装（文字列リテラル考慮なし）は禁止**: プラグイン名キーに `"plugin}@mp"` のような
     `}` を含む値が存在すると終端を誤検出し、後続の `mcpServers` / `apiKeyHelper` 等の機密キーが
     `enabledPlugins` ブロックに混入するリスクがあるため、文字列リテラル考慮は必須とする
   - **LLM 走査の実装精度について**: 本手順は Claude（LLM）が長文に対して状態機械
     （文字列内/外、エスケープ直後、ネストカウンタ、配列カウンタ）を走査することを要求するが、
     LLM の取りこぼしリスクは構造上ゼロにできない。第四手順（ホワイトリスト方式の事後検証ガード）が
     **構造的バックストップ** として機能する設計。決定論的実装（外部 Bash + Python による
     `json.loads` ベースの抽出）への移行は ADR-PU-003 Future Direction で議論する
   - **第四手順スキップ禁止（フェイルクローズ）**: 第三手順を完了した時点で **必ず第四手順を
     実行する**。Claude が「第三手順で問題なし」と判断して第四手順をスキップすることを禁止。
     第三・第四手順のいずれかをスキップした場合（または実行有無が不明な場合）は A-Sec 全体の
     フェイルクローズとしてエラー終了する

4. **第四手順（必須）— 事後検証ガード（フェイルクローズ二重化・パターン検証）**: 第三手順の
   ブロック終端検出後、**保持テキスト** に対して **`enabledPlugins` 以外のトップレベル相当キーが
   1 件でも検出されたらフェイルクローズ** とする（**ホワイトリスト方式**を採用）:

   ```text
   # 保持テキスト内のトップレベル相当のキーを全列挙（任意インデント対応：4 スペース・タブ含む）
   ^\s*"([A-Za-z_][A-Za-z0-9_]*)"\s*:
   ```

   インデント上限は撤廃（`\s*` で任意の先頭空白を許容）。プラグイン識別子は必ず `@` を含むため
   `[A-Za-z_][A-Za-z0-9_]*` パターンに合致せず、誤検知リスクは生じない。**4 スペースインデント・
   タブインデント・混在インデントの settings.json でも検出漏れが起きない構造**。

   **判定式（厳密）**:

   ```text
   detected_keys = findall(pattern, 保持テキスト)
   # 第三手順の保持範囲定義により、保持テキストに enabledPlugins キー自身は含まれない
   # （起点が { 開始位置のため）。よって detected_keys には enabledPlugins は通常含まれない
   # が、防御的に除外フィルタを適用する:
   forbidden_keys = [k for k in detected_keys if k != "enabledPlugins"]
   if len(forbidden_keys) >= 1:
       raise Error("検出キー: " + forbidden_keys[0])  # 即エラー終了
   ```

   `len(forbidden_keys) >= 1` 判定（件数が 1 以上で即エラー）が正しい実装。`>= 2` や
   `> 0 で即エラー（除外フィルタなし）` は誤実装であり、正常な settings.json で常時
   フェイルクローズしてしまう / 機密キー混入を許容してしまうため厳禁。

   ホワイトリスト方式を採用する理由: Claude Code の `settings.json` には今後新規の機密キー
   （`anthropicApiKey` / `awsCredentials` / `oauthAccount` / `proxy` / `httpsProxy` 等）が追加される
   可能性があり、列挙方式（ブラックリスト）では未知キーに対して未防御となる。`enabledPlugins`
   配下の値はオブジェクト型でありキー部分は `"<plugin>@<mp>":` 形式のため、ホワイトリスト方式でも
   誤検出は起きない（プラグイン識別子は `@` を含むため `[A-Za-z_][A-Za-z0-9_]*` パターンに
   合致しない）。

   **将来拡張への注意**: 現在の `enabledPlugins` スキーマはフラット 1 段ネスト
   （`{ "<plugin>@<mp>": true|false|null }`）を前提としている。将来 Claude Code が
   `{ "<plugin>@<mp>": { "enabled": true, "config": {...} } }` のようなネスト拡張を導入した場合、
   サブキー（`enabled` / `config`）がインデント任意段数で出現する。本第四手順の正規表現は
   `\s*` で任意インデントに対応しているため、サブキー（`enabled` / `config` など `[A-Za-z_][A-Za-z0-9_]*`
   パターンに合致するもの）が **誤って混入キーとして検知される可能性がある**。
   スキーマ拡張時は本第四手順の正規表現に「`@` を含むキーの直下サブキーは除外」する除外フィルタの
   追加が必要。回帰テスト基準は ADR-PU-003 Future Direction を参照。

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

#### target と git リポジトリの関係

| target | git リポジトリ状態 | 動作 |
|--------|------------------|------|
| `current-project` | リポジトリ外 | エラーで中断 |
| `current-project` | リポジトリ内 | `<repo>` を使用して通常実行 |
| `all` | リポジトリ外 | `<repo>` は不要。Marketplace + User は実行。Project / Local は `installed_plugins.json` の各 `projectPath` から更新 |
| `all` | リポジトリ内 | `<repo>` は参考情報として保持するが、Project / Local の対象範囲は `installed_plugins.json` の全 `projectPath` |

`target=current-project` で git リポジトリ外の場合:

```text
エラー: target=current-project が指定されましたが、git リポジトリ外のため Project / Local スコープを処理できません。
全プロジェクトのプラグインを更新したい場合は /update-all を使用してください。
```

`target=all` で git リポジトリ外の場合の INFO:

```text
INFO: git リポジトリ外で実行されたため、target=all でも現在のプロジェクトの Project / Local スコープはありません。
他プロジェクトの Project / Local プラグインは installed_plugins.json の projectPath に基づいて更新されます。
```

各プラグインエントリは `target=all` の場合 **(scope, plugin-name, marketplace-name, projectPath)** の
4 つ組、`target=current-project` の場合 **(scope, plugin-name, marketplace-name)** の 3 つ組として記録。
スコープ / projectPath が異なれば同一 (plugin-name, marketplace-name) でも別エントリとして扱う。

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
   - **0 個の場合**: マーケットプレイス名なし（プラグイン名のみ）の不完全エントリ。Phase F 備考列に
     「Skipped（不正な名前: マーケットプレイス指定なし）」を表示
   - **2 個以上の場合**: 誤形式（プラグイン名または MP 名に `@` が含まれる）。Phase F 備考列に
     「Skipped（不正な名前: `@` の数が不正）」を表示
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

### target=current-project 時の A-2 挙動

`target=current-project` では Phase A で `claude plugin marketplace list` を **スキップ** するため、
A-2 の MP 整合性検証に必要なデータが存在しない。この場合 **A-2 自体をスキップ** し、
Phase A-3 の `installed_plugins.json` ベース検証のみで Project/Local エントリを処理する。

A-2 スキップ時の影響:
- XR-2 サーキットブレーカーの MP 名解決は Phase B 不実行のため不要（`target=current-project` では
  Phase B 自体がスキップされるため、B-1 由来の Failed カウントは発生しない）
- MP 未登録エントリが Phase D/E に到達する可能性があるが、CLI 側で `not found` を返すため
  Missing として記録される（ADR-PU-005 の exit code 一次判定で吸収）

### 二重実施の挙動と A→B 間ドリフト

A-2 は `target=all` の場合、**Phase A 直後に 1 回のみ実施** する。Phase B 後の再実施は行わない
（ADR-PU-003 / ADR-PU-002 参照）。

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

> **状態保持要件（再掲）**: Phase A で取得した `claude plugin marketplace list` 結果は、A-2 完了後も
> **B-1 結果分類完了まで保持** すること（ADR-PU-005 偽陽性回避ルールの A-2 連携で再利用）。

---

## Phase A-3: スコープ判定（installed_plugins.json による）

### A-3 が解決する問題

`enabledPlugins`（settings.json）は **そのスコープにおける有効/無効フラグ** であり、
プラグインが **どこに（user / project / local のどの projectPath に）インストールされたか** を
表現しない。`scope=project|local` のプラグインは `~/.claude/plugins/installed_plugins.json` の
`projectPath` フィールドが **真のインストール先** を示す。

A-3 は `installed_plugins.json` を **スコープ判定の SSOT** として読み取り、`target` パラメータに
応じて各エントリを分類する。

#### target=all の場合（全プロジェクト更新）

| 判定 | 扱い |
|------|------|
| `projectPath` のディレクトリが実在する project/local エントリ | Phase D / E の更新対象（当該 `projectPath` で CLI を実行） |
| `projectPath` のディレクトリが実在しない project/local エントリ | **Skipped（projectPath ディレクトリ不在）** |
| `scope=user` のエントリ | Phase C の更新対象 |
| `installed_plugins.json` に存在しない `enabledPlugins` エントリ | **Skipped（未インストール）** |

#### target=current-project の場合（現在のプロジェクトのみ）

| 判定 | 扱い |
|------|------|
| 現在の `<repo>` と一致する `projectPath` を持つ project/local エントリ | Phase D / E の更新対象 |
| `projectPath` が現在の `<repo>` と不一致な project/local エントリ | **Skipped（現在のプロジェクト外）** |
| `scope=user` のエントリ | スキップ（Phase C 自体が `target=current-project` では非実行） |
| `installed_plugins.json` に存在しない `enabledPlugins` エントリ | **Skipped（未インストール）** |

設計判断は ADR-PU-009 / ADR-PU-015 を参照。

### A-3-1. installed_plugins.json の Read

| 項目 | 値 |
|------|-----|
| 読み取りパス | `~/.claude/plugins/installed_plugins.json` |
| 読み取り方式 | **Read ツールで全文読み込み可**（機械生成ファイルで `mcpServers` / `apiKeyHelper` 等の機密キーを構造的に含まないため。**前提**: ADR-PU-009 Trade-offs に列挙された現行スキーマフィールド `scope` / `projectPath` / `installPath` / `version` / `installedAt` / `lastUpdated` / `gitCommitSha` のみが含まれること。スキーマ変更時は ADR-PU-009 Future Direction を参照） |
| **ファイルサイズ上限** | **4000 行 または 1 MB のいずれか先に到達した時点でフェイルクローズ** とする（DoS 抑止 / CWE-400）。超過時は A-3 をスキップしファイル不在時と同じ INFO + 警告を表示する。Read ツールは `limit: 4000` を明示してから取得し、戻り値が打ち切られた場合は超過とみなす |
| ファイル不在時 | A-3 をスキップし、Phase A の `enabledPlugins` 抽出結果に対して既定スコープ（settings.json
由来）で処理を継続。Phase F-4 に「`installed_plugins.json` が見つからないため projectPath による
スコープ真値判定を行えませんでした。Project / Local スコープのプラグインで更新失敗が起きた場合は
別プロジェクトでのインストールである可能性があります」を INFO 表示 |

> **ホワイトリストピックアップ（必須・CWE-20 対策）**: Read 直後、各 `<plugin>@<mp>` 配列要素から
> **`scope` と `projectPath` の 2 フィールドのみ** を抽出した派生オブジェクトを構築し、以降の処理は
> 派生オブジェクトに対してのみ行う。`installPath` / `installedAt` / `lastUpdated` / `gitCommitSha` /
> `version` および攻撃者が注入する可能性のある未定義フィールド（`description` / `notes` 等の任意長
> 値）はメインコンテキストに保持しない。これにより、将来 Claude Code がスキーマ拡張した際に新規
> フィールドが意図せずコンテキスト混入する経路を構造的に遮断する。

### A-3-2. スキーマバージョン検証

```text
expected: { "version": 2, "plugins": { "<plugin>@<mp>": [ {scope, projectPath?, ...}, ... ] } }
```

- `version` フィールドが整数 `2` でない場合（`null` / 文字列 / 不在 / `1` / `3` 以降）は **未対応スキーマ**
  として A-3 をスキップし、A-3-1 のファイル不在時と同じ INFO を表示する（フェイルセーフ）。
- 将来 `version` が増加した場合に備え、本プラグインを更新してから再実行するようユーザに促す。

> **フォールバック時の XR-1 適用範囲**: A-3 をスキップするフォールバック経路では、
> `installed_plugins.json` 由来の値は使用されず、Phase A の `enabledPlugins` 抽出結果（A-1 で
> XR-1 検証済み）のみが C/D/E に渡るため、入力検証の盲点は生じない。XR-1 二重適用の責務は
> A-1（settings.json 由来）と A-3-4（installed_plugins.json 由来）で **データソース別に対称的**
> に担保される（一方のフォールバック時はもう一方が実効、両方有効時は両方適用）。

### A-3-3-pre. `projectPath` のパス検証（XR-1 パス検証の対称適用・必須）

`<repo>` 側は XR-1 のパス検証を A-Repo で適用済みだが、`projectPath` 側は外部入力
（`installed_plugins.json` 由来）であり、ホームディレクトリ上のファイルが他プロセスに改変された場合の
攻撃面となる。比較前に **`projectPath` に対しても XR-1 のパス検証を対称的に適用** する（CWE-22 / CWE-706 防御）:

| 検証項目 | 判定 |
|---------|------|
| `..` を含まない | 含めば当該エントリを Skipped（不正な projectPath）として除外 |
| 改行・null 文字・制御文字（`\x00`〜`\x1F` / `\x7F`）を含まない | 含めば除外 |
| **長さ上限** | 4096 文字超過で除外（OS 依存の現実的なパス上限） |
| 末尾の連続空白を含まない | 含めば除外（NTFS の trailing-space 詐称対策） |
| Windows 拡張長プレフィックス `\\?\` で始まらない | 始まれば除外（`\\?\C:\repo\..\evil` 系の正規化バイパス対策） |
| Windows UNC パス（`^\\\\` で始まる）でない | UNC ならば除外（リモート共有経由の信頼境界外） |
| 絶対パス | Windows: 正規表現 `^[A-Za-z]:[\\/]`、POSIX: `^/`。相対パスならば除外 |

検証に失敗したエントリは **Skipped（不正な projectPath）** として記録し、`<repo>` との比較には
進めない。XR-1 のパス検証は SSOT として [`cross-cutting-rules.md`](cross-cutting-rules.md) を参照する
（規則本体を本ファイル内で再定義しない）。

### A-3-3. `<repo>` および `projectPath` の正規化

`projectPath` の文字列比較に先立ち、両者を **同一 OS 判定で対称的** に正規化する:

| 実行 OS | 正規化手順 |
|---------|----------|
| **Windows** | (a) `/` を `\` に置換、(b) 末尾区切り削除（ルートは 1 文字残す）、(c) ASCII 範囲で `tolower`（NTFS 大文字小文字非区別に整合） |
| **POSIX** | (a) 末尾 `/` 削除（ルートは 1 文字残す）、(b) 大文字小文字を維持。**`\` の `/` 置換は行わない**（POSIX で `\` はファイル名として合法な文字のため、変換すると別パスと誤一致するリスクがある） |

正規化は `<repo>` と `projectPath` の **両方に同じ手順** を適用したうえで文字列比較する。
両者で異なる OS の手順を混在させない。

> ⚠️ **シンボリックリンク・ジャンクション**: XR-1 のパス検証で既に拒否済み（`<repo>` は
> 通常ディレクトリのみが採用される）。`projectPath` 側についてはユーザの過去のインストール時点の
> パスがそのまま記録されているため、シンボリックリンク経由でインストールされた稀ケースでは
> 文字列一致しない可能性がある（Skipped として扱われる安全側の動作）。実害は「更新できないので
> ユーザが手動で `/plugin update` を実行する必要がある」のみで、誤更新は発生しない。

> **POSIX で `\` を含む `projectPath` の扱い**: WSL 経由インストール時の誤記等で `projectPath` に
> backslash が混入したケースは「正規化しても `<repo>` と一致しない可能性が高い」ため、結果的に
> Skipped（現在のプロジェクト外）として扱われる。これは誤更新を防ぐ安全側の動作であり、ユーザは
> 該当 `projectPath` のディレクトリで再インストールするか `enabledPlugins` を整理することで解消できる。

### A-3-4. エントリ突合と分類（交差集合方式）

> **交差集合の必須性**: 候補集合は **「enabledPlugins ∩ installed_plugins.json」の交差集合のみ** を
> 採用する。`installed_plugins.json` のみに存在し `enabledPlugins` に登録されていないキーは
> A-3-5 の「enabledPlugins 未登録」として Skipped とし、CLI には到達させない。これにより、
> `installed_plugins.json` 単独に攻撃者が細工キーを注入しても、A-1（settings.json）を経由しない
> ルートで CLI に到達することはできない（XR-1 二重防御の構造化）。

`installed_plugins.json["plugins"]` の各キー `<plugin>@<mp>` について、配列の各要素を以下のように分類する:

```text
for plugin_at_mp, entries in installed_plugins["plugins"].items():
    plugin, mp = plugin_at_mp.split("@", 1)
    # XR-1 の入力検証は A-1 で済んでいるが、installed_plugins.json 由来の値は
    # 未検証のため A-3 でも再度 XR-1 を適用してから採用する
    if XR-1 不合致:
        記録: Skipped（不正な名前: installed_plugins.json 由来）
        continue
    for entry in entries:
        scope = entry["scope"]
        if scope == "user":
            if target == "all":
                候補に追加: (scope=user, plugin, mp)
            # target=current-project の場合は user スコープをスキップ
        elif scope in ("project", "local"):
            project_path = entry.get("projectPath")
            if not project_path:
                記録: Skipped（installed_plugins.json projectPath 欠落）
                continue
            if target == "all":
                # ディレクトリ存在確認のみ（<repo> との一致は不要）
                if ディレクトリが実在する(正規化(project_path)):
                    候補に追加: (scope, plugin, mp, project_path)  # project_path を保持
                else:
                    記録: Skipped（projectPath ディレクトリ不在）
            elif target == "current-project":
                # 現在の <repo> と一致チェック（従来の挙動）
                if 正規化(project_path) == 正規化(<repo>):
                    候補に追加: (scope, plugin, mp)
                else:
                    記録: Skipped（現在のプロジェクト外）
            # projectPath 値はメインコンテキストに保持しない（XR-3 サニタイズの C:\Users\... マスク方針に整合）
        else:
            記録: Skipped（未知の scope 値）
```

> **`target=all` でのディレクトリ存在確認**: `projectPath` のディレクトリが実在するかどうかは
> XR-1 パス検証（A-3-3-pre）通過後に確認する。実在判定は Read ツールまたは
> `test -d <path>`（Bash）/ `Test-Path <path>`（PowerShell）で行う。
> `projectPath` は正規化済みかつ XR-1 パス検証済みであるため、コマンドインジェクションのリスクは排除済み。

### A-3-5. settings.json の `enabledPlugins` と突合（disabled 除外）

A-3-4 で抽出した候補に対し、Phase A で取得済みの該当スコープ `enabledPlugins` を確認する:

| `enabledPlugins[<plugin>@<mp>]` の値 | 扱い |
|--------------------------------------|------|
| `true` | Phase B-1 結果が OK / 部分失敗（許容）/ 全体失敗（警告付き継続）の MP 配下なら C/D/E の更新対象 |
| `false` | **Skipped（disabled）** として記録（リトライ対象外） |
| `null` | **Skipped（disabled / 無効と同等扱い）** として記録（リトライ対象外） |
| キー欠落 | **Skipped（enabledPlugins 未登録）** として記録（リトライ対象外） |

> **enabledPlugins 未登録の意味**: `installed_plugins.json` に存在するが `enabledPlugins` にキーが
> 存在しない場合、Claude Code 仕様上「インストール済みだが当該スコープでは未有効化」を意味する。
> 当該プラグインを更新すべきか不明確であり、ユーザの明示的な有効化を促すため Skipped 扱いとする
> （誤って予期しない hooks / MCP を引き込まない安全側の動作）。

### A-3 から派生する Skipped 区分（リトライ対象外）

A-3 が確定した時点で、以下の Skipped 区分が派生する。**いずれも Phase G リトライ対象から除外** する。
備考列の定型文は [`output-formats.md`](output-formats.md) の「F-3 備考列の Skipped 区分定型文」表が SSOT。

| 区分 | 発生条件 | 備考列定型文（output-formats.md SSOT より） |
|------|---------|------------------------------------------|
| **Skipped（projectPath ディレクトリ不在）** | `target=all` かつ `projectPath` のディレクトリが実在しない | `projectPath のディレクトリが存在しないためスキップしました` |
| **Skipped（現在のプロジェクト外）** | `target=current-project` かつ `projectPath != <repo>` | `現在のプロジェクト外にインストールされたプラグインをスキップしました` |
| **Skipped（未インストール）** | 共通 | `installed_plugins.json に該当エントリがありません` |
| **Skipped（disabled）** | 共通 | `enabledPlugins で false / null のため対象外` |
| **Skipped（enabledPlugins 未登録）** | 共通 | `当該スコープの enabledPlugins に未登録` |
| **Skipped（projectPath 欠落）** | 共通 | `project / local スコープに projectPath が記録されていません` |

> **リトライ対象外の根拠**: これらの Skipped は「設定の問題」（enabledPlugins 編集 /
> `/plugin install` / ディレクトリ復元 等）でしか解消しない永続的状態であり、CLI のリトライでは
> 回復しないため Phase G の対象としない。Missing と同様の扱い（ADR-PU-007 / ADR-PU-009）。

### A-3-6. Phase F-4 アクション提示の追加

A-3 由来の Skipped が 1 件以上発生した場合、Phase F-4 の「次のアクション」に以下を追記する。
**注意**: アクション文言中で `projectPath` の **実値を出力しない**。「その `projectPath` のディレクトリ」
のように一般語で表現し、実値を出力する場合は **必ず XR-3 サニタイズ（`<user-home>` マスク）を
通したうえで** 出力する。

- **Skipped（projectPath ディレクトリ不在）が 1 件以上**: 「該当 projectPath のディレクトリが
  存在しません。ディレクトリを復元するか、`enabledPlugins` から該当エントリを除外してください」
- **Skipped（現在のプロジェクト外）が 1 件以上**（`target=current-project` の場合のみ）:
  「全プロジェクトのプラグインを更新したい場合は `/update-all` を実行してください」
- **Skipped（未インストール）が 1 件以上**: 「該当エントリを `enabledPlugins` から除外するか、
  `claude plugin install <plugin>@<marketplace>` でインストールしてください」
- **Skipped（disabled）/（enabledPlugins 未登録）が 1 件以上**: 「該当プラグインを有効化したい
  場合は `/plugin` で有効化してください」

---

## Phase B: マーケットプレイス更新（最初に必ず実行・XR-1/XR-2/XR-3 を適用・dry-run 時はコマンド表示のみ）

`target=all` の場合は常に実行する。`target=current-project` の場合は **スキップ** する（ADR-PU-015）。

```bash
claude plugin marketplace update
```

### B-1. 結果判定

結果分類テーブル（マーケットプレイス更新用）は ADR-PU-005 の「結果分類テーブル — マーケットプレイス更新（B-1）」
セクション（[architecture-decisions.md](architecture-decisions.md)）を参照。
例外行抽出パターン・Unknown 区分の扱いも ADR-PU-005 に集約されている。

> **状態保持要件**: ADR-PU-005 の偽陽性回避ルール（A-2 整合性検証連携で `timeout` 等の汎用語を
> Unknown に格上げ）を実施するため、**Phase A で取得した `claude plugin marketplace list`
> 結果を A-2 終了後も B-1 結果分類完了まで保持** すること。本スナップショットは A-2 と B-1 の
> 両方で参照される。Phase B 自体は MP 一覧の追加・削除のみで既存エントリ名は変わらないため
> ドリフトリスクは低い（ADR-PU-003 Trade-offs / ADR-PU-005 補足参照）。

> **SSOT 注記（サーキットブレーカー）**: 本 Phase B / B-1 における Failed カウントが XR-2
> サーキットブレーカー（MP 単位累計 3 件）に集計される際の集計対象（B-1 部分失敗のみ・全体失敗
> およびUnknown は対象外）と、G-3 リトライ時に Phase B 全件再実行へサーキットブレーカーが
> **適用されない設計上の許容事項** は、**ADR-PU-006 が SSOT**。本ファイルは再定義しない。

---

## Phase C / D / E: スコープ別プラグイン更新（XR-1/XR-2/XR-3 を適用・dry-run 時はコマンド表示のみ）

各スコープの更新対象は **Phase A-3 で確定した候補集合**（A-3-5 で `enabledPlugins=true` と
判定されたエントリ）から取得する。A-3 で派生した Skipped（projectPath ディレクトリ不在 /
現在のプロジェクト外 / 未インストール / disabled / enabledPlugins 未登録 / projectPath 欠落）は
すべて C/D/E の対象外であり、Phase F-3 にスキップ理由を備考付きで表示するのみで CLI を呼び出さない。

### Phase C: User スコープ更新

`target=all` の場合のみ実行。`target=current-project` の場合はスキップ。

```bash
claude plugin update <plugin-name>@<marketplace-name> --scope user
```

### Phase D / E: Project / Local スコープ更新

#### target=all の場合（全プロジェクト更新・ADR-PU-015）

候補集合を **`projectPath` でグルーピング** し、各 `projectPath` ディレクトリ内で CLI を実行する。

```bash
# 各 projectPath ごとに、サブシェルでディレクトリを変更して実行する（cwd 復帰保証）
(cd <projectPath> && claude plugin update <plugin-name>@<marketplace-name> --scope project)
(cd <projectPath> && claude plugin update <plugin-name>@<marketplace-name> --scope local)
```

- **cwd 復帰保証（MANDATORY）**: `cd <projectPath>` は **必ずサブシェル `(...)` で囲む**。
  これにより CLI の成否に関わらず、後続の projectPath 処理前に元のディレクトリに自動復帰する。
  `pushd`/`popd` パターンでも可だが、サブシェルの方がエラー時の復帰保証が確実。
  Phase G-3 のリトライ時にも同じサブシェルパターンを適用する
- `projectPath` は A-3-3-pre の XR-1 パス検証を通過済みであること（必須前提）
- ディレクトリ移動前に `projectPath` が A-3-4 のディレクトリ存在確認を通過していること
- **実行順序**: `projectPath` ごとにまとめて処理し、同一 `projectPath` 内では Phase D（project）→
  Phase E（local）の順で逐次実行する。`projectPath` 間の実行順序は `projectPath` の
  アルファベット順（正規化後）で固定し、Phase F-3 の表示順序と一致させる

#### target=current-project の場合（現在のプロジェクトのみ）

現在のディレクトリ（`<repo>`）で従来通り実行する。

```bash
# Phase D: Project スコープ
claude plugin update <plugin-name>@<marketplace-name> --scope project

# Phase E: Local スコープ
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

> **状態保持要件（G-1 用）**: `<bn>` の **変数定義・集計タイミング・保持要件の SSOT** は
> [`output-formats.md`](output-formats.md) の「Phase G-1 質問文 → 変数定義（SSOT）」表を参照。
> 本ファイルは再定義しない（ADR-PU-006 由来の値）。

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
| マーケットプレイス Failed（`target=all` のみ） | **Phase B を引数なしで再度実行**（`claude plugin marketplace update` = 全マーケットプレイス対象）。**サーキットブレーカー作動中の MP も Phase B 全件リトライでは再試行され得る**: Phase B は MP 単位個別指定をサポートしないため、XR-2 「サーキットブレーカー作動中の MP は G-3 のリトライ対象から除外」原則は **プラグイン単位（C/D/E）のリトライにのみ適用** され、MP 単位の Phase B 全件リトライには適用されない（設計上の許容事項）。CLI が `claude plugin marketplace update <name>` の引数指定をサポートしたら個別 MP リトライに切り替えてサーキットブレーカー除外を厳密化する（ADR-PU-002 Future Direction 参照） |
| プラグイン Failed（C/D/E 由来） | `claude plugin update <plugin>@<marketplace> --scope <scope>` を当該エントリのみ実行。`target=all` の場合は当該 `projectPath` ディレクトリ内で実行 |

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

> **Phase G の終了**: G-4 完了をもって Phase G は終了する。XR-4 によりリトライは元の失敗集合に対し
> 最大 1 回のため、リトライ後の新規失敗は記録のみで Phase G は **再起動しない**（無限ループ防止）。

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
- Phase A-1 / A-2 / A-3 の検証も実行（A-3 は読み取り専用・スコープ判定）
- Phase B / C / D / E（**変更系 CLI**）の代わりに、実行予定の CLI コマンド一覧を表示。フォーマットは
  [`output-formats.md`](output-formats.md) の **「Phase F（dry-run モード）」セクション**
  （F-1 / F-2 / F-3 dry-run 専用テーブル）を SSOT として参照する
- `target=current-project` の場合は Phase B / C の実行予定コマンドも省略される
- `target=all` の場合は `projectPath` ごとにグルーピングされた実行予定コマンド一覧が表示される
- **XR-3 サニタイズは Phase B/C/D/E の更新ログに対しては適用不要**: dry-run 時は変更系 CLI 出力が
  発生しないため。ただし **Phase A の `claude plugin marketplace list` 出力** は通常モードでも
  サニタイズ対象外（出力フォーマットが MP 名・URL 主体で機密性が低い）であり、dry-run でも同様の
  扱い（output-formats.md Phase F(dry-run) 末尾の注記参照）
- Phase F-4 / G はスキップ

**重要な制約**: `--dry-run` は **実行予定のコマンド一覧** のみを提示します。
**各プラグインの変更内容（新規 hooks / MCP / agents の追加）は確認しません**。
変更内容の確認には実行後 `claude plugin show <plugin>@<marketplace>` を別途実行する必要があります。

---

## 注意事項（ユーザー向け）

ユーザー向け注意事項（サプライチェーンリスク・ロールバック手順・破壊操作回避・autoUpdate 同時実行）は
プラグイン README に集約されている。本スキルでは実行手順のみを記述し、ユーザー向け注意事項の
重複は避ける。
