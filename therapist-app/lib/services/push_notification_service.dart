import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/constants/app_config.dart';

/// Bridges FCM into the app: requests permission, keeps the server token in
/// sync, and renders foreground messages as local notifications (Android does
/// not display FCM notifications while the app is in the foreground).
class PushNotificationService {
  PushNotificationService(this._api);

  final ApiClient _api;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'touch_of_cure_default',
    'Touch of Cure',
    description: 'Appointment, payment and chat notifications',
    importance: Importance.high,
  );

  /// Set by the app shell so a notification tap can navigate.
  void Function(Map<String, dynamic> data)? onNotificationTap;

  Future<void> initialise() async {
    await _requestPermission();
    await _setupLocalNotifications();

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // A notification that cold-started the app arrives here instead
    final RemoteMessage? initial =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // Tokens rotate; re-register whenever that happens
    FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);
  }

  Future<void> _requestPermission() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS needs this to show banners while the app is open
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _setupLocalNotifications() async {
    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null) return;
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        onNotificationTap?.call(data);
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    if (notification == null) return;

    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleTap(RemoteMessage message) {
    onNotificationTap?.call(message.data);
  }

  Future<void> _registerToken(String token) async {
    try {
      await _api.post(ApiRoutes.fcmToken, body: {'token': token});
    } catch (error) {
      debugPrint('Failed to register FCM token: $error');
    }
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref.watch(apiClientProvider));
});
