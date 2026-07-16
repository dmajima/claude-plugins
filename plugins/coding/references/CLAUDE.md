# coding references/

Claude エージェントが coding プラグインで実装・設計業務を行う際に従う原則とナビゲーション。

## 目的と範囲

このディレクトリは coding プラグイン横断の **SSOT（唯一の情報源）** を集約する。設計原則（設計観点・リスクヘッジ・データフロー）・規約優先順位の解決・言語検出・言語スキル対応表・言語横断フレームワークプロファイル・成果物テンプレートを含む。言語固有の規約・コード構造は各言語スキル `skills/coding-{lang}/references/` が、ワークフロー固有の手順は各オーケストレーターの `references/` が保有する。

## 原則

1. **SSOT 優先**: 言語横断の原則（設計・規約解決・検出・テンプレート）は本ディレクトリが正典。オーケストレーター・言語スキル・エージェントプロンプトに重複記述しない
2. **言語知識は言語スキルへ**: 言語・FW 固有の規約・コード構造・ツールチェーンは `skills/coding-{lang}/references/` が正典（[skill-index.md](skill-index.md) で対応を管理）。ただし複数言語で共有する FW（React / Vue / Node / ORM 等）は本ディレクトリの [frameworks/](frameworks/) に置く
3. **デファクトはデフォルト**: 言語スキルの規約は「プロジェクト独自規約が存在しない場合のデフォルト」。優先順位の解決は [conventions-resolution.md](conventions-resolution.md) に必ず従う（プロジェクト独自規約 > デファクト）
4. **検出してから適用**: 言語スキル・FW プロファイルの適用は [skill-index.md](skill-index.md) の検出マーカーに基づく。検出されなかった言語の知識を適用しない
5. **未対応言語は明示**: [skill-index.md](skill-index.md) に無い言語では、言語スキル不在をユーザに明示する（推測規約で黙って進めない）
6. **言語スキル追加は template 準拠**: 新しい言語・FW の追加は [language-skill-template.md](language-skill-template.md) の構成を完全踏襲する
7. **README.md 参照禁止**: `README.md` は人間向け資料であり、エージェント動作で参照してはならない

## ナビゲーション

| タスク | 最初に読む | 次に読む |
|-------|----------|---------|
| **対象プロジェクトの言語・FW を検出する** | [language-detection.md](language-detection.md) | [skill-index.md](skill-index.md) |
| **適用する規約を決定する** | [conventions-resolution.md](conventions-resolution.md) | 該当言語スキルの `references/conventions.md` |
| **設計する（観点・リスク・データフロー）** | [design-principles.md](design-principles.md) | 該当言語スキルの references（コード構造） |
| **言語横断 FW の規約を知る** | [skill-index.md](skill-index.md) 節 2 | [frameworks/](frameworks/) の該当ファイル |
| **成果物を作成する** | 各オーケストレーターの workflow.md | [template/](template/) の該当テンプレート |
| **新しい言語・FW を追加する** | [language-skill-template.md](language-skill-template.md) | [skill-index.md](skill-index.md)（登録） |

## ディレクトリ構成

| パス | 種別 | 参照タイミング |
|------|------|-------------|
| [design-principles.md](design-principles.md) | 設計観点・リスクヘッジ・データフローの SSOT | Design フェーズ（両オーケストレーター） |
| [conventions-resolution.md](conventions-resolution.md) | 規約優先順位解決の SSOT | Analyze フェーズ・言語スキル単独実行時 |
| [language-detection.md](language-detection.md) | 言語・FW 検出手順の SSOT | Analyze フェーズの冒頭 |
| [skill-index.md](skill-index.md) | 検出マーカー → 言語スキル対応の SSOT | 言語検出時・言語スキル追加時 |
| [frameworks/](frameworks/) | 言語横断 FW プロファイル（React / Vue / Node / frontend-tooling / ORM） | 該当 FW 検出時に言語スキルと併用 |
| [template/](template/) | 成果物テンプレート（計画・分析・設計・実装・レビュー・報告） | 各フェーズの成果物作成時 |
| [language-skill-template.md](language-skill-template.md) | 言語スキル追加ガイド | 言語スキル新規追加時 |
