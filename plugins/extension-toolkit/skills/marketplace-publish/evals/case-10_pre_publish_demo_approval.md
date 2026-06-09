# Case 10: 公開モード選択前の動作デモ + AskUserQuestion 承認取得（A-1 / ADR-032）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`new-plugin` を公開して" |
| 引数 | `new-plugin` |
| フラグ | なし（対話モード） |
| 既存状態 | プラグイン本体検証・marketplace.json 更新・重複チェック・シークレットスキャンが完了。「公開モード選択」フェーズ直前 |

## 期待動作

### Phase 1〜5: 標準フロー（case-01 と同様）

[case-01](case-01_new_register_handoff.md) の Phase 1〜5 までを実施:
1. 現状確認
2. プラグイン実体検証（plugin.json 妥当性・LICENSE 存在等）
3. 重複・マージチェック
4. marketplace.json の更新（marketplace-toolkit に委譲）
5. 検証

### Phase 6 直前: 公開対象プラグインの動作デモ（A-1 / ADR-032 必須）

[`completion-checklist.md`](../../../references/checklists/completion-checklist.md) 節 2.4 + ADR-032 に従い、**公開モード選択の前に** 以下を実施する:

| ステップ | 内容 |
|---------|------|
| (a) 公開対象プラグインの主要スキル / コマンドを起動 | `bash <plugin>/evals/demo.sh` または該当スキルの代表シナリオ |
| (b) AskUserQuestion 含有スキルなら実発火 | 公開後の利用者が遭遇する UI を実機で確認 |
| (c) marketplace 整合性確認 | marketplace-toolkit が同期した README の表示確認 |
| (d) 結果を提示 | 標準出力 / 生成成果物 / 同期 README の差分 |

### Phase 6: AskUserQuestion による公開承認

```text
AskUserQuestion({
  questions: [{
    question: "公開対象プラグインのデモを確認しました。公開してよいですか？",
    header: "公開承認",
    options: [
      { label: "承認・公開モード選択へ進む",
        description: "デモ結果が想定どおりであり、公開フローに進む" },
      { label: "追加デモ・別シナリオを実施",
        description: "未確認の動作分岐を追加検証する" },
      { label: "不具合あり・公開中断",
        description: "デモ結果に問題があり、該当 *-toolkit に戻して修正する" }
    ],
    multiSelect: false
  }]
})
```

### Phase 7: ユーザ選択別の動作

| ユーザ選択 | 後続動作 |
|----------|---------|
| 承認・公開モード選択へ進む | SKILL.md 節 6「公開モードの選択」へ進み、ハンドオフ / フルオートを `AskUserQuestion` で再選択 |
| 追加デモ・別シナリオを実施 | Phase 6 直前に戻り、別シナリオでデモ |
| 不具合あり・公開中断 | 該当 `*-toolkit` への接続を提案して終了。`marketplace.json` の更新は維持するか revert するか確認 |

### Phase 8: 公開モード選択（A-1 承認後のみ）

SKILL.md 節 6 のフローに従い、ハンドオフ or フルオートを AskUserQuestion で選択（[case-01](case-01_new_register_handoff.md) / [case-04](case-04_full_auto.md) のいずれかへ分岐）。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | デモ実行結果 + AskUserQuestion 公開承認 UI 発火 + 承認後の公開モード選択 |
| 終了状態 | 承認時: 公開モード選択へ / 不具合時: 公開中断（marketplace.json は維持） |

## 分岐の根拠

ADR-032 の必須項目で「marketplace-publish は公開モード選択の前にデモ承認を取得」と明記。SKILL.md 節 6 にも「公開モード選択の前に必須」「公開はマーケットプレイス越しに利用者に届くため、デモなき公開は禁止」と記載。免責ケース（緊急セキュリティ修正のみ）に該当しない通常公開フローでは本ケースの手順を必ず通る。

## 関連ケース

- `case-01_new_register_handoff.md`（公開モード選択以降の標準ハンドオフフロー）
- `case-04_full_auto.md`（公開モード選択以降のフルオートフロー）
- `case-03_duplication_merge.md`（重複検出時の分岐、Phase 3）
- ADR-032 / SKILL.md 節 6 / completion-checklist.md 節 2.4
