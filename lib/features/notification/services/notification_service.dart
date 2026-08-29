import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';

/// Alaram suara + push/local notification untuk peringatan sesi hampir habis.
///
/// - Suara: `audioplayers` memutar assets/sounds/alert.wav secara looping
///   sampai direspons (dialog ditutup / tombol ditekan).
/// - Push notification: FCM payload berisi `route` (misal `/table/abc`)
///   supaya tap notifikasi langsung deep-link via go_router.
class NotificationService {
  final AudioPlayer _player = AudioPlayer();
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _soundPlaying = false;
  GoRouter? _router;

  static const _channelId = 'session_alerts';
  static const _channelName = 'Peringatan Sesi Meja';
  static const _channelDesc = 'Pemberitahuan sesi meja hampir habis atau waktu habis';

  /// Inisialisasi di main(): request izin, setup local channel, handle tap.
  Future<void> init({required GoRouter router}) async {
    _router = router;

    try {
      if (!kIsWeb) {
        await _initLocalNotifications();
      }
    } catch (e) {
      debugPrint('[notif] local notifications tidak tersedia: $e');
    }

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Foreground message: tampilkan sebagai local notification
      FirebaseMessaging.onMessage.listen(_showLocalNotification);

      // App dibuka dari notifikasi saat background/terminated → deep link
      FirebaseMessaging.onMessageOpenedApp.listen(_navigateFromMessage);
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        _navigateFromMessage(initial);
      }

      _saveToken(messaging);
    } catch (e) {
      debugPrint('[notif] FCM tidak tersedia di platform ini: $e');
    }
  }

  void _saveToken(FirebaseMessaging messaging) {
    messaging.getToken().then((token) {
      if (token == null) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            {'fcm_token': token},
            SetOptions(merge: true),
          );
    });
  }

Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // Windows butuh settings sendiri (required di v22+).
    final winInit = defaultTargetPlatform == TargetPlatform.windows
        ? WindowsInitializationSettings(
            appName: 'Yes Billiard',
            appUserModelId: 'yesbilliard.pos',
            guid: 'f1d0c0a0-1b2c-3d4e-5f6a-7b8c9d0e1f2a',
          )
        : null;

    final initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
      windows: winInit,
    );
    await _local.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && _router != null) navigateToRoute(_router!, route);
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
        ));
  }

  /// Tampilkan notifikasi peringatan + nyalakan alarm suara.
  Future<void> showSessionAlert({
    required String tableId,
    required String tableName,
    required String message,
  }) async {
    final route = '/table/$tableId';
    if (!kIsWeb) {
      await _local.show(
        id: DateTime.now().millisecondsSinceEpoch % 100000,
        title: '⏰ $tableName',
        body: message,
        notificationDetails: NotificationDetails(
          android: const AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
          ),
          iOS: const DarwinNotificationDetails(),
          windows: const WindowsNotificationDetails(),
        ),
        payload: route,
      );
    }
    await startAlarmSound();
  }

  Future<void> startAlarmSound() async {
    if (_soundPlaying) return;
    _soundPlaying = true;
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(1.0);
      await _player.play(AssetSource('sounds/alert.wav'));
    } catch (e) {
      debugPrint('[notif] alarm sound gagal: $e');
    }
  }

  Future<void> stopAlarmSound() async {
    if (!_soundPlaying) return;
    _soundPlaying = false;
    await _player.stop();
  }

  void _showLocalNotification(RemoteMessage message) {
    if (kIsWeb) return;
    final route = message.data['route'] as String?;
    _local.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch % 100000,
      title: message.notification?.title ?? 'Yes Billiard',
      body: message.notification?.body ?? '',
      notificationDetails: NotificationDetails(
        android: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
        windows: const WindowsNotificationDetails(),
      ),
      payload: route,
    );
  }

  void _navigateFromMessage(RemoteMessage message) {
    final route = message.data['route'] as String?;
    if (route != null && _router != null) navigateToRoute(_router!, route);
  }
}