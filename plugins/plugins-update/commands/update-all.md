---
description: Claude Code 公式 CLI でマーケットプレイスとプラグインを一括最新化
argument-hint: "[--dry-run] [--scope <user|project|local>]"
---

ユーザの引数: $ARGUMENTS

Claude Code 公式 CLI（`claude plugin marketplace update` / `claude plugin update`）を経由して
インストール済みマーケットプレイスとプラグインを **一括で最新版に更新** するコマンド。
**マーケットプレイス更新 → User → Project → Local の固定順** で処理し、同一プラグインが
複数スコープに存在する場合も **スコープごとに個別に更新** する。

## 動作モード判定

| 引数 | モード | 動作 |
|-----|-------|------|
| 空 | 通常更新（全スコープ） | Phase A〜G を実行 |
| `--dry-run` | 確認のみ | 実行予定のコマンド一覧を提示。実際の更新は行わない |
| `--scope user` / `--scope project` / `--scope local` | スコープ限定 | マーケットプレイス更新後、指定スコープのみ処理 |
| 指定なし | 通常更新（全スコープ） | `--scope` 省略時は全スコープが対象 |

`--dry-run` と `--scope` は併用可能。併用時は指定スコープに限定したプレビューを表示する。
不正な `--scope` 値（例: `--scope foo`）が渡された場合は処理を実行せずエラーを返す。

## 重要原則

| 原則 | 内容 |
|-----|------|
| **公式 CLI 経由** | `claude plugin marketplace update` / `claude plugin update` を呼び出す。`git fetch` / `git reset` 等の低レベル git 操作は行わない |
| **固定順序** | マーケットプレイス → User → Project → Local の順序を厳守。順序を入れ替えない |
| **スコープ個別更新** | 同一プラグインが複数スコープにある場合、各スコープで個別に CLI を呼ぶ（重複排除しない） |
| **継続実行** | 個別更新でエラーが発生しても処理を **中断せず** 次の対象へ進む。エラーは記録し最後に集計する |
| **失敗対応の確認** | 全フェーズ完了後、失敗があれば結果報告に続けてユーザにリトライ・スキップの対応を確認する |

順序の根拠:
- マーケットプレイス更新を先に行う理由: マーケットプレイス本体が SSOT のため、最新化してからプラグイン更新を行わないと旧版のまま処理される。
- スコープ順 (User → Project → Local) の理由: 上書き優先順位（より狭いスコープが優先される）の逆順で更新することで、より広いスコープから順に最新化する。

## 実行フロー

### Phase A: 対象収集（読み取りのみ）

| 項目 | 取得元 | 取得方法 |
|-----|-------|---------|
| マーケットプレイス一覧 | Claude Code CLI | `claude plugin marketplace list` |
| User プラグイン | `~/.claude/settings.json` の `enabledPlugins` | JSON 読み取り |
| Project プラグイン | `<repo>/.claude/settings.json` の `enabledPlugins` | JSON 読み取り |
| Local プラグイン | `<repo>/.claude/settings.local.json` の `enabledPlugins` | JSON 読み取り |

`<repo>` は `git rev-parse --show-toplevel` の結果。git リポジトリ外で実行され、
かつ `--scope project` または `--scope local` が **明示指定** された場合は、
エラーメッセージを表示して処理を中断する。`--scope` 未指定時は Project / Local を黙って省略する。

各プラグインエントリは **(scope, plugin-name, marketplace-name)** の 3 つ組として記録し、
スコープが異なれば同一 (plugin-name, marketplace-name) でも別エントリとして扱う。

`enabledPlugins` の値が `false` のエントリ（明示的に無効化されたプラグイン）はスキップする。

### Phase B: マーケットプレイス更新（最初に必ず実行）

公式 CLI でマーケットプレイス全件を一括更新する。

```bash
claude plugin marketplace update
```

このコマンドは Claude Code が内部で各マーケットプレイスのソース（`github` / `git` / `path`）に
応じた更新処理を行う。手動の `git fetch` / `git reset --hard` は **不要かつ実行禁止**
（ローカル変更の意図しない破壊・ロールバック手段の喪失を防ぐため）。

| 結果 | 判定 |
|-----|------|
| コマンド成功 | OK として記録 |
| 一部マーケットプレイス失敗（CLI が部分的成功を返す） | 出力を解析して失敗マーケットプレイス名を記録、他は OK |
| コマンド全体失敗（exit code 非 0） | 失敗として記録し、Phase C 以降は警告付きで継続（プラグイン更新は新版が来ない可能性あり） |

CLI の出力フォーマットがバージョンによって異なる場合があるため、行単位で
「updated」「failed」「skipped」「up-to-date」相当のキーワードを検出して結果を分類する。

### Phase C: User スコープのプラグイン更新

`--scope` が `user` または未指定の場合のみ実行。

User スコープの (plugin-name, marketplace-name) ごとに以下を実行する:

```bash
claude plugin update <plugin-name>@<marketplace-name> --scope user
```

| 結果分類 | 判定基準 |
|---------|---------|
| Updated | CLI が exit 0 で「updated」相当のメッセージを出力 |
| No change | CLI が exit 0 で「up-to-date」「already latest」相当を出力 |
| Missing | マーケットプレイスに当該プラグインが存在しない（CLI がエラー） |
| Failed | 上記以外のエラー（ネットワーク・認証等） |

例外発生時はエラー内容を記録し、次のエントリに進む。

### Phase D: Project スコープのプラグイン更新

`--scope` が `project` または未指定の場合、かつ git リポジトリ配下のときのみ実行。
処理内容は Phase C と同等で `--scope project` を指定する。

### Phase E: Local スコープのプラグイン更新

`--scope` が `local` または未指定の場合、かつ git リポジトリ配下のときのみ実行。
処理内容は Phase C と同等で `--scope local` を指定する。

### Phase F: 結果報告

すべての更新処理を完了した時点で、以下の構造で **必ず結果報告** を提示する。
変数表記の `<count>` 等は Claude が実行時に実際の値に置き換える。

#### F-1. サマリ

```markdown
## 更新結果サマリ

| 区分 | 成功 | 変更なし | スキップ | 失敗 |
|-----|-----|---------|---------|-----|
| マーケットプレイス | <count> | - | <count> | <count> |
| User プラグイン | <count> | <count> | <count> | <count> |
| Project プラグイン | <count> | <count> | <count> | <count> |
| Local プラグイン | <count> | <count> | <count> | <count> |
```

#### F-2. マーケットプレイス詳細

```markdown
### マーケットプレイス

| マーケットプレイス | 結果 | 備考 |
|-----------------|-----|-----|
| <name> | OK / Skipped / Failed | <CLI 出力の要約 or エラー> |
```

`git` 操作を行わないため SHA は表示しない。詳細は `claude plugin marketplace list` で確認可能。

#### F-3. スコープ別詳細

```markdown
### User プラグイン

| プラグイン | マーケットプレイス | 結果 | 備考 |
|----------|-----------------|-----|-----|
| <plugin> | <marketplace> | Updated / No change / Missing / Failed | <備考> |

### Project プラグイン
（User と同形式。git リポジトリ外なら "リポジトリ外のため省略" を表示）

### Local プラグイン
（User と同形式。git リポジトリ外なら "リポジトリ外のため省略" を表示）
```

#### F-4. 次のアクション提示

```markdown
### 次のアクション

- Claude Code を再起動するか `/reload-plugins` を実行して更新をセッションに反映する
  （`claude plugin update` は **再起動が必要** と公式 CLI が明示している）
- （失敗があれば）次のリトライ・スキップ確認に応答する
```

### Phase G: 失敗対応の確認（失敗ありの場合のみ）

Phase F の結果報告後、**失敗が 1 件以上ある場合** は `AskUserQuestion` で以下を確認する。
質問文の `<N>` には失敗総数を、内訳には Phase B と Phase C〜E の失敗件数を入れる。

#### G-1. 全体方針の確認

```text
AskUserQuestion({
  questions: [{
    question: "<N> 件の更新失敗があります（マーケットプレイス: <M> 件 / プラグイン: <P> 件）。どう対応しますか？",
    header: "更新失敗対応",
    options: [
      { label: "全件リトライ", description: "失敗した全エントリをもう一度更新する" },
      { label: "個別に判断", description: "失敗エントリごとにリトライ / スキップを選択" },
      { label: "全件スキップ", description: "失敗エントリは諦めて完了する" }
    ],
    multiSelect: false
  }]
})
```

#### G-2. 個別判断モードの場合

各失敗エントリについて以下を確認:

```text
AskUserQuestion({
  questions: [{
    question: "[<scope>] <plugin>@<marketplace> の更新に失敗しました（理由: <error>）。リトライしますか？",
    header: "個別失敗対応",
    options: [
      { label: "リトライ", description: "もう一度更新を試行" },
      { label: "スキップ", description: "このエントリは諦める" }
    ],
    multiSelect: false
  }]
})
```

#### G-3. リトライ実行（範囲限定）

リトライは失敗種別に応じて **必要最小限のフェーズのみ** 再実行する。

| 失敗種別 | 再実行範囲 |
|---------|-----------|
| マーケットプレイス失敗 | `claude plugin marketplace update <name>` を当該マーケットプレイスのみ実行 |
| プラグイン更新失敗（C/D/E 由来） | `claude plugin update <plugin>@<marketplace> --scope <scope>` を当該エントリのみ実行 |

リトライは **元の失敗集合に対してのみ** 行う。リトライ中に新たに発生した失敗は記録のみとし、
再度 Phase G を起動しない（無限ループ防止）。2 回目の失敗時はそのまま最終結果として報告する。

## --dry-run モード時の挙動

`--dry-run` 指定時は **実際の更新コマンドを一切実行せず**、以下のみ提示する。

- Phase A の対象収集は通常通り実行（読み取りのみ）
- Phase B / C / D / E の代わりに、実行予定の CLI コマンド一覧を Phase F と同形式のテーブルで表示
  - 「結果」列の代わりに「実行予定コマンド」列を表示
- Phase G はスキップ（失敗が発生しないため）

`--scope` と組み合わせた場合（例: `--dry-run --scope user`）は、
指定スコープに限定したプレビューを表示する。

## 注意事項

- 本コマンドは Claude Code 公式 CLI に処理を委譲するため、**ローカル変更の意図しない破壊や
  ブランチ強制移動は発生しない**（CLI 内部のロック制御・状態管理に依存）。
- スコープ別更新で同一プラグインを複数回処理しても、CLI が冪等性を保証する（既に最新なら "No change"）。
- プライベートリポジトリのマーケットプレイスは Git credential helper / SSH キーの設定が前提。
  認証エラー時の詳細は CLI 出力に依存する。
- `claude plugin update` は **再起動が必要** と公式が明示しているため、
  本コマンド完了後は `/reload-plugins` か Claude Code 再起動を促す。
- リトライは 1 回まで（合計 2 試行）。それでも解消しない場合はネットワーク・認証・対象ファイルの
  状態を個別に調査する必要がある。

## 関連

- グローバルルール `~/.claude/rules/claude/plugin-auto-update.md`（自動更新ポリシー）
- `extension-toolkit:marketplace-toolkit`（マーケットプレイス本体管理）
- `extension-toolkit:marketplace-publisher`（マーケットプレイスへの公開）
