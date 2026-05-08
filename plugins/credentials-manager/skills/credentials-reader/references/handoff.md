# credentials-manager への引き継ぎ仕様

`credentials-reader` スキルが書き込み（追加・編集・削除）を必要と判断した際に、`credentials-manager` スキルへ引き継ぐためのプロトコル。SKILL.md 実行フロー step 7 から参照される。

## 1. 引き継ぎが発生するケース

| ケース | 起点 | 引き継ぎの理由 |
|-------|------|--------------|
| 0 件マッチ後の保存承諾 | auto-match step 4 | `credentials.json` への新規エントリ追加 |
| プロアクティブ検出後の保存承諾 | proactive-detect step 6 | 同上 |
| ユーザが明示的に「保存して／編集して／削除して」と要求 | 直接判定 | 書き込みは reader 責務外 |
| `credentials.json` 破損検知（JSON パース失敗） | retrieve / list 中 | バックアップ + 再初期化は manager 責務 |
| `/credentials-manager:manage` コマンド呼び出し | コマンド経由 | コマンド本体が manager を起動するため reader は静観 |

## 2. 引き継ぎ時の渡し方

### 2.1 起動方法（**必須**）

メイン Claude は **必ず Skill ツール経由で `credentials-manager` を起動する**（自然言語案内のみで完結させない）。引き継ぎは以下の引数フォーマットで行う。

```
Skill(skill: "credentials-manager:credentials-manager", args: "save name:openai-api-key domain:api.openai.com auth_method:header:Authorization:Bearer")
Skill(skill: "credentials-manager:credentials-manager", args: "update name:openai-api-key field:value")
Skill(skill: "credentials-manager:credentials-manager", args: "delete name:openai-api-key")
Skill(skill: "credentials-manager:credentials-manager", args: "repair")
```

`value` フィールドは **引数に含めない**。`credentials-manager` 側で `AskUserQuestion` を使ってユーザにフル値を再入力させる。reader が文脈から推定したマスク済み値（例: `sk-p****f456`）は確認表示用にのみ使用する。

### 2.2 同時のユーザ案内（推奨・併用）

Skill 起動と **併せて** 以下のような案内を行うとユーザの混乱を防げる。Skill 起動の代替ではなく、Skill 起動と同時に提示する。

```
[credentials-reader] '<masked>' を credentials-manager に引き継いで保存します。
（または「/credentials-manager:manage」で対話メニュー UI から管理できます。）
```

## 3. 引き継ぎ時の情報

引き継ぎ時に渡してよい情報・渡してはならない情報を分ける。

| 種別 | 渡してよいか | 備考 |
|-----|----------|------|
| 認証情報名（候補） | ○ | 文脈から推定したものを提案する |
| マスク済み値 | ○ | 例: `sk-p****f456` |
| 関連 URL / ドメイン | ○ | 文脈から抽出したもの |
| 種別推定（`api_key` / `token` 等） | ○ | パターンから推定 |
| **フル値** | ✕ | メインコンテキストおよび引き継ぎログに残さない。`credentials-manager` 側がユーザの再入力 or 既存ストア参照で取得する |

## 4. 0 件マッチ後の保存承諾フロー

```
1. reader: 「<domain> 用の認証情報は保存されていません。提供しますか？」
2. user: 「はい」
3. reader: 「では credentials-manager に引き継いで保存します。」（自然言語案内）
4. main → Skill(credentials-manager:credentials-manager, "save name:<候補> domain:<抽出>")  ← **必須**
5. credentials-manager: 認証情報の値（フル値）を AskUserQuestion でユーザに再入力させ保存
6. main: 保存完了通知（マスク値のみ） + 元の URL アクセス処理を続行
```

## 5. プロアクティブ検出後の保存承諾フロー

```
1. reader: パターン検出（例: `ghp_xxxxxxxxxxxxxxxxxxxx`）
2. reader: マスクして通知（`ghp_****xxxx`、フル値復唱なし） + 「この認証情報を保存しますか？」
3. user: 「はい」
4. reader: 「credentials-manager に引き継ぎます」（自然言語案内）
5. main → Skill(credentials-manager:credentials-manager, "save name:<候補> domain:<推定>")  ← **必須**
6. credentials-manager: フル値を AskUserQuestion でユーザに再入力させる + 残りの未確定パラメータを確認 → 保存
7. main: 保存完了通知（マスク値のみ）
```

## 6. JSON パース失敗時の引き継ぎ

```
1. reader: 「credentials.json のパースに失敗しました。バックアップして再初期化が必要です。」
2. reader: AskUserQuestion で「修復する/中止する」を確認
3. main → Skill(credentials-manager:credentials-manager, "repair")  ← **必須**（ユーザ承諾時のみ）
4. credentials-manager: `credentials.json.bak.{timestamp}` を作成 → 空ストア再初期化
5. main: reader へ戻り元の操作を再試行
```

## 7. 引き継ぎ後の責任境界

| 項目 | 引き継ぎ前（reader） | 引き継ぎ後（manager） |
|-----|------------------|-------------------|
| ファイル読み込み | ○ | ○（再読込） |
| 認証情報の照合・自動適用 | ○ | △（書き込み確定後に再照合は不要） |
| `credentials.json` 書き込み | ✕ | ○ |
| `.gitignore` 登録の確認・警告 | △（参照時には行わない） | ○（書き込み前に必須確認） |
| マスク済み表示 | ○ | ○ |
| フル値の取り扱い | 保持しない | 保存時のみ一時保持 |

## 8. 引き継ぎを行わないケース

- 参照のみで完結する場合（retrieve / list / 自動適用が成功）
- ユーザが「保存しない」と回答した場合
- フォールバックで非対話モードで進む際の単純照合失敗（書き込みを推奨せず終了）
