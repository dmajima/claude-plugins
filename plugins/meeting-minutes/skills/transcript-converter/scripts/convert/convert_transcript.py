"""汎用文字起こしファイルを標準構造（transcript.txt + metadata.json）に変換する"""
import sys
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path


def parse_time_hms(s: str) -> float:
    parts = s.strip().replace(',', '.').split(':')
    if len(parts) == 3:
        return int(parts[0]) * 3600 + int(parts[1]) * 60 + float(parts[2])
    if len(parts) == 2:
        return int(parts[0]) * 60 + float(parts[1])
    return float(parts[0])


def format_time(seconds: float) -> str:
    total = int(seconds)
    h, rem = divmod(total, 3600)
    m, s = divmod(rem, 60)
    return f"{h:02d}:{m:02d}:{s:02d}"


def detect_format(text: str, ext: str) -> str:
    if ext == '.vtt' or text.strip().startswith('WEBVTT'):
        return 'vtt'
    if ext == '.srt':
        return 'srt'
    lines = text.strip().split('\n')
    if lines and re.match(r'^\d+$', lines[0].strip()):
        if len(lines) > 1 and '-->' in lines[1]:
            return 'srt'
    if re.search(r'\[\d{2}:\d{2}:\d{2}\s*-\s*\d{2}:\d{2}:\d{2}\]', text[:500]):
        return 'ailead'
    teams_hits = sum(1 for line in lines[:20] if re.match(r'^.{2,30}\s+\d{1,2}:\d{2}$', line.strip()))
    if teams_hits >= 2:
        return 'teams-paste'
    return 'plain'


def parse_vtt(text: str) -> list[dict]:
    segments = []
    blocks = re.split(r'\n\s*\n', text)
    for block in blocks:
        lines = block.strip().split('\n')
        time_line = None
        text_lines = []
        for line in lines:
            if '-->' in line:
                time_line = line
            elif time_line and line.strip() and not line.strip().startswith('WEBVTT') and not re.match(r'^\d+$', line.strip()):
                text_lines.append(line.strip())
        if time_line and text_lines:
            m = re.match(r'(\d[\d:.]+)\s*-->\s*(\d[\d:.]+)', time_line)
            if m:
                start = parse_time_hms(m.group(1))
                end = parse_time_hms(m.group(2))
                full_text = ' '.join(text_lines)
                speaker = 'Unknown'
                vm = re.match(r'<v\s+([^>]+)>(.*?)(?:</v>)?$', full_text)
                if vm:
                    speaker = vm.group(1).strip()
                    full_text = vm.group(2).strip()
                    full_text = re.sub(r'</v>', '', full_text).strip()
                segments.append({
                    'speaker': speaker,
                    'text': full_text,
                    'startTime': start,
                    'endTime': end,
                })
    return segments


def parse_srt(text: str) -> list[dict]:
    segments = []
    blocks = re.split(r'\n\s*\n', text.strip())
    for block in blocks:
        lines = block.strip().split('\n')
        if len(lines) < 2:
            continue
        time_line = None
        for line in lines:
            if '-->' in line:
                time_line = line
                break
        if not time_line:
            continue
        m = re.match(r'(\d[\d:,.]+)\s*-->\s*(\d[\d:,.]+)', time_line)
        if not m:
            continue
        start = parse_time_hms(m.group(1))
        end = parse_time_hms(m.group(2))
        text_lines = []
        found_time = False
        for line in lines:
            if '-->' in line:
                found_time = True
                continue
            if found_time and line.strip() and not re.match(r'^\d+$', line.strip()):
                text_lines.append(line.strip())
        segments.append({
            'speaker': 'Unknown',
            'text': ' '.join(text_lines),
            'startTime': start,
            'endTime': end,
        })
    return segments


def parse_ailead(text: str) -> list[dict]:
    segments = []
    for line in text.strip().split('\n'):
        m = re.match(
            r'\[(\d{2}:\d{2}:\d{2})\s*-\s*(\d{2}:\d{2}:\d{2})\]\s*(.+?):\s*(.*)',
            line.strip(),
        )
        if m:
            segments.append({
                'speaker': m.group(3).strip(),
                'text': m.group(4).strip(),
                'startTime': parse_time_hms(m.group(1)),
                'endTime': parse_time_hms(m.group(2)),
            })
    return segments


def parse_teams_paste(text: str) -> list[dict]:
    segments = []
    current_speaker = None
    current_time = 0.0
    for line in text.strip().split('\n'):
        header = re.match(r'^(.{2,30})\s+(\d{1,2}:\d{2})$', line.strip())
        if header:
            current_speaker = header.group(1).strip()
            current_time = parse_time_hms(header.group(2))
        elif line.strip() and current_speaker:
            segments.append({
                'speaker': current_speaker,
                'text': line.strip(),
                'startTime': current_time,
                'endTime': current_time + 30,
            })
    return segments


def parse_plain(text: str) -> list[dict]:
    segments = []
    for i, line in enumerate(text.strip().split('\n')):
        if line.strip():
            segments.append({
                'speaker': 'Unknown',
                'text': line.strip(),
                'startTime': 0.0,
                'endTime': 0.0,
            })
    return segments


def build_transcript_txt(segments: list[dict]) -> str:
    lines = []
    for seg in segments:
        start = format_time(seg['startTime'])
        end = format_time(seg['endTime'])
        lines.append(f"[{start} - {end}] {seg['speaker']}: {seg['text']}")
    return '\n'.join(lines)


def build_metadata(segments: list[dict], source: str, title: str) -> dict:
    speakers = defaultdict(int)
    for seg in segments:
        speakers[seg['speaker']] += len(seg['text'])
    total_chars = sum(speakers.values()) or 1
    participants = [
        {'name': name, 'talkRatio': round(chars / total_chars, 4)}
        for name, chars in sorted(speakers.items(), key=lambda x: -x[1])
    ]
    duration = 0
    if segments:
        start_times = [s['startTime'] for s in segments if s['startTime'] > 0]
        end_times = [s['endTime'] for s in segments if s['endTime'] > 0]
        if start_times and end_times:
            duration = int(max(end_times) - min(start_times))

    system = 'unknown'
    if source == 'vtt':
        system = 'teams'
    elif source == 'teams-paste':
        system = 'teams'

    return {
        'title': title,
        'startDatetime': '',
        'duration': duration,
        'system': system,
        'participants': participants,
        'source': source,
        'hostUser': '',
    }


def main():
    parser = argparse.ArgumentParser(description='Convert transcript to standard format')
    parser.add_argument('--input', required=True, help='Input file path')
    parser.add_argument('--output', required=True, help='Output directory')
    parser.add_argument('--title', default='', help='Meeting title (optional)')
    args = parser.parse_args()

    input_path = Path(args.input)
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    with open(input_path, 'r', encoding='utf-8') as f:
        text = f.read()

    ext = input_path.suffix.lower()
    fmt = detect_format(text, ext)
    print(f"Detected format: {fmt}")

    parsers = {
        'vtt': parse_vtt,
        'srt': parse_srt,
        'ailead': parse_ailead,
        'teams-paste': parse_teams_paste,
        'plain': parse_plain,
    }
    segments = parsers[fmt](text)
    print(f"Parsed segments: {len(segments)}")

    title = args.title or input_path.stem
    transcript_txt = build_transcript_txt(segments)
    metadata = build_metadata(segments, fmt, title)

    with open(output_dir / 'transcript.txt', 'w', encoding='utf-8') as f:
        f.write(transcript_txt)

    with open(output_dir / 'metadata.json', 'w', encoding='utf-8') as f:
        json.dump(metadata, f, ensure_ascii=False, indent=2)

    print(f"Output: {output_dir / 'transcript.txt'} ({len(segments)} segments)")
    print(f"Output: {output_dir / 'metadata.json'}")
    print(f"Participants: {len(metadata['participants'])}")
    print(f"Duration: {metadata['duration']}s")


if __name__ == '__main__':
    main()
