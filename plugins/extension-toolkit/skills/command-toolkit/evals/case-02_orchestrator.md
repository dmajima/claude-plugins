# Case 02: オーケストレータ型コマンド作成

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`/extension` コマンドを作成。skill-toolkit / plugin-toolkit / agent-toolkit にルーティング" |
| 引数 | `extension --routes "skill:skill-toolkit,plugin:plugin-toolkit,agent:agent-toolkit"` |
| フラグ | なし |
| 既存状態 | 未存在 |

## 期待動作

### Phase 1: パラメータ確認

ルーティング情報が引数に含まれるため、ルーティング表テンプレートを使う。

### Phase 2: テンプレート展開 + ルーティング表充填

`templates/command/command.md` の `## ルーティング` セクションに引数情報を反映。

### Phase 3: 検証

- ルーティング表に列挙されたスキルが存在するか確認
- フォールバック動作が定義されているか確認

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | ルーティング表を含む `extension.md` |
| 標準出力 | 「`/extension` オーケストレータ作成」+ 各ルーティング先の確認 |
| 終了状態 | 成功 |

## 分岐の根拠

`--routes` 引数の有無 である。
