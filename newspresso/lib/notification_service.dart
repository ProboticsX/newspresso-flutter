import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Must be a top-level function — called by FCM when app is terminated
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM shows the notification in the system tray automatically for
  // notification messages. Nothing extra needed here.
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Set by _MainShellState to navigate to an article when a notification is tapped
  void Function(String newsId)? onNotificationTap;

  // Holds a news ID from a terminated-app notification tap, drained once
  // the shell sets onNotificationTap
  String? _pendingNewsId;

  static const _channelId = 'breaking_news';
  static const _channelName = 'Breaking News';
  static const _channelDesc = 'Breaking news alerts from Newspresso';

  /// Call in main() BEFORE runApp() to register the background handler.
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  /// Call in _MainAppState.initState() — requests permission, subscribes to
  /// topic, sets up foreground/tap handlers.
  Future<void> initialize() async {
    // Request permission (shows dialog on iOS; on Android 13+ the OS dialog is
    // already triggered by the POST_NOTIFICATIONS permission in the manifest
    // but FCM's requestPermission() handles it correctly on both platforms).
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // All users subscribe to this topic — this is how breaking news is delivered
    await FirebaseMessaging.instance.subscribeToTopic('breaking_news');

    // Local notifications: used to show FCM messages when app is in foreground
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (details) {
        final newsId = details.payload;
        if (newsId != null && newsId.isNotEmpty) {
          _dispatch(newsId);
        }
      },
    );

    // Create the Android notification channel (no-op on iOS)
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Foreground messages: FCM doesn't show a heads-up on its own, so we
    // display a local notification manually
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Background (not terminated) tap: app was minimised, user tapped notification
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

    // Terminated tap: app was closed, user tapped notification to open it
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      final newsId = initial.data['article_id'];
      if (newsId != null && newsId.isNotEmpty) {
        _pendingNewsId = newsId;
      }
    }
  }

  /// Call this from _MainShellState.initState() after setting [onNotificationTap]
  /// to flush any notification tap that opened the app from a terminated state.
  void drainPending() {
    if (_pendingNewsId != null) {
      _dispatch(_pendingNewsId!);
      _pendingNewsId = null;
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    final newsId = message.data['article_id'] ?? '';
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      null,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: newsId,
    );
  }

  void _onNotificationTap(RemoteMessage message) {
    final newsId = message.data['article_id'];
    if (newsId != null && newsId.isNotEmpty) {
      _dispatch(newsId);
    }
  }

  void _dispatch(String newsId) {
    if (onNotificationTap != null) {
      onNotificationTap!(newsId);
    } else {
      // Shell not ready yet — hold it until drainPending() is called
      _pendingNewsId = newsId;
    }
  }
}
