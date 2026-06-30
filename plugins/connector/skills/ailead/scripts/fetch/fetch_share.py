"""ailead 外部共有リンクからデータを取得するスクリプト

connector プラグインの ailead スキル用。
meeting-minutes プラグインの ailead-fetcher を connector 規約に適応。
"""
import sys
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

import argparse
import json
import re
from pathlib import Path
from typing import Optional

import requests

KNOWN_HASHES = [
    "4a1237bbe10bf7ef3a7e9586ef2eb3a171b96311f6d3dbd6323be604b207f037",
]

GRAPHQL_ENDPOINT = "https://dashboard.ailead.app/api/v2/graphql"
BASE_URL = "https://dashboard.ailead.app"
REQUEST_TIMEOUT = 30
MAX_RESPONSE_BYTES = 1_048_576  # 1MB (safe-api-access 準拠)
SHARE_URL_PATTERN = re.compile(
    r'^https://dashboard\.ailead\.app/share/([^/?#]+)'
)
HASH_RETRY_CODES = frozenset({
    "CLIENT_CODE_OUT_OF_DATE",
    "PERSISTED_QUERY_NOT_FOUND",
})


def extract_key(url: str) -> str:
    m = SHARE_URL_PATTERN.search(url)
    if not m:
        raise ValueError(
            f"Invalid ailead share URL: {url} "
            "(expected https://dashboard.ailead.app/share/...)"
        )
    return m.group(1)


def _check_response_size(resp: requests.Response) -> None:
    if len(resp.content) > MAX_RESPONSE_BYTES:
        raise RuntimeError(
            f"Response size {len(resp.content)} exceeds "
            f"{MAX_RESPONSE_BYTES} byte limit"
        )


def fetch_share_page(key: str) -> tuple:
    resp = requests.get(
        f"{BASE_URL}/share/{key}",
        timeout=REQUEST_TIMEOUT,
        allow_redirects=False,
    )
    if resp.status_code in (301, 302, 303, 307, 308):
        raise RuntimeError(
            f"Redirect detected (HTTP {resp.status_code}). "
            f"Location: {resp.headers.get('Location', 'N/A')}. "
            "Redirect follow is disabled per safe-api-access policy."
        )
    resp.raise_for_status()
    _check_response_size(resp)
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
    js_resp = requests.get(js_url, timeout=REQUEST_TIMEOUT, allow_redirects=False)
    if js_resp.status_code in (301, 302, 303, 307, 308):
        print(f"       JS chunk redirect detected, aborting.", file=sys.stderr)
        return None
    js_resp.raise_for_status()
    _check_response_size(js_resp)

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
        timeout=REQUEST_TIMEOUT,
        allow_redirects=False,
    )
    if resp.status_code in (301, 302, 303, 307, 308):
        raise RuntimeError(
            f"GraphQL redirect detected (HTTP {resp.status_code}). "
            "Redirect follow is disabled per safe-api-access policy."
        )
    resp.raise_for_status()
    _check_response_size(resp)
    return resp.json()


def try_known_hashes(key: str, build_id: str) -> tuple:
    for h in KNOWN_HASHES:
        try:
            result = query_graphql(key, h, build_id)
        except requests.exceptions.RequestException as e:
            print(f"       Network error with hash {h[:16]}...: {e}", file=sys.stderr)
            raise
        if "errors" not in result:
            return result, h
        err_code = (
            result.get("errors", [{}])[0]
            .get("extensions", {})
            .get("code", "")
        )
        if err_code in HASH_RETRY_CODES:
            print(f"       Hash {h[:16]}... returned {err_code}, trying next...", file=sys.stderr)
            continue
        return result, h
    return None, None


def format_time(seconds: float) -> str:
    total = int(seconds)
    h, rem = divmod(total, 3600)
    m, s = divmod(rem, 60)
    return f"{h:02d}:{m:02d}:{s:02d}"


def build_transcript_text(data: dict) -> str:
    share = data.get("data", {}).get("externalShare", {}) or {}
    transcripts = share.get("transcripts") or []
    duration = share.get("duration", 0)

    segments = []
    for t in transcripts:
        text = (t.get("text") or "").strip()
        if not text:
            continue
        start_sec = (t.get("startTime") or 0) * duration
        end_sec = (t.get("endTime") or 0) * duration
        name = t.get("participantName") or "Unknown"
        segments.append((start_sec, end_sec, name, text))

    segments.sort(key=lambda x: x[0])
    return "\n".join(
        f"[{format_time(s)} - {format_time(e)}] {n}: {tx}"
        for s, e, n, tx in segments
    )


def build_summary_md(data: dict) -> str:
    share = data.get("data", {}).get("externalShare", {}) or {}
    summary = share.get("callSummary") or {}
    duration = share.get("duration", 0)
    if not summary:
        return "# 会議要約\n\n要約データなし\n"

    lines = ["# 会議要約\n"]
    lines.append(f"## 概要\n\n{summary.get('description', 'N/A')}\n")

    keywords = summary.get("keywords", [])
    if keywords:
        lines.append(f"## キーワード\n\n{', '.join(keywords)}\n")

    topics = summary.get("topics", [])
    if topics:
        lines.append("## トピック\n")
        for topic in topics:
            dt = topic.get("dateTime", 0)
            if isinstance(dt, (int, float)) and dt > 0:
                time_str = format_time(dt)
            else:
                time_str = "--:--:--"
            lines.append(f"### [{time_str}] {topic.get('title', 'N/A')}")
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
    call_tasks = share.get("callTasks") or []
    task_statuses = {
        ct.get("type", ""): ct.get("status", "")
        for ct in call_tasks
    }
    return {
        "title": share.get("title", ""),
        "startDatetime": share.get("startDatetime", ""),
        "duration": share.get("duration", 0),
        "system": share.get("system", ""),
        "source": "ailead",
        "expirationDatetime": share.get("expirationDatetime", ""),
        "hostUser": " ".join(
            filter(None, [host.get("lastName", ""), host.get("firstName", "")])
        ),
        "hlsUrl": share.get("hlsUrl", ""),
        "participants": participants,
        "transcriptCount": len(share.get("transcripts") or []),
        "topicCount": len(
            (share.get("callSummary") or {}).get("topics") or []
        ),
        "callTaskStatuses": task_statuses,
    }


def check_data_readiness(metadata: dict) -> list:
    warnings = []
    statuses = metadata.get("callTaskStatuses", {})
    transcript_status = statuses.get("TRANSCRIPT")
    if transcript_status is None:
        warnings.append("文字起こしタスク情報がありません（非対応の可能性）")
    elif transcript_status not in ("DONE", "COMPLETED"):
        warnings.append(
            f"文字起こしが未完了です（ステータス: {transcript_status}）"
        )
    summary_status = statuses.get("SUMMARY")
    if summary_status is None:
        warnings.append("AI要約タスク情報がありません（非対応の可能性）")
    elif summary_status not in ("DONE", "COMPLETED"):
        warnings.append(
            f"AI要約が未完了です（ステータス: {summary_status}）"
        )
    if metadata.get("transcriptCount", 0) == 0:
        warnings.append("文字起こしセグメントが0件です")
    return warnings


def main():
    parser = argparse.ArgumentParser(
        description="Fetch ailead share data via GraphQL API"
    )
    parser.add_argument("--url", required=True, help="ailead share URL")
    parser.add_argument(
        "--output", required=True, help="Output directory path"
    )
    args = parser.parse_args()

    try:
        key = extract_key(args.url)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"[1/5] Fetching buildId for key: {key[:8]}...")
    try:
        build_id, html = fetch_share_page(key)
    except requests.exceptions.HTTPError as e:
        if e.response is not None and e.response.status_code == 404:
            print(
                "ERROR: Share page returned 404. "
                "The share link may have expired.",
                file=sys.stderr,
            )
        else:
            print(f"ERROR: Failed to fetch share page: {e}", file=sys.stderr)
        sys.exit(1)
    except (requests.exceptions.RequestException, RuntimeError) as e:
        print(f"ERROR: Failed to fetch share page: {e}", file=sys.stderr)
        sys.exit(1)
    print(f"       buildId: {build_id}")

    print("[2/5] Querying GraphQL API with known hashes...")
    result, used_hash = try_known_hashes(key, build_id)

    if result is None:
        print("       Known hashes failed. Extracting from JS chunk...")
        new_hash = extract_operation_hash_from_js(html)
        if not new_hash:
            print(
                "ERROR: Could not extract operationHash from JS chunk.",
                file=sys.stderr,
            )
            sys.exit(1)
        print(f"       New hash: {new_hash}")
        try:
            result = query_graphql(key, new_hash, build_id)
        except requests.exceptions.RequestException as e:
            print(f"ERROR: GraphQL query failed: {e}", file=sys.stderr)
            sys.exit(1)
        used_hash = new_hash

    if "errors" in result:
        errors_json = json.dumps(result["errors"], ensure_ascii=False)
        print(f"ERROR: GraphQL returned errors: {errors_json}", file=sys.stderr)
        sys.exit(1)

    print(f"       Success (hash: {used_hash[:16]}...)")

    print("[3/5] Building output files...")
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

    print("[4/5] Checking data readiness...")
    warnings = check_data_readiness(metadata)
    if warnings:
        for w in warnings:
            print(f"       WARNING: {w}")
    else:
        print("       All data ready.")

    print("[5/5] Done.")
    print(f"  Title:      {metadata.get('title', 'N/A')}")
    print(f"  Duration:   {format_time(metadata.get('duration', 0))}")
    print(f"  System:     {metadata.get('system', 'N/A')}")
    print(f"  Transcript: {output_dir / 'transcript.txt'} ({metadata['transcriptCount']} segments)")
    print(f"  Summary:    {output_dir / 'summary.md'} ({metadata['topicCount']} topics)")
    print(f"  Metadata:   {output_dir / 'metadata.json'}")
    print(f"  Raw JSON:   {output_dir / 'response.json'}")
    if metadata.get("hlsUrl"):
        print("  HLS URL:    (available in metadata.json)")


if __name__ == "__main__":
    main()
