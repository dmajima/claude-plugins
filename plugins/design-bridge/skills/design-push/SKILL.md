---
name: design-push
description: ローカルの画面設計書とモックを claude.ai/design へ反映するスキル（スクショ再生成 → Markdown の画面イメージ更新 → DesignSync で push → 未反映記録のクリア）。「Claude Design に反映して」「デザインを同期して」等の依頼で起動する。Stop フックのブロック解除にも使う。Use when pushing local specs and mocks to claude.ai/design. SKIP when 取り込み（design-pull）、導入（design-init）。
---

# design-push

ローカル正本（`specs/` の Markdown と `mocks/` の HTML）を claude.ai/design へ反映し、未反映記録をクリアする。Stop フックがブロックした状態を解除する唯一の正規手段。

## 責務

- モック HTML のスクリーンショットを再生成する
- Markdown 設計書の画面イメージ参照（画像 + モックへのリンク）を最新化する
- `DesignSync` で design-system プロジェクトへファイルを push する
- 未反映リスト（`pending.txt`）と連続ブロックカウンタを削除する

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| 導入・設定ファイル生成 | `design-init` |
| モック HTML の新規生成 | `design-mock` |
| Claude Design 側を正とする取り込み | `design-pull` |
| 反映せずに状態だけ見る | `design-status` |

## トリガー条件

- 「Claude Design に反映して」「デザインを同期して」「push して」
- Stop フックが未反映を理由にブロックしたとき
- 設計書・モックを編集した直後

このスキルを起動しないケース:

- `.claude/design-bridge.json` が無い（→ `design-init`）
- Claude Design 側の変更を取り込みたい（→ `design-pull`）

## 前提

1. `.claude/design-bridge.json` が存在すること
2. `/design-login` による design-system 認可が済んでいること
3. スクリーンショット用 venv が構築済みであること（未構築ならこのスキル内で `design-init` の手順 6 を促す）

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| 引数で対象を指定、または `--non-interactive` | 非対話 | 対象を確定して進行。plan の確認を省略しない |
| 上記以外 | 対話 | 対象範囲と push 計画をユーザーに提示して確認 |

## 実行フロー

### 1. 導入確認と対象決定

`.claude/design-bridge.json` を読む。無ければ `design-init` を案内して中断する。

| 入力 | 対象 |
|-----|------|
| 引数で画面 ID 指定 | その画面の設計書・モックのみ |
| 引数なし | `.claude/.local/plugins/design-bridge/pending.txt` の全件 |
| `--all` | `mocksDir` 配下の全モック |

`pending.txt` が空で引数も無い場合は「反映すべき変更はありません」と報告して正常終了する。

### 2. スクリーンショットの再生成

対象モックに対し、プラグイン同梱スクリプトでスクリーンショットを生成する。

```bash
"<venv>/Scripts/python.exe" "${CLAUDE_PLUGIN_ROOT}/references/scripts/screenshot/capture.py" \
  --mocks-dir "<mocksDir>" \
  --out-dir "<assetsDir>" \
  --width 1280 --height 800 \
  --only "<画面 ID>"
```

Windows で子プロセスがハングする既知事象を避けるため、`PowerShell` ツールから直接起動せず `Bash` ツール経由で実行する。詳細は [references/procedures.md](references/procedures.md) を参照。

### 3. Markdown の画面イメージ更新

各設計書に「画面イメージ」セクションが無ければ追加し、あれば参照を最新化する。

```markdown
## 画面イメージ

![<画面名>](../assets/<画面 ID>.png)

[モックを開く](../../mocks/<画面 ID>.html) ｜ Design カード: `<画面 ID>`
```

既存の本文は書き換えない。画面イメージセクションのみを対象とする。

### 4. バンドルの作成

push 対象を `.claude/.local/plugins/design-bridge/bundle/` に集約する。Claude Design 側のパス構成は次のとおり。

| バンドル内パス | 内容 |
|--------------|------|
| `foundations/_tokens.html` | トンマナ |
| `foundations/_layout.html` | 基礎レイアウト |
| `screens/<画面 ID>.html` | 画面モック |

各 HTML の先頭行に `<!-- @dsCard group="..." -->` が無い場合は付与する。Design System ペインのカード索引はこのマーカーから構築されるため、明示的な `register_assets` は不要。

### 5. DesignSync による push

必ず次の順序で実行する。

1. `get_project` で `projectId` が design-system 型であることを確認する
2. `list_files` で現在のリモート構成を取得し、追加・更新・削除の計画を立てる
3. 計画をユーザーに提示する（非対話モードでも提示は省略しない）
4. `finalize_plan` で `writes` / `deletes` と `localDir`（バンドルディレクトリ）を確定する
5. `write_files` で `localPath` を指定して送る（内容をコンテキストに載せない）

1 回あたり 256 ファイルが上限。超える場合は同一 `planId` で複数回に分割する。

### 6. 未反映記録のクリア

push 成功後にのみ、次を削除する。

- `.claude/.local/plugins/design-bridge/pending.txt`
- `.claude/.local/plugins/design-bridge/block-count`

push が失敗した場合は削除しない（未反映のまま Stop フックで再度ブロックさせる）。

### 7. 報告

反映したカード一覧、生成したスクリーンショット、更新した設計書、Claude Design プロジェクト名を提示する。

## 重要な制約

- push が失敗した状態で `pending.txt` を削除しない
- `finalize_plan` を経ずに `write_files` を呼ばない（仕様上拒否される）
- `localDir` の外にあるファイルを `localPath` に指定しない
- 設計書の画面イメージセクション以外を書き換えない
- リモートが先行している可能性がある場合は、上書き前に `design-pull` での確認をユーザーへ提案する

## 参照

| 用途 | ファイル |
|-----|---------|
| 実行手順の詳細 | [references/procedures.md](references/procedures.md) |
| スクリーンショット生成 | `${CLAUDE_PLUGIN_ROOT}/references/scripts/screenshot/capture.py` |
