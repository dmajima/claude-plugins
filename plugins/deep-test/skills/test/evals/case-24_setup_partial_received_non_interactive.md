# case-24 Phase 1 で test-setup が PARTIAL を返す（非対話・停止せず自動続行し skipped 見込みを記録）

オーケストレータ `test` の Phase 1（setup 確認）で `test-setup` が総合判定 **PARTIAL** を返した場合の**非対話モード**の挙動を検証する。case-22（対話・主軸）の対として、ユーザー提示を伴わず停止せず自動続行し、利用不可項目に対応するレベルのケースが実行時 skipped + reason になる見込みを記録することを扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「テストして」 + `--non-interactive`（フル・非対話） |
| 前提 | run を含むモードで環境未検証のため Phase 1 で test-setup へ委譲する。`test-setup` の返却が総合判定 = **PARTIAL**（例: Playwright MCP = loaded、テストランナー = none〔unit 対象なのに未検出〕、venv = ready）。新規 MCP 登録・未ロードは発生していない（RESTART_REQUIRED 要因なし） |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/flow.md` 2.1 章「Phase 別の要点」Phase 1（setup 確認）および Phase 1 の PARTIAL 分岐（PARTIAL 受領時は停止せず続行し、利用不可項目の影響を後続へ引き継ぐ）、`${CLAUDE_SKILL_DIR}/references/flow.md` 2 章 Phase 1 入出力（検出結果〔MCP / ランナー / venv〕を受領）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（実行手段が利用不可の場合、実行を偽装せず skipped + reason・報告書の未確認事項へ転記）・9 章（非対話既定値: 実行手段不在は skipped 扱いで自動続行・確認を挟まない）、`deep-test:test-setup` の環境検証レポート（総合判定 3 値 READY / RESTART_REQUIRED / PARTIAL は test-setup の SKILL.md「引き渡し」・`setup-procedures.md` 6.2 章が定義元）。

## 期待動作

- test-setup の返却の**総合判定を読み、PARTIAL を RESTART_REQUIRED と混同しない**:
  - RESTART_REQUIRED（`newly-registered` / `not-loaded`）→ 再起動ハンドオフを出力して**停止**（case-03 の系。非対話でも自動続行せず停止する）
  - **PARTIAL → 停止せず後続フェーズへ続行**する
- 利用不可項目（ランナー = none）を「利用可」「問題なし」と扱わない。該当レベル（unit）のケースは**実行フェーズで skipped + reason になる見込み**として引き継ぐ（execution-policy.md 2 章）。MCP が loaded のため functional 等のブラウザ依存レベルは実行可能見込みとして扱う
- **非対話モード**: PARTIAL の内容についてユーザーへの確認・提示（AskUserQuestion）を挟まず、停止せず自動続行する。利用不可による skipped 見込みを記録する（execution-policy.md 9 章。実行手段不在は skipped 扱いで自動続行）
- 人間承認ゲート（Phase 4）は非対話のためスキップされる（PARTIAL の再提示も行われない。execution-policy.md 9 章）
- skipped 見込みのレベルは最終的に報告書の「未確認事項」に転記される（report-format.md への引き継ぎ）
- Phase 1 の PARTIAL を理由に venv や MCP の状態を勝手に上書き・再構築しない（判定材料としてのみ用いる）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | Phase 1 時点では test-setup が構築した venv 以外の生成物なし。以降のフェーズで通常どおり test-cases.yaml / test-results.yaml が更新される |
| 標準出力（要約） | PARTIAL を受領したが停止せず自動続行する旨・利用不可項目（ランナー none）と影響レベル（unit は skipped 見込み）を記録（ユーザー提示・確認は挟まない）。以降は通常フローの引き渡し |
| 終了状態 | 停止しない（RESTART_REQUIRED でない）。人間承認ゲートをスキップして後続フェーズを継続し、利用不可レベルは実行時 skipped として最終的に未確認事項へ計上 |

## 関連ケース

- case-22: 同じ PARTIAL 受領の**対話モード**版（PARTIAL 内容をユーザーへ提示して続行。本ケースの主軸）
- case-03: Phase 1 で新規 MCP 登録 / 未ロード → RESTART_REQUIRED で再起動ハンドオフ停止（非対話でも自動続行せず停止する側）
- case-05: 非対話モードの既定値動作（人間承認スキップ・manual-assist skipped 等、実行手段不在の skipped 全般）
- test-setup case-07 / case-08: test-setup 側が PARTIAL を**返す**分岐（本ケースは test 側が PARTIAL を**受領**して制御する分岐）
