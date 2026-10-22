# design-push 実行手順詳細

`design-push` の各手順の具体的な実行方法。

## 1. スクリーンショット生成

### 呼び出し

```bash
"<venv>/Scripts/python.exe" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/screenshot/capture.py" \
  --mocks-dir "<mocksDir>" \
  --out-dir "<assetsDir>" \
  --width 1280 --height 800
```

対象を絞る場合は `--only <画面 ID>` を繰り返し指定する。部品（`_tokens.html` 等）を除外する場合は `--skip-partials` を付ける。

### 実行環境の注意

Windows では、`PowerShell` ツールから Python 子プロセスを `Start-Process -NoNewWindow` や リダイレクト付き `&` で起動すると、ライブラリ初期化中にハングする既知事象がある。**`Bash` ツール経由で起動する**こと。やむを得ず PowerShell から起動する場合は `Start-Job` 経由のラッパーを使う。

### 終了コード

| 値 | 意味 | 対応 |
|---|------|------|
| 0 | 全件成功（対象 0 件を含む） | 続行 |
| 1 | 1 件以上失敗 | 失敗したモックを報告し、push を続けるかユーザーに確認 |
| 2 | 引数エラー / playwright 未導入 | venv 構築（`design-init` の手順 6）を案内して中断 |

## 2. Markdown の画面イメージ更新

対象の設計書に次のセクションを置く。既にあれば中身を差し替え、無ければ適切な位置（画面概要の直後）に挿入する。

```markdown
## 画面イメージ

![<画面名>](<assetsDir からの相対パス>/<画面 ID>.png)

[モックを開く](<mocksDir からの相対パス>/<画面 ID>.html) ｜ Design カード: `<画面 ID>`
```

相対パスは設計書の位置から解決できる形にする。`specsDir` が `specs/screens`、`assetsDir` が `specs/assets` の既定構成なら次のとおり。

```markdown
![ログイン](../assets/S001_login.png)

[モックを開く](../../mocks/S001_login.html) ｜ Design カード: `S001_login`
```

画面イメージセクション以外は書き換えない。

## 3. バンドルの作成

`.claude/.local/plugins/design-bridge/bundle/` に push 対象を集約する。

```text
bundle/
├─ foundations/
│  ├─ _tokens.html
│  └─ _layout.html
└─ screens/
   ├─ S001_login.html
   └─ S002_home.html
```

`mocksDir` 直下のアンダースコア始まりを `foundations/`、それ以外を `screens/` へ配置する。バンドルは毎回作り直す（古い残骸が push されるのを防ぐ）。

### @dsCard マーカー

各 HTML の **先頭行** に次の形式のコメントが必要。Design System ペインのカード索引はこのマーカーから構築される。

```html
<!-- @dsCard group="画面" -->
```

| group の例 | 用途 |
|-----------|------|
| `Foundations` | トンマナ・レイアウト |
| `画面` | 画面モック |
| 業務分類名 | 画面数が多い場合の分類（「受注」「マスタ」等） |

マーカーが無い HTML には付与してからバンドルに入れる。`@dsCard` を使う場合、`register_assets` の明示呼び出しは不要。

## 4. DesignSync の呼び出し順序

順序は仕様で固定されている。read → finalize_plan → write を守る。

### 4.1 プロジェクト型の確認

```text
DesignSync(method: "get_project", projectId: "<projectId>")
```

`type` が `PROJECT_TYPE_DESIGN_SYSTEM` であることを確認する。通常プロジェクトには push できず、型は作成後に変更できない。異なる場合は中断し、`design-init` での再設定を案内する。

### 4.2 リモート構成の取得

```text
DesignSync(method: "list_files", projectId: "<projectId>")
```

返ったパス一覧とバンドルを突き合わせ、次を決める。

| 区分 | 判定 |
|-----|------|
| 追加 | バンドルにあり、リモートに無い |
| 更新 | 両方にある |
| 削除 | リモートにあり、バンドルに無い |

削除は慎重に扱う。ローカルで意図的に消したのか、別経路で追加されたものかを区別できないため、**削除対象がある場合は必ずユーザーに確認する**。

### 4.3 計画の確定

```text
DesignSync(
  method: "finalize_plan",
  projectId: "<projectId>",
  writes: ["foundations/**", "screens/**"],
  deletes: [...],
  localDir: "<bundle の絶対パス>"
)
```

- `writes` / `deletes` はパスまたはグロブ（`*` は 1 セグメント、`**` は任意深さ）
- 1 パターンあたりワイルドカードは 3 個まで、エントリは 256 件まで
- `localDir` 配下のファイルしか `localPath` で送れない
- 返る `planId` を以降の呼び出しで使う

### 4.4 ファイル送信

```text
DesignSync(
  method: "write_files",
  projectId: "<projectId>",
  planId: "<planId>",
  files: [
    { path: "screens/S001_login.html", localPath: "screens/S001_login.html" },
    ...
  ]
)
```

- `localPath` を使うと内容がコンテキストに載らない。**常に `localPath` を使う**（`data` はごく小さな動的内容のみ）
- `localPath` は `localDir` からの相対パス
- 1 回 256 ファイルまで。超える場合は同じ `planId` で複数回に分ける

削除がある場合は `delete_files` を同じ `planId` で呼ぶ。

## 5. 失敗時の扱い

| 失敗箇所 | 対応 |
|---------|------|
| 認可エラー | `/design-login` の実行をユーザーに依頼して中断。`pending.txt` は残す |
| `get_project` で型が違う | 中断し `design-init` を案内。`pending.txt` は残す |
| `write_files` が一部失敗 | 失敗分を報告し、`pending.txt` から成功分のみ削除する |
| スクショ生成の失敗 | 該当画面を除いて push するか、中断するかをユーザーに確認 |

**push が完全に成功した場合にのみ** `pending.txt` と `block-count` を削除する。中途半端な削除は「反映済みのつもりで未反映」という最悪の状態を生む。

## 6. リモート先行への配慮

`DesignSync` にはリモート変更の通知機構が無いため、push は常にローカル内容での上書きになる。`list_files` の結果にローカルが知らないファイルが含まれていた場合、Claude Design 側で誰かが作業した可能性がある。その場合は上書き前に `design-status` または `design-pull` での確認をユーザーへ提案する。
