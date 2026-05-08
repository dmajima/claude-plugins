---
description: 保存済み認証情報を対話メニューで参照・追加・編集・削除する設定UI
argument-hint: "[list|add|update|delete]"
---

ユーザの引数: $ARGUMENTS

`credentials-manager` プラグインの **対話的な管理 UI** を起動します。Claude Code の `/config` コマンドのように、`AskUserQuestion` を使って操作メニューを順次提示し、参照（`credentials-reader`）・書き込み（`credentials-manager`）の各スキルを必要に応じて呼び出します。

## 動作モード

| 引数 | 起動時の動作 |
|-----|------------|
| 空（メニューモード） | メニューUIを表示し、ユーザに操作を選ばせる |
| `list` | 一覧表示を直接実行（`credentials-reader` 委譲） |
| `add` | 新規追加を直接実行（`credentials-manager` の save 委譲） |
| `update` | 編集を直接実行（`credentials-manager` の update 委譲） |
| `delete` | 削除を直接実行（`credentials-manager` の delete 委譲） |
| `repair` | JSON 破損時の修復を実行（`credentials-manager` の repair 委譲） |

引数が空、または上記以外の値が渡された場合はメニューモードで起動します。

## 実行フロー

### Phase 1: 認証情報ストアパス解決と現状把握

1. 解決パスを Bash で確定（`-e` で `.git` ファイル/ディレクトリ両対応、`git` 不在環境フォールバック付き）:
   ```bash
   HOME_DIR="${HOME:-${USERPROFILE:-}}"
   REPO_ROOT=""
   if command -v git >/dev/null 2>&1; then
     REPO_ROOT="$(git -C "${PWD}" rev-parse --show-toplevel 2>/dev/null || true)"
   fi
   if [[ -z "${REPO_ROOT}" ]]; then
     # git 不在 / 非リポジトリ環境: 祖先ディレクトリを遡って .git を探す
     CUR="${PWD}"
     while [[ "${CUR}" != "/" && -n "${CUR}" ]]; do
       if [[ -e "${CUR}/.git" ]]; then  # サブモジュールの .git ファイル含めて検出
         REPO_ROOT="${CUR}"
         break
       fi
       PARENT="$(dirname "${CUR}")"
       [[ "${PARENT}" == "${CUR}" ]] && break
       CUR="${PARENT}"
     done
   fi
   if [[ -n "${REPO_ROOT}" ]]; then
     STORE="${REPO_ROOT}/.claude/.local/plugins/credentials-manager/credentials.json"
     SCOPE="project-scoped"
   else
     STORE="${HOME_DIR}/.claude/.local/plugins/credentials-manager/credentials.json"
     SCOPE="user-scoped"
   fi
   echo "store=${STORE}"
   echo "scope=${SCOPE}"
   ```
   解決ロジックは `credentials-reader` / `credentials-manager` SKILL.md 実行フロー step 1 と同一仕様（解決パスのみ Bash で得て、判定ロジックは AI が解釈する）。
2. ストアファイルの存在を確認し、存在すればエントリ件数を取得。
3. JSON パース失敗を検知した場合は **メニュー表示前に Phase 5 の repair 提案へ即座に遷移**（`AskUserQuestion` で「修復する／中止する」を確認）。

### Phase 2: メニュー表示（引数空時のみ）

`AskUserQuestion` で以下の選択肢を提示します。選択肢は最大 4 件のため、頻度の低い `repair` はメニューには出さず、Phase 1 step 3 で破損検知時に自動提案する設計とします（明示的に `/credentials-manager:manage repair` 起動でも実行可能）。

```
question: 認証情報ストアの管理操作を選択してください
header:   credentials manage
options:
  - label: "一覧表示"
    description: "保存済み認証情報を表形式で表示する（マスク値・関連ドメイン・更新日）"
  - label: "追加"
    description: "新規認証情報を保存する（識別名・値・URL/ドメイン・auth_method を対話で確認）"
  - label: "編集"
    description: "既存認証情報のフィールド（value / urls / domains / auth_method 等）を更新する"
  - label: "削除"
    description: "既存認証情報を削除する（事前にマスク値で対象を確認、引数指定でも事前確認は必須）"
multiSelect: false
```

ユーザ選択に応じて Phase 3 の対応する分岐へ遷移します。「Other」が選ばれた場合はユーザの自由入力を解釈して該当操作（`list` / `add` / `update` / `delete` / `repair`）にマッピングします。

### Phase 3: 操作の委譲

| 選択 | 委譲先 |
|-----|--------|
| 一覧表示 | `Skill(skill: "credentials-manager:credentials-reader", args: "list")` |
| 追加 | `Skill(skill: "credentials-manager:credentials-manager", args: "save")` |
| 編集 | `Skill(skill: "credentials-manager:credentials-manager", args: "update")` |
| 削除 | `Skill(skill: "credentials-manager:credentials-manager", args: "delete")` |
| 修復 | `Skill(skill: "credentials-manager:credentials-manager", args: "repair")` |

各スキル委譲時は次の補助情報を渡します（必要に応じて）:
- 解決済みストアパス（Phase 1 で取得）
- スコープ（project / user）
- 対象認証情報名（編集・削除時に既知の場合）

スキル側で不足パラメータがあれば `AskUserQuestion` で追加確認を行います。

**削除（delete）の事前確認は必須**: 引数指定（`/credentials-manager:manage delete <name>`）で対象が確定している場合でも、`credentials-manager` 側 `references/operations.md` 節 4 step 3 に従って **必ず `AskUserQuestion` で削除前確認を通すこと**。マスク値・関連ドメイン・更新日を提示した上でユーザ承諾を取得してから削除する。手動入力ミス・コマンド誤入力での意図しない削除を防ぐ二重ガードである。

### Phase 4: 完了確認とメニュー再表示

操作完了後、`AskUserQuestion` で以下を確認:

```
question: 続けて他の操作を行いますか？
header:   continue?
options:
  - label: "メニューに戻る"
    description: "別の管理操作を続けて行う"
  - label: "終了"
    description: "管理 UI を終了する"
multiSelect: false
```

「メニューに戻る」が選ばれた場合は Phase 2 へ戻り、「終了」または引数指定での直接実行モードでは制御をメインへ返します。

## 引数指定で直接実行する場合

例:

```text
/credentials-manager:manage list
/credentials-manager:manage add
/credentials-manager:manage update openai-api-key
/credentials-manager:manage delete openai-api-key
/credentials-manager:manage repair
```

引数が `<操作名>` のみであれば操作だけ確定、`<操作名> <名前>` であれば対象認証情報名まで初期値として渡します。

**delete 引数指定でも事前確認は省略しない**（誤入力ガード）: `Skill(credentials-manager, "delete <name>")` 委譲後、`credentials-manager` 側で必ず `AskUserQuestion` を通る設計です。

## 表示する情報

各操作の完了時に以下を提示:

- 操作種別（list / add / update / delete / repair）
- 対象認証情報名（マスク済み値・関連ドメイン・更新日）
- 保存先パスとスコープ
- 完了 or キャンセル

## 失敗時

| 状況 | 動作 |
|-----|------|
| ストアパス解決失敗 | `${HOME}` 不定義などのエラーをユーザに提示し、操作を中止 |
| `credentials.json` パース失敗 | 「修復が必要です」と通知し、`repair` モードへの遷移を提案（`AskUserQuestion`） |
| ユーザが `AskUserQuestion` で「終了」を選択 | フローを停止しメインへ復帰 |
| 不正な引数 | メニューモードで起動 |

## 補足

- 本コマンドは複数の操作を 1 回のセッションで連続して行うことを想定しています。
- 単発の操作（保存だけしたい・一覧だけ見たい）は、自然言語で `credentials-manager` / `credentials-reader` を直接起動する方が軽量です。
- `credentials-reader` / `credentials-manager` のスキル責務分離は、フックからの起動コンテキストを軽量化することが目的です。本コマンドは両スキルを統合的に呼び分けることで「ユーザ向けの設定 UI」体験を提供します。
