import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      notificationChannelId: 'udp_channel',
      initialNotificationTitle: 'UDP Listener',
      initialNotificationContent: 'Listening for UDP packets...',
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: (_) async {
        return true;
      },
    ),
  );
  await service.startService();
}

void onStart(ServiceInstance service) async {
  // Initialize notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // UDP socket
  RawDatagramSocket.bind(InternetAddress.anyIPv4, 5005).then((socket) {
    socket.listen((event) async {
      if (event == RawSocketEvent.read) {
        Datagram? dg = socket.receive();
        if (dg != null) {
          String message = String.fromCharCodes(dg.data);
          // Show notification
          await flutterLocalNotificationsPlugin.show(
            0,
            'UDP Message',
            message,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'udp_channel',
                'UDP Channel',
                channelDescription: 'UDP message notifications',
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
            ),
          );
        }
      }
    });
  });
}
