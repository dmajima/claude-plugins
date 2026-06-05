# Case 31: `--workspace-root` 経由のパストラバーサル拒否

## 入力

- 入力 PPTX: 任意の有効な PPTX
- 出力 MD: `<セッション>/output.md`
- オプション: `--workspace-root <セッション>/work --structured-json ../../../etc/evil.json`

## 期待動作

1. `_validate_pptx` で入力 PPTX を検証
2. `__init__` で `_workspace_root = <セッション>/work` を確定
3. `--structured-json ../../../etc/evil.json` を `_enforce_under(workspace_root, candidate, "--structured-json")` で検証
4. `candidate.resolve` が `_workspace_root` 配下に解決されないため `ValueError` を raise
5. メッセージ: `--structured-json must be under workspace root (path traversal blocked): <絶対パス>`
6. main の `except ValueError` で stderr 出力 + 終了コード 1
7. python-pptx での読み込みは行われない（fail-closed）

## 期待出力

- 標準エラー: `Error: --structured-json must be under workspace root (path traversal blocked): /etc/evil.json`
- 終了コード: 1
- JSON / MD / 画像はいずれも生成されない

## 分岐の根拠

`convert_from_pptx.py:_enforce_under` および `__init__` 内の検証:
```python
self.structured_json_path = (
    _enforce_under(
        self._workspace_root, Path(args.structured_json),
        "--structured-json", "workspace root",
    )
    if getattr(args, "structured_json", None) else None
)
```

`_enforce_under` の本体:
```python
try:
    cand_resolved.relative_to(base_resolved)
except ValueError as exc:
    raise ValueError(f"{label} must be under {msg_suffix} (path traversal blocked): {cand_resolved}") from exc
```

## 関連ケース

- [case-10_path_traversal_images_dir.md](case-10_path_traversal_images_dir.md): `--images-dir` のパストラバーサル拒否（output MD ディレクトリ基準）
- [case-23a_structured_json_normal.md](case-23a_structured_json_normal.md): `--structured-json` の正常系
