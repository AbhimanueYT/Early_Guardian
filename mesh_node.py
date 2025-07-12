# mesh_node.py
import socket
import threading
import hashlib
import time

PORT = 5005
BROADCAST_IP = "255.255.255.255"

# Store hashes of recent messages to avoid rebroadcasting duplicates
recent_messages = set()
MESSAGE_EXPIRY_SECONDS = 30

def hash_message(msg):
    return hashlib.sha256(msg.encode()).hexdigest()

def broadcast_alert(message):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.sendto(message.encode(), (BROADCAST_IP, PORT))
    sock.close()
    print(f"[Mesh] Rebroadcasted: {message}")

def listen_and_repeat():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    try:
        sock.bind(("", PORT))
    except OSError as e:
        print(f"[Mesh] Failed to bind to port {PORT}: {e}")
        return

    print("[Mesh] Listening and ready to rebroadcast...")

    while True:
        data, addr = sock.recvfrom(1024)
        message = data.decode()
        message_hash = hash_message(message)

        if message_hash not in recent_messages:
            print(f"[Mesh] Received new: {message}")
            recent_messages.add(message_hash)
            broadcast_alert(message)

            # Clean up old hashes after timeout
            threading.Timer(MESSAGE_EXPIRY_SECONDS, lambda: recent_messages.discard(message_hash)).start()
        else:
            print(f"[Mesh] Ignored duplicate from {addr}")

if __name__ == "__main__":
    listen_and_repeat()
