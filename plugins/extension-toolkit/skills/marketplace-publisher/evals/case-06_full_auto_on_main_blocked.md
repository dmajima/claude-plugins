# Case 06: フルオートモード - main ブランチ実行時の阻止

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`extension-toolkit` を公開" |
| 引数 | `extension-toolkit --full-auto` |
| フラグ | `--full-auto` |
| 既存状態 | 現在ブランチ = `main`（または `master`） |

## 期待動作

### Phase 1: 公開モード選択

`--full-auto` 検出 → フルオートモード。

### Phase 2: ブランチ検査（必須・最優先）

[`../references/publish-workflow.md`](../references/publish-workflow.md) のブランチ判定ロジックに従い、現在ブランチが保護対象パターン（`main` / `master` / 設定で追加された保護パターン）に合致するかを判定。

| 判定結果 | 動作 |
|---------|------|
| 保護対象（`main` / `master` 等）に合致 | **公開フローを中断**（fail-closed）、後続処理を実施しない |
| 非保護ブランチ（feature ブランチ等）| 通常フローへ続行 |

### Phase 3: ユーザへの提示（fail-closed）

中断時に以下のメッセージを表示し、`AskUserQuestion` で次アクションを確認:

```text
保護対象ブランチ（main）への直接公開は禁止されています。

選択肢:
1. feature ブランチを切ってから再実行（git checkout -b feature/publish-extension-toolkit）
2. 現在の変更を stash して別ブランチで作業
3. キャンセル

どうしますか？
```

### Phase 4: 引き渡し（処理停止）

| 項目 | 値 |
|-----|----|
| `git push` | **実行しない** |
| PR 作成 | **実行しない** |
| `marketplace.json` の変更 | コミット前なら破棄、コミット済みなら保持してユーザ判断を仰ぐ |

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | 保護ブランチ警告 + 選択肢提示 |
| 終了状態 | 中断（フルオート未完了、ユーザ操作待ち） |
| Git 状態 | リモートへの push なし、PR 未作成 |

## 分岐の根拠

`--full-auto` フラグ + 現在ブランチが保護パターン → 直接公開の事故を防ぐため fail-closed 動作。
ユーザが明示的に feature ブランチへ切替した上で再実行することを要求する。

## 関連ケース

- `case-04_full_auto.md`（feature ブランチでの正常フロー）
- `case-01_new_register_handoff.md`（ハンドオフモード、ブランチ判定はスキップ可）
