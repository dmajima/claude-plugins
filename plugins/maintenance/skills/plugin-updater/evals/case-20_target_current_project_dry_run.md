# Case 20: target=current-project + dry-run（B/C スキップ・ヘッダなし）

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update --dry-run` |
| コマンドから委譲される `mode` | `dry-run` |
| コマンドから委譲される `target` | `current-project` |
| 既存状態 | git リポジトリ内（`/home/user/myproject`）で実行 / 現在のリポジトリに project スコープ 1 件 + local スコープ 1 件 / User プラグイン 2 件あり |

## 期待動作

### Phase A-0-1: 引数バリデーション
- `mode` を `dry-run` と確定
- `target` を `current-project` と確定

### Phase A-0-2: CLI 存在チェック
- 通常通り通過

### Phase A: 対象収集（target=current-project のため範囲限定）
- `claude plugin marketplace list`: **スキップ**（target=current-project のため Phase A 収集対象外）
- User プラグインの `enabledPlugins`: **スキップ**（同上）
- Project プラグイン（`<repo>/.claude/settings.json`）と Local プラグイン（`<repo>/.claude/settings.local.json`）の `enabledPlugins` のみ A-Sec 手順で抽出

### Phase A-1 / A-2 / A-3: 入力検証（dry-run 時も省略不可）
- A-3: 現在のリポジトリ（`/home/user/myproject`）の project/local エントリを `installed_plugins.json` で確認 → 1 件ずつ対象に含める

### Phase B: スキップ（target=current-project のため phase-flow.md ADR-PU-015 に基づくスキップ）

### Phase C: スキップ（同上）

### Phase D / E: 変更系 CLI 呼び出しなし（dry-run）
- 現在のリポジトリの project/local のみ対象として実行予定コマンドを収集

### Phase F: dry-run 専用フォーマット（output-formats.md Phase F（dry-run）参照）

#### F-1（dry-run）実行予定サマリ
- マーケットプレイス: 行なし（target=current-project のため B スキップ）
- User プラグイン: 行なし（同上）
- Project プラグイン: 実行予定 1 件 / スキップ 0 件（target=current-project: 現在の git リポジトリのみ）
- Local プラグイン: 実行予定 1 件 / スキップ 0 件（同上）

#### F-2（dry-run）: なし（B スキップのため）

#### F-3（dry-run）スコープ別実行予定詳細
- Project: **target=current-project のため projectPath ヘッダなし**（User と同形式）
  - `claude plugin update <plugin>@<marketplace> --scope project` を表示
- Local: 同形式（ヘッダなし）

#### F-4: 省略（dry-run のため）

### Phase G: スキップ（dry-run のため）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | なし |
| F-1 に マーケットプレイス行 / User 行 | なし（B/C スキップのため） |
| F-3 Project/Local のヘッダ | なし（target=current-project のため projectPath ヘッダなし） |
| 末尾メッセージ | `(dry-run) 実適用は行いません` |
| F-4 / G | なし |

## 分岐の根拠

このケースが分岐するトリガーは `mode = dry-run` かつ `target = current-project` の組み合わせである。

`case-18_target_all_dry_run.md` と対照することで、dry-run 時の `target` 差が以下の 2 点に現れることを検証する:
1. `target=current-project` では Phase B / C がスキップされるため F-1/F-2 にマーケットプレイス・User 行が出ない
2. `target=current-project` では F-3 の Project / Local に projectPath ヘッダが付かない（`target=all` では付く）

## 関連ケース

- `case-18_target_all_dry_run.md`（target=all + dry-run。projectPath グルーピングあり）
- `case-01_dry_run.md`（旧来の dry-run 正常系。scope パラメータ前提）
- output-formats.md Phase F（dry-run）セクション
- output-formats.md F-3 dry-run の `target=current-project` 時はヘッダなし仕様
- phase-flow.md ADR-PU-015（target=current-project 時の B/C スキップ）