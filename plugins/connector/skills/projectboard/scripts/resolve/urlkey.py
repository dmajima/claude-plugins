# urlkey.py - ProjectBoard の urlKey(base62) と projectId(UUID) の相互変換
#
# 使い方:
#   python urlkey.py <urlKey>            # urlKey → UUID（デコード）
#   python urlkey.py --encode <uuid>     # UUID → urlKey（エンコード）
#
# URL の /wbs/project/{urlKey}/... の urlKey は projectId(UUID) を base62 化したもの。
# API は UUID を要求するため、URL 入力時は本スクリプトで変換する（落とし穴 #2）。
#
# 自己検証ガード（ADR-7）:
#   decode は decode→re-encode の round-trip が入力と一致しなければ即エラーにする。
#   アルゴリズム変更時のサイレント誤変換（別プロジェクト取得）を fail-fast 化する。
#
# 検証済み: abcDEFghiJKLmnoPQRst → 0bc4978b-41e7-11f1-9633-85b8872b7139
import sys
import re

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

ALPHABET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
IDX = {c: i for i, c in enumerate(ALPHABET)}


def decode(urlkey: str) -> str:
    n = 0
    for c in urlkey:
        if c not in IDX:
            raise ValueError(f"Invalid urlKey char: {c!r}")
        n = n * 62 + IDX[c]
    h = format(n, '032x')
    if len(h) != 32:  # 128bit=32hex。超過/不足は異常
        raise ValueError(f"Unexpected hex length {len(h)} for urlKey {urlkey!r}")
    uuid = f"{h[0:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}"
    if encode(uuid) != urlkey:  # 自己検証ガード(ADR-7): round-trip 不一致は誤変換
        raise ValueError(f"Round-trip mismatch: {urlkey} -> {uuid} -> {encode(uuid)}")
    return uuid


def encode(uuid: str) -> str:
    u = uuid.strip().lower()
    if not re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', u):
        raise ValueError(f"Invalid UUID: {uuid!r}")
    n = int(u.replace('-', ''), 16)
    if n == 0:
        return ALPHABET[0]
    out = []
    while n > 0:
        out.append(ALPHABET[n % 62])
        n //= 62
    return ''.join(reversed(out))


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if not args:
        print("usage: urlkey.py <urlKey> | urlkey.py --encode <uuid>", file=sys.stderr)
        sys.exit(2)
    try:
        print(encode(args[0]) if '--encode' in sys.argv else decode(args[0]))
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
