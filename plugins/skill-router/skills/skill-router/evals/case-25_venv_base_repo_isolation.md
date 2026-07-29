# case-25 venv base repo isolation

リポジトリ配下に `.venv` が同梱されていても、フックがそのインタプリタを実行しないことを確認する負例。clone したリポジトリを開くだけで任意コードが実行される経路を塞ぐ境界の検証。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "clone したリポジトリで skill-router が意図しない python を使っていないか確認したい" |
| 既存状態 | リポジトリ直下に `.claude/.local/plugins/skill-router/.venv/Scripts/python.exe`（または `bin/python`）が存在する / `${CLAUDE_PLUGIN_DATA}` は未設定 / `<venv-base>`（ホーム配下）には venv が無い |
| モード | 自動（フック発火）・負例 |

## トリガープロンプト

```text
clone したリポジトリで skill-router が意図しない python を使っていないか確認したい
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | `UserPromptSubmit` フックが `resolve_base.sh` の `skill_router_venv_python` でインタプリタを選択する |
| 2 | 探索先は `skill_router_venv_base`（`${CLAUDE_PLUGIN_DATA}` → ホーム配下）のみで、リポジトリ配下は候補に含まれない |
| 3 | ホーム配下に venv が無いため、選択結果は空になる |
| 4 | フックはシステム Python（`python3` / `python`）で `route.py` を実行する |
| 5 | SessionStart 側も `venv_lifecycle.resolve_venv_base()` で同じ境界を用い、リポジトリ配下の `.venv` を参照・撤去・実行のいずれも行わない |

## 期待出力

| ケース | 提示内容 |
|-------|---------|
| リポジトリ同梱 venv がある | 「リポジトリ配下の `.venv` は探索対象外です。フックはシステム Python で動作しており、同梱されたインタプリタは実行されません」 |
| ホーム配下に venv がある | 「`<venv-base>` の venv が使われます。リポジトリ配下の `.venv` は無関係で、参照されません」 |
| `pyvenv.cfg` が無い | 「`python` 実行ファイルだけが置かれた状態は venv とみなしません（`pyvenv.cfg` の同伴を要求します）。システム Python にフォールバックします」 |
| 候補がシンボリックリンク | 「リンクは辿って実行可能性を確認したうえで採用します（POSIX の venv は `bin/python` をシステム python への symlink として作るため）。境界はパスの所在で担保し、リンク種別では判定しません」 |
| リンク切れ | 「`readlink` 先が存在しないか実行不可の場合は採用せず、システム Python にフォールバックします」 |
| 副作用 | リポジトリ配下の `.venv` に対する読み取り・実行・削除をいずれも行わない |

## 分岐の根拠

`references/scripts/routing/venv_lifecycle.py` の `resolve_venv_base()` と `references/scripts/commands/resolve_base.sh` の `skill_router_venv_base` は、いずれもリポジトリ相対の階層を持たない。データ用の `<base>`（`resolve_base_dir()` / `skill_router_base`）はリポジトリ配下に解決されうるため、両者を同一視すると境界が消える。

`skill_router_venv_python` は候補に対し `pyvenv.cfg` の同伴を要求し、実行ファイルだけを置いた残骸や偽装を排除する。シンボリックリンクは POSIX の venv で正常な形態のため拒否せず、辿った先が実行可能であることのみ確認する。境界は「候補パスが `<venv-base>` 配下に固定されていること」で担保する。

## 関連ケース

- `case-24_diag_prompt_hook_timeout` — `<base>` と `<venv-base>` の解決順の違い
- `case-13_embedding_disabled` — 既定では venv 自体が構築されないこと
- `case-10_fail_open` — インタプリタ選択に失敗した場合もプロンプトを妨げないこと

## 備考

- 同義表現として「リポジトリの .venv が使われていないか」「clone した .venv を実行してしまわないか」等もカバーする
- `${CLAUDE_PLUGIN_DATA}` が設定されている環境では、そのディレクトリが `<venv-base>` になる。この場合もリポジトリ配下は候補に含まれない
- 単体テストでは Bash 側を `test_resolve_base.py` の `test_repository_venv_is_never_selected`、Python 側を `test_venv_lifecycle.py` の `test_falls_back_to_home_not_repository` が検証している
