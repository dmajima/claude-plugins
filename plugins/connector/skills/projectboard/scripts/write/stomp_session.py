# stomp_session.py - HUE ProjectBoard の WebSocket+STOMP 接続を確立し、
# 接続を保持したまま REST 書き込みコマンドを実行するラッパ。
#
# 背景（重要）:
#   ProjectBoard の書き込み API（/wbs/project/node/*）に渡す connectionId は、
#   SockJS の session_id であり、サーバはこの connectionId が「生きた WebSocket+STOMP
#   接続」として登録済みかを検証する。ランダム値だけでは 500（System Error）になる。
#   そのため書き込み前に本スクリプトで WebSocket を張り、STOMP CONNECT で connectionId を
#   登録し、その接続を保持したまま REST 書き込みを実行する必要がある。
#
# 使い方:
#   python stomp_session.py <WORK_DIR> <TENANT> <PROJECT_UUID> <SHEET_WBS_ID> -- <command...>
#     - <command...> は環境変数 PB_CONNECTION_ID を参照して REST 書き込みを行うコマンド。
#       本スクリプトが connectionId を生成し PB_CONNECTION_ID として子プロセスへ渡す。
#     - 子プロセスの標準出力/エラー/終了コードをそのまま中継する。
#
# 依存: Python 標準ライブラリのみ（socket, ssl, base64, hashlib, struct, secrets, subprocess）。
#
# 認証: <WORK_DIR>/cookies.txt（login.sh が生成した Netscape cookie jar）から SESSION /
#       XSRF-TOKEN を読み、WebSocket ハンドシェイクの Cookie ヘッダに付与する。
import sys
import os
import socket
import ssl
import base64
import struct
import secrets
import subprocess
import threading
import time

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

NUL = '\x00'


def log(msg):
    print(f"[stomp] {msg}", file=sys.stderr)


def read_cookies(cookie_file):
    """Netscape cookie jar から name=value を読む（#HttpOnly_ プレフィックスも処理）。"""
    cookies = {}
    with open(cookie_file, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if line.startswith('#HttpOnly_'):
                line = line[len('#HttpOnly_'):]
            elif not line or line.startswith('#'):
                continue
            parts = line.split('\t')
            if len(parts) >= 7:
                cookies[parts[5]] = parts[6]
    return cookies


def gen_connection_id():
    """SockJS session_id 相当の 8 文字英数字を生成する。"""
    alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return ''.join(secrets.choice(alphabet) for _ in range(8))


def recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("socket closed during recv")
        buf += chunk
    return buf


def ws_send_text(sock, text):
    """WebSocket テキストフレーム送信（クライアント→サーバはマスク必須）。"""
    payload = text.encode('utf-8')
    header = bytearray([0x81])  # FIN + opcode text
    mask = secrets.token_bytes(4)
    n = len(payload)
    if n < 126:
        header.append(0x80 | n)
    elif n < 65536:
        header.append(0x80 | 126)
        header += struct.pack('>H', n)
    else:
        header.append(0x80 | 127)
        header += struct.pack('>Q', n)
    header += mask
    masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
    sock.sendall(bytes(header) + masked)


def ws_recv_frame(sock, timeout=15):
    """WebSocket フレーム 1 つを受信しテキストを返す（制御フレームは読み飛ばす）。"""
    sock.settimeout(timeout)
    while True:
        b0b1 = recv_exact(sock, 2)
        opcode = b0b1[0] & 0x0f
        masked = b0b1[1] & 0x80
        length = b0b1[1] & 0x7f
        if length == 126:
            length = struct.unpack('>H', recv_exact(sock, 2))[0]
        elif length == 127:
            length = struct.unpack('>Q', recv_exact(sock, 8))[0]
        mask = recv_exact(sock, 4) if masked else None
        data = recv_exact(sock, length) if length else b""
        if mask:
            data = bytes(b ^ mask[i % 4] for i, b in enumerate(data))
        if opcode == 0x8:  # close
            raise ConnectionError("server closed websocket")
        if opcode in (0x9, 0xA):  # ping/pong は無視
            continue
        return data.decode('utf-8', 'replace')


def ws_handshake(host, path, cookies):
    raw = socket.create_connection((host, 443), timeout=30)
    ctx = ssl.create_default_context()
    sock = ctx.wrap_socket(raw, server_hostname=host)
    key = base64.b64encode(secrets.token_bytes(16)).decode()
    cookie_hdr = '; '.join(f'{k}={v}' for k, v in cookies.items())
    req = (
        f"GET {path} HTTP/1.1\r\n"
        f"Host: {host}\r\n"
        f"Upgrade: websocket\r\n"
        f"Connection: Upgrade\r\n"
        f"Sec-WebSocket-Key: {key}\r\n"
        f"Sec-WebSocket-Version: 13\r\n"
        f"Origin: https://{host}\r\n"
        f"Cookie: {cookie_hdr}\r\n"
        f"\r\n"
    )
    sock.sendall(req.encode())
    resp = b""
    sock.settimeout(30)
    while b"\r\n\r\n" not in resp:
        chunk = sock.recv(4096)
        if not chunk:
            break
        resp += chunk
    status_line = resp.split(b"\r\n", 1)[0].decode('latin-1', 'replace')
    if "101" not in status_line:
        raise RuntimeError(f"WebSocket handshake failed: {status_line}")
    return sock


def stomp_connect(sock, connection_id):
    """SockJS open(o) 受信 → STOMP CONNECT 送信 → CONNECTED 受信。"""
    # SockJS は接続直後に 'o' フレームを送る
    first = ws_recv_frame(sock)
    if not first.startswith('o'):
        log(f"warning: expected SockJS open 'o', got: {first[:40]!r}")
    connect_frame = (
        f"CONNECT\nconnectionId:{connection_id}\naccept-version:1.2\n"
        f"heart-beat:20000,20000\n\n{NUL}"
    )
    # SockJS のクライアント送信は JSON 配列文字列
    import json as _json
    ws_send_text(sock, _json.dumps([connect_frame]))
    # CONNECTED を待つ（a[...] 形式。h はハートビート）
    deadline = time.time() + 15
    while time.time() < deadline:
        frame = ws_recv_frame(sock)
        if frame.startswith('a'):
            if 'CONNECTED' in frame:
                return True
            if 'ERROR' in frame:
                raise RuntimeError(f"STOMP error: {frame[:200]}")
        # 'h'（heartbeat）/ 'o' は読み飛ばす
    raise RuntimeError("STOMP CONNECTED not received within timeout")


def heartbeat_loop(sock, stop_event):
    """接続維持のため定期的に SockJS ハートビートを送る（heart-beat:20000）。"""
    import json as _json
    while not stop_event.is_set():
        if stop_event.wait(15):
            break
        try:
            # STOMP ハートビートは改行 1 文字
            ws_send_text(sock, _json.dumps(["\n"]))
        except Exception:
            break


def main():
    argv = sys.argv[1:]
    if '--' not in argv:
        print("usage: stomp_session.py <WORK_DIR> <TENANT> <PROJECT_UUID> <SHEET_WBS_ID> -- <command...>",
              file=sys.stderr)
        return 2
    sep = argv.index('--')
    head = argv[:sep]
    command = argv[sep + 1:]
    if len(head) < 4 or not command:
        print("usage: stomp_session.py <WORK_DIR> <TENANT> <PROJECT_UUID> <SHEET_WBS_ID> -- <command...>",
              file=sys.stderr)
        return 2
    work_dir, tenant, project_uuid, sheet_wbs_id = head[:4]

    cookie_file = os.path.join(work_dir, "cookies.txt")
    if not os.path.isfile(cookie_file):
        print(f"ERROR: cookies.txt が見つかりません: {cookie_file}（先に login.sh を実行）", file=sys.stderr)
        return 1
    cookies = read_cookies(cookie_file)
    if 'SESSION' not in cookies:
        print("ERROR: cookies.txt に SESSION がありません（ログイン状態を確認）", file=sys.stderr)
        return 1

    host = f"{tenant}.pm.apps.worksap.com"
    connection_id = gen_connection_id()
    server_id = str(secrets.randbelow(900) + 100)  # SockJS server_id（3 桁）
    path = f"/portal/worktie-ws/{server_id}/{connection_id}/websocket"

    log(f"connecting WebSocket (connectionId={connection_id}) ...")
    sock = ws_handshake(host, path, cookies)
    stomp_connect(sock, connection_id)
    log("STOMP CONNECTED. 書き込みコマンドを実行します")

    stop_event = threading.Event()
    hb = threading.Thread(target=heartbeat_loop, args=(sock, stop_event), daemon=True)
    hb.start()

    # 子プロセスへ connectionId を渡して REST 書き込みを実行
    child_env = dict(os.environ)
    child_env['PB_CONNECTION_ID'] = connection_id
    try:
        result = subprocess.run(command, env=child_env)
        rc = result.returncode
    finally:
        stop_event.set()
        try:
            import json as _json
            ws_send_text(sock, _json.dumps([f"DISCONNECT\n\n{NUL}"]))
        except Exception:
            pass
        try:
            sock.close()
        except Exception:
            pass
    log(f"切断しました（child exit={rc}）")
    return rc


if __name__ == '__main__':
    sys.exit(main())
