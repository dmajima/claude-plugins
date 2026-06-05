# Case 14: XR-5 Unknown 閾値警告（試行済みの 20% 超）

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all` |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `target` | `all` |
| 既存状態 | claude plugin CLI の出力フォーマットが想定と異なり、exit code は 0 だが出力パターンマッチ不能（Unknown 区分）が多数発生 |

## 期待動作

### Phase A〜E: 通常通り実行
- 各 Phase で `claude plugin update <name>@<mp>` を実行
- exit code は 0 だが、出力フォーマットが想定と異なる Unknown 区分が複数発生

### Phase F: 結果報告 + XR-5 警告

XR-5 の閾値判定:

```text
unknown_count / attempted_count > 0.20
```

例: 試行 10 件のうち Unknown が 3 件（30%）→ XR-5 警告発火。

```text
[XR-5 WARNING] CLI 出力フォーマットが想定と異なる Unknown 区分が
全体の 30%（3/10）に達しました。Claude Code CLI のバージョン変更が
あった可能性があります。

確認手順:
1. `claude --version` でバージョンを確認
2. 公式リリースノートで `plugin update` の出力変更を確認
3. plugin-updater スキルの cross-cutting-rules.md (XR-5) を更新
```

### Phase G
- Unknown は exit code 0 のため Failed 扱いではない → 通常は発火しない
- ただし運用上は警告を見て手動で `claude plugin update <name>@<mp>` を再実行することを推奨

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| XR-5 警告メッセージ | Phase F-1 のサマリに必須出力 |
| 警告条件 | unknown / attempted > 20% |
| 終了状態 | exit 0 |

## 分岐の根拠

このケースが分岐するトリガーは Unknown 区分の発生率 > 20% である（XR-5 SSOT）。

## 関連ケース

- `case-05_target_all.md`（Unknown 発生なしの正常系）
- `case-09_phase_g_retry.md`（Failed 発生時）
- references/cross-cutting-rules.md XR-5 詳細仕様
