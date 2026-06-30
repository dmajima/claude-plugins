# tasks_to_csv.py - getWbsNodes のタスクツリーを CSV に整形
#
# 使い方:
#   python tasks_to_csv.py <input.json> <output.csv> [--mode standard|all]
#                          [--page-detail <pagedetail.json>] [--fields a,b,c] [--tz +0900]
#
# 引数:
#   input.json    getWbsNodes のレスポンス JSON（get_tasks.sh の出力）
#   output.csv    出力 CSV パス
#   --mode        standard(既定): 標準10列 / all: getPageDetail.linkedNodeFields から全列を動的生成（ADR-8）
#   --page-detail all モード時に必須。getPageDetail のレスポンス JSON（sheet_detail.sh の出力）
#   --fields      列を明示指定（カンマ区切り。--mode より優先）
#   --tz          日付変換のタイムゾーン（既定 +0900）。epoch ミリ秒 → YYYY-MM-DD
#
# 備考:
#   - 値が未設定のフィールドはレスポンスにキー自体が無いため空文字で出力する
#   - dict 値（status 等）は extraData.ja > name > id の順で文字列化
#   - list 値（predecessor 等）は dependentEntityNumber:type を ";" 連結（例 "8:FS;12:FS"）
import sys
import json
import csv
import argparse
import re
from datetime import datetime, timezone, timedelta

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

STANDARD_FIELDS = [
    "taskId", "title", "status", "type",
    "plannedStart", "plannedEnd", "plannedEffort",
    "actualStart", "actualEnd", "progress",
]
# epoch ミリ秒として日付変換するフィールド（DATE 型）
DEFAULT_DATE_FIELDS = {"plannedStart", "plannedEnd", "actualStart", "actualEnd"}


def parse_tz(s: str) -> timezone:
    m = re.fullmatch(r'([+-])(\d{2})(\d{2})', s.strip())
    if not m:
        raise ValueError(f"Invalid --tz format (expected like +0900): {s!r}")
    sign = 1 if m.group(1) == '+' else -1
    return timezone(sign * timedelta(hours=int(m.group(2)), minutes=int(m.group(3))))


def fmt_date(ms, tz: timezone) -> str:
    try:
        return datetime.fromtimestamp(ms / 1000, tz).strftime('%Y-%m-%d')
    except (OverflowError, OSError, ValueError):
        return str(ms)


def find_key_recursive(obj, key):
    """JSON のラップ構造（{result: {...}} 等）に依存せず指定キーの値を探す。"""
    if isinstance(obj, dict):
        if key in obj:
            return obj[key]
        for v in obj.values():
            r = find_key_recursive(v, key)
            if r is not None:
                return r
    elif isinstance(obj, list):
        for v in obj:
            r = find_key_recursive(v, key)
            if r is not None:
                return r
    return None


def walk_nodes(root):
    """displayRoot からツリーを深さ優先で走査し data を持つノードを yield する。"""
    stack = [root]
    while stack:
        node = stack.pop()
        data = node.get("data") or {}
        if data.get("title") is not None:
            yield data
        children = node.get("children") or []
        # 兄弟順を保つため逆順 push
        stack.extend(reversed(children))


def stringify(value, field, tz, date_fields):
    if value is None:
        return ""
    if isinstance(value, dict):
        extra = value.get("extraData") or {}
        return str(extra.get("ja") or value.get("name") or value.get("id") or "")
    if isinstance(value, list):
        parts = []
        for item in value:
            if isinstance(item, dict):
                num = item.get("dependentEntityNumber")
                dep_type = item.get("type") or ""
                if num is not None:
                    parts.append(f"{num}:{dep_type}" if dep_type else str(num))
                else:
                    parts.append(str(item.get("name") or item.get("id") or ""))
            else:
                parts.append(str(item))
        return ";".join(p for p in parts if p)
    if field in date_fields and isinstance(value, (int, float)):
        return fmt_date(value, tz)
    return str(value)


def fields_from_page_detail(page_detail_path):
    """getPageDetail の linkedNodeFields から (列IDリスト, DATE型フィールド集合) を生成する。"""
    with open(page_detail_path, encoding='utf-8') as f:
        detail = json.load(f)
    linked = find_key_recursive(detail, "linkedNodeFields")
    if not linked:
        raise ValueError("page-detail JSON に linkedNodeFields が見つかりません")
    fields, date_fields = [], set(DEFAULT_DATE_FIELDS)
    for entry in linked:
        field = entry.get("field") or entry
        fid = field.get("id")
        if not fid:
            continue
        fields.append(fid)
        if field.get("valueType") == "DATE":
            date_fields.add(fid)
    if not fields:
        raise ValueError("linkedNodeFields から列を生成できません")
    return fields, date_fields


def main():
    parser = argparse.ArgumentParser(description="getWbsNodes JSON をタスク CSV に整形")
    parser.add_argument("input_json")
    parser.add_argument("output_csv")
    parser.add_argument("--mode", choices=["standard", "all"], default="standard")
    parser.add_argument("--page-detail", default=None)
    parser.add_argument("--fields", default=None)
    parser.add_argument("--tz", default="+0900")
    args = parser.parse_args()

    tz = parse_tz(args.tz)

    if args.fields:
        fields = [f.strip() for f in args.fields.split(",") if f.strip()]
        date_fields = set(DEFAULT_DATE_FIELDS)
    elif args.mode == "all":
        if not args.page_detail:
            print("ERROR: --mode all には --page-detail <pagedetail.json> が必要です", file=sys.stderr)
            sys.exit(2)
        fields, date_fields = fields_from_page_detail(args.page_detail)
    else:
        fields = STANDARD_FIELDS
        date_fields = set(DEFAULT_DATE_FIELDS)

    with open(args.input_json, encoding='utf-8') as f:
        payload = json.load(f)
    root = find_key_recursive(payload, "displayRoot")
    if root is None:
        print("ERROR: 入力 JSON に displayRoot が見つかりません（getWbsNodes のレスポンスを指定してください）", file=sys.stderr)
        sys.exit(1)

    count = 0
    with open(args.output_csv, "w", encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(fields)
        for data in walk_nodes(root):
            writer.writerow([stringify(data.get(fid), fid, tz, date_fields) for fid in fields])
            count += 1

    print(f"OK: {args.output_csv} ({count} tasks, {len(fields)} columns, mode={args.mode})")


if __name__ == "__main__":
    main()
