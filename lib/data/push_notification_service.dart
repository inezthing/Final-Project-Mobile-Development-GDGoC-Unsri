import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart' show navigatorKey;
import '../pages/order_list_page.dart';
import '../pages/seller_orders_page.dart';

/// Handler background HARUS top-level function (bukan method di dalam
/// class) -- ini syarat wajib dari firebase_messaging di Android supaya
/// tetap bisa dipanggil walau app-nya lagi tidak jalan sama sekali
/// (terminated), bukan cuma di-minimize.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Sengaja kosong -- selama payload FCM ada field "notification" (bukan
  // cuma "data"), sistem operasi (Android/iOS) OTOMATIS nampilin notifnya
  // sendiri di system tray waktu app lagi background/terminated. Kita
  // cuma perlu nge-handle manual pas app-nya lagi KEBUKA (lihat onMessage
  // di bawah), karena di kondisi itu OS tidak nampilin apa-apa.
  debugPrint('Push diterima waktu background: ${message.messageId}');
}

/// Servis buat semua urusan push notification:
/// 1. Minta izin notifikasi ke user
/// 2. Ambil & simpan FCM token device ini ke Supabase (tabel `device_tokens`)
///    supaya backend tahu ke mana push harus dikirim buat user ini
/// 3. Nampilin notif manual waktu app lagi kebuka (foreground)
/// 4. Handle TAP notif (baik app lagi background maupun abis di-buka dari
///    kondisi ke-terminate total) buat auto-navigate ke halaman yang pas:
///    tracker pesanan (buyer) atau pesanan masuk (seller).
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifs = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channel = AndroidNotificationDetails(
    'orders_channel',
    'Notifikasi Pesanan',
    channelDescription: 'Update status pesanan & pesanan masuk',
    importance: Importance.high,
    priority: Priority.high,
  );

  /// Dipanggil sekali di main(), sebelum runApp. Cuma nyiapin listener --
  /// BELUM minta token (token baru diambil setelah user login, lihat
  /// [registerToken], karena token itu harus dikaitkan ke user_id).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('Izin push notification: ${settings.authorizationStatus}');

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifs.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      // Tap notif LOKAL (yang kita tampilkan manual pas foreground)
      onDidReceiveNotificationResponse: (response) {
        final raw = response.payload;
        if (raw == null || raw.isEmpty) return;
        try {
          _handleTap(jsonDecode(raw) as Map<String, dynamic>);
        } catch (e) {
          debugPrint('Gagal parse payload notif lokal: $e');
        }
      },
    );

    // Notif masuk waktu app KEBUKA (foreground) -- FCM TIDAK otomatis
    // nampilin apa-apa di kondisi ini, jadi kita tampilkan manual pakai
    // flutter_local_notifications supaya user tetap lihat popup-nya.
    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null) return;
      _localNotifs.show(
        id: message.hashCode,
        title: n.title,
        body: n.body,
        notificationDetails:
            const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
        payload: jsonEncode(message.data),
      );
    });

    // User TAP notif system tray waktu app lagi di background (di-minimize,
    // bukan ke-close)
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _handleTap(message.data));

    // App dibuka PERTAMA KALI lewat notif, padahal sebelumnya app
    // ke-terminate total (bukan cuma di-minimize)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handleTap(initialMessage.data);

    // Token bisa berubah sewaktu-waktu (misal abis reinstall app) --
    // begitu berubah, langsung update ke Supabase biar push berikutnya
    // tetap nyampe ke device ini.
    _messaging.onTokenRefresh.listen(_saveToken);
  }

  /// Panggil ini SETELAH user berhasil login/daftar (lihat AppState.loadAllData).
  /// Ambil FCM token device ini & simpan ke `device_tokens`, dikaitkan ke
  /// user yang baru login.
  Future<void> registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('FCM token belum tersedia untuk device ini.');
        return;
      }
      await _saveToken(token);
    } catch (e) {
      debugPrint('Gagal ambil FCM token: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('device_tokens').upsert(
        {
          'user_id': userId,
          'fcm_token': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'fcm_token',
      );
      debugPrint('FCM token berhasil didaftarkan untuk user $userId.');
    } catch (e) {
      debugPrint('Gagal simpan FCM token ke Supabase: $e');
    }
  }

  /// Panggil ini pas LOGOUT -- hapus token device ini dari DB supaya user
  /// yang sudah keluar tidak lagi kebagian push punya akun tadi (penting
  /// kalau 1 HP dipakai gantian sama akun lain).
  Future<void> unregisterToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await Supabase.instance.client.from('device_tokens').delete().eq('fcm_token', token);
      }
    } catch (e) {
      debugPrint('Gagal hapus FCM token dari Supabase: $e');
    }
  }

  // Routing tap notif ke halaman yang relevan. "type" ini datang dari
  // kolom `notifications.type` yang sudah lama ada di kodemu, cuma
  // sekarang dipakai lagi buat nentuin arah navigasi setelah push di-tap.
  void _handleTap(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    switch (type) {
      case 'order_placed':
      case 'order_processing':
      case 'order_shipped':
      case 'order_completed':
        // Notif buat PEMBELI -> buka "Pesanan Saya" (tracker 3 tahap ada di sini)
        navState.push(MaterialPageRoute(builder: (_) => const OrderListPage()));
        break;
      case 'order_incoming':
        // Notif buat SELLER -> buka "Pesanan Masuk" (tombol Proses/Kirim
        // Barang otomatis muncul sesuai status order-nya)
        navState.push(MaterialPageRoute(builder: (_) => const SellerOrdersPage()));
        break;
    }
  }
}
