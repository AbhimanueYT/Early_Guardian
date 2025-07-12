// message_relay.dart
import 'package:early_guardian/ble_manager.dart';
import 'package:uuid/uuid.dart';

/// Mesh-packet with unique ID and TTL
class MeshPacket {
  final String packetId;
  final int ttl;
  final String payload;

  MeshPacket(this.packetId, this.ttl, this.payload);

  String encode() => '$packetId|$ttl|$payload';

  static MeshPacket? decode(String raw) {
    final parts = raw.split('|');
    if (parts.length < 3) return null;
    final ttl = int.tryParse(parts[1]) ?? 0;
    return MeshPacket(parts[0], ttl, parts[2]);
  }
}

class MessageRelay {
  final BLEManager _ble;
  final Set<String> _seen = {};
  final int _maxHops = 7;

  /// Fires when a new chat payload arrives.
  Function(String payload)? onMessageReceived;

  MessageRelay(this._ble) {
    _ble.onRawPacket = _handleRaw;
    _ble.startScanning();
  }

  void _handleRaw(String raw) {
    final packet = MeshPacket.decode(raw);
    if (packet == null) return;
    if (_seen.contains(packet.packetId)) return;
    _seen.add(packet.packetId);

    // deliver
    onMessageReceived?.call(packet.payload);
    // relay if hops remain
    if (packet.ttl > 1) {
      final next = MeshPacket(packet.packetId, packet.ttl - 1, packet.payload);
      _ble.advertiseMessage(next.encode());
    }
  }

  /// Broadcast a new message.
  void sendBroadcast(String text) {
    final id = const Uuid().v4();
    final packet = MeshPacket(id, _maxHops, text);
    _seen.add(id);
    _ble.advertiseMessage(packet.encode());
  }
}
