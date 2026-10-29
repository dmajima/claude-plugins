# Case 11: 設定値が異常（capture.py を実行せず中断）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「Claude Design に反映して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | `.claude/design-bridge.json` あり（`projectId` は design-system 型）。認可済み・venv 構築済み。`pending.tsv` に 2 行（`mocks/S001_login.html` と `specs/screens/S001_login.md`）。ただし設定の `mocksDir` に異常な値が入っている（下表のいずれか） |

### 異常値のパターン

`.claude/design-bridge.json` はリポジトリ同梱の設定ファイルであり、**そのリポジトリを開いた第三者が書き換えうる入力** である。本ケースはそのいずれかが `mocksDir`（または `assetsDir`）に入っている状態を指す。

| パターン | 値の例 | 抵触する検査 |
|---------|-------|-------------|
| `..` を含む | `../../etc` | 相対パスでプロジェクトルートの外へ出る |
| 絶対パス | `/etc`、`C:/Windows/Temp` | プロジェクトルート基準でない |
| シェルのメタ文字を含む | `mocks; rm -rf /`、<code>mocks&#124;cat</code>、`mocks$(id)` | コマンド文字列へ展開するとシェルが解釈する |

```json
{
  "projectId": "<uuid>",
  "specsDir": "specs/screens",
  "assetsDir": "specs/assets",
  "mocksDir": "../../etc"
}
```

## 期待動作

### Phase 1: 導入確認と対象決定
- `.claude/design-bridge.json` を読み、`specsDir` / `assetsDir` / `mocksDir` / `viewport` を得る
- 引数が無いため対象は `pending.tsv` の全件（2 件）。対象集合として記録する
- ここまでは通常どおり進行する（設定の異常は次の検証で検出する）

### Phase 2 の手前: 設定値の検証（本ケースの中心）
- procedures.md「設定値を渡すときの注意」に従い、`capture.py` のコマンド文字列を組み立てる **前に** `mocksDir` と `assetsDir` を検査する
- 値は二重引用符で囲んで渡すが、**囲めば安全だから実行してよい、とは判断しない。** procedures.md は引用符で囲んだうえで、なお `..`・絶対パス・シェルのメタ文字（`;` `|` `&` `$` バッククォート）を含む値は実行しないと定めている
- 異常を検出したため、**`capture.py` を起動しない**
- 異常な値をコマンド文字列へ展開しない（報告には載せるが、シェルに渡さない）
- config-schema.md の「パスはすべてプロジェクトルートからの相対パスで書く。`..` や絶対パスは使わない」に反する状態である

### Phase 3 以降: 実行しない
- **設計書の画面イメージセクションを更新しない**（スクリーンショットが無いまま画像参照だけ更新しない）
- バンドルを作成しない
- **`DesignSync` を一切呼び出さない**（`get_project` も含む）
- `last-push.json` を更新しない
- **`clear_pending.sh` を呼び出さない。** `pending.tsv` の 2 行をそのまま残す。`block-count` と `dismissed` も変更しない

### Phase 8: 報告
- 設定ファイルの異常として報告する。**どのフィールドの、どの値が、どの検査に抵触したか** を示す
- `.claude/design-bridge.json` は第三者が書き換えうる入力であるため、値を確認・修正したうえで再実行する必要があることを伝える
- 修正方法を案内する（プロジェクトルートからの相対パスへ直す。導入・設定ファイル生成は `bridge-init` の責務のため、本スキルは設定ファイルを書き換えない）
- 未反映の 2 件がそのまま残っていること、次の応答終了時に Stop フックが再度ブロックしうることを伝える
- 「反映しました」とは報告しない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの案内 | `.claude/design-bridge.json` の `mocksDir`（または `assetsDir`）の修正 |
| 外部呼び出し | `capture.py` 0 回、`DesignSync` 0 回、`clear_pending.sh` 0 回 |
| 生成ファイル | なし（PNG も `bundle/` も作られない） |
| 更新ファイル | なし（設計書・`last-push.json`・設定ファイルとも変更しない） |
| 残存ファイル | `pending.tsv`（2 行のまま）、`block-count`・`dismissed`（あれば保持） |
| 標準出力（要約） | 異常なフィールド名と値、抵触した検査、修正方法、未反映のまま残っている旨 |
| 終了状態 | 中断（未反映のまま） |

## 分岐の根拠

このケースが分岐するトリガーは `.claude/design-bridge.json` の `mocksDir` / `assetsDir` = `..`・絶対パス・シェルのメタ文字を含む値 である。procedures.md「設定値を渡すときの注意」の「値に `..`、絶対パス、シェルのメタ文字（`;` `|` `&` `$` バッククォート）が含まれる場合は実行せず、設定の異常としてユーザーへ報告する」に基づく。

この検査を `capture.py` に委ねられない理由がある。`capture.py` も `--mocks-dir` / `--out-dir` の位置を検証する（case-12）が、それは **プロセスが起動した後** の話である。`mocks; rm -rf /` のような値は、コマンド文字列へ展開された時点でシェルが解釈してしまうため、`capture.py` に到達する前に止めるしかない。**シェル実行前の検査はスキルにしか置けない層** であり、本ケースはその層を検証する。

一方、値そのものは正常でも symlink でプロジェクト外へ出る場合は、文字列の検査では検出できない。そこは `capture.py` 側の封じ込め検証が受け持つ（case-12）。両者は代替関係ではなく多層の関係にある。

## エッジケース

| 状況 | 動作 |
|-----|------|
| `assetsDir` 側が異常 | 同じく実行せず報告する（検査対象は `mocksDir` と `assetsDir` の両方） |
| `specsDir` が異常 | `capture.py` には渡さないが、設計書の書き込み先を決める値であるため同様に設定異常として報告し、書き込みを行わない |
| 値は正常だが `mocksDir` が存在しない | 検査は通る。`capture.py` が「モックディレクトリが見つかりません」で exit 2 を返すため、終了コード表に従って中断する |
| 値に `..` は無いが symlink でプロジェクト外を指す | 文字列の検査では検出できない。`capture.py` の封じ込め検証が exit 2 で止める（case-12） |
| `viewport` が範囲外（`0` や `10001`） | `capture.py` の `--width` / `--height` は 1〜10000 の範囲検査を持つため引数エラーとなり exit 2。中断の扱いは case-09 と同じ |
| 異常値が `pending.tsv` 側のパスに含まれる | `pending.tsv` へ記録する時点でフックが検証しており、`[A-Za-z0-9._/-]` のみ・200 文字以内・`..` を含まない相対パス以外は記録されない（config-schema.md） |

## 関連ケース

- [case-12_capture_containment_violation.md](case-12_capture_containment_violation.md)（スキル側の検査をすり抜けた場合に `capture.py` が exit 2 で止める。本ケースの次の層）
- [case-09_screenshot_venv_missing.md](case-09_screenshot_venv_missing.md)（同じく中断するが、`capture.py` を起動したうえで exit 2 を受け取る点が異なる）
- [case-05_push_failure.md](case-05_push_failure.md)（同じく記録を温存するが、中断の位置が手順 5 である）
- [case-10_plan_rejected.md](case-10_plan_rejected.md)（同じく何も push しないが、原因がユーザー判断である）
