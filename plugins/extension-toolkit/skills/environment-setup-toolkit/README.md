# environment-setup-toolkit (skill)

Claude Code のスキル / プラグインが利用する Python 仮想環境（venv）と依存パッケージを構築・撤去するスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 導入手順

`extension-toolkit` プラグインに同梱されています。プラグイン導入後、自然言語または `/extension` 経由で起動可能です。

```text
/plugin install extension-toolkit@dmajima-claude-plugins
```

## 利用方法

### 自然言語起動

| 発話 | 動作 |
|-----|------|
| 「venv 作って」 | 作業ディレクトリに venv 構築 |
| 「Python 環境セットアップ」 | 同上 |
| 「環境を片付けて」「venv 削除」 | venv 撤去 |
| 「依存パッケージをインストール」 | venv へ requirements.txt 反映 |

### 最小例

ユーザ:
> Python venv をこのタスク用に作って

Claude（要約）:
> `.claude/.local/work/{yyyyMMdd_nn_summary}/workspace/.venv` に venv を作成。
> pip 最新化、`requirements.txt` の依存をインストール。

## 動作要件

- Python 3.10 以上を推奨
- 作業ディレクトリ書き込み権限

## 関連スキル

| スキル | 関係 |
|-------|------|
| `skill-toolkit` | Python 利用スキル作成時、本スキルへの参照を生成スキルに含める |
| `plugin-toolkit` | プラグイン全体の環境構築をオーケストレーションする際に呼び出される |

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `SKILL.md` | スキル定義とトリガー条件 |
| `references/procedures.md` | setup / teardown / refresh / check の詳細手順 |
| `references/python-venv.md` | Python venv の構造・互換性 |
| `scripts/setup/setup_venv.sh` | venv 構築スクリプト |
| `scripts/setup/teardown_venv.sh` | venv 撤去スクリプト |

## 技術スタック・アーキテクチャ

### 採用技術

- Python 標準 venv モジュール
- pip
- Bash スクリプト（クロスプラットフォーム: Windows `Scripts/` / Unix `bin/`）

### 配置原則

- venv は **必ずセッション作業領域**（`.claude/.local/work/{yyyyMMdd_nn_summary}/workspace/.venv`）に作成
- スキル / プラグインのソース内には venv を作らない
- venv 構築・撤去は本スキルが責務単一として担当（各スキルは依存リストのみ保有）
