# connector references/

Claude エージェントが connector プラグインで外部サービス操作を行う際に従う原則とナビゲーション。

## 目的と範囲

このディレクトリは connector プラグイン横断の **SSOT（唯一の情報源）** を集約する。認証事前確認・API アクセス安全原則・委譲/サブエージェントプロトコル・投稿署名・レンダリングルール・共通スクリプトを含む。スキル固有の手順・API 仕様は各 `skills/{skill}/references/` 配下にある。

## 原則

1. **SSOT 優先**: 本ディレクトリの各ファイルが正典。スキル側ドキュメントは SSOT を参照し、重複記述しない
2. **API を呼ぶ前に認証事前確認**: 全スキルは [credentials-precheck.md](credentials-precheck.md) セクション 1 の解決順序を必ず通る（credentials-manager はオプション。不在時は対話取得フォールバック / サブエージェント時はエラーマニフェスト）
3. **安全原則の全適用**: 外部 API アクセスは [safe-api-access.md](safe-api-access.md)（ホワイトリスト・シークレット取り扱い・HTTP エラー分岐・書き込みゲート・外部由来テキスト境界）に必ず従う
4. **呼び出し方式の使い分け**: write 委譲 = `Skill()`（[delegation-interface.md](delegation-interface.md)）/ 後続フローのある read = `Agent()`（[subagent-protocol.md](subagent-protocol.md)）
5. **スクリプトは `scripts/` に集約**: プラグイン共通の実行可能ファイルは `references/scripts/` 配下にのみ配置（ADR-025）。venv はプラグイン単位で 1 つ（ADR-024）
6. **README.md 参照禁止**: `README.md` は人間向け資料であり、エージェント動作で参照してはならない

## ナビゲーション

| タスク | 最初に読む | 次に読む |
|-------|----------|---------|
| **認証情報を確認・取得する** | [credentials-precheck.md](credentials-precheck.md) | `scripts/credentials/`（照合・保存の実装） |
| **外部 API を呼び出す** | [safe-api-access.md](safe-api-access.md) | 各スキルの `references/api-*.md` |
| **他プラグインへ write 操作を提供する** | [delegation-interface.md](delegation-interface.md) | 各スキル SKILL.md の委譲操作テーブル |
| **他プラグインへ read 操作を提供する** | [subagent-protocol.md](subagent-protocol.md) | セクション 5 の操作別パラメータ |
| **投稿本文を組み立てる** | [signatures.md](signatures.md) | `rendering/` の対象サービス別ルール |
| **Python スクリプトを実行する** | `scripts/setup/`（venv 構築） | `scripts/run_via_job.sh`（PowerShell ツール経由時） |

## ディレクトリ構成

| パス | 種別 | 参照タイミング |
|------|------|-------------|
| `credentials-precheck.md` | 認証解決の SSOT | 全スキルの Step 1（API 呼び出し前に必ず） |
| `safe-api-access.md` | 安全原則の SSOT | 外部 API を呼ぶすべての操作 |
| `delegation-interface.md` / `subagent-protocol.md` | 呼び出しプロトコルの SSOT | 他プラグインとの連携時 |
| `signatures.md` | 投稿署名の SSOT | 書き込み操作時 |
| `rendering/` | レンダリングルール | render-check 実行時 |
| `scripts/` | プラグイン共通スクリプト | venv 構築・認証照合/保存・PowerShell 経由の Python 起動 |
