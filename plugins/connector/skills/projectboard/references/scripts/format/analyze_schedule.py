# analyze_schedule.py - getWbsNodes のタスクツリーを構造解析しスケジュールレポートを生成
#
# 使い方:
#   python analyze_schedule.py <wbsnodes.json> [--out-json <path>] [--tz +0900] [--max-depth N]
#
# 引数:
#   wbsnodes.json  getWbsNodes のレスポンス JSON（get_tasks.sh の出力）
#   --out-json     構造化データ（ツリー・依存・CPM 結果）の JSON 出力先（任意）
#   --tz           日付表示のタイムゾーン（既定 +0900）
#   --max-depth    WBS ツリー表示の最大深さ（既定: 無制限）
#
# 出力（stdout に Markdown レポート）:
#   1. サマリ（タスク数・type/status 別内訳・期間・依存件数）
#   2. WBS ツリー（階層構造）
#   3. 依存関係一覧（先行 → 後続）
#   4. クリティカルパス分析（CPM: forward/backward pass・total float・クリティカル経路）
#   5. 警告（循環依存・未解決参照・duration 推定の内訳）
#
# CPM の duration 推定（日数。優先順）:
#   plannedDuration > plannedStart/End の日数差 > actualStart/End の日数差
#   > plannedEffort/480（EFFORT は分単位・1日=8h=480分と推定） > MILESTONE=0 > 既定 1.0
#   ※ plannedDuration の単位はシートにより分（1440=1日）と日が混在しうるため、
#     シート全体の値分布（中央値 >= 1440 なら分単位）から自動判定する。
#   ※ シートによっては planned 系が全タスク未設定（キー自体が無い）。その場合も
#     フォールバックにより常に解析可能（推定根拠の内訳は警告セクションに出力）。
import sys
import json
import argparse
import re
from datetime import datetime, timezone, timedelta
from collections import defaultdict

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

MS_PER_DAY = 86400000.0
EFFORT_MINUTES_PER_DAY = 480.0  # 8h/日 と推定（要検証）


def parse_tz(s: str) -> timezone:
    m = re.fullmatch(r'([+-])(\d{2})(\d{2})', s.strip())
    if not m:
        raise ValueError(f"Invalid --tz format (expected like +0900): {s!r}")
    sign = 1 if m.group(1) == '+' else -1
    return timezone(sign * timedelta(hours=int(m.group(2)), minutes=int(m.group(3))))


def fmt_date(ms, tz):
    if not isinstance(ms, (int, float)):
        return ""
    try:
        return datetime.fromtimestamp(ms / 1000, tz).strftime('%Y-%m-%d')
    except (OverflowError, OSError, ValueError):
        return ""


def find_key_recursive(obj, key):
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


def status_label(status):
    if not isinstance(status, dict):
        return str(status or "")
    extra = status.get("extraData") or {}
    return str(extra.get("ja") or status.get("name") or status.get("id") or "")


def collect_nodes(root):
    """ツリーを走査し、ノード一覧（表示順）を構築する。表示ルート（title なし）は除外。
    深い階層でも RecursionError を起こさないよう明示スタックで反復走査する。"""
    nodes = []
    stack = [(root, 0, None)]
    while stack:
        node, depth, parent_id = stack.pop()
        data = node.get("data") or {}
        node_id = node.get("id")
        has_title = data.get("title") is not None
        if has_title:
            nodes.append({
                "id": node_id,
                "parentId": parent_id,
                "depth": depth,
                "taskId": data.get("taskId") or "",
                "title": data.get("title") or "",
                "type": data.get("type") or "",
                "status": status_label(data.get("status")),
                "plannedStart": data.get("plannedStart"),
                "plannedEnd": data.get("plannedEnd"),
                "actualStart": data.get("actualStart"),
                "actualEnd": data.get("actualEnd"),
                "plannedDuration": data.get("plannedDuration"),
                "plannedEffort": data.get("plannedEffort"),
                "progress": data.get("progress"),
                "predecessor": data.get("predecessor") or [],
            })
        next_depth = depth + 1 if has_title else depth
        next_parent = node_id if has_title else parent_id
        # 兄弟順を保つため逆順 push
        for child in reversed(node.get("children") or []):
            stack.append((child, next_depth, next_parent))
    return nodes


def detect_duration_unit(nodes, warnings):
    """plannedDuration の単位（分 or 日）をシート全体の分布から判定し、日数への除数を返す。
    中央値 >= 1440（=24h 分）なら分単位とみなす。"""
    values = sorted(
        n["plannedDuration"] for n in nodes
        if isinstance(n.get("plannedDuration"), (int, float)) and n["plannedDuration"] > 0
    )
    if not values:
        return 1.0
    median = values[len(values) // 2]
    if median >= 1440:
        if values[0] < 100:
            warnings.append(
                f"plannedDuration に分単位（中央値 {median:g}）と日単位らしき小値（最小 {values[0]:g}）が"
                "混在している可能性があります。分単位（/1440）として一括換算します"
            )
        return 1440.0  # 分 → 日
    return 1.0  # 日のまま


def estimate_duration(n, duration_divisor=1.0):
    """duration（日数）と推定根拠を返す。"""
    pd = n.get("plannedDuration")
    if isinstance(pd, (int, float)) and pd >= 0:
        return float(pd) / duration_divisor, "plannedDuration"
    ps, pe = n.get("plannedStart"), n.get("plannedEnd")
    if isinstance(ps, (int, float)) and isinstance(pe, (int, float)) and pe >= ps:
        return (pe - ps) / MS_PER_DAY + 1.0, "planned dates"
    as_, ae = n.get("actualStart"), n.get("actualEnd")
    if isinstance(as_, (int, float)) and isinstance(ae, (int, float)) and ae >= as_:
        return (ae - as_) / MS_PER_DAY + 1.0, "actual dates"
    eff = n.get("plannedEffort")
    if isinstance(eff, (int, float)) and eff > 0:
        return eff / EFFORT_MINUTES_PER_DAY, "plannedEffort"
    if n.get("type") == "MILESTONE":
        return 0.0, "milestone (0d)"
    return 1.0, "default (1d)"


def build_edges(nodes, warnings):
    """predecessor から依存エッジ (pred_id → succ_id) を構築する。
    dependentEntityId をノード id 索引で解決し、失敗時は dependentEntityNumber
    （taskId の数値部）で解決する。"""
    by_id = {n["id"]: n for n in nodes}
    by_num = {}
    for n in nodes:
        m = re.match(r'^(.+)-(\d+)$', n["taskId"])
        if m:
            by_num[int(m.group(2))] = n
    edges = []
    for n in nodes:
        for dep in n["predecessor"]:
            if not isinstance(dep, dict):
                continue
            pred = None
            dep_id = dep.get("dependentEntityId")
            if dep_id and dep_id in by_id:
                pred = by_id[dep_id]
            elif dep.get("dependentEntityNumber") is not None:
                pred = by_num.get(dep.get("dependentEntityNumber"))
            if pred is None:
                warnings.append(
                    f"依存の先行タスクを解決できません: {n['taskId']}({n['title']}) の先行 "
                    f"dependentEntityId={dep.get('dependentEntityId')} / Number={dep.get('dependentEntityNumber')}"
                )
                continue
            if pred["id"] == n["id"]:
                warnings.append(f"自己依存を無視: {n['taskId']}")
                continue
            lag = dep.get("lag")
            edges.append({
                "predId": pred["id"],
                "succId": n["id"],
                "type": dep.get("type") or "FS",
                "lag": float(lag) if isinstance(lag, (int, float)) else 0.0,
            })
    return edges


def run_cpm(nodes, edges, warnings):
    """CPM forward/backward pass。FS 依存 + lag(日数) を前提とする。
    返り値: (cpm 結果 dict by id, critical_paths, project_duration, excluded_cycle_node_ids)"""
    # 頂点 = PACKAGE 以外の全ノード + 依存に関与する PACKAGE
    involved = {e["predId"] for e in edges} | {e["succId"] for e in edges}
    vertex_ids = [n["id"] for n in nodes if n["type"] != "PACKAGE" or n["id"] in involved]
    vset = set(vertex_ids)
    use_edges = [e for e in edges if e["predId"] in vset and e["succId"] in vset]
    by_id = {n["id"]: n for n in nodes}

    # 単位判定は CPM 頂点（TASK/MILESTONE + 依存関与 PACKAGE）に絞る
    # （集約値を持つ PACKAGE 全体を含めると分布が歪むため）
    cpm_nodes = [by_id[vid] for vid in vertex_ids]
    duration_divisor = detect_duration_unit(cpm_nodes, warnings)
    if duration_divisor != 1.0:
        warnings.append(f"plannedDuration を分単位と判定し 1/{duration_divisor:g} で日数換算しました")
    dur, basis = {}, {}
    for vid in vertex_ids:
        d, b = estimate_duration(by_id[vid], duration_divisor)
        dur[vid], basis[vid] = d, b

    preds, succs = defaultdict(list), defaultdict(list)
    indeg = {vid: 0 for vid in vertex_ids}
    for e in use_edges:
        preds[e["succId"]].append(e)
        succs[e["predId"]].append(e)
        indeg[e["succId"]] += 1

    # Kahn のトポロジカルソート + サイクル検出
    order, queue = [], [vid for vid in vertex_ids if indeg[vid] == 0]
    indeg_work = dict(indeg)
    while queue:
        vid = queue.pop(0)
        order.append(vid)
        for e in succs[vid]:
            indeg_work[e["succId"]] -= 1
            if indeg_work[e["succId"]] == 0:
                queue.append(e["succId"])
    cycle_ids = [vid for vid in vertex_ids if vid not in set(order)]
    if cycle_ids:
        labels = ", ".join(by_id[v]["taskId"] or by_id[v]["title"] for v in cycle_ids[:10])
        warnings.append(f"循環依存を検出（{len(cycle_ids)} ノードを CPM から除外): {labels}")
        # Kahn の性質上 order にサイクルノードは含まれないため、エッジ側のみ除外すればよい
        cyc = set(cycle_ids)
        use_edges = [e for e in use_edges if e["predId"] not in cyc and e["succId"] not in cyc]
        preds, succs = defaultdict(list), defaultdict(list)
        for e in use_edges:
            preds[e["succId"]].append(e)
            succs[e["predId"]].append(e)

    # forward pass
    es, ef = {}, {}
    for vid in order:
        es[vid] = max((ef[e["predId"]] + e["lag"] for e in preds[vid]), default=0.0)
        ef[vid] = es[vid] + dur[vid]
    project_duration = max(ef.values(), default=0.0)

    # backward pass
    ls, lf = {}, {}
    for vid in reversed(order):
        lf[vid] = min((ls[e["succId"]] - e["lag"] for e in succs[vid]), default=project_duration)
        ls[vid] = lf[vid] - dur[vid]

    eps = 1e-9
    cpm = {}
    for vid in order:
        cpm[vid] = {
            "duration": dur[vid], "basis": basis[vid],
            "es": es[vid], "ef": ef[vid], "ls": ls[vid], "lf": lf[vid],
            "float": ls[vid] - es[vid],
            "critical": (ls[vid] - es[vid]) <= eps,
        }

    # クリティカルパス（依存チェーン）の抽出:
    # EF = project_duration の critical 終端から、critical な先行を遡って連結する
    critical_paths = []
    terminals = [vid for vid in order
                 if cpm[vid]["critical"] and abs(cpm[vid]["ef"] - project_duration) <= eps]
    seen_paths = set()
    for term in terminals:
        path, cur = [term], term
        while True:
            cands = [e["predId"] for e in preds[cur]
                     if cpm.get(e["predId"], {}).get("critical")
                     and abs(cpm[e["predId"]]["ef"] + e["lag"] - cpm[cur]["es"]) <= eps]
            if not cands:
                break
            cur = cands[0]  # 分岐時は代表 1 本（全列挙は組合せ爆発のため）
            path.append(cur)
        path.reverse()
        key = tuple(path)
        if key not in seen_paths:
            seen_paths.add(key)
            critical_paths.append(path)
    # 依存チェーン（2 ノード以上）を優先して先頭に
    critical_paths.sort(key=len, reverse=True)
    return cpm, critical_paths, project_duration, cycle_ids


def date_range(nodes, keys, tz):
    values = [n[k] for n in nodes for k in keys if isinstance(n.get(k), (int, float))]
    if not values:
        return None
    return fmt_date(min(values), tz), fmt_date(max(values), tz), len(values)


def render_markdown(nodes, edges, cpm, critical_paths, project_duration, warnings, tz, max_depth):
    by_id = {n["id"]: n for n in nodes}
    out = []
    out.append("# ProjectBoard スケジュールシート構造解析")
    out.append("")

    # 1. サマリ
    type_counts, status_counts = defaultdict(int), defaultdict(int)
    for n in nodes:
        type_counts[n["type"] or "(なし)"] += 1
        status_counts[n["status"] or "(なし)"] += 1
    out.append("## 1. サマリ")
    out.append("")
    out.append("| 項目 | 値 |")
    out.append("|---|---|")
    out.append(f"| ノード総数 | {len(nodes)} |")
    out.append(f"| type 内訳 | {', '.join(f'{k}: {v}' for k, v in sorted(type_counts.items()))} |")
    out.append(f"| status 内訳 | {', '.join(f'{k}: {v}' for k, v in sorted(status_counts.items()))} |")
    pr = date_range(nodes, ["plannedStart", "plannedEnd"], tz)
    ar = date_range(nodes, ["actualStart", "actualEnd"], tz)
    out.append(f"| 予定期間 (planned) | {f'{pr[0]} 〜 {pr[1]}（設定 {pr[2]} 値）' if pr else '未設定'} |")
    out.append(f"| 実績期間 (actual) | {f'{ar[0]} 〜 {ar[1]}（設定 {ar[2]} 値）' if ar else '未設定'} |")
    out.append(f"| 依存関係（解決済み） | {len(edges)} 件 |")
    out.append(f"| CPM プロジェクト総工期（推定） | {project_duration:.1f} 日 |")
    out.append("")

    # 2. WBS ツリー
    out.append("## 2. WBS ツリー")
    out.append("")
    out.append("```")
    omitted = 0
    for n in nodes:
        if max_depth is not None and n["depth"] > max_depth:
            omitted += 1
            continue
        indent = "  " * n["depth"]
        mark = {"PACKAGE": "[P]", "MILESTONE": "[M]", "TASK": "[T]"}.get(n["type"], "[?]")
        dates = ""
        d1 = fmt_date(n.get("plannedStart"), tz) or fmt_date(n.get("actualStart"), tz)
        d2 = fmt_date(n.get("plannedEnd"), tz) or fmt_date(n.get("actualEnd"), tz)
        if d1 or d2:
            dates = f" ({d1}〜{d2})"
        crit = " ★CP" if cpm.get(n["id"], {}).get("critical") else ""
        out.append(f"{indent}{mark} {n['taskId']} {n['title']} [{n['status']}]{dates}{crit}")
    out.append("```")
    if omitted:
        out.append(f"※ --max-depth 指定により {omitted} ノードを省略")
    out.append("")

    # 3. 依存関係
    out.append("## 3. 依存関係（先行 → 後続）")
    out.append("")
    if edges:
        out.append("| 先行 | 後続 | type | lag |")
        out.append("|---|---|---|---|")
        for e in edges:
            p, s = by_id[e["predId"]], by_id[e["succId"]]
            out.append(f"| {p['taskId']} {p['title']} | {s['taskId']} {s['title']} | {e['type']} | {e['lag']:g} |")
    else:
        out.append("依存関係（predecessor）は定義されていません。")
    out.append("")

    # 4. クリティカルパス分析
    out.append("## 4. クリティカルパス分析（CPM）")
    out.append("")
    if not edges:
        out.append("依存関係が定義されていないため、依存チェーンに基づくクリティカルパスは算出できません。")
        out.append("参考: duration（推定）上位のタスクが工期を支配します。")
        top = sorted((cpm[v] | {"id": v} for v in cpm), key=lambda x: -x["duration"])[:10]
        if top:
            out.append("")
            out.append("| taskId | title | duration(日) | 推定根拠 |")
            out.append("|---|---|---|---|")
            for c in top:
                n = by_id[c["id"]]
                out.append(f"| {n['taskId']} | {n['title']} | {c['duration']:.1f} | {c['basis']} |")
    else:
        chains = [p for p in critical_paths if len(p) >= 2]
        if chains:
            out.append(f"クリティカルパス（total float = 0 の依存チェーン。代表 {len(chains)} 本）:")
            out.append("")
            for i, path in enumerate(chains, 1):
                steps = " → ".join(f"{by_id[v]['taskId']}({by_id[v]['title']})" for v in path)
                total = sum(cpm[v]["duration"] for v in path)
                out.append(f"{i}. {steps}　[計 {total:.1f} 日]")
            out.append("")
        else:
            out.append("依存チェーン上にクリティカルパス（float=0 の連鎖）は形成されていません"
                       "（依存が部分的なため、独立タスクが工期を支配しています）。")
            out.append("")
        crit_nodes = [v for v in cpm if cpm[v]["critical"]]
        out.append(f"クリティカル（total float = 0）ノード: {len(crit_nodes)} / {len(cpm)}")
        out.append("")
        out.append("| taskId | title | duration(日) | ES | EF | LS | LF | float | critical |")
        out.append("|---|---|---|---|---|---|---|---|---|")
        # 依存に関与するノードを優先表示し、独立ノードは float 昇順上位のみ
        involved = {e["predId"] for e in edges} | {e["succId"] for e in edges}
        rows = [v for v in cpm if v in involved]
        rows += [v for v in sorted(cpm, key=lambda x: cpm[x]["float"]) if v not in involved][:20]
        for v in rows:
            n, c = by_id[v], cpm[v]
            out.append(f"| {n['taskId']} | {n['title']} | {c['duration']:.1f} | {c['es']:.1f} | "
                       f"{c['ef']:.1f} | {c['ls']:.1f} | {c['lf']:.1f} | {c['float']:.1f} | "
                       f"{'★' if c['critical'] else ''} |")
        hidden = len(cpm) - len(rows)
        if hidden > 0:
            out.append("")
            out.append(f"※ 依存に関与しない独立ノード {hidden} 件は省略（--out-json で全件取得可能）")
    out.append("")

    # 5. 警告・推定根拠
    out.append("## 5. 警告・推定根拠")
    out.append("")
    basis_counts = defaultdict(int)
    for v in cpm:
        basis_counts[cpm[v]["basis"]] += 1
    out.append(f"duration 推定根拠の内訳: {', '.join(f'{k}: {v}' for k, v in sorted(basis_counts.items()))}")
    out.append("")
    if warnings:
        for w in warnings:
            out.append(f"- WARNING: {w}")
    else:
        out.append("- 警告なし")
    out.append("")
    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser(description="getWbsNodes JSON のスケジュール構造解析（CPM 含む）")
    parser.add_argument("input_json")
    parser.add_argument("--out-json", default=None)
    parser.add_argument("--tz", default="+0900")
    parser.add_argument("--max-depth", type=int, default=None)
    args = parser.parse_args()

    tz = parse_tz(args.tz)
    with open(args.input_json, encoding='utf-8') as f:
        payload = json.load(f)
    root = find_key_recursive(payload, "displayRoot")
    if root is None:
        print("ERROR: 入力 JSON に displayRoot が見つかりません（getWbsNodes のレスポンスを指定してください）", file=sys.stderr)
        sys.exit(1)

    warnings = []
    nodes = collect_nodes(root)
    edges = build_edges(nodes, warnings)
    cpm, critical_paths, project_duration, _cycles = run_cpm(nodes, edges, warnings)

    print(render_markdown(nodes, edges, cpm, critical_paths, project_duration, warnings, tz, args.max_depth))

    if args.out_json:
        result = {
            "summary": {
                "nodeCount": len(nodes),
                "edgeCount": len(edges),
                "projectDurationDays": project_duration,
            },
            "nodes": nodes,
            "edges": edges,
            "cpm": cpm,
            "criticalPaths": critical_paths,
            "warnings": warnings,
        }
        with open(args.out_json, "w", encoding='utf-8') as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        print(f"\n（構造化データ: {args.out_json}）")


if __name__ == "__main__":
    main()
