# case-22 Phase 1 で test-setup が PARTIAL を返す（対話・停止せず続行し、利用不可項目の影響を実行フェーズへ引き継ぐ）

オーケストレータ `test` の Phase 1（setup 確認）で、委譲した `test-setup` が総合判定 **PARTIAL** の環境検証レポートを返した場合、RESTART_REQUIRED（再起動ハンドオフで停止）とは区別して**停止せずに後続フェーズへ続行**し、利用不可項目（例: ランナー未検出）に対応するレベルのケースが実行フェーズで skipped + reason になる見込みを保持・引き継ぐことを検証する。本ケースは**対話モード**を主軸に、PARTIAL の内容をユーザーへ提示して続行する挙動を扱う（非対話モードは case-24）。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「テストして」（フル・対話） |
| 前提 | run を含むモードで環境未検証のため Phase 1 で test-setup へ委譲する。`test-setup` の返却が総合判定 = **PARTIAL**（例: Playwright MCP = loaded、テストランナー = none〔unit 対象なのに未検出〕、venv = ready）。新規 MCP 登録・未ロードは発生していない（RESTART_REQUIRED 要因なし） |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/flow.md` 2.1 章「Phase 別の要点」Phase 1（setup 確認。新規 MCP 登録時は再起動ハンドオフで停止）および **Phase 1 の PARTIAL 分岐（追記後）**（PARTIAL 受領時は停止せず続行し、利用不可項目の影響を後続へ引き継ぐ）、`${CLAUDE_SKILL_DIR}/references/flow.md` 2 章 Phase 1 入出力（検出結果〔MCP / ランナー / venv〕を受領）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（実行手段が利用不可の場合、実行を偽装せず skipped + reason・報告書の未確認事項へ転記）・9 章（非対話既定値）、`deep-test:test-setup` の環境検証レポート（総合判定 3 値 READY / RESTART_REQUIRED / PARTIAL は test-setup の SKILL.md「引き渡し」・`setup-procedures.md` 6.2 章が定義元）。

## 期待動作

- test-setup の返却の**総合判定を読み、PARTIAL を RESTART_REQUIRED と混同しない**:
  - RESTART_REQUIRED（`newly-registered` / `not-loaded`）→ 再起動ハンドオフを出力して**停止**（case-03 の系）
  - **PARTIAL → 停止せず後続フェーズ（Phase 2 以降、環境検証済みモードなら Phase 4）へ続行**する
- 利用不可項目（ランナー = none）を「利用可」「問題なし」と扱わない。該当レベル（unit）のケースは**実行フェーズで skipped + reason になる見込み**として引き継ぐ（execution-policy.md 2 章）。MCP が loaded のため functional 等のブラウザ依存レベルは実行可能見込みとして扱う
- **対話モード**: PARTIAL の内容（どの項目が利用不可で、どのレベルが skipped 見込みか）をユーザーに提示して続行する（degrade した環境であることを隠さない）。後続の人間承認ゲート（Phase 4）で実行ケース数・レベルとともに再提示される
- skipped 見込みのレベルは最終的に報告書の「未確認事項」に転記される（report-format.md への引き継ぎ）
- Phase 1 の PARTIAL を理由に venv や MCP の状態を勝手に上書き・再構築しない（判定材料としてのみ用いる）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | Phase 1 時点では test-setup が構築した venv 以外の生成物なし。以降のフェーズで通常どおり test-cases.yaml / test-results.yaml が更新される |
| 標準出力（要約） | PARTIAL を受領したが停止せず続行する旨・利用不可項目（ランナー none）と影響レベル（unit は skipped 見込み）をユーザーへ提示。以降は通常フローの引き渡し |
| 終了状態 | 停止しない（RESTART_REQUIRED でない）。後続フェーズを継続し、利用不可レベルは実行時 skipped として最終的に未確認事項へ計上 |

## 関連ケース

- case-24: 同じ PARTIAL 受領の**非対話モード**版（ユーザー提示を伴わず自動続行・skipped 見込みを記録。本ケースの対）
- case-03: Phase 1 で新規 MCP 登録 / 未ロード → RESTART_REQUIRED で再起動ハンドオフ停止（PARTIAL と対の総合判定）
- case-05: 非対話モードの既定値動作（manual-assist skipped 等、実行手段不在の skipped 全般）
- test-setup case-07 / case-08: test-setup 側が PARTIAL を**返す**分岐（本ケースは test 側が PARTIAL を**受領**して制御する分岐）
