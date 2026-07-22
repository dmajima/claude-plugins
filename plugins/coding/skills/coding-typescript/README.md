# coding-typescript スキル

TypeScript（`.ts` / `.tsx`）のデファクト規約・コード構造・型安全のベストプラクティス・フレームワーク知識を提供する言語スキル。JavaScript 規約を継承し、TypeScript 固有の型規約を追加する。オーケストレーターからの規約・構造の判定基準として、また単独起動時の軽量実装フロー（規約解決 → 実装 → 検証）として動作する。

## このドキュメントについて

本 README は **人間向けのリファレンス** であり、Claude のスキル動作では参照されない。Claude が実行時に読み込むのは `SKILL.md` および `references/` 配下のファイルである。スキルの利用者・開発者向けに、利用方法・対応範囲・カスタマイズ手順をまとめる。

## 導入手順

本スキルは `coding` プラグインに同梱されています。プラグイン本体の導入手順（マーケットプレイス登録・インストール・自動更新）は [プラグイン README](../../README.md) を参照してください。本スキル単体での追加インストールは不要です。

導入後は `orchestrator-coding` / `orchestrator-design` から自動的に参照されるほか、下記「使い方」のトリガーフレーズでユーザが直接起動できます。

## 使い方

2 通りの利用モードがある。

- **オーケストレーターからの参照モード**: `orchestrator-coding` / `orchestrator-design` が、TypeScript プロジェクトの規約・コード構造の判定基準として本スキルの `references/conventions.md` と SSOT フレームワークプロファイルを参照する。フェーズ制御はオーケストレーター側が行う。
- **単独起動モード**: ユーザが直接依頼したときに、軽量実装フローを実施する。トリガーフレーズ例:
  - 「TypeScript で〜を実装して」「この TS の型エラーを直して」
  - 「React コンポーネントを書いて」「NestJS のサービスを追加して」

`tsconfig.json` の無い JavaScript のみのプロジェクトは `coding-javascript` が担当する。

## 対応フレームワーク

FW プロファイルは複数言語（JS / TS 等）で共有するため、スキル内ではなく SSOT の `../../references/frameworks/` に配置している。

| フレームワーク | プロファイル（SSOT） |
|--------------|---------------------|
| Express / NestJS | `../../references/frameworks/node.md` |
| React / Next.js | `../../references/frameworks/react.md` |
| Vue / Nuxt | `../../references/frameworks/vue.md` |
| Vite / Tailwind / Vitest / Jest / Playwright | `../../references/frameworks/frontend-tooling.md` |
| Prisma（ORM） | `../../references/frameworks/orm.md` |

## カスタマイズ

- 言語規約（型規約・命名・イディオム・典型エラー）を変更する場合は `references/conventions.md` を編集する（本スキルの SSOT）。JavaScript から継承する規約は `coding-javascript` 側の `conventions.md` を編集する。
- フレームワーク固有の規約は言語横断のため、SSOT `../../references/frameworks/` 側を編集する（本スキル内には置かない）。
- 規約の優先順位ルールは SSOT `../../references/conventions-resolution.md` が管理し、本スキルからは変更しない。

## ファイル構成

```text
skills/coding-typescript/
├── SKILL.md                 # スキル定義（Claude が実行時に読み込む）
├── README.md                # 人間向けリファレンス（Claude 動作では不参照）
└── references/
    └── conventions.md       # TypeScript 言語規約（本スキルの SSOT）
```
