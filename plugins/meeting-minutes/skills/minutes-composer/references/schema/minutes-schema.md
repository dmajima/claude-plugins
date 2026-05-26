# 議事録構造データ JSON スキーマ

minutes-composer が出力する `minutes.json` の構造定義。

## トップレベル

```json
{
  "version": "1.0",
  "metadata": { ... },
  "agendas": [ ... ],
  "decisions": [ ... ],
  "actionItems": [ ... ],
  "nextMeeting": { ... },
  "notes": "string | null"
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
  "location": "オンライン（Microsoft Teams）",
  "participants": [
    {
      "name": "眞嶋大介",
      "organization": "W2",
      "role": "host",
      "talkRatio": 0.5787
    }
  ],
  "source": "ailead | teams | manual",
  "sourceUrl": "https://dashboard.ailead.app/share/...",
  "recordingSystem": "TEAMS",
  "createdBy": "AI（ailead + Claude）"
}
```

## agendas

```json
[
  {
    "id": 1,
    "title": "議題タイトル",
    "category": "SHARE | DISCUSSION | DECISION | CONCERN | SUGGESTION | DIALOGUE | SCHEDULE",
    "timeSeconds": 85,
    "summary": "議題の要約（1〜2文）",
    "discussions": [
      {
        "point": "論点の説明",
        "details": ["補足1", "補足2"],
        "speaker": "発言者名（特定できる場合）"
      }
    ],
    "confirmations": ["確認された事実1", "確認された事実2"]
  }
]
```

## decisions

```json
[
  {
    "id": 1,
    "content": "決定内容",
    "relatedAgendaId": 3,
    "conditions": "条件・例外（ある場合）",
    "decidedBy": "決定者/合意者"
  }
]
```

## actionItems

```json
[
  {
    "id": 1,
    "task": "タスク内容",
    "assignee": "担当者名",
    "organization": "所属",
    "deadline": "次回まで | 2026-06-02 | 要件定義期間中",
    "relatedAgendaId": 3
  }
]
```

## nextMeeting

```json
{
  "date": "来週火曜日",
  "plannedAgendas": ["議題1", "議題2"],
  "preparations": [
    {
      "task": "準備内容",
      "assignee": "担当者/組織"
    }
  ]
}
```

## フィールド説明

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `version` | Yes | スキーマバージョン（現在 "1.0"） |
| `metadata.source` | Yes | データソース識別子 |
| `metadata.participants[].role` | No | "host" or null |
| `metadata.participants[].talkRatio` | No | 発言割合（0.0〜1.0、ailead ソース時のみ） |
| `agendas[].category` | No | ailead トピックのカテゴリ（汎用ソース時は null） |
| `agendas[].timeSeconds` | No | 議題の開始秒数（タイムスタンプ情報がある場合） |
| `decisions[].conditions` | No | 条件付き決定の条件 |
| `actionItems[].deadline` | No | 期限（会議中に言及された場合のみ） |
| `nextMeeting` | No | 次回予定（言及された場合のみ） |
| `notes` | No | 補足事項 |
