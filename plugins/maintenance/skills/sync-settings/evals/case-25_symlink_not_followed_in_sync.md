# Case 25: pull / push / バックアップ取得経路で symlink / junction を追従しない

## 入力（複合）

### Sub-case 25-A: リモート repo 内の symlink（pull 経路）

| 項目 | 値 |
|-----|---|
| 起動経路 | `/sync-pull --scope global --yes` |
| 既存状態 | リモート repo の `skills/foo/link` が symlink でローカル `~/.ssh/id_rsa` を指す（あるいは `..` 経由で repo 外を指す） |

### Sub-case 25-B: ローカル側の symlink（push 経路）

| 項目 | 値 |
|-----|---|
| 起動経路 | `/sync-push --scope project --yes` |
| 既存状態 | ローカル `<project>/.claude/skills/link` が symlink で外部 `C:\Users\xx\.ssh` を指す |

### Sub-case 25-C: バックアップ取得時の symlink

| 項目 | 値 |
|-----|---|
| 起動経路 | `/sync-pull --scope global --yes` |
| 既存状態 | ローカル `~/.claude/skills/link` が symlink で外部を指す |

## 期待動作（全 sub-case 共通）

- 各経路（差分検出 / コピー / バックアップ取得）で `Get-NonReparseFileItems` を使用
- 再解析ポイントを持つディレクトリ / ファイルは **追従せず、配下を列挙しない**
- 単一ファイルが reparse point の場合もスキップ + warning 出力:
  - "再解析ポイントのためスキップ（target）: ..."

### Sub-case 25-A: pull
- 差分検出で symlink ファイルは候補に含まれない
- ローカル `~/.claude/skills/foo/link` には影響なし
- リモート repo 内の symlink 経由でローカル機密領域への参照が試みられても遮断

### Sub-case 25-B: push
- ローカル → repo-push/ コピー時に symlink ファイル / ディレクトリはスキップ
- 外部認証情報領域（`~/.ssh` 等）がリモートに push されない
- push 完了後の git status に symlink は含まれない

### Sub-case 25-C: バックアップ取得
- `Get-NonReparseFileItems -Root $src` で reparse 配下を列挙しない
- バックアップディレクトリに認証情報が複製されない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| symlink 追従 | なし（pull / push / backup の全経路） |
| リモートへの認証情報漏洩 | なし |
| ローカル機密領域への参照 | なし |
| warning メッセージ | 単一ファイル reparse 時に "再解析ポイントのためスキップ" |
| 終了状態 | exit 0（symlink スキップは正常動作） |

## 分岐の根拠

このケースが分岐するトリガーは ファイル / ディレクトリの ReparsePoint 属性検出 である。
safety.md 節 10 検証チェックリスト「Get-NonReparseFileItems により symlink / junction が
pull / push / バックアップ取得経路で追従されないことをテスト」の仕様を回帰固定。

## 設計意図

cleanup-workspace の case-12 と対称的に、sync-settings の最重要セキュリティ装置として
symlink / junction 追従禁止を独立 eval で保証する。`Get-NonReparseFileItems` の自前再帰列挙
が pull / push / バックアップの 3 経路すべてで一貫適用されることを確認する。

## 関連ケース

- `case-08_credentials_excluded.md`（認証情報除外）
- `case-12_branch_not_found.md`（pull 経路の正常系）
- `case-18_push_basic.md`（push 経路の正常系）
- cleanup-workspace case-12_symlink_skipped.md（同等装置の cleanup 側）
- safety.md 節 8.4 push の認証情報二重除外 / 節 10 検証チェックリスト
