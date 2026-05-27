# meeting-minutes

会議の文字起こし・録画データから構造化議事録を作成し、docx（Word）出力するプラグイン。

## スキル構成

| スキル | 責務 | 状態 |
|-------|------|------|
| `minutes-composer` | 文字起こしから構造化議事録データ（JSON）を作成 | 実装済み |
| `ailead-fetcher` | ailead 外部共有リンクからデータを取得 | 実装済み |
| `transcript-converter` | VTT / SRT / テキストを標準形式に変換 | 実装済み |
| `minutes-docx` | 構造化データを docx（Word）に変換 | 実装済み |
| `minutes-reviewer` | 議事録と文字起こしの突合検証（フレッシュ起動） | 実装済み |

## 使い方

### ailead 共有リンクから議事録を作成

```
ailead の共有リンクから議事録を作成してください。
https://dashboard.ailead.app/share/...
```

処理フロー: `ailead-fetcher` → `minutes-composer` → `minutes-reviewer` → `minutes-docx`

### VTT / SRT / テキストファイルから議事録を作成

```
この文字起こしから議事録を作成してください。
（VTT ファイル / SRT ファイル / テキストを貼り付け or パスを指定）
```

処理フロー: `transcript-converter` → `minutes-composer` → `minutes-reviewer` → `minutes-docx`

## 対応入力形式

| 形式 | 説明 |
|------|------|
| ailead 共有リンク | GraphQL API 経由で文字起こし・要約・参加者を自動取得 |
| WebVTT (.vtt) | Teams 等の文字起こしエクスポート（発話者タグ対応） |
| SRT (.srt) | 汎用字幕ファイル |
| Teams コピペ | Teams の文字起こしパネルからのコピーペースト |
| プレーンテキスト | 任意のテキスト（発話者・タイムスタンプは推定） |

## 出力ファイル

| ファイル | 説明 |
|---------|------|
| `minutes.json` | 構造化議事録データ（中間形式） |
| `minutes.docx` | 完成した議事録 Word ファイル |
| `transcript.txt` | 標準形式の文字起こし全文 |
| `metadata.json` | 会議メタデータ |
| `workspace/verification-log.md` | 突合検証ログ |

## 依存パッケージ

| パッケージ | 用途 |
|-----------|------|
| `requests` | ailead API アクセス |
| `python-docx` | Word ファイル生成 |

## ライセンス

[MIT License](LICENSE) の下で配布されています。
