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

`claude plugin --help` を実行し以下をすべて満たすことを確認する:

- exit code が 0
- 出力に正規表現 `^\s+marketplace\s+update\b` または `^\s+update\b` のいずれかが
  サブコマンド一覧行として現れる（行頭インデント + サブコマンド名 + 単語境界）

サブコマンド一覧形式の正規表現は **行頭が空白で始まり、サブコマンド名が単語境界で終わる**
パターンを採用。これにより、ヘルプ末尾の説明文中に `marketplace update` という単語が含まれる
だけのシムは検出できる（説明文は通常インデントなしで開始されるため）。

いずれも満たさない場合は以下のエラーで処理を中断する:

```text
エラー: claude plugin CLI に必要なサブコマンドが見つかりません（または不正な実装の可能性）。
Claude Code のインストール状況と PATH を確認してください。
```

**注**: 出力照合は **ヒューリスティックな補助** であり、CLI バイナリ自体の真正性検証は
OS のパッケージマネージャ署名検証に依存する（ADR-PU-002 Trade-offs 参照）。
攻撃者がヘルプ出力を精巧に偽装したシムを作れば回避可能。`which claude` / `Get-Command claude`
で実行バイナリの絶対パスを確認することをユーザに推奨（README「動作要件」参照）。

---

## Phase A: 対象収集（読み取りのみ）

| 項目 | 取得元 | 取得方法 |
|-----|-------|---------|
| マーケットプレイス一覧 | Claude Code CLI | `claude plugin marketplace list` |
| User プラグイン | `~/.claude/settings.json` の `enabledPlugins` | Read ツールで読み込み Claude が JSON 解析 |
| Project プラグイン | `<repo>/.claude/settings.json` の `enabledPlugins` | 同上 |
| Local プラグイン | `<repo>/.claude/settings.local.json` の `enabledPlugins` | 同上 |

`settings.json` 系の読み取りは **Read ツールで直接ファイルを読み込み、Claude 自身が JSON を解析** する。
`jq` など外部ツールは使用しない。

### A-Sec. シークレット二次経路の遮断（必須手順）

読み取った JSON の **`enabledPlugins` キー以外（`mcpServers` / `extraKnownMarketplaces` / `hooks` 等）は
メインコンテキストに一切載せない**。以下の手順を **必ず順守**する:

1. **第一手順（必須）**: `Grep` で `enabledPlugins` の開始ブロックを抽出（暫定範囲 500 行）:
   ```text
   Grep(pattern: '"enabledPlugins"', path: '<settings.json>', output_mode: 'content', -A: 500)
   ```
2. **第二手順（必須）— 型ガード**: 抽出結果の `enabledPlugins` 直後の値が `{` で始まることを確認する。
   `[`（配列）や他の型の場合は当該スコープを「対象なし（不正なスキーマ）」として扱い、Phase F に
   その旨を備考付きで報告する。
3. **第三手順（必須）— ブロック終端検出**: 抽出結果を Claude が走査し、`enabledPlugins` の値である
   `{` の対応する `}` を検出した時点で **それ以降のテキストを破棄** する。具体的には:
   - 値の `{` 位置から開始し、`{` でネストレベル +1、`}` でネストレベル -1 を計上
   - ネストレベルが 0 に戻った位置までを `enabledPlugins` ブロックとして保持し、それ以降は破棄
4. **第四手順（必須）— ブロック終端未検出時の倍々再 Grep**: 500 行内でネストレベルが 0 に戻らない
   場合、`-A` を倍にして再実行する（500 → 1000 → 2000 → 4000）。最大 4 回まで拡張し、それでも
   未検出ならエラーで処理を中断する（フェイルクローズ。**全文 Read は禁止**）:
   ```text
   エラー: <scope> スコープの enabledPlugins ブロックが 4000 行を超えるため、
   情報漏洩防止のため処理を中断します。settings.json の構造を確認してください。
   ```
5. **抽出失敗時のフォールバック**: `enabledPlugins` キーが見つからない場合は当該スコープを
   「対象なし」として扱い、Phase F に空テーブルで報告（エラー扱いにはしない）。
   **全文 Read は禁止**（`mcpServers` 等が直接コンテキストに乗るリスクがあるため）。
6. **メインコンテキストの最終状態**: `enabledPlugins` 配下のキー・値のみが残ること。
   `mcpServers` / `extraKnownMarketplaces` / `hooks` 等のキー名を含む行は、結果報告本文・
   備考列・引き継ぎ要約のいずれにも一切出力しない。出力フィルタは「JSON 値部分の文字列照合」に
   限定し、プラグイン名・MP 名・備考の自然言語に偶発的に含まれる単語（例: `mcp-config`）と
   区別する。

### A-Repo. `<repo>` の決定と検証

`<repo>` は `git rev-parse --show-toplevel` の結果。検証ルールは XR-1 の「パス検証」セクション
（[cross-cutting-rules.md](cross-cutting-rules.md)）を参照。検証失敗時は Project / Local
処理をスキップして INFO で理由を表示する（フェイルクローズ）。

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

| 値 | 扱い |
|----|------|
| `true` | 有効として処理対象に含める |
| `false` / `null` | 明示的に無効化されているのでスキップ |
| 文字列 / オブジェクト等の異常値 | Skipped（不明な値型）として記録。Phase F 備考列には値そのものを表示せず「(不明な値型: \<型名のみ\>)」固定文言に置換 |

---

## Phase A-1: 入力検証（XR-1 を適用）

抽出した各エントリについて XR-1（[cross-cutting-rules.md](cross-cutting-rules.md)）を適用。
`@` で **分割した後** の plugin-name / marketplace-name 各部分と、scope 値を個別に検証する。
合致しないエントリは Phase F のサマリで「Skipped（不正な名前）」として除外し、CLI コマンドには絶対に渡さない。

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

## Phase B: マーケットプレイス更新（最初に必ず実行・XR-1/XR-2/XR-3 を適用）

呼び出し元の `scope` の値にかかわらず、本フェーズは常に実行する。

```bash
claude plugin marketplace update
```

### B-1. 結果判定

結果分類テーブル（マーケットプレイス更新用）は ADR-PU-005 の「結果分類テーブル — マーケットプレイス更新（B-1）」
セクション（[architecture-decisions.md](architecture-decisions.md)）を参照。
例外行抽出パターン・Unknown 区分の扱いも ADR-PU-005 に集約されている。

---

## Phase C / D / E: スコープ別プラグイン更新（XR-1/XR-2/XR-3 を適用）

各スコープの (plugin-name, marketplace-name) ごとに以下を実行する:

```bash
# Phase C: User スコープ（scope が user または all のとき）
claude plugin update <plugin-name>@<marketplace-name> --scope user

# Phase D: Project スコープ（scope が project または all、かつ git リポジトリ配下のとき）
claude plugin update <plugin-name>@<marketplace-name> --scope project

# Phase E: Local スコープ（scope が local または all、かつ git リポジトリ配下のとき）
claude plugin update <plugin-name>@<marketplace-name> --scope local
```

B-1 で MP Unknown 判定された MP 配下のエントリは除外する。

### C-1 / D-1 / E-1. 結果分類（ADR-PU-005 に基づく）

結果分類テーブル（プラグイン更新用）は ADR-PU-005 の「結果分類テーブル — プラグイン更新（C-1 / D-1 / E-1 共通）」
セクションを参照（Updated / No change / Missing / Failed / Unknown の 5 区分）。
3 スコープすべてで同一テーブルを適用する。

---

## Phase F: 結果報告

すべての更新処理を完了した時点で、必ず結果報告を提示する。
出力フォーマット（サマリ表 / 詳細テーブル / 警告メッセージ / 次のアクション）は
[`output-formats.md`](output-formats.md) を SSOT として参照する。

> **NOTE（サニタイズ適用タイミング）**: F-1 / F-2 / F-3 / G-2 で備考列・質問文を生成する
> **直前** に XR-3（[cross-cutting-rules.md](cross-cutting-rules.md)）のサニタイズを
> 必ず適用する。規則本体・列単位の例外・「文脈外」判定の具体ルール・テストケース・適用順序は
> すべて XR-3 SSOT を参照のこと。本ファイルは XR-3 を再定義しない。

---

## Phase G: 失敗対応の確認（失敗ありの場合のみ）

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
| マーケットプレイス Failed | **Phase B を引数なしで再度実行**（`claude plugin marketplace update` = 全マーケットプレイス対象）。`--scope` 指定の有無によらず Phase B は常に全 MP 対象（ADR-PU-003「Phase B を常に実行する理由」参照）。CLI が `claude plugin marketplace update <name>` の引数指定をサポートしていることが確認できたら個別 MP リトライに切り替える（ADR-PU-002 Future Direction 参照） |
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

呼び出し元から `mode = dry-run` で起動された場合、**実際の更新コマンドを一切実行せず**、以下のみ提示する。

- Phase A の対象収集は通常通り実行（Read ツールで `settings.json` 系を読み込み、`claude plugin marketplace list` を実行。
  `marketplace list` はキャッシュ参照のみで更新通信を行わないことが期待されるが、CLI バージョンにより異なる場合がある）
- Phase A-0 / A-1 / A-2 の検証も実行
- Phase B / C / D / E の代わりに、実行予定の CLI コマンド一覧を Phase F と同形式のテーブルで表示
  - 「結果」列の代わりに「実行予定コマンド」列を表示
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
