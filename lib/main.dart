import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'data/app_state.dart';
import 'data/secure_storage_service.dart';
import 'data/supabase_service.dart';
import 'data/push_notification_service.dart';
import 'theme/app_theme.dart';
import 'pages/login_page.dart';
import 'pages/main_navigation.dart';
import 'pages/email_verified_page.dart';

// Navigator key global -- dipakai supaya deep link (link verifikasi email)
// bisa langsung buka halaman "Akun Terhubung" dari MANAPUN posisi user
// saat itu (splash/login/lagi di tengah app), tanpa butuh BuildContext
// dari widget tertentu.
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Wajib dipanggil sebelum akses plugin native sebelum runApp
  WidgetsFlutterBinding.ensureInitialized();

  String? supabaseUrl;
  String? supabaseAnonKey;

  // Load file .env (kalau tidak ada / gagal, lanjut pakai nilai default di bawah)
  try {
    await dotenv.load(fileName: '.env');
    if (dotenv.isInitialized) {
      supabaseUrl = dotenv.maybeGet('SUPABASE_URL');
      supabaseAnonKey = dotenv.maybeGet('SUPABASE_ANON_KEY');
    }
  } catch (e) {
    debugPrint(
        'Peringatan: File .env tidak ditemukan atau gagal dimuat: $e. Menggunakan nilai default.');
  }

  // Ambil kredensial Supabase dari .env, fallback ke nilai default kalau kosong
  supabaseUrl ??= 'https://plmoyaxwjefvswtxpigq.supabase.co';
  supabaseAnonKey ??=
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBsbW95YXh3amVmdnN3dHhwaWdxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0ODA1NzMsImV4cCI6MjA5ODA1NjU3M30.GLaU4IXTRGn0vXRAwlboWTPrEkk8DvP_-0m42cp0TNg';

  // Inisialisasi koneksi ke Supabase (auth pakai PKCE flow + secure storage)
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
      // ✅ Token JWT tersimpan di Keychain/Keystore, bukan SharedPreferences biasa
      pkceAsyncStorage: SecureStorageService(),
    ),
  );

  // Inisialisasi Firebase (WAJIB ada file firebase_options.dart hasil
  // `flutterfire configure` + google-services.json/GoogleService-Info.plist
  // -- lihat panduan setup. Tanpa ini, push notification tidak akan jalan).
  //
  // CATATAN: begitu `flutterfire configure` berhasil dan file
  // lib/firebase_options.dart sudah muncul, ganti baris
  // `await Firebase.initializeApp();` di bawah jadi:
  //
  //   import 'firebase_options.dart';   <-- taruh di bagian import atas
  //   ...
  //   await Firebase.initializeApp(
  //     options: DefaultFirebaseOptions.currentPlatform,
  //   );
  //
  // Sebelum file itu ada, JANGAN diubah -- biarkan polos seperti ini.
  try {
    await Firebase.initializeApp();
    // Handler push waktu app lagi background/terminated, WAJIB didaftarkan
    // di top level (bukan di dalam widget) sebelum runApp
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushNotificationService.instance.init();
  } catch (e) {
    debugPrint('Peringatan: Gagal inisialisasi Firebase/push notification: $e');
  }

  runApp(const WhimsifyApp());
}

// Widget root aplikasi, daftarin AppState supaya bisa diakses di semua halaman
class WhimsifyApp extends StatelessWidget {
  const WhimsifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // Load preferensi tema (light/dark) tersimpan setelah frame pertama render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadThemePreference();
    });
    _initAuthListener();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  // Dengerin perubahan status auth dari Supabase (JWT access token cuma
  // hidup ~1 jam, tapi biasanya auto-refresh diam-diam pakai refresh token
  // -- lihat `autoRefreshToken: true` di main()). Kalau refresh token-nya
  // sendiri sudah tidak valid lagi (misal user ganti password dari device
  // lain, akun di-suspend, atau refresh token sudah lama tidak dipakai),
  // Supabase SDK otomatis mengeluarkan event `signedOut` juga -- jadi event
  // ini menangkap DUA kasus sekaligus: logout manual dan sesi yang mati
  // sendiri. Tanpa listener ini, untuk kasus kedua user bakal keliatan
  // "diam" di halaman yang lagi dibuka padahal semua request ke server
  // bakal gagal 401.
  //
  // Efek sampingnya: kalau logout manual dari SettingsPage (yang juga sudah
  // navigasi sendiri), halaman Login bisa "ke-push" dua kali beruntun --
  // ini tidak berbahaya (tampilannya sama persis, cuma dobel di balik
  // layar), jadi sengaja dibiarkan demi kesederhanaan.
  void _initAuthListener() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event != AuthChangeEvent.signedOut) return;
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      ctx.read<AppState>().handleSessionExpired();
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Sesi kamu berakhir. Silakan masuk kembali.'),
        ),
      );
    });
  }

  // Tangkap link verifikasi email (skema `whimsify://auth-callback`) baik
  // waktu app lagi kebuka (uriLinkStream) maupun waktu app dibuka PERTAMA
  // KALI lewat link itu (getInitialLink -- misal app sebelumnya ke-close).
  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();

    try {
      final initialUri = await appLinks.getInitialLink();
      if (initialUri != null) _handleIncomingLink(initialUri);
    } catch (e) {
      debugPrint('Gagal ambil initial deep link: $e');
    }

    _linkSubscription = appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (e) => debugPrint('Deep link stream error: $e'),
    );
  }

  Future<void> _handleIncomingLink(Uri uri) async {
    // Cuma proses link yang memang skema callback auth kita (lihat
    // SupabaseService.authCallbackDeepLink), biar tidak ke-trigger sama
    // deep link lain (kalau nanti ada fitur share link, dll)
    final expected = Uri.parse(SupabaseService.authCallbackDeepLink);
    if (uri.scheme != expected.scheme || uri.host != expected.host) return;

    try {
      // Tukar kode PKCE di URL jadi session aktif -- ini yang bikin user
      // otomatis "connected"/login begitu link di email di-klik, tanpa
      // perlu balik ke halaman Login & masukin password lagi.
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const EmailVerifiedPage()),
      );
    } catch (e) {
      debugPrint('Gagal proses deep link verifikasi email: $e');
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text(
              'Link verifikasi sudah kedaluwarsa/tidak valid. Coba daftar ulang atau minta link baru.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dengerin perubahan themeMode aja, biar rebuild-nya efisien
    final themeMode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Whimsify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}

// ==========================================
// SPLASH SCREEN
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndRoute();
  }

  // Cek sesi login: kalau ada, load data & masuk ke Main. Kalau tidak, ke Login
  Future<void> _checkAuthAndRoute() async {
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        // Pre-fetch data dengan timeout agar tidak pernah stuck di splash screen
        try {
          await context
              .read<AppState>()
              .loadAllData()
              .timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('Peringatan: Gagal memuat data awal di splash screen: $e');
        }
        if (!mounted) return;
        _navigateTo(const MainNavigation());
      } else {
        _navigateTo(const LoginPage());
      }
    } catch (e) {
      debugPrint('Error saat pemeriksaan sesi autentikasi: $e');
      if (mounted) {
        _navigateTo(const LoginPage());
      }
    }
  }

  // Pindah halaman dengan animasi fade
  void _navigateTo(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A0D1A) : AppTheme.blush,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Text('🌷', style: TextStyle(fontSize: 48)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Whimsify',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.primary.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}