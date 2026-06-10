"""構造化議事録データ（JSON v2.0）から Markdown ファイルを生成する"""
import sys
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

import argparse
import json
from pathlib import Path
from typing import Optional


def format_participants(participants: list) -> str:
    by_org = {}
    for p in participants:
        org = p.get('organization', '')
        name = p.get('name', '')
        if org not in by_org:
            by_org[org] = []
        by_org[org].append(name)

    lines = []
    for org, names in by_org.items():
        prefix = f"{org} / " if org else ""
        for n in names:
            lines.append(f"- {prefix}{n}")
    return '\n'.join(lines) if lines else '- （参加者情報なし）'


def format_time_display(metadata: dict) -> str:
    date_str = metadata.get('date', '')
    start = metadata.get('startTime', '')
    end = metadata.get('endTime', '')
    dur = metadata.get('durationMinutes', '')
    display = f"{date_str}  {start} - {end}" if start else date_str
    if dur:
        display += f"（{dur}分）"
    return display


def render_agenda(agenda: dict) -> list[str]:
    lines = []
    aid = agenda.get('id', '')
    lines.append(f"## {aid}. {agenda.get('title', '')}")
    lines.append('')

    sections = [
        ('background', '背景・目的:', False),
        ('specifications', '仕様・機能詳細:', True),
        ('discussions', '議論の内容:', True),
        ('concerns', '懸念点:', True),
        ('conclusions', '結論・合意事項:', True),
    ]

    for field, heading, is_list in sections:
        value = agenda.get(field, [] if is_list else '')
        if not value:
            continue
        lines.append(f"### {heading}")
        if is_list:
            for item in value:
                lines.append(f"- {item}")
        else:
            lines.append(str(value))
        lines.append('')

    lines.append('---')
    lines.append('')
    return lines


def render_action_items(items: list) -> list[str]:
    lines = ['## アクションまとめ', '']
    if not items:
        lines.append('なし')
        lines.append('')
        return lines

    for idx, item in enumerate(items, 1):
        label = item.get('label', '')
        heading = f"{item.get('id', idx)}. {label}" if label else f"{item.get('id', idx)}."
        lines.append(heading)
        lines.append(f"   担当: {item.get('assignee', '')}")
        lines.append(f"   期限: {item.get('deadline', '')}")
        lines.append(f"   内容: {item.get('content', '')}")
        lines.append('')
    return lines


def render_next_meeting(next_meeting: Optional[dict]) -> list[str]:
    lines = ['---', '', '## 次回予定', '']
    if not next_meeting:
        lines.append('未定')
        lines.append('')
        return lines

    if next_meeting.get('date'):
        lines.append(f"日時: {next_meeting['date']}")
    planned = next_meeting.get('plannedAgendas', []) or []
    if planned and isinstance(planned, list):
        lines.append(f"議題（予定）: {', '.join(str(a) for a in planned)}")
    preps = next_meeting.get('preparations', []) or []
    if preps:
        lines.append('')
        lines.append('準備事項:')
        for p in preps:
            lines.append(f"- {p.get('task', '')}（{p.get('assignee', '')}）")
    lines.append('')
    return lines


def generate(input_path: str, output_path: str):
    try:
        with open(input_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except FileNotFoundError:
        print(f"ERROR: Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in {input_path}: {e}", file=sys.stderr)
        sys.exit(1)

    metadata = data.get('metadata', {})
    agendas = data.get('agendas', [])
    action_items = data.get('actionItems', [])
    next_meeting = data.get('nextMeeting', {})

    lines = []

    title = metadata.get('title', '会議議事録')
    lines.append(f"# 【会議議事録】{title}")
    lines.append('')
    lines.append(f"日時: {format_time_display(metadata)}")
    lines.append('')
    lines.append(f"場所: {metadata.get('location', 'オンライン会議')}")
    lines.append('')
    lines.append('出席者:')
    lines.append(format_participants(metadata.get('participants', [])))
    lines.append('')
    lines.append('---')
    lines.append('')

    for agenda in agendas:
        lines.extend(render_agenda(agenda))

    lines.extend(render_action_items(action_items))
    lines.extend(render_next_meeting(next_meeting))
    lines.append('')

    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

    print(f"Generated: {output_path}")


def main():
    parser = argparse.ArgumentParser(description='Generate meeting minutes markdown')
    parser.add_argument('--input', required=True, help='Path to minutes.json')
    parser.add_argument('--output', required=True, help='Output markdown path')
    args = parser.parse_args()
    generate(args.input, args.output)


if __name__ == '__main__':
    main()
