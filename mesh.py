# mesh.py
import socket
import threading

PORT = 5005
BROADCAST_IP = "255.255.255.255"

def broadcast_alert(message):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.sendto(message.encode(), (BROADCAST_IP, PORT))
    sock.close()

def listen_for_alerts(callback):
    def listener():
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        # Allow multiple bindings on the same port (Windows fix)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            sock.bind(("", PORT))
        except OSError as e:
            print(f"[Mesh] Failed to bind to port {PORT}: {e}")
            return
        print("[Mesh] Listening for alerts...")
        while True:
            data, addr = sock.recvfrom(1024)
            alert = data.decode()
            print(f"[Mesh] Received: {alert}")
            callback(alert)

    t = threading.Thread(target=listener, daemon=True)
    t.start()

