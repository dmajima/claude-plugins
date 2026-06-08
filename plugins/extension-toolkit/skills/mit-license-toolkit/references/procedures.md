# 実行手順詳細

`mit-license-toolkit` の各フェーズの詳細手順。SKILL.md 本体から参照される。

## 1. 対象プラグイン確認

引数または対話で取得した `plugin-name` から以下を確認:

| 確認項目 | 動作 |
|---------|------|
| `plugins/{plugin-name}/.claude-plugin/plugin.json` 存在 | 不在なら `plugin-toolkit` への接続を案内して終了 |
| `plugin.json` が valid JSON | パース失敗ならエラー終了 |
| `plugin.json.name` がディレクトリ名と一致 | 不一致は警告のみ（修正は `plugin-toolkit` 担当） |

## 2. license-info.json 解決

### 2.1 探索順序

| 優先 | 条件 | パス |
|-----|------|------|
| 1 | カレントディレクトリ祖先に `.git` がある（リポジトリ配下） | `<repo_root>/.claude/.local/plugins/extension-toolkit/license-info.json` |
| 2 | リポジトリ外 | `~/.claude/.local/plugins/extension-toolkit/license-info.json` |

リポジトリルートの判定は `git rev-parse --show-toplevel` を使用（git 不在時はカレントディレクトリから上方向に `.git` を探索）。

### 2.2 ファイル状態

| 状態 | 動作 |
|-----|------|
| 不在 | 新規収集フロー（節 4）へ |
| 存在・valid JSON・`licenses[]` 空 | 新規収集フロー（節 4）へ |
| 存在・valid JSON・`licenses[]` 1 件 | 自動適用（節 5）へ。適用したエントリの `label` をユーザに通知 |
| 存在・valid JSON・`licenses[]` 複数 | 選択フロー（節 3）へ |
| 存在・JSON パース失敗 | エラー終了（バックアップを案内、利用者に修正を委ねる） |

### 2.3 ディレクトリ作成

新規保存時に親ディレクトリ `.claude/.local/plugins/extension-toolkit/` が不在なら自動作成する。

## 3. 選択フロー（複数エントリ存在時）

`AskUserQuestion` で利用するエントリを選択する。

```text
AskUserQuestion({
  questions: [{
    question: "どのライセンス情報を適用しますか？",
    header: "ライセンス選択",
    options: [
      // licenses[] の各エントリを展開
      { label: "<licenses[i].label>", description: "<copyright_holder> / <copyright_year>" },
      ...
      { label: "新規追加", description: "新しいライセンス情報を入力します" }
    ],
    multiSelect: false
  }]
})
```

### 選択肢生成ルール

| 元エントリ | label | description |
|----------|-------|-------------|
| `licenses[i]` | `licenses[i].label`（不在時は `licenses[i].copyright_holder`） | `Copyright (c) <copyright_year> <copyright_holder>` |
| 末尾固定 | `新規追加` | 新規エントリ収集フローへ遷移 |

「新規追加」が選択された場合、節 4 の新規収集フローへ遷移し、収集完了後にそのエントリを適用する。

`--license-id` 引数あり（非対話モード）の場合は、AskUserQuestion を呼ばず、引数値と一致する `licenses[].id` を持つエントリを直接適用する。一致なしならエラー終了。

## 4. 新規収集フロー

### 4.1 収集項目

| 項目 | 必須 | 取得方法 | デフォルト |
|-----|------|---------|-----------|
| `copyright_holder` | 必須 | テキスト対話（フリーテキスト） | なし |
| `copyright_year` | 必須 | テキスト対話 | 現在年（システム日付の年部分） |
| `author` | 任意 | テキスト対話 | `copyright_holder` と同値 |
| `label` | 推奨 | テキスト対話 | `<copyright_holder>用` |
| `id` | 必須 | 自動生成 | `copyright_holder` の kebab-case 化、衝突時は `-2` `-3` を付与 |

`AskUserQuestion` は **選択 UI** であり、自由入力には適さない。新規収集はテキスト対話で行うが、収集完了後の「保存可否」「保存先選択」は `AskUserQuestion` を使う（重要選択のため）。

### 4.2 保存可否確認

```text
AskUserQuestion({
  questions: [{
    question: "このライセンス情報を保存しますか？",
    header: "保存確認",
    options: [
      { label: "保存する", description: "<解決した license-info.json のパス> に保存し、次回以降も再利用できるようにします" },
      { label: "一時利用のみ", description: "今回のみ適用し、ストアには保存しません" }
    ],
    multiSelect: false
  }]
})
```

「保存する」選択時のみ `license-info.json` の `licenses[]` に追記する。既存ファイルがあれば追記、不在なら新規作成（`version: 1`、`licenses: [新規エントリ]`）。

### 4.3 非対話モード

`--non-interactive` 指定時は、`--copyright-year` `--copyright-holder` `--author` `--save` 引数で確定する。`--copyright-holder` 不足時はエラー終了。`--save` のデフォルトは `--no-save`（誤書き込み防止）。

## 5. LICENSE 配置

### 5.1 既存 LICENSE 確認

`plugins/{plugin-name}/LICENSE` が存在する場合:

| 状態 | 動作 |
|-----|------|
| MIT 標準文と完全一致（copyright 行のみ差分） | スキップ（既に整備済み）。`plugin.json.license` のみ確認・更新 |
| MIT 標準文と異なる（他ライセンス・カスタム文） | `AskUserQuestion` で「MIT に置換 / キャンセル」を確認。キャンセル時は警告のみ出して LICENSE は変更しない |
| プレースホルダ `{year}` `{holder}` が残存 | 自動修正（選択したエントリの値で置換） |

### 5.2 生成・上書き

[`scripts/license/apply_license.py`](scripts/license/apply_license.py) を呼び出し、以下を実行:

1. テンプレート [`../template/LICENSE`](../template/LICENSE) を読み込み
2. `{year}` を `copyright_year` で置換
3. `{copyright_holder}` を `copyright_holder` で置換
4. `plugins/{plugin-name}/LICENSE` に書き込み（既存なら上書き、確認済みの場合のみ）

書き込み時のエンコーディングは UTF-8（BOM なし）、改行は LF とする。

## 6. plugin.json 更新

### 6.1 license フィールド設定

`plugins/{plugin-name}/.claude-plugin/plugin.json` を読み込み、以下を実施:

| 既存値 | 動作 |
|-------|------|
| 不在 | `license: "MIT"` を追加 |
| `"MIT"` | スキップ（既に正） |
| `"MIT"` 以外（例: `"Apache-2.0"`） | `AskUserQuestion` で「MIT に変更 / キャンセル」を確認 |

### 6.2 author フィールドとの整合

`plugin.json.author.name` が不在の場合、選択した `licenses[].author` を `author.name` として **設定する** ことを `AskUserQuestion` で確認する（既存値があれば上書きしない、利用者が明示変更を選んだ場合のみ）。

### 6.3 バージョンバンプ

`plugin.json` を変更した場合、`versioning.md` のルールに従いバージョンを更新する。

| 変更内容 | バンプ種別 |
|---------|-----------|
| `license` 新規追加 | patch（後方互換修正扱い） |
| `license` 変更（MIT → 他、または逆） | minor（メタ情報の意味的変更） |
| `author` 新規追加・変更 | patch |

`plugin-toolkit` から呼び出された場合、バンプは `plugin-toolkit` 側に委譲する（呼び出し元が plugin.json 全体を編集中のため、二重バンプを避ける）。

### 6.4 JSON 整形

更新後の `plugin.json` は元の整形（インデント・改行・キー順）を維持する。`apply_license.py` は **既存スタイル保持** を原則とし、Python の `json.dump` で `indent=2` `ensure_ascii=False` `sort_keys=False` を指定する。

## 7. 検証

完了前に以下を確認（[`../../../references/checklists/completion-checklist.md`](../../../references/checklists/completion-checklist.md) の自己検証フォーマットに従って報告）:

- [ ] `plugins/{name}/LICENSE` 存在
- [ ] `LICENSE` 本文が MIT 標準文（[`../template/LICENSE`](../template/LICENSE)）と一致
- [ ] `Copyright (c) <year> <holder>` の `<year>` `<holder>` 空でなく、プレースホルダ未残存
- [ ] `plugin.json.license == "MIT"`
- [ ] `license-info.json`（保存した場合）が valid JSON、`version: 1`、`licenses[]` 1 件以上
- [ ] パスポータビリティ合格（[`../../../references/policies/path-portability.md`](../../../references/policies/path-portability.md)）
- [ ] エンコーディング UTF-8 / 改行 LF

## 8. エラーハンドリング

| エラー | 対応 |
|-------|------|
| 対象プラグイン不在 | `plugin-toolkit` への接続を案内して終了 |
| `license-info.json` JSON パース失敗 | 利用者にバックアップ + 手動修正を案内、新規収集は実施しない |
| `--license-id` 不一致（非対話） | エラーで終了、利用可能 ID 一覧を提示 |
| 既存 LICENSE が他ライセンス、利用者がキャンセル | 警告のみ、LICENSE は変更しない（責務外として記録） |
| `plugin.json` 書き込み失敗 | エラーで終了。LICENSE は配置済みのまま `plugin.json` 未更新で停止する（**partial-commit**、再実行で収束可能。真のロールバックは行わず、利用者の手動修正または再実行に委ねる）|
