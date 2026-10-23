#!/usr/bin/env python3
"""Server WebSocket cho bảng vẽ chung (dùng thư viện `websockets`).

Đây chính là "NGUỒN SỰ THẬT DUY NHẤT":
  - Khi đang kéo, máy gửi từng đoạn điểm nhỏ ("live"); server chuyển ngay cho các máy KHÁC => thấy nét realtime.
  - Khi nhấc tay, máy gửi "end"; server gán số thứ tự `seq` tăng dần, lưu vào danh sách duy nhất, rồi phát nét chốt cho TẤT CẢ máy.
  - Máy nào mới kết nối sẽ nhận "snapshot" = toàn bộ các nét đã chốt + các nét đang vẽ dở.
=> Mọi máy đều nhận cùng một dãy nét theo cùng thứ tự `seq`, nên tranh giống hệt nhau.

Cài và chạy (lần đầu):
    python3 -m venv Server/.venv && Server/.venv/bin/pip install websockets
    Server/.venv/bin/python Server/drawing_server.py
"""
import asyncio
import json

from websockets.asyncio.server import broadcast, serve
from websockets.exceptions import ConnectionClosed

PORT = 8765
MAX_POINTS = 5000

strokes = []   # danh sách nét đã chốt, duy nhất
live = {}      # strokeId -> nét đang vẽ dở (chưa có seq), kèm owner là kết nối đang vẽ nó
seq = 0        # số thứ tự toàn cục; asyncio xử lý từng tin một nên tăng seq không bao giờ bị 2 máy giành cùng lúc
clients = set()


def send_all(obj, exclude=None):
    """Gửi cho mọi máy đang kết nối (trừ `exclude` nếu có)."""
    broadcast(clients - {exclude} if exclude else clients, json.dumps(obj, ensure_ascii=False))


def live_view(s):
    return {k: s[k] for k in ("strokeId", "author", "colorIndex", "points")}


def clean_points(raw, min_len=2):
    if not isinstance(raw, list) or not (min_len <= len(raw) <= MAX_POINTS):
        return None
    out = []
    for p in raw:
        try:
            out.append({"x": min(max(float(p["x"]), 0.0), 1.0), "y": min(max(float(p["y"]), 0.0), 1.0)})
        except (KeyError, TypeError, ValueError):
            return None
    return out


def handle_message(text, ws):
    global seq
    try:
        msg = json.loads(text)
    except ValueError:
        return
    kind = msg.get("type")
    sid = str(msg.get("strokeId", ""))[:64]

    if kind == "live" and sid:
        chunk = clean_points(msg.get("points"), min_len=1)
        if chunk is None:
            return
        s = live.get(sid)
        if s is None:
            s = {"strokeId": sid, "author": str(msg.get("author", "?"))[:20],
                 "colorIndex": int(msg.get("colorIndex", 0)) % 6, "points": [], "owner": ws}
            live[sid] = s
        elif s["owner"] is not ws:
            return
        if len(s["points"]) + len(chunk) > MAX_POINTS:
            return
        s["points"].extend(chunk)
        # chuyển ngay đoạn điểm mới cho các máy KHÁC (máy gửi tự có bản nháp của nó)
        send_all({"type": "live", "strokeId": sid, "author": s["author"],
                  "colorIndex": s["colorIndex"], "points": chunk}, exclude=ws)

    elif kind == "end" and sid:
        s = live.get(sid)
        if s is None or s["owner"] is not ws:
            return
        del live[sid]
        if len(s["points"]) < 2:  # chỉ chạm 1 điểm => bỏ
            send_all({"type": "cancel", "strokeId": sid}, exclude=ws)
            return
        seq += 1
        stroke = {"seq": seq, "strokeId": sid, "author": s["author"],
                  "colorIndex": s["colorIndex"], "points": s["points"]}
        strokes.append(stroke)
        print(f"#{seq} nét từ {stroke['author']} ({len(stroke['points'])} điểm) -> phát cho {len(clients)} máy")
        send_all({"type": "stroke", "stroke": stroke})

    elif kind == "clear":
        strokes.clear()
        live.clear()
        print("xoá bảng")
        send_all({"type": "clear"})


async def handler(ws):
    """Chạy 1 lần cho mỗi máy kết nối, đến khi máy đó ngắt."""
    clients.add(ws)
    print(f"+ máy mới kết nối (tổng {len(clients)})")
    try:
        await ws.send(json.dumps({"type": "snapshot", "strokes": strokes,
                                  "live": [live_view(s) for s in live.values()]}, ensure_ascii=False))
        async for message in ws:  # mỗi tin nhắn máy gửi lên
            if isinstance(message, str):
                handle_message(message, ws)
    except ConnectionClosed:
        pass  # máy rớt đột ngột (tắt app, mất mạng) là chuyện bình thường, không cần in lỗi
    finally:
        clients.discard(ws)
        print(f"- máy ngắt kết nối (còn {len(clients)})")
        for sid, s in list(live.items()):  # máy rớt giữa chừng thì xoá nét dở của nó, tránh "nét ma" trên máy khác
            if s["owner"] is ws:
                del live[sid]
                send_all({"type": "cancel", "strokeId": sid})


async def main():
    async with serve(handler, "0.0.0.0", PORT):
        print(f"Server bảng vẽ chung đang chạy ở ws://127.0.0.1:{PORT}  (Ctrl+C để dừng)")
        await asyncio.Future()  # chạy mãi


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass

# 3. Trạng thái của server (nguồn sự thật)

# strokes = []   # các nét đã chốt, theo thứ tự
# live = {}      # các nét đang vẽ dở, tra theo strokeId
# seq = 0        # số thứ tự toàn cục
# clients = set()  # các kết nối đang mở
# Toàn bộ dữ liệu nằm trong bộ nhớ của tiến trình này. Tắt server là mất hết nét.

# 4. Luồng xử lý một tin nhắn

# Hàm handle_message xử lý 3 loại tin:

# ┌──────────────────┬──────────────────────────────────────────────────────────────────────────────┐
# │     Máy gửi      │                                Server làm gì                                 │
# ├──────────────────┼──────────────────────────────────────────────────────────────────────────────┤
# │ live (đoạn điểm) │ Gom điểm vào live[strokeId], chuyển ngay cho các máy khác                    │
# ├──────────────────┼──────────────────────────────────────────────────────────────────────────────┤
# │ end (nhấc tay)   │ Lấy nét trong live, tăng seq += 1, đưa vào strokes, phát nét chốt cho tất cả │
# ├──────────────────┼──────────────────────────────────────────────────────────────────────────────┤
# │ clear            │ Xoá strokes và live, báo tất cả máy                                          │
# └──────────────────┴──────────────────────────────────────────────────────────────────────────────┘

# Khi máy mới kết nối, server gửi snapshot gồm toàn bộ strokes và live hiện tại để máy đó bắt kịp.

# 5. Vì sao thứ tự không bao giờ bị lệch

# seq += 1 chỉ diễn ra ở đúng một nơi, trong một luồng duy nhất (asyncio chạy tuần tự từng tin). Dù hai máy nhấc tay cùng lúc, server vẫn xử lý lần lượt: ai đến trước nhận seq nhỏ hơn. Mọi máy sau đó nhận cùng một dãy theo cùng thứ tự seq. Đây là cốt lõi của "single source of truth".