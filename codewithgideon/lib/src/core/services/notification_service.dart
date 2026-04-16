import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  String? _pendingPayload;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationTap(response.payload);
      },
    );

    final androidImplementation = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.requestNotificationsPermission();

    final launchDetails = await _flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _pendingPayload = launchDetails?.notificationResponse?.payload;
    }
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'codewithgideon_channel',
          'CodeWithGideon Notifications',
          channelDescription: 'Notifications for CodeWithGideon app',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails();

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  Future<void> showNewMessageNotification({String? payload}) async {
    await showNotification(
      title: 'New Message',
      body: 'You have a new message from your cohort.',
      payload: payload ?? '/community/messages',
    );
  }

  Future<void> showLiveClassNotification() async {
    await showNotification(
      title: 'Live Class Starting',
      body: 'Your class is now live! Join now.',
      payload: '/classes',
    );
  }

  Future<void> showRecordingReadyNotification() async {
    await showNotification(
      title: 'Recording Ready',
      body: 'Your class recording is now available.',
      payload: '/classes',
    );
  }

  void consumePendingNavigation() {
    final payload = _pendingPayload;
    if (payload == null || payload.trim().isEmpty) return;

    final context = appRootNavigatorKey.currentContext;
    if (context == null) return;

    _pendingPayload = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigatorContext = appRootNavigatorKey.currentContext;
      if (navigatorContext == null) return;
      GoRouter.of(navigatorContext).push(payload);
    });
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null || payload.trim().isEmpty) return;
    _pendingPayload = payload;
    consumePendingNavigation();
  }
}
