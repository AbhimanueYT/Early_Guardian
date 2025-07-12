# receiver.py
import socket

PORT = 5005

def start_receiver():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    try:
        sock.bind(("", PORT))
    except OSError as e:
        print(f"[Receiver] Failed to bind to port {PORT}: {e}")
        return

    print("[Receiver] Listening for mesh alerts...")
    while True:
        data, addr = sock.recvfrom(1024)
        message = data.decode()
        print(f"[Receiver] Received from {addr}: {message}")

if __name__ == "__main__":
    start_receiver()
