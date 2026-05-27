# 議事録構造データ JSON スキーマ

minutes-composer が出力する `minutes.json` の構造定義。
人間が作成する議事録と同等の分類・粒度を持つ中間データ形式。

## トップレベル

```json
{
  "version": "2.0",
  "metadata": { ... },
  "agendas": [ ... ],
  "actionItems": [ ... ],
  "nextMeeting": { ... }
}
```

## metadata

```json
{
  "title": "会議タイトル",
  "date": "2026-05-26",
  "startTime": "15:00",
  "endTime": "16:04",
  "durationMinutes": 64,
  "location": "オンライン会議",
  "participants": [
    {
      "name": "眞嶋大介",
      "organization": "W2",
      "role": "host",
      "talkRatio": 0.5787
    }
  ],
  "source": "ailead | vtt | srt | teams-paste | plain | manual",
  "sourceUrl": "https://dashboard.ailead.app/share/...",
  "recordingSystem": "TEAMS",
  "createdBy": "AI（ailead + Claude）"
}
```

## agendas

各議題は以下の 5 区分で構成される（人間が作成する議事録と同等の分類）。

```json
[
  {
    "id": 1,
    "title": "要件定義第2回の進め方について",
    "timeSeconds": 85,
    "background": "本会議は要件定義第2回として実施された。今回の主な確認対象は...",
    "specifications": [
      "プロジェクト全体像は、提案時に提示した全体構成図をベースに整理している",
      "カスタマイズ一覧は、先日確認したExcelファイルで別管理とする"
    ],
    "discussions": [
      "W2より、今回は要件定義第2回として、機能の利用想定範囲と各種設定周りを中心に確認したい旨を説明した",
      "日世様より、いきなり帳票の話に入ったため業務フローから説明した方がよいのではとの指摘があった"
    ],
    "concerns": [
      "機能単位で確認を進めると、日世様側で業務全体の流れをイメージしづらい可能性がある",
      "現時点の確認内容が確定事項と誤解されないよう注意が必要である"
    ],
    "conclusions": [
      "今回は、まず機能単位で利用方針を確認する",
      "今回の確認内容は確定ではなく、後続の業務フロー整理時に見直し可能とする",
      "次回以降、今回ヒアリングした内容をもとに業務の流れとして再整理する"
    ]
  }
]
```

### 5 区分の定義

| 区分 | フィールド | 内容 | 記述ガイドライン |
|------|----------|------|----------------|
| 背景・目的 | `background` | この議題を取り上げた理由・確認の背景 | 「本会議は〜として実施された」「〜を確認する必要がある」等 |
| 仕様・機能詳細 | `specifications` | システム仕様・機能の説明・現行運用の事実 | 「〜は〜である」「〜が可能である」等の客観的記述 |
| 議論の内容 | `discussions` | 誰が何を発言し、どのようなやり取りがあったか | 「W2より〜と説明した」「日世様より〜との回答があった」等。発言者を明記 |
| 懸念点 | `concerns` | 未解決の課題・リスク・後続で確認が必要な事項 | 「〜が未確定である」「〜の可能性がある」等 |
| 結論・合意事項 | `conclusions` | この議題で合意された内容・決定事項 | 「〜とする」「〜で進める」「〜は日世様側で確認する」等 |

### 記述の粒度

- `background`: 自由テキスト（1段落〜3段落）
- `specifications`: 箇条書き配列。各項目は1文〜2文
- `discussions`: 箇条書き配列。発言者を「W2より」「日世様より」等で明記
- `concerns`: 箇条書き配列。未解決・リスクのみ記載（解決済みは conclusions へ）
- `conclusions`: 箇条書き配列。合意・決定のみ記載（議論過程は discussions へ）

## actionItems

アクションまとめ。組織別・期限付きで管理する。

```json
[
  {
    "id": 1,
    "label": "W2対応",
    "assignee": "W2",
    "deadline": "次回まで",
    "content": "今回ヒアリングした内容をもとに、業務フロー/利用機能資料を更新する",
    "relatedAgendaId": 1
  },
  {
    "id": 2,
    "label": "日世対応",
    "assignee": "日世様",
    "deadline": "次回まで",
    "content": "税額端数処理の方式を請求書発行部門に確認する",
    "relatedAgendaId": 3
  }
]
```

## nextMeeting

```json
{
  "date": "来週火曜日",
  "plannedAgendas": ["Excel利用機能一覧の確認", "800円配送料対応の説明"],
  "preparations": [
    {
      "task": "Excel利用機能一覧の黄色箇所確認",
      "assignee": "日世様"
    }
  ]
}
```

## v1.0 からの変更点

| 項目 | v1.0 | v2.0 |
|------|------|------|
| 議題内の分類 | summary + discussions + confirmations | background + specifications + discussions + concerns + conclusions |
| decisions | トップレベルに独立配列 | 各議題の conclusions に統合（トップレベル廃止） |
| actionItems | relatedAgendaId + task + assignee | label + assignee + deadline + content（人間が作成する形式に準拠） |
| version | "1.0" | "2.0" |
