# Case 08: プライベート IP の画像 URL → SSRF 対策で拒否

## 入力

- 入力 MD: 内部 IP の画像参照を含む

  ```markdown
  # 攻撃シナリオ
  ![internal](http://192.168.1.10/admin.png)
  ![loopback](http://127.0.0.1:8080/secret)
  ```

## 期待動作

1. `_load_image_bytes()` で `urlparse(src)` を実行
2. `_is_public_host(parsed.hostname)` が:
   - `192.168.1.10` → `ipaddress.ip_address("192.168.1.10").is_private` が True → **拒否**
   - `127.0.0.1` → `is_loopback` が True → **拒否**
3. stderr に `Warning: image URL host blocked (SSRF guard): 192.168.1.10` を出力
4. 画像は埋め込まれず、`[画像が見つかりません: ...]` 等のフォールバックテキストでスライドに表示

## 期待出力

- スライド内にプライベート IP の画像コンテンツは含まれない
- 標準エラーに SSRF guard 警告が出る
- スライド全体は正常に生成される

## 分岐の根拠

`scripts/convert/convert_pptx.py`:
```python
@staticmethod
def _is_public_host(host: str) -> bool:
    ...
    ip = ipaddress.ip_address(host)
    return not (ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved)

@classmethod
def _load_image_bytes(cls, src, base_dir):
    if parsed.scheme in ("http", "https"):
        if not cls._is_public_host(parsed.hostname or ""):
            print(f"Warning: image URL host blocked (SSRF guard): ...", file=sys.stderr)
            return None
```

`SKILL.md`「重要な制約」:
> 画像 URL は HTTP(S) のみ許可。プライベート IP（127.0.0.1、10.0.0.0/8、192.168.0.0/16 等）への接続は SSRF 対策として拒否する

## 関連ケース

なし（セキュリティ）
