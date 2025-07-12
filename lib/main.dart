// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'udp_channel',
      initialNotificationTitle: 'UDP Listener',
      // initialNotificationContent: 'Listening for UDP packets on port 5005...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: (_) async => true,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Set up foreground service immediately for Android to prevent timeout
  if (service is AndroidServiceInstance) {
    try {
      service.setAsForegroundService();
      // service.setForegroundNotificationInfo(
      //   title: "UDP Listener",
      //   content: "Initializing UDP listener...",
      // );
    } catch (e) {
      print('[UDP Receiver] Error setting foreground service: $e');
      // Continue anyway, the service might still work
    }
  }

  // Initialize notifications
  final notifications = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await notifications.initialize(initSettings);

  // Create notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'udp_channel',
    'UDP Channel',
    description: 'Channel for UDP background service notifications',
    importance: Importance.max,
  );
  await notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // Initialize UDP socket
  RawDatagramSocket? udp;
  try {
    // Try to bind to port 5005
    udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 5005);
    print('[UDP Receiver] Successfully bound to port 5005');

    // Update notification to show successful binding
    if (service is AndroidServiceInstance) {
      // service.setForegroundNotificationInfo(
      //   title: "UDP Listener Active",
      //   content: "Listening on port 5005",
      // );
    }
  } catch (e) {
    print('[UDP Receiver] Failed to bind to port 5005: $e');

    // Try alternative port if 5005 is busy
    try {
      udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 5006);
      print('[UDP Receiver] Successfully bound to alternative port 5006');

      if (service is AndroidServiceInstance) {
        // service.setForegroundNotificationInfo(
        //   title: "UDP Listener Active",
        //   content: "Listening on port 5006 (5005 was busy)",
        // );
      }
    } catch (e2) {
      print('[UDP Receiver] Failed to bind to alternative port 5006: $e2');

      // Try binding to any available port
      try {
        udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
        print('[UDP Receiver] Successfully bound to dynamic port');

        if (service is AndroidServiceInstance) {
          // service.setForegroundNotificationInfo(
          //   title: "UDP Listener Active",
          //   content: "Listening on dynamic port",
          // );
        }
      } catch (e3) {
        print('[UDP Receiver] Failed to bind to any port: $e3');
        if (service is AndroidServiceInstance) {
          // service.setForegroundNotificationInfo(
          //   title: "UDP Listener Error",
          //   content: "Failed to bind to any port. Check network permissions.",
          // );
        }
        return;
      }
    }
  }

  // Main UDP listening loop
  int notificationId = 0;
  bool isRunning = true;

  try {
    // Set up the UDP listener
    udp!.listen((RawSocketEvent event) async {
      if (event == RawSocketEvent.read && isRunning) {
        try {
          final datagram = udp!.receive();
          if (datagram != null) {
            final message = String.fromCharCodes(datagram.data);
            final sender = datagram.address.address;
            final port = datagram.port;
            final timestamp = DateTime.now().toIso8601String();

            print('[UDP Receiver] Received from $sender:$port: $message');

            // Store message in shared preferences
            try {
              final prefs = await SharedPreferences.getInstance();
              final messagesKey = 'udp_messages';
              final existingMessages = prefs.getStringList(messagesKey) ?? [];

              // Create message object
              final messageData = {
                'message': message,
                'sender': sender,
                'port': port,
                'timestamp': timestamp,
              };

              // Add new message to the beginning (most recent first)
              existingMessages.insert(0, jsonEncode(messageData));

              // Keep only last 50 messages to prevent storage overflow
              if (existingMessages.length > 50) {
                existingMessages.removeRange(50, existingMessages.length);
              }

              await prefs.setStringList(messagesKey, existingMessages);
            } catch (e) {
              print('[UDP Receiver] Error storing message: $e');
            }

            // Show notification
            try {
              await notifications.show(
                notificationId++,
                'UDP Message',
                'From $sender:$port\n$message',
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'udp_channel',
                    'UDP Channel',
                    importance: Importance.max,
                    priority: Priority.high,
                    showWhen: true,
                    enableVibration: true,
                    playSound: true,
                  ),
                ),
              );
            } catch (e) {
              print('[UDP Receiver] Error showing notification: $e');
            }

            // Update foreground notification with latest message
            if (service is AndroidServiceInstance) {
              try {
                service.setForegroundNotificationInfo(
                  title: "UDP Listener Active",
                  content:
                      "Last message: ${message.length > 30 ? '${message.substring(0, 30)}...' : message}",
                );
              } catch (e) {
                print(
                  '[UDP Receiver] Error updating foreground notification: $e',
                );
              }
            }
          }
        } catch (e) {
          print('[UDP Receiver] Error processing datagram: $e');
        }
      }
    });

    // Handle service stop
    service.on('stopService').listen((_) {
      print('[UDP Receiver] Stopping service...');
      isRunning = false;
      udp?.close();
      service.stopSelf();
    });

    // Keep the service running indefinitely
    print('[UDP Receiver] Service started and listening for UDP packets...');
    while (isRunning) {
      await Future.delayed(const Duration(seconds: 5));

      // Update notification periodically to show service is still alive
      if (service is AndroidServiceInstance) {
        try {
          // service.setForegroundNotificationInfo(
          //   title: "UDP Listener Active",
          //   content:
          //       "Listening for UDP packets... (${notificationId} messages received)",
          // );
        } catch (e) {
          print('[UDP Receiver] Error updating periodic notification: $e');
        }
      }
    }
  } catch (e) {
    print('[UDP Receiver] Fatal error in main loop: $e');
    if (service is AndroidServiceInstance) {
      try {
        service.setForegroundNotificationInfo(
          title: "UDP Listener Error",
          content:
              "Service encountered an error: ${e.toString().substring(0, 50)}...",
        );
      } catch (notifError) {
        print('[UDP Receiver] Error showing error notification: $notifError');
      }
    }
  } finally {
    // Cleanup
    isRunning = false;
    udp?.close();
    print('[UDP Receiver] Service stopped');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UDP Receiver',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const UDPReceiverPage(),
    );
  }
}

class UDPReceiverPage extends StatefulWidget {
  const UDPReceiverPage({super.key});

  @override
  State<UDPReceiverPage> createState() => _UDPReceiverPageState();
}

class _UDPReceiverPageState extends State<UDPReceiverPage> {
  bool _serviceRunning = false;
  String _status = 'Service not running.';
  String _activePort = '5005';
  List<Map<String, dynamic>> _receivedMessages = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    _loadMessages();
    // Refresh messages every 2 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_serviceRunning) {
        _loadMessages();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesKey = 'udp_messages';
      final messageStrings = prefs.getStringList(messagesKey) ?? [];

      final messages =
          messageStrings
              .map((msgStr) {
                try {
                  return Map<String, dynamic>.from(jsonDecode(msgStr));
                } catch (e) {
                  return null;
                }
              })
              .where((msg) => msg != null)
              .cast<Map<String, dynamic>>()
              .toList();

      if (mounted) {
        setState(() {
          _receivedMessages = messages;
        });
      }
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _checkServiceStatus() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    setState(() {
      _serviceRunning = isRunning;
      _status =
          isRunning
              ? '🟢 UDP service running on port $_activePort • ${_receivedMessages.length} messages received'
              : '🔴 Service not running';
    });
  }

  Future<bool> _checkAndRequestPermissions() async {
    bool granted = true;
    if (Platform.isAndroid) {
      // Android 13+ notification permission
      if (await Permission.notification.isDenied) {
        final notif = await Permission.notification.request();
        if (!notif.isGranted) granted = false;
      }

      // Foreground service permission (Android 9+)
      if (await Permission.systemAlertWindow.isDenied) {
        final fg = await Permission.systemAlertWindow.request();
        if (!fg.isGranted) granted = false;
      }

      // Battery optimizations (optional, for reliability)
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        final ignore = await Permission.ignoreBatteryOptimizations.request();
        if (!ignore.isGranted) granted = false;
      }

      // Location permissions (required for network access on some devices)
      if (await Permission.location.isDenied) {
        final location = await Permission.location.request();
        if (!location.isGranted) granted = false;
      }
    }
    return granted;
  }

  Future<void> _startService() async {
    final hasPerm = await _checkAndRequestPermissions();
    if (!hasPerm) {
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Permissions Required'),
                content: const Text(
                  'This app needs the following permissions for UDP communication:\n\n'
                  '• Notifications: To show UDP messages\n'
                  '• Foreground Service: To run UDP listener in background\n'
                  '• Location: Required for network access on some devices\n'
                  '• Battery Optimization: For reliable background operation\n\n'
                  'Note: On Android 14+, additional foreground service permissions may be required.\n\n'
                  'Please grant these permissions to use the UDP receiver.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
      return;
    }

    try {
      final service = FlutterBackgroundService();
      final started = await service.startService();

      setState(() {
        _serviceRunning = started;
        _status =
            started
                ? '🟢 UDP service running on port 5005 • ${_receivedMessages.length} messages received'
                : '🔴 Failed to start service';
      });

      if (started) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('UDP listener started successfully on port 5005'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh messages after a short delay to show any new messages
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            _loadMessages();
            _checkServiceStatus();
          }
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error starting service: $e';
      });
    }
  }

  Future<void> _stopService() async {
    try {
      final service = FlutterBackgroundService();
      service.invoke('stopService');

      setState(() {
        _serviceRunning = false;
        _status = 'Service stopped.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('UDP listener stopped'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      setState(() {
        _status = 'Error stopping service: $e';
      });
    }
  }

  Future<void> _clearMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('udp_messages');
      setState(() {
        _receivedMessages = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Messages cleared'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('Error clearing messages: $e');
    }
  }

  Future<void> _testUDPConnection() async {
    try {
      // Try to send a test UDP packet to localhost
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final testData = 'test'.codeUnits;
      socket.send(testData, InternetAddress.loopbackIPv4, 5005);
      socket.close();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('UDP test packet sent to port 5005'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('UDP test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UDP Receiver'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _testUDPConnection,
            icon: const Icon(Icons.wifi_tethering),
            tooltip: 'Test UDP',
          ),
          IconButton(
            onPressed: _loadMessages,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Messages',
          ),
          if (_receivedMessages.isNotEmpty)
            IconButton(
              onPressed: _clearMessages,
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear Messages',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _serviceRunning ? null : _startService,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start UDP'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _serviceRunning ? _stopService : null,
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop UDP'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UDP Configuration',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Port: $_activePort (primary: 5005, fallback: 5006)'),
                    const Text('Protocol: UDP'),
                    const Text('Mode: Broadcast/Unicast'),
                    const SizedBox(height: 8),
                    const Text(
                      'This app listens for UDP packets and shows notifications for received messages.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Make this card Expanded so it takes up remaining space
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Received Messages (${_receivedMessages.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (_receivedMessages.isNotEmpty)
                            TextButton.icon(
                              onPressed: _clearMessages,
                              icon: const Icon(Icons.clear_all, size: 16),
                              label: const Text('Clear'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_receivedMessages.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'No messages received yet.\nStart the UDP listener and send some test messages.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else
                        // Wrap ListView in Flexible to fix layout issues
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _receivedMessages.length,
                            itemBuilder: (context, index) {
                              final msg = _receivedMessages[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                child: ListTile(
                                  title: Text(
                                    msg['message'] ?? 'Unknown message',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${_formatTimestamp(msg['timestamp'])} • From: ${msg['sender']}:${msg['port']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  leading: const Icon(
                                    Icons.message,
                                    color: Colors.blue,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
