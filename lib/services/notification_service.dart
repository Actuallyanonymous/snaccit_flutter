import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Top-level background message handler (must be top-level, not a class method).
/// FCM requires this to be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages with a `notification` payload are automatically shown
  // by the system on Android/iOS. No extra work needed here.
  debugPrint('[NotificationService] Background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Android notification channel for order updates
  static const AndroidNotificationChannel
  _orderChannel = AndroidNotificationChannel(
    'snaccit_order_updates', // id
    'Order Updates', // name
    description:
        'Notifications about your order status (accepted, preparing, ready)',
    importance: Importance.high,
    enableVibration: true,
    playSound: true,
  );

  // Android notification channel for promotional messages
  static const AndroidNotificationChannel _promoChannel =
      AndroidNotificationChannel(
        'snaccit_promotions', // id
        'Promotions & Updates', // name
        description: 'Deals, offers, and announcements from Snaccit',
        importance: Importance.defaultImportance,
      );

  /// Initialize the full notification pipeline.
  /// Call this once in main() after Firebase.initializeApp().
  Future<void> initialize() async {
    // 1. Create Android notification channels
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_orderChannel);
      await androidPlugin.createNotificationChannel(_promoChannel);
    }

    // 2. Initialize flutter_local_notifications (for foreground display)
    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // 3. Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
      '[NotificationService] Permission status: ${settings.authorizationStatus}',
    );

    // 4. Listen for foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. Handle notification taps when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 6. Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    debugPrint('[NotificationService] Initialized successfully');
  }

  /// Get the current FCM token (call after login to save to Firestore).
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Listen for token refresh events.
  /// Call this after login so token changes get persisted.
  void onTokenRefresh(void Function(String token) callback) {
    _messaging.onTokenRefresh.listen(callback);
  }

  /// Save / update the user's FCM token in Firestore.
  Future<void> saveTokenToFirestore(String userId) async {
    try {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(userId).update(
          {'fcmToken': token},
        );
        debugPrint('[NotificationService] Token saved for user $userId');
      }
    } catch (e) {
      debugPrint('[NotificationService] Error saving token: $e');
    }
  }

  /// Remove FCM token on logout to stop receiving notifications.
  Future<void> removeToken(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
      });
      await _messaging.deleteToken();
      debugPrint('[NotificationService] Token removed for user $userId');
    } catch (e) {
      debugPrint('[NotificationService] Error removing token: $e');
    }
  }

  // ─── Handlers ───

  /// Show a local notification when a message arrives while app is in foreground.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      '[NotificationService] Foreground message: ${message.notification?.title}',
    );

    final notification = message.notification;
    if (notification == null) return;

    // Determine channel based on data payload
    final isOrder =
        message.data.containsKey('orderId') ||
        message.data['type'] == 'order_update';
    final channelId = isOrder ? _orderChannel.id : _promoChannel.id;
    final channelName = isOrder ? _orderChannel.name : _promoChannel.name;
    final channelDesc = isOrder
        ? _orderChannel.description
        : _promoChannel.description;

    _localNotifications.show(
      // Use hashCode of messageId for a unique, non-duplicate notification ID
      message.messageId.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: isOrder ? Importance.high : Importance.defaultImportance,
          priority: isOrder ? Priority.high : Priority.defaultPriority,
          icon: '@drawable/ic_notification',
          color: const Color(0xFF10B981),
          styleInformation: BigTextStyleInformation(
            notification.body ?? '',
            contentTitle: notification.title,
          ),
        ),
      ),
      // Pass data so we can handle taps
      payload: jsonEncode(message.data),
    );
  }

  /// Handle tap on a notification that opened the app from background.
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[NotificationService] Notification tap: ${message.data}');
    // Navigation is handled via the deep-link pipeline in main.dart
    // or we could navigate directly if we have the navigatorKey.
    // For now the notification payload contains orderId in data.
  }

  /// Handle tap on a local notification (foreground tap).
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
      '[NotificationService] Local notification tapped: ${response.payload}',
    );
    // Could navigate to order detail here if needed
  }
}
