# meeting-minutes

会議の文字起こし・録画データから構造化議事録を作成し、Markdown / docx（Word）出力するプラグイン。

## このドキュメントについて

このファイルは人間向けリファレンスであり、Claude の動作では使用されない。

## 導入手順

### マーケットプレイス経由（推奨）

```text
/plugin marketplace add https://github.com/dmajima/claude-plugins
/plugin install meeting-minutes@dmajima-claude-plugins
```

### ローカル複製

```bash
git clone https://github.com/dmajima/claude-plugins <local-path>
/plugin marketplace add <local-path>
/plugin install meeting-minutes@dmajima-claude-plugins
```

### 自動更新の有効化

`~/.claude/settings.json` に以下を追加:

```json
{
  "extraKnownMarketplaces": {
    "dmajima-claude-plugins": {
      "source": { "type": "github", "repo": "dmajima/claude-plugins" },
      "autoUpdate": true
    }
  }
}
```

### 依存関係

外部プラグインへの依存はない。

| 外部ツール | 用途 | 必須 |
|-----------|------|------|
| Python 3.9+ | スクリプト実行 | 必須 |
| ffmpeg | HLS 動画ダウンロード | 任意 |

## 使い方

### ailead 共有リンクから議事録を作成

```
ailead の共有リンクから議事録を作成してください。
https://dashboard.ailead.app/share/...
```

処理フロー: `ailead-fetcher` → `minutes-composer` → `minutes-reviewer` → `minutes-md` or `minutes-docx`

### VTT / SRT / テキストファイルから議事録を作成

```
この文字起こしから議事録を作成してください。
（VTT ファイル / SRT ファイル / テキストを貼り付け or パスを指定）
```

処理フロー: `transcript-converter` → `minutes-composer` → `minutes-reviewer` → `minutes-md` or `minutes-docx`

### 出力形式を指定して作成

```
/meeting-minutes:minutes-md     → Markdown 出力
/meeting-minutes:minutes-docx   → Word 出力
```

## 対応入力形式

| 形式 | 説明 |
|------|------|
| ailead 共有リンク | GraphQL API 経由で文字起こし・要約・参加者を自動取得 |
| WebVTT (.vtt) | Teams 等の文字起こしエクスポート（発話者タグ対応） |
| SRT (.srt) | 汎用字幕ファイル |
| Teams コピペ | Teams の文字起こしパネルからのコピーペースト |
| プレーンテキスト | 任意のテキスト（発話者・タイムスタンプは推定） |

## 出力ファイル

### 最終成果物（セッション直下）

| ファイル | 説明 |
|---------|------|
| `minutes.md` | 完成した議事録 Markdown ファイル |
| `minutes.docx` | 完成した議事録 Word ファイル |

### 中間成果物（workspace/）

| ファイル | 説明 |
|---------|------|
| `workspace/minutes.json` | 構造化議事録データ（中間形式） |
| `workspace/transcript.txt` | 標準形式の文字起こし全文 |
| `workspace/metadata.json` | 会議メタデータ |
| `workspace/response.json` | ailead GraphQL レスポンス（ailead ソースのみ） |
| `workspace/summary.md` | AI 会議要約（ailead ソースのみ） |
| `workspace/verification-log.md` | 突合検証ログ |
| `workspace/review-result.json` | 検証結果データ |

## スキル構成

| スキル | 責務 |
|-------|------|
| `minutes-composer` | 文字起こしから構造化議事録データ（JSON）を作成 |
| `ailead-fetcher` | ailead 外部共有リンクからデータを取得 |
| `transcript-converter` | VTT / SRT / テキストを標準形式に変換 |
| `minutes-md` | 構造化データを Markdown に変換 |
| `minutes-docx` | 構造化データを docx（Word）に変換 |
| `minutes-reviewer` | 議事録と文字起こしの突合検証（フレッシュ起動） |

## コマンド

| コマンド | 説明 |
|---------|------|
| `/meeting-minutes:minutes-md` | 議事録をフルパイプラインで作成し Markdown 出力 |
| `/meeting-minutes:minutes-docx` | 議事録をフルパイプラインで作成し Word 出力 |

## 技術スタック

| パッケージ | 用途 |
|-----------|------|
| `requests` | ailead API アクセス |
| `python-docx` | Word ファイル生成 |

## ライセンス

[MIT License](LICENSE) の下で配布されています。
