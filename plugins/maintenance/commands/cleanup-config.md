---
description: maintenance cleanup-workspace の閾値設定を表示・変更
argument-hint: "[--show] [--set-... N|name] [--reset --yes]"
---

`maintenance` プラグインの `cleanup-workspace` スキルが参照する閾値設定ファイル `~/.claude/.local/plugins/maintenance/cleanup-config.json`（グローバル配下）を表示・変更・リセットするコマンド。

`$ARGUMENTS` の有無により **2 つの動作モード** を切り替える。

## 1. 非対話モード（`$ARGUMENTS` が非空）

引数を解析し、`${CLAUDE_PLUGIN_ROOT}/skills/cleanup-workspace/references/scripts/cleanup/cleanup-config.sh` を Bash ツールで実行する。

| 引数 | 動作 |
|------|------|
| `--show` | 現在の設定内容を表示 |
| `--set-days N` | `default_days` を更新（0 以上の整数） |
| `--set-keep-recent N` | `default_keep_recent` を更新（0 以上の整数） |
| `--set-scope <global\|project\|both>` | `default_scope` を更新 |
| `--set-active-minutes N` | `active_session_minutes` を更新（1 以上の整数） |
| `--reset --yes` | 出荷時デフォルトにリセット（`--yes` 必須） |

実行例:

`$ARGUMENTS` の文字列を直接 cleanup-config.sh に展開するのは引数インジェクションの
余地が残るため、**個別フラグを明示的にパースして名前付き引数で渡す**こと。

```bash
bash "$CLAUDE_PLUGIN_ROOT/skills/cleanup-workspace/references/scripts/cleanup/cleanup-config.sh" "${args[@]}"
```
## 2. 対話モード（`$ARGUMENTS` が空）

**AskUserQuestion 1 回で 4 質問を同時発火** し、`default_days` → `default_keep_recent` → `default_scope` → `active_session_minutes` の順に一気に設定する。

### Step 1: 設定読み込み

実行前に `cleanup-config.sh -Show`（または直接 `~/.claude/.local/plugins/maintenance/cleanup-config.json` を読み込み）で **現在値** を取得する。設定ファイル不在時は出荷時デフォルト（`default_days=30` / `default_keep_recent=0` / `default_scope=both` / `active_session_minutes=5`）を採用する。

### Step 2: AskUserQuestion 4 質問同時発火

各質問の選択肢は **以下のルール** で構築する:

| ルール | 内容 |
|-------|------|
| 1 つ目の選択肢 | **現在値**（設定ファイル存在時）または **出荷時デフォルト**（設定ファイル不在時）|
| 1 つ目の label 末尾 | `（現在の設定）` または `（既定）` を付与 |
| 残りの選択肢 | 推奨値（下表）から現在値を除いたもの。現在値が推奨値外なら推奨値全部を追加（最大 4 options） |
| Other（Type something） | AskUserQuestion 仕様で自動付与。整数項目は自由入力可、scope は再入力誘導 |

#### 推奨値テーブル

| 項目 | 推奨値 | description に併記する他の典型値 |
|-----|-------|------------------------------|
| `default_days` | **14 / 30 / 90** | 60 / 180 / 365 |
| `default_keep_recent` | 0 / 3 / 5 | 10 / 20 |
| `default_scope` | both / global / project（全候補） | （全カバー、Other 入力時は再入力誘導） |
| `active_session_minutes` | 5 / 10 / 15 | 3 / 30 / 60 |

#### Question 1: default_days

例（現在値が 30 の場合）:

```text
{
  question: "default_days（古いと判定する日数）を選択してください。Other を選ぶと任意の 0 以上の整数を入力できます（他に 60 / 180 / 365 等が頻用されます）。",
  header: "default_days",
  options: [
    { label: "30（現在の設定）", description: "1 ヶ月以内のセッションを保持。通常運用の既定。" },
    { label: "14",               description: "2 週間以内のセッションを保持。クリーンアップを積極的に行いたい場合。" },
    { label: "90",               description: "3 ヶ月以内のセッションを保持。四半期単位でクリーンアップしたい場合。" }
  ],
  multiSelect: false
}
```

現在値が推奨 3 値（14/30/90）の外、例えば `60` の場合:

```text
options: [
  { label: "60（現在の設定）", description: "現在の閾値。維持する場合は本選択肢を選んでください。" },
  { label: "14", description: "..." },
  { label: "30", description: "..." },
  { label: "90", description: "..." }
]
```

#### Question 2: default_keep_recent

例（現在値が 0 の場合）:

```text
{
  question: "default_keep_recent（古さ条件を満たしても保持する最新セッション数）を選択してください。Other を選ぶと任意の 0 以上の整数を入力できます（他に 10 / 20 等も使用可能）。",
  header: "default_keep_recent",
  options: [
    { label: "0（既定）",                description: "最新セッションは保持しない（古さのみで判定）。" },
    { label: "3（直近 3 セッション保持）", description: "デバッグや参照頻度の高いセッションを残す標準的な設定。" },
    { label: "5（直近 5 セッション保持）", description: "頻繁にセッションを跨ぐ運用の場合の設定。" }
  ],
  multiSelect: false
}
```

> **note**: 設定ファイル不在時の 1 つ目 label は `0（既定）` のように `（既定）` 表記。設定ファイル存在 + 現在値 = 0 のような場合は `0（現在の設定）` のように `（現在の設定）` 表記。

#### Question 3: default_scope

例（現在値が both の場合）:

```text
{
  question: "default_scope（クリーンアップ対象スコープ）を選択してください。Other を選んだ場合は 'global' / 'project' / 'both' のいずれかを入力してください。",
  header: "default_scope",
  options: [
    { label: "both（現在の設定）", description: "グローバル（~/.claude/.local/work）とプロジェクト（<repo>/.claude/.local/work）の両方を対象。" },
    { label: "global",              description: "~/.claude/.local/work のみを対象。" },
    { label: "project",             description: "<repo>/.claude/.local/work のみを対象。" }
  ],
  multiSelect: false
}
```

#### Question 4: active_session_minutes

例（現在値が 5 の場合）:

```text
{
  question: "active_session_minutes（進行中保護の閾値分数）を選択してください。Other を選ぶと任意の 1 以上の整数を入力できます（他に 3 / 30 / 60 等が頻用されます）。",
  header: "active_session_minutes",
  options: [
    { label: "5（既定・現在の設定）", description: "Claude Code の典型的なタスク粒度に対し十分な保護幅。" },
    { label: "10",                    description: "長めの分析タスクを行う場合の保護幅。" },
    { label: "15",                    description: "AskUserQuestion を多用するタスク等で更新間隔が空く場合の保護幅。" }
  ],
  multiSelect: false
}
```

> **note**: 「既定値 = 現在値」のケース（設定ファイル不在 or 出荷時デフォルトのまま）は `5（既定・現在の設定）` のように両方表記してもよい（または `5（現在の設定）` のみで簡潔に）。

### Step 3: スクリプト実行（変更があった項目のみ）

4 つの選択結果と現在値を比較し、**変更があった項目のみ** を `cleanup-config.sh` の引数として渡す。

| 変更項目 | 渡す引数 |
|---------|---------|
| default_days | `-SetDays <選択値>` |
| default_keep_recent | `-SetKeepRecent <選択値>` |
| default_scope | `-SetScope <選択値>` |
| active_session_minutes | `-SetActiveSessionMinutes <選択値>` |

変更が **1 件もない** 場合は `-Show` で現在の設定を表示するのみ。

実行例（複数項目を一度に更新）:

```bash
bash "$CLAUDE_PLUGIN_ROOT/skills/cleanup-workspace/references/scripts/cleanup/cleanup-config.sh" -SetDays 90 -SetKeepRecent 3 -SetScope global -SetActiveSessionMinutes 10
```
### Step 4: 完了報告

更新後の設定全体を表示し、変更前→変更後の差分をユーザに提示する。

### 補助操作（対話モードからの分岐）

| 操作 | 起動方法 |
|------|---------|
| 現在の設定だけを確認 | `/cleanup-config --show` を引数指定で呼び出す |
| 出荷時デフォルトにリセット | `/cleanup-config --reset --yes` を引数指定で呼び出す |

これらは対話モードの 4 質問フローには含めない（Step 2 を簡潔に保つため）。ただし、対話モードの完了報告に「`--show` / `--reset --yes` で別操作が可能」と案内を付ける。

## 関連

- 設定ファイル本体: `~/.claude/.local/plugins/maintenance/cleanup-config.json`
- 利用元スキル: `cleanup-workspace`（`SKILL.md` / `references/scripts/cleanup/cleanup.sh`）
- atime 戦略: `cleanup-config.json` の `atime_strategy` フィールドで指定（既定: `progress_md`、フォールバック: 配下最大 mtime）
