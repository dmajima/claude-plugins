# transcript-converter

汎用の文字起こしテキスト・ファイル（VTT / SRT / Teams コピペ / プレーンテキスト等）をプラグイン共通の標準構造に変換するスキル。

## このドキュメントについて

本ファイルは人間向けリファレンスであり、Claude の動作では使用されない。

## 使い方

文字起こしテキストを直接貼り付けるか、VTT/SRT ファイルのパスを提示して議事録作成を依頼する。

```
この文字起こしから議事録を作って
（テキスト貼り付け）
```

```
C:\path\to\meeting.vtt から議事録を作成して
```

## 対応入力形式

| 形式 | 拡張子 / パターン | 自動判定 |
|------|-----------------|---------|
| WebVTT | `.vtt` | Yes |
| SRT | `.srt` | Yes |
| Teams コピペ | `名前 HH:MM` + 発言行 | Yes |
| ailead transcript.txt | `[HH:MM:SS - HH:MM:SS] 名前: テキスト` | Yes |
| プレーンテキスト | `.txt` / 直接入力 | Fallback |

出力は connector:ailead と同一形式（transcript.txt + metadata.json）に正規化される。

## ファイル構成

```
transcript-converter/
├── SKILL.md
├── README.md
├── references/
│   ├── procedures.md          # 変換手順
│   └── format-detection.md    # 形式判定ロジック
└── scripts/
    └── convert/
        └── convert_transcript.py  # 変換スクリプト
```
