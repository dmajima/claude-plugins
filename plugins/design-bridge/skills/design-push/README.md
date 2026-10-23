# design-push (skill)

ローカル正本（`specs/` の Markdown 画面設計書と `mocks/` のモック HTML）を claude.ai/design の design-system プロジェクトへ反映し、未反映記録をクリアするスキルです。スクリーンショットの再生成から Claude Design への送信までを 1 本で実行します。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は [`SKILL.md`](SKILL.md) および [`references/procedures.md`](references/procedures.md) を参照してください。

## なぜこのスキルがあるか

design-bridge の設計上の前提と、それが design-push の形に落ちる理由は次のとおりです。

| 前提 | 帰結 |
|-----|------|
| 正本は常にローカル。claude.ai/design は表示・承認用の鏡として扱う | 反映は「ローカル → Claude Design」の一方向が既定になる |
| `DesignSync` にリモート変更の通知機構（watch）が無い | 双方向の自動同期は原理的に成立しない。そのため push は強制、pull は明示指示のみ、という非対称な設計になっている |
| 未反映の変更が残っていると Stop フックが応答の終了をブロックする | design-push は、そのブロックを解除する唯一の正規手段 |
| `DesignSync` の `write_files` は `localPath` 指定でローカルファイルを直接アップロードする | モック HTML の内容がコンテキストを消費しない。画面数が多くても会話が圧迫されない |

「設計書を直したが Claude Design に反映し忘れた」状態を運用ルールではなくフック機構で防ぐのが design-bridge の中心的な仕組みであり、design-push はその出口にあたります。

## 責務（要約）

- 対象モック HTML のスクリーンショットを再生成する
- Markdown 設計書の「画面イメージ」セクション（画像 + モックへのリンク）を最新化する
- push 対象をバンドルディレクトリへ集約し、`DesignSync` で design-system プロジェクトへ送る
- push マニフェスト（`last-push.json`）を更新し、ドリフト判定の基準点を残す
- push に成功した対象に限って、未反映記録を `clear_pending.sh` で解除する（対象外のエントリは残す）

モック HTML の新規生成（`design-mock`）、導入・設定生成（`design-init`）、Claude Design 側を正とする取り込み（`design-pull`）、読み取りのみの状態確認（`design-status`）は責務外です。

## 導入手順

### 前提

- Claude Code がインストール済み
- `design-bridge` プラグインがインストール済み
- 対象リポジトリに `.claude/design-bridge.json` が存在すること（無ければ `design-init` を先に実行）
- `/design-login` による design-system 認可が済んでいること
- スクリーンショット用 venv が構築済みであること（未構築の場合は `design-init` の手順 6 を案内されます）

### 起動方法

以下のフレーズで自動起動します。

- 「Claude Design に反映して」
- 「デザインを同期して」
- 「push して」

明示起動する場合は `/design-push [画面ID] [--all]` を使います。Stop フックが未反映を理由にブロックした場合も、このスキルの実行で解除されます。

## 利用方法（最小例）

ユーザ:
> ログイン画面のモックを直したので Claude Design に反映して

Claude（要約）:
> `pending.tsv` の対象を確認し、`S001_login` のスクリーンショットを再生成。設計書の画面イメージセクションを更新したうえで push 計画（更新 1 件・追加 0 件・削除 0 件）を提示。承認後に `DesignSync` で送信し、`last-push.json` を更新。`clear_pending.sh --path` で当該 2 件だけ記録を解除し、反映結果と残存件数を報告。

## 引数と対象範囲

| 引数 | 対象 | モード |
|-----|------|-------|
| なし | `.claude/.local/plugins/design-bridge/pending.tsv` の全件 | 対話 |
| 画面 ID | その画面の設計書・モックのみ | 非対話 |
| `--all` | `mocksDir` 配下の全モック | 非対話 |
| `--non-interactive` | 対象は上記の規則に従う | 非対話 |

引数なしで `pending.tsv` も空の場合は、「反映すべき変更はありません」と報告して正常終了します（空振りの push を行いません）。

**非対話モードでも push 計画の提示は省略されません。** リモートを上書きする操作のためです。

## 処理の流れ

| 手順 | 内容 |
|-----|------|
| 1 | 導入確認（`.claude/design-bridge.json`）と対象決定 |
| 2 | スクリーンショットの再生成（`capture.py`） |
| 3 | Markdown の画面イメージセクション更新 |
| 4 | バンドル（`foundations/` `screens/`）の作成と `@dsCard` マーカー付与 |
| 5 | `DesignSync` による push（`get_project` → `list_files` → 計画提示 → `finalize_plan` → `write_files`） |
| 6 | push マニフェスト（`last-push.json`）の更新 |
| 7 | `clear_pending.sh` による未反映記録の解除（push に成功した対象のみ） |
| 8 | 反映結果と残存件数の報告 |

手順 5 の呼び出し順序は `DesignSync` の仕様で固定されています。`finalize_plan` を経ずに `write_files` を呼ぶと拒否されます。

## 安全性の要点

| 要点 | 理由 |
|-----|------|
| push が成功しなかった場合、未反映記録を解除しない | 中途半端な解除は「反映済みのつもりで未反映」という最悪の状態を生む。未反映のまま Stop フックに再度ブロックさせる |
| 対象が一部のときは該当分だけ解除する | 画面 ID 指定の push で他画面の記録まで消えると、その画面の未反映が検知対象から外れる。解除は `clear_pending.sh --path` で明示的に行う |
| 認可エラー時は `/design-login` を案内して中断する | 認可なしでは送信できず、記録だけ消えると未反映が見えなくなる |
| 削除対象がある場合は必ずユーザーに確認する | ローカルで意図的に消したのか、Claude Design 側で誰かが追加したのかを区別できない |
| `localDir` の外にあるファイルを `localPath` に指定しない | `DesignSync` の仕様上、バンドルディレクトリ配下しか送れない |
| 設計書の画面イメージセクション以外を書き換えない | 設計書本文の正本性を壊さない |
| リモート先行の疑いがあれば `design-pull` での確認を提案する | push は常にローカル内容での上書きになるため |

## トリガー例

- 「Claude Design に反映して」
- 「デザインを同期して」
- 「push して」
- 「設計書を更新したので反映もお願い」
- Stop フックが未反映を理由にブロックしたとき

## 関連スキル

| スキル | 関係 |
|-------|------|
| `design-init` | 前段。`.claude/design-bridge.json` の生成とスクショ用 venv の構築を行う |
| `design-mock` | 前段。設計書からモック HTML を生成する。生成後は design-push で反映する |
| `design-pull` | 逆方向。Claude Design 側を正としてローカルを更新する（明示指示時のみ） |
| `design-status` | 事前確認。反映せずに未反映一覧とドリフト状況だけを表示する |

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| [`SKILL.md`](SKILL.md) | スキル定義・トリガー条件・実行フロー |
| [`references/procedures.md`](references/procedures.md) | 各手順の具体的な実行方法、`DesignSync` の呼び出し順序、失敗時の扱い |
| `${CLAUDE_PLUGIN_ROOT}/skills/design-push/references/scripts/screenshot/capture.py` | スクリーンショット生成スクリプト |
| [`../design-init/references/config-schema.md`](../design-init/references/config-schema.md) | `design-bridge.json` のスキーマと状態ファイルの一覧 |
| [`evals/`](evals/) | 動作分岐の期待挙動 |

## ファイル構成

```text
skills/design-push/
├── SKILL.md                              # スキル定義
├── README.md                             # 人間向けリファレンス（本ファイル）
├── references/
│   ├── procedures.md                     # 実行手順の詳細
│   └── scripts/screenshot/capture.py     # スクリーンショット生成
└── evals/
    ├── README.md                           # evals の概要とケース一覧
    ├── case-01_pending_all.md              # 引数なし（pending.tsv 全件・対話）
    ├── case-02_screen_id.md                # 画面 ID 指定（部分解除）
    ├── case-03_all_mocks.md                # --all（削除候補の確認）
    ├── case-04_pending_empty.md            # pending 空 → 正常終了
    ├── case-05_push_failure.md             # 完全失敗 → 解除しない
    ├── case-06_partial_push_failure.md     # 一部失敗 → 成功分のみ解除
    ├── case-07_auth_error.md               # 認可エラー → /design-login 案内
    ├── case-08_not_design_system.md        # 型違い → design-init 案内
    ├── case-09_screenshot_venv_missing.md  # venv 未整備 → 構築案内
    └── case-10_plan_rejected.md            # 計画拒否 → 何も変更しない
```
