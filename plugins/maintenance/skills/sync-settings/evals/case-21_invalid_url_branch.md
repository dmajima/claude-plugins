# Case 21: 不正な URL / Branch 名のバリデーション失敗

## 入力（複合）

### Sub-case 21-A: 不正な Repo URL

| 項目 | 値 |
|-----|---|
| 引数 | `--Repo "file:///etc/passwd" --Yes` |
| 期待動作 | URL バリデーション失敗で exit 1 |

### Sub-case 21-B: '-' で始まる Repo URL（オプション偽装）

| 項目 | 値 |
|-----|---|
| 引数 | `--Repo "--upload-pack=cmd.exe" --Yes` |
| 期待動作 | `-` 始まり検出で exit 1 |

### Sub-case 21-C: 不正な Branch 名（許可外文字）

| 項目 | 値 |
|-----|---|
| 引数 | `--Repo "https://github.com/u/r" --Branch "main; rm -rf" --Yes` |
| 期待動作 | Branch 名バリデーション失敗で exit 1 |

### Sub-case 21-D: マッピング由来値の改ざん検出

| 項目 | 値 |
|-----|---|
| 既存状態 | 攻撃者が `sync-mappings.json` の `remote_branch` を `"--upload-pack=cmd.exe"` に書き換え |
| 引数 | `--Mapping global --Yes` |
| 期待動作 | マッピング読み込み直後の再検証で検出し exit 1 |

## 期待動作（共通）

### Phase 1: 引数解析
- 各 sub-case ごとの引数を受け取る

### Phase 2: 入力検証
- `REPO_URL_REGEX = '^(https?|git|ssh)://|^git@[A-Za-z0-9._\-]+:'` での URL 検証
- `Repo.StartsWith('-')` での `-` 始まり検出（オプション偽装防止）
- `BRANCH_REGEX = '^[A-Za-z0-9._/\-]+$'` での Branch 名検証
- Mapping 使用時はマッピング由来値も同じ正規表現で再検証

### Phase 3: 検証失敗時の挙動
- `Write-Error "<理由>"` を出力
- exit 1 で即時終了
- Git CLI は一切呼び出さない（clone / fetch なし）

## 期待出力（共通）

| 項目 | 期待値 |
|-----|-------|
| Git CLI 呼び出し | なし |
| 標準エラー出力 | "Repo URL の形式が無効です" / "'-' で始められません" / "Branch 名に無効な文字が含まれています" / "マッピング由来の remote_branch が無効です（外部書き換え疑い）" のいずれか |
| 終了状態 | エラー終了（exit 1） |

## 分岐の根拠

各 sub-case が分岐するトリガー:

- A: `--Repo` が `https?://` / `git://` / `ssh://` / `git@host:` のいずれにも該当しない
- B: `--Repo` 文字列が `-` で始まる
- C: `--Branch` が `^[A-Za-z0-9._/\-]+$` を満たさない
- D: マッピング由来 `remote_branch` が同じ正規表現を満たさない

## 設計意図

セキュリティレビュー Cycle 1 の Critical C-Sec-1（マッピング由来値の引数注入リスク）への対策として、
**引数経由・マッピング経由のいずれの値も同じバリデーション規則で検証する** ことを保証する。
sub-case D は外部スクリプトや別経路で sync-mappings.json が書き換えられた場合の防御を検証する。

## 関連ケース

- `case-02_interactive_overwrite.md`（正常系の Repo URL / Branch）
- `case-12_branch_not_found.md`（バリデーション後の Git CLI エラー）
- safety.md 節 8.5 マッピング由来値の再検証
