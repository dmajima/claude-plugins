# case-08 toggle on

skill-router スキルが `skill-router を再有効化して` 系の依頼に対し、`/router-toggle on` を案内する正例。case-03 の裏返しケース。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "skill-router を再有効化して" |
| 既存状態 | `<base>/disabled` フラグが少なくとも 1 つの解決階層に存在（OFF 状態） |
| モード | 対話 |

## トリガープロンプト

```text
skill-router を再有効化して
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | skill-router スキルが起動する（high 帯） |
| 2 | `/router-toggle on` を案内、または直接実行 |
| 3 | 3 階層すべて（`${CLAUDE_PLUGIN_DATA}` / `<repo>` / `${HOME}`）の `disabled` ファイルを順次削除 |
| 4 | 削除したパスを集計しユーザに提示 |
| 5 | 「次回 UserPromptSubmit から有効化されます」を補足 |

## 期待出力

| 出力 | 内容 |
|-----|------|
| 標準出力 | `skill-router: removed disabled flag at <path>` を削除した階層分（0 階層なら空）+ 最終的に `skill-router toggled ON` |
| 副作用 | 全階層の `disabled` ファイル削除（存在した分のみ） |
| べき等動作 | 既に ON 状態（`disabled` 不在）でも何もエラーにならず ON を維持 |

## 分岐の根拠

設計書 v2 セクション 7「`/router-toggle on|off`」とセクション 4.4「base 解決順位」。`route_prompt.sh` は 3 階層を OR 条件で参照するため、再有効化時には全階層を順次削除する必要がある（`/router-toggle off` で `${CLAUDE_PLUGIN_DATA}` に作られたフラグを `${HOME}` 階層の確認だけでは消せない）。

## 関連ケース

- `case-03_disable` — 無効化（`/router-toggle off`）正例（裏返し関係）
- `case-02_status` — トグル状態確認

## 備考

- 同義表現として「ルーティングを戻して」「router を ON にして」「skill-router 復活させて」等もカバー
- べき等性の検証: 同じ `on` を複数回実行してもエラーにならない
- 永続的に無効化したい場合は `enabledPlugins` から外すことを案内するのも親切
