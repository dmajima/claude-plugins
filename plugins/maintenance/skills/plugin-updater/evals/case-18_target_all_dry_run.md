# Case 18: target=all + dry-run（projectPath グルーピング付き実行予定一覧）

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all --dry-run` |
| コマンドから委譲される `mode` | `dry-run` |
| コマンドから委譲される `target` | `all` |
| 既存状態 | マーケットプレイス 2 件 / User プラグイン 2 件 / projA（`/home/user/projA`）に project 1 件 + local 1 件 / projB（`/home/user/projB`）に project 1 件 / いずれのディレクトリも存在する |

## 期待動作

### Phase A-0-1: 引数バリデーション
- `mode` を `dry-run` と確定
- `target` を `all` と確定

### Phase A-0-2: CLI 存在チェック
- 通常通り通過

### Phase A: 対象収集（dry-run でも全手順実行）
- `claude plugin marketplace list` でマーケットプレイス列挙
- User / Project / Local の全 `enabledPlugins` を A-Sec 手順で抽出
- `installed_plugins.json` から projectPath を取得し projA / projB にグルーピング

### Phase A-1 / A-2 / A-3: 入力検証（dry-run 時も省略不可）
- A-3: projA / projB の projectPath ディレクトリ実在確認 → 両方存在

### Phase B / C / D / E: 変更系 CLI 呼び出しなし（dry-run）
- 実行予定コマンドのみ収集

### Phase F: dry-run 専用フォーマット（output-formats.md Phase F（dry-run）参照）

#### F-1（dry-run）実行予定サマリ
- マーケットプレイス: 実行予定 2 件 / スキップ -
- User プラグイン: 実行予定 2 件 / スキップ 0 件
- Project プラグイン: 実行予定 2 件 / スキップ 0 件（target=all: 全 projectPath 対象）
- Local プラグイン: 実行予定 1 件 / スキップ 0 件（同上）

#### F-2（dry-run）マーケットプレイス実行予定詳細
- 各 MP に `claude plugin marketplace update` を表示

#### F-3（dry-run）スコープ別実行予定詳細
- User: 実行予定コマンド一覧（projectPath ヘッダなし）
- Project: **target=all のため projectPath ごとにグルーピング**
  - ヘッダ `#### <projectPath>` の下に `claude plugin update <plugin>@<marketplace> --scope project` を表示
  - projA のエントリと projB のエントリを別ヘッダで区切る
- Local: Project と同形式（target=all → projectPath ヘッダあり）

#### F-4: 省略（dry-run のため output-formats.md F-4 より省略）

### Phase G: スキップ（dry-run のため output-formats.md G-1 より省略）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | なし |
| F-1 冒頭 | `## 実行予定サマリ（dry-run）` |
| F-3 Project ヘッダ | `#### /home/user/projA`（XR-3 サニタイズ後）、`#### /home/user/projB` の 2 ヘッダ |
| F-3 Local ヘッダ | `#### /home/user/projA`（projA の local エントリのみ） |
| 末尾メッセージ | `(dry-run) 実適用は行いません` |
| F-4 / G | なし |

## 分岐の根拠

このケースが分岐するトリガーは `mode = dry-run` かつ `target = all` の組み合わせである。

`case-01_dry_run.md` は `scope` パラメータを前提とした旧来の dry-run 正常系であるのに対し、本ケースは `target=all` 導入後の dry-run フォーマット（projectPath グルーピング付き F-3 出力）を検証する。

`case-20_target_current_project_dry_run.md` と対照することで、dry-run 時に `target` の差がどのフェーズ・フォーマットに影響するかを確認できる。

## 関連ケース

- `case-01_dry_run.md`（旧来の dry-run 正常系。scope パラメータ前提）
- `case-20_target_current_project_dry_run.md`（target=current-project + dry-run。B/C スキップ・ヘッダなし）
- output-formats.md Phase F（dry-run）セクション
- output-formats.md F-3 dry-run の projectPath グルーピング仕様