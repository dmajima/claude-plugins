# coding-python スキル

Python のコード実装・コード構造設計を、言語規約（PEP 8 / PEP 257）とプロジェクト独自規約に基づいて支援する言語スキル。`orchestrator-coding` / `orchestrator-design` からの参照と、単独起動の両方に対応する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません（スキルの動作は `SKILL.md` と `references/` 配下が定義します）。

## 使い方

### 利用モード

| モード | 起動のされ方 | 動作 |
|-------|------------|------|
| 参照モード | `orchestrator-coding` / `orchestrator-design` から呼ばれる | 規約・FW プロファイルを判定基準として提供（フェーズ制御はしない） |
| 単独実行モード | 下記トリガーフレーズでユーザが直接依頼 | 規約解決 → 実装 → 検証の軽量フローを実施 |

### トリガーフレーズ例

| 発話例 | 動作 |
|-------|------|
| 「この関数を Python で実装して」 | 単独実行モード（規約解決 → 実装 → lint / 型チェック） |
| 「Flask の API エンドポイントを追加して」 | FW プロファイルを併用して実装 |
| 「pytest のテストを追加して」 | ツールチェーンに沿ってテスト実装・実行 |

## 対応フレームワーク

### Python Web フレームワーク

| フレームワーク | プロファイル | 主な検出マーカー |
|--------------|-------------|----------------|
| Flask | `references/frameworks/python-web.md` | 依存定義の `flask` |
| Django | `references/frameworks/python-web.md` | 依存定義の `django` |
| FastAPI | `references/frameworks/python-web.md` | 依存定義の `fastapi` |

### ORM

SQLAlchemy 等の横断知識はプラグイン SSOT `../../references/frameworks/orm.md` を参照する。

## カスタマイズ

| やりたいこと | 方法 |
|-------------|------|
| Python の規約・ツールチェーンを調整 | `references/conventions.md` を編集 |
| Web FW 固有の規約を調整 | `references/frameworks/python-web.md` を編集 |
| 新しい言語への対応 | プラグイン SSOT `../../references/language-skill-template.md` に従い言語スキルを追加 |

## ファイル構成

```text
skills/coding-python/
├── SKILL.md                        # スキル定義（Claude が実行時に参照）
├── README.md                       # 本ファイル（人間向け）
└── references/
    ├── conventions.md              # Python 言語規約（PEP 8 / ツールチェーン / 典型エラー）
    └── frameworks/
        └── python-web.md           # Flask / Django / FastAPI
```

言語検出・規約解決・ORM 横断知識・設計原則・成果物テンプレートはプラグイン直下 `references/`（SSOT）を参照する。
