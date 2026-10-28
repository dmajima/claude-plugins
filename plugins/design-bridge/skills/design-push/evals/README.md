# Evals: design-push

このディレクトリは `design-push` スキルの動作分岐ごとの期待挙動を定義するケース集。各ケースは仕様書として機能する（`DesignSync` への実アクセスと対話承認を伴うため、自動実行フロントマターは付与しない）。

正本は [`../SKILL.md`](../SKILL.md) と [`../references/procedures.md`](../references/procedures.md)。状態ファイルの形式は [`../../design-init/references/config-schema.md`](../../design-init/references/config-schema.md) を参照する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| [case-01_pending_all.md](case-01_pending_all.md) | 引数なし。`pending.tsv` の全件を対象に、計画提示 → 承認 → push → `last-push.json` 更新 → `--all --drop-bundle` での解除まで実行する | 引数 = なし かつ `pending.tsv` が非空 かつ 全件成功 |
| [case-02_screen_id.md](case-02_screen_id.md) | 画面 ID を指定。その画面のみを非対話で反映し、`--path` で部分解除する。他画面の記録は `pending.tsv` に残る | 引数 = 画面 ID → 非対話モード・対象が `pending.tsv` の部分集合 |
| [case-03_all_mocks.md](case-03_all_mocks.md) | `--all` 指定。`mocksDir` 配下の全モックを対象にし、リモート側の余剰ファイル（削除候補）をユーザーに確認する。解除は push したモックと更新した設計書のみ | 引数 = `--all` → 全モック対象。かつ `list_files` に削除候補あり |
| [case-04_pending_empty.md](case-04_pending_empty.md) | 引数なしで `pending.tsv` が空。「反映すべき変更はありません」と報告して正常終了し、`capture.py` も `DesignSync` も呼ばない | 引数 = なし かつ `pending.tsv` が空（または不在） |
| [case-05_push_failure.md](case-05_push_failure.md) | `write_files` が全件失敗。`clear_pending.sh` を呼ばず、記録を一切解除しない | `write_files` の結果 = 全件失敗 |
| [case-06_partial_push_failure.md](case-06_partial_push_failure.md) | `write_files` が一部失敗。成功分のみ `--path` で解除し、失敗分は `pending.tsv` に残す | `write_files` の結果 = 一部成功・一部失敗 |
| [case-07_auth_error.md](case-07_auth_error.md) | design-system 未認可。`get_project` が認可エラーを返した時点で `/design-login` を案内して中断し、記録を温存する | `DesignSync` の応答 = 認可エラー |
| [case-08_not_design_system.md](case-08_not_design_system.md) | `get_project` の `type` が `PROJECT_TYPE_DESIGN_SYSTEM` でない。`design-init` での再設定を案内して中断し、記録を温存する | `get_project` の `type` = design-system 以外 |
| [case-09_screenshot_venv_missing.md](case-09_screenshot_venv_missing.md) | `capture.py` が exit 2（playwright 未導入）。venv 構築を案内して中断し、設計書も書き換えず記録を温存する | `capture.py` の終了コード = 2 |
| [case-10_plan_rejected.md](case-10_plan_rejected.md) | ユーザーが push 計画全体を拒否。`finalize_plan` に到達せず、何も push せず記録も解除しない | push 計画への応答 = 拒否 |
| [case-11_invalid_config_value.md](case-11_invalid_config_value.md) | `mocksDir` に `..`・絶対パス・シェルのメタ文字が入っている。コマンドを組み立てる前に設定異常として報告し、`capture.py` を起動せず中断する。記録は温存する | 設定値 = `..` / 絶対パス / シェルのメタ文字を含む |
| [case-12_capture_containment_violation.md](case-12_capture_containment_violation.md) | 文字列検査を通る値（symlink）でスキル側の検証をすり抜けた場合でも、`capture.py` が `--mocks-dir` / `--out-dir` の実体位置を検証して exit 2 を返す多層防御。中断し記録は温存する | `capture.py` の終了コード = 2（原因 = 封じ込め違反） |
| [case-13_capture_partial_failure.md](case-13_capture_partial_failure.md) | `capture.py` が exit 1（2 画面のうち 1 件が撮影失敗）。残りで push を続けるかユーザーに確認し、続行時は失敗画面を以降の対象から外す（設計書も更新せず記録も解除しない）。中止時は何も push しない | `capture.py` の終了コード = 1 |

## 必須カバレッジ対応表

| カバレッジ | 観点 | 対応ケース |
|----------|-----|----------|
| 対話モード | 引数・フラグなしでの通常実行 | case-01、case-04、case-05、case-06、case-07、case-08、case-09、case-10、case-11、case-12、case-13 |
| 非対話モード | 引数で対象を指定（`--non-interactive` 相当）。計画提示は省略しない | case-02、case-03 |
| 主要分岐: 対象決定 | 引数なし（`pending.tsv` 全件） | case-01、case-05、case-06 |
| 主要分岐: 対象決定 | 画面 ID 指定 | case-02 |
| 主要分岐: 対象決定 | `--all`（`mocksDir` 配下の全モック） | case-03 |
| 主要分岐: 対象決定 | `pending.tsv` が空 → 早期正常終了 | case-04 |
| 主要分岐: 解除範囲 | 全件成功 → `--all --drop-bundle` | case-01 |
| 主要分岐: 解除範囲 | 部分集合 → `--path` での部分解除 | case-02、case-03、case-06、case-13（続行時） |
| 主要分岐: 解除範囲 | 失敗・中断 → 解除しない | case-05、case-07、case-08、case-09、case-10、case-11、case-12、case-13（中止時） |
| 主要分岐: `capture.py` 終了コード | 0 → 確認なしで続行 | case-01、case-02、case-03 |
| 主要分岐: `capture.py` 終了コード | 1 → 残りで続行するかユーザーに確認（続行 / 中止の両帰結） | case-13 |
| 主要分岐: `capture.py` 終了コード | 2 → 確認なしで中断（原因別に案内） | case-09（環境不備）、case-12（封じ込め違反） |
| 主要分岐: リモート差分 | 削除候補の検出とユーザー確認、リモート先行の提案 | case-03 |
| `list_files` の正規化 | ディレクトリ名の除外、記録の無いリモートファイルを削除候補にしないこと | case-03 |
| 主要分岐: 承認 | 計画の承認 / 部分拒否 / 全体拒否 | case-01（承認）、case-03（部分拒否）、case-10（全体拒否） |
| エラー系: 前提不足 | 認可なし | case-07 |
| エラー系: 設定不正 | プロジェクト型が design-system でない | case-08 |
| エラー系: 設定不正 | `mocksDir` / `assetsDir` の値が `..` / 絶対パス / シェルのメタ文字を含む（実行前に検出） | case-11 |
| エラー系: 封じ込め | 入出力パスの実体がプロジェクトルート外（`capture.py` 側で検出） | case-12 |
| エラー系: 環境不備 | venv 未整備による `capture.py` exit 2 | case-09 |
| エラー系: 撮影失敗 | 一部のモックで撮影に失敗（exit 1） | case-13 |
| エラー系: 送信失敗 | 全件失敗 / 一部失敗 | case-05、case-06 |

`capture.py` の終了コードは 3 分岐すべてをケース化している（0 = case-01 ほか、1 = case-13、2 = case-09 / case-12）。

設定値の扱いは 2 層でケース化している。case-11 がシェルへ渡す前のスキル側検査、case-12 がそれをすり抜けた場合の `capture.py` 側検証にあたる。両者は代替関係ではなく多層の関係にあり、どちらか一方だけでは不十分である（層ごとの役割は case-12 の「多層防御の構造」を参照）。

## 安全性の中心的な不変条件

case-05 から case-13 が検証するのは design-push の最重要要件である。

> **push に成功した対象に限って未反映記録を解除する。対象外のエントリを巻き込んで消さない。**

この不変条件が破れると、未反映の変更が Stop フックに検出されなくなり、「反映済みのつもりで未反映」という、design-bridge が防ごうとしている状態そのものが発生する。procedures.md の「迷った場合は解除しない側に倒す」はこの判断を言語化したものである。

関連する運用上の前提:

- 記録の解除は必ず `clear_pending.sh` を経由する。`pending.tsv` を直接編集しない
- 解除しなかった場合、Stop フックは `blockLimit`（既定 3）まで再通知する。上限に達すると `dismissed` にその時点の内容ハッシュが記録され、`pending.tsv` の内容が変わるまで再通知されない
- `clear_pending.sh` は残存が 0 件になった場合に `block-count` と却下マーカーを削除する
- `last-push.json` は `design-status` のドリフト判定の基準点であり、push 成功時にのみ更新する

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

- `DesignSync` への実アクセスを伴うため、検証用の design-system プロジェクトに対して実施する
- 事前に `pending.tsv` の内容を「入力」の状態に揃える（記録は PostToolUse フックが行う。手で `pending.tsv` を書かない）
- case-05 から case-13 の確認後は、`pending.tsv` が期待どおり残っていることをファイルシステム上で確認する
- 部分解除のケース（case-02 / case-03 / case-06 / case-13 の続行時）は `clear_pending.sh` が出力する `解除: N 件 / 残存: M 件` を突き合わせる
- case-11 / case-12 は `capture.py` の呼び出し回数（それぞれ 0 回 / 1 回）と終了コードを確認する。case-12 の symlink はリポジトリにコミットせず、検証時にローカルで作成する
- case-13 は続行・中止の両方を実施し、それぞれの期待出力表と突き合わせる
- 計画提示と承認 UI の実発火は機械検証の射程外のため、人間レビューで確認する

## ケース追加ルール

次のいずれかを変更した場合は、対応するケースを必ず追加・更新する。

- 対象決定の規則（引数・`pending.tsv`・`--all` の扱い）
- `DesignSync` の呼び出し順序、または中断条件
- `clear_pending.sh` の解除範囲の表
- `capture.py` の終了コードの意味
- 設定値の検査規則（`..`・絶対パス・シェルのメタ文字）、または `capture.py` の封じ込め検証の範囲
- `last-push.json` の記録タイミング
