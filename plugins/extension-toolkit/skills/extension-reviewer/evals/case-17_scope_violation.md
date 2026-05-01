# Case 17: 機械チェックの scope 違反による拒否

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`/etc/passwd` の妥当性を確認して" 等、スコープ外パスを target に指定 |
| 引数 | `--target /etc/passwd --scope-root .` (target が scope-root の祖先または無関係) |
| フラグ | なし |
| 既存状態 | `/etc/passwd` は存在するが、`scope-root` 配下ではない |

## 期待動作

### Phase 1: パストラバーサル防御

`run_checks.py` 内 `assert_in_scope(scope_root, target)` が `target.resolve()` と `scope_root.resolve()` を比較し、`target` が scope-root 配下でないことを検出して `ValueError` を raise する。

### Phase 2: スクリプトの fail-closed 終了

```text
[ERROR] out of scope: /etc/passwd
exit code: 2
```

`stderr` に ASCII プレフィックスで出力。JSON ファイルは作成されない（攻撃者がレビュー結果経由でファイル内容を取得することを防ぐ）。

### Phase 3: ユーザへの提示

| 提示項目 | 内容 |
|---------|------|
| エラー要因 | レビュー対象がスコープルート配下にない（パストラバーサル防御） |
| 推奨アクション | `--scope-root` をレビュー対象の親ディレクトリに変更、または target をスコープ内に再指定 |
| セキュリティ通知 | 意図せず外部パスを指定した場合は問題なし。意図的指定の場合は scope-root の見直し |

## 期待出力

```markdown
## レビュー中断（セキュリティ防御）

**理由**: 指定された対象がスコープルート配下にありません: `/etc/passwd`

**スコープルート**: `.`（現在ディレクトリ）

`extension-reviewer` はパストラバーサル防止のため、レビュー対象を必ずスコープルート配下に限定します。スコープ外のシステムファイルは検査対象になりません。

**次のアクション**:
- スコープ内のパスを指定して再実行
- スコープを広げたい場合は `--scope-root` を明示
```

| 項目 | 期待値 |
|-----|-------|
| 機械チェック JSON | 未生成 |
| エージェント並列起動 | 行わない（対象がスコープ外のため） |
| 終了状態 | 中断（exit 1 相当）|
| セキュリティログ | scope 違反の事実を記録（誤指定 / 攻撃いずれも検出可能とする） |

## 分岐の根拠

`run_checks.py` の `assert_in_scope()` は `resolve()` で symlink を展開してから祖先関係を検証するため、`/etc/passwd` のような絶対パス・`../../../etc/passwd` のような相対経路いずれも一様に検出できる。`extension-reviewer` 側はこの fail-closed をユーザに優しく提示する責務を持つ。

## 関連ケース

- case-16（target 不在による中断）
- case-05（Critical 検出による REJECT、ただしレビュー自体は完走する点が異なる）
