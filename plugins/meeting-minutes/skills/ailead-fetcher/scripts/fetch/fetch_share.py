"""ailead 外部共有リンクからデータを取得するスクリプト"""
import sys
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

import argparse
import json
import os
import re
from pathlib import Path

from typing import Optional
import requests

KNOWN_HASHES = [
    "4a1237bbe10bf7ef3a7e9586ef2eb3a171b96311f6d3dbd6323be604b207f037",
]

GRAPHQL_ENDPOINT = "https://dashboard.ailead.app/api/v2/graphql"
BASE_URL = "https://dashboard.ailead.app"


def extract_key(url: str) -> str:
    m = re.search(r'/share/([^/?#]+)', url)
    if not m:
        raise ValueError(f"Invalid ailead share URL: {url}")
    return m.group(1)


def fetch_share_page(key: str) -> tuple:
    resp = requests.get(f"{BASE_URL}/share/{key}", timeout=30)
    resp.raise_for_status()
    html = resp.text
    m = re.search(r'"buildId":"([^"]+)"', html)
    if not m:
        raise RuntimeError("buildId not found in HTML")
    return m.group(1), html


def extract_operation_hash_from_js(html: str) -> Optional[str]:
    js_match = re.search(
        r'/_next/static/chunks/pages/share/%5Bkey%5D-[^"]+\.js', html
    )
    if not js_match:
        return None

    js_url = BASE_URL + js_match.group(0)
    js_resp = requests.get(js_url, timeout=30)
    js_resp.raise_for_status()

    hash_match = re.search(
        r'externalShare/dataflow/query.*?hash:"([0-9a-f]{64})"',
        js_resp.text,
    )
    return hash_match.group(1) if hash_match else None


def query_graphql(key: str, operation_hash: str, build_id: str) -> dict:
    body = {
        "operationName": "externalShare",
        "variables": {"key": key},
        "extensions": {
            "operationHash": operation_hash,
            "buildId": build_id,
        },
    }
    resp = requests.post(
        GRAPHQL_ENDPOINT,
        json=body,
        headers={"Content-Type": "application/json; charset=utf-8"},
        timeout=60,
    )
    resp.raise_for_status()
    return resp.json()


def try_known_hashes(key: str, build_id: str) -> tuple:
    for h in KNOWN_HASHES:
        try:
            result = query_graphql(key, h, build_id)
        except requests.exceptions.RequestException as e:
            print(f"       Network error with hash {h[:16]}...: {e}", file=sys.stderr)
            continue
        if "errors" not in result:
            return result, h
        err_code = result.get("errors", [{}])[0].get("extensions", {}).get("code", "")
        if err_code not in ("CLIENT_CODE_OUT_OF_DATE", "PERSISTED_QUERY_NOT_FOUND"):
            return result, h
    return None, None


def format_time(seconds: float) -> str:
    total = int(seconds)
    h, rem = divmod(total, 3600)
    m, s = divmod(rem, 60)
    return f"{h:02d}:{m:02d}:{s:02d}"


def build_transcript_text(data: dict) -> str:
    share = data.get("data", {}).get("externalShare", {})
    transcripts = share.get("transcripts", [])
    duration = share.get("duration", 0)

    lines = []
    for t in transcripts:
        start_sec = t.get("startTime", 0) * duration
        end_sec = t.get("endTime", 0) * duration
        name = t.get("participantName", "Unknown")
        text = t.get("text", "")
        lines.append(f"[{format_time(start_sec)} - {format_time(end_sec)}] {name}: {text}")
    return "\n".join(lines)


def build_summary_md(data: dict) -> str:
    share = data.get("data", {}).get("externalShare", {})
    summary = share.get("callSummary", {})
    if not summary:
        return "# 会議要約\n\n要約データなし\n"

    lines = [f"# 会議要約\n"]
    lines.append(f"## 概要\n\n{summary.get('description', 'N/A')}\n")

    keywords = summary.get("keywords", [])
    if keywords:
        lines.append(f"## キーワード\n\n{', '.join(keywords)}\n")

    topics = summary.get("topics", [])
    if topics:
        lines.append("## トピック\n")
        for topic in topics:
            dt = topic.get("dateTime", 0)
            lines.append(f"### [{format_time(dt)}] {topic.get('title', 'N/A')}")
            lines.append(f"- カテゴリ: {topic.get('category', 'N/A')}")
            lines.append(f"- 発話者: {topic.get('speakerName', 'N/A')}")
            lines.append(f"- {topic.get('description', '')}\n")

    return "\n".join(lines)


def build_metadata(data: dict) -> dict:
    share = data.get("data", {}).get("externalShare", {}) or {}
    host = share.get("hostUser") or {}
    participants = [
        {
            "name": p.get("participantName", ""),
            "talkRatio": p.get("participantTalkRatio", 0),
            "isHost": p.get("isHost", False),
        }
        for p in (share.get("participants") or [])
    ]
    return {
        "title": share.get("title", ""),
        "startDatetime": share.get("startDatetime", ""),
        "duration": share.get("duration", 0),
        "system": share.get("system", ""),
        "source": "ailead",
        "expirationDatetime": share.get("expirationDatetime", ""),
        "hostUser": f"{host.get('lastName', '')} {host.get('firstName', '')}".strip(),
        "hlsUrl": share.get("hlsUrl", ""),
        "participants": participants,
        "transcriptCount": len(share.get("transcripts") or []),
        "topicCount": len((share.get("callSummary") or {}).get("topics") or []),
    }


def main():
    parser = argparse.ArgumentParser(description="Fetch ailead share data")
    parser.add_argument("--url", required=True, help="ailead share URL")
    parser.add_argument("--output", required=True, help="Output session directory")
    args = parser.parse_args()

    try:
        key = extract_key(args.url)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"[1/4] Fetching buildId for key: {key[:8]}...")
    try:
        build_id, html = fetch_share_page(key)
    except (requests.exceptions.RequestException, RuntimeError) as e:
        print(f"ERROR: Failed to fetch share page: {e}", file=sys.stderr)
        sys.exit(1)
    print(f"       buildId: {build_id}")

    print("[2/4] Querying GraphQL API...")
    result, used_hash = try_known_hashes(key, build_id)

    if result is None:
        print("       Known hashes failed. Extracting from JS chunk...")
        new_hash = extract_operation_hash_from_js(html)
        if not new_hash:
            print("ERROR: Could not extract operationHash from JS chunk.", file=sys.stderr)
            sys.exit(1)
        print(f"       New hash: {new_hash}")
        result = query_graphql(key, new_hash, build_id)
        used_hash = new_hash

    if "errors" in result:
        print(f"ERROR: GraphQL returned errors: {json.dumps(result['errors'], ensure_ascii=False)}", file=sys.stderr)
        sys.exit(1)

    print(f"       Success (hash: {used_hash[:16]}...)")

    print("[3/4] Saving results...")
    with open(output_dir / "response.json", "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    transcript_text = build_transcript_text(result)
    with open(output_dir / "transcript.txt", "w", encoding="utf-8") as f:
        f.write(transcript_text)

    summary_md = build_summary_md(result)
    with open(output_dir / "summary.md", "w", encoding="utf-8") as f:
        f.write(summary_md)

    metadata = build_metadata(result)
    with open(output_dir / "metadata.json", "w", encoding="utf-8") as f:
        json.dump(metadata, f, ensure_ascii=False, indent=2)

    print("[4/4] Done.")
    print(f"  Transcript: {output_dir / 'transcript.txt'} ({metadata['transcriptCount']} segments)")
    print(f"  Summary:    {output_dir / 'summary.md'} ({metadata['topicCount']} topics)")
    print(f"  Metadata:   {output_dir / 'metadata.json'}")
    print(f"  Raw JSON:   {output_dir / 'response.json'}")
    if metadata.get('hlsUrl'):
        print(f"  HLS URL:    (available in metadata.json)")


if __name__ == "__main__":
    main()
