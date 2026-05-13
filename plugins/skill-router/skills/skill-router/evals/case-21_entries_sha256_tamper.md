# case-21 manifest entries_sha256 tamper detection

`<base>/embeddings_cache/manifest.json` の `entries` を書き換えても `entries_sha256` を更新し忘れた攻撃シナリオで、`load_manifest()` が **自己整合性チェックで全件破棄** することを確認するエラー系。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | 任意の自然言語プロンプト（UserPromptSubmit） |
| 既存状態 | `embedding.enabled=true`、`<base>/embeddings_cache/{vectors.npz, manifest.json}` 構築済、その後 `manifest.json` の `entries` を改竄（特定スキルの `idx` を別 idx に書き換え、`entries_sha256` はそのまま）|
| モード | 自動（フック発火）|

## トリガープロンプト

```text
HTML に変換したい
```

事前準備:

```bash
# 検証用に manifest.json の entries を改竄するが entries_sha256 は元のまま
python -c "
import json, sys
from pathlib import Path
p = Path('<base>/embeddings_cache/manifest.json')
data = json.loads(p.read_text(encoding='utf-8'))
# 攻撃シナリオ: 別スキルへ誘導するため idx を入れ替え
first_key = next(iter(data['entries']))
data['entries'][first_key]['idx'] = (data['entries'][first_key]['idx'] + 1) % 100
# entries_sha256 はあえて再計算しない
p.write_text(json.dumps(data), encoding='utf-8')
"
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | `route.route()` が `embedding_enrich.load_manifest(base)` を呼ぶ |
| 2 | `load_manifest()` で manifest を JSON パース後、`entries_sha256` を取得 |
| 3 | 現在の `entries` から `_compute_entries_signature(entries)` を再計算 |
| 4 | 記録値と再計算値が不一致 → **空 dict 返却** |
| 5 | `route.py` で `qn_to_idx` が空 → `embedding_route.boost_rows` 呼出スキップ |
| 6 | heuristic 単独で tier 判定 |
| 7 | `route_decisions.jsonl` に `embedding_used: false` で記録 |

## 期待出力

| 出力 | 内容 |
|-----|------|
| `route_decisions.jsonl` | 改竄後の決定行で `embedding_used: false` |
| `route.log` | `embedding=off` と記録（embedding 無効と等価扱い）|
| 副作用 | プロセス継続、例外伝播なし。ユーザの本来作業はブロックされない |

## 分岐の根拠

`references/scripts/lib/embedding_enrich.py` の `_compute_entries_signature()` 自己整合チェック（B11 で追加、`test_embedding_enrich.py::test_load_manifest_rejects_tampered_entries` でユニット保証）。manifest 自体の改竄を best-effort で検出する CWE-345 緩和策の eval 形式化（review evals M-8）。

## 関連ケース

- `case-14_cache_tamper_failopen` — `vectors.npz` 改竄時の SHA-256 不一致
- `case-10_fail_open` — index 破損時のフェイルオープン

## 備考

- 攻撃者が `entries` と `entries_sha256` を **同時に整合的に書き換え** た場合は本チェックを突破できる（攻撃者抑止力ゼロ、SECURITY.md でも明示）
- 完全防御には keyed HMAC か外部 trusted store が必要だが、本機能はあくまで「無差別書き換え・偶発破損」に対する第一段階フィルタ
- 検出後の運用対処は `/router-embedding-cache --clear` → `/router-rebuild` で再生成
