// ble_manager.dart
import 'dart:typed_data';

import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BLEManager {
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  bool _isAdvertising = false;

  /// Fires whenever a raw mesh-packet string is heard.
  Function(String raw)? onRawPacket;

  // simple de-duplication window
  final Map<String, DateTime> _lastHeard = {};

  /// Call once at startup.
  void startScanning() {
    FlutterBluePlus.startScan(
      timeout: const Duration(days: 1),
      androidScanMode: AndroidScanMode.lowLatency,
    );
    FlutterBluePlus.scanResults.listen((results) {
      if (_isAdvertising) return;
      final now = DateTime.now();
      for (final r in results) {
        final raw = _extractRaw(r.advertisementData);
        if (raw == null) continue;
        final last = _lastHeard[raw];
        if (last != null && now.difference(last) < const Duration(seconds: 3)) {
          continue;
        }
        _lastHeard[raw] = now;
        onRawPacket?.call(raw);
      }
    });
  }

  /// Broadcasts a raw mesh-packet string for 2 seconds.
  Future<void> advertiseMessage(String raw) async {
    _isAdvertising = true;
    await _peripheral.stop();

    final data = AdvertiseData(
      includeDeviceName: false,
      manufacturerId: 0x1234,
      manufacturerData: Uint8List.fromList(raw.codeUnits),
    );
    await _peripheral.start(advertiseData: data);
    await Future.delayed(const Duration(seconds: 2));
    await _peripheral.stop();

    _isAdvertising = false;
  }

  String? _extractRaw(AdvertisementData data) {
    final bytes = data.manufacturerData[0x1234];
    if (bytes == null || bytes.isEmpty) return null;
    return String.fromCharCodes(bytes);
  }
}
