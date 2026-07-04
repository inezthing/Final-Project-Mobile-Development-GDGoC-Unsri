import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/app_state.dart';
import 'data/secure_storage_service.dart';
import 'theme/app_theme.dart';
import 'pages/login_page.dart';
import 'pages/main_navigation.dart';

void main() async {
  // Wajib dipanggil sebelum akses plugin native sebelum runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Load file .env (kalau tidak ada, lanjut pakai nilai default di bawah)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint(
        'Peringatan: File .env tidak ditemukan, menggunakan nilai default.');
  }

  // Ambil kredensial Supabase dari .env, fallback ke nilai default kalau kosong
  final supabaseUrl =
      dotenv.env['SUPABASE_URL'] ?? 'https://plmoyaxwjefvswtxpigq.supabase.co';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ??
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
  @override
  void initState() {
    super.initState();
    // Load preferensi tema (light/dark) tersimpan setelah frame pertama render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadThemePreference();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dengerin perubahan themeMode aja, biar rebuild-nya efisien
    final themeMode = context.select<AppState, ThemeMode>((s) => s.themeMode);
    return MaterialApp(
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
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      await context.read<AppState>().loadAllData();
      if (!mounted) return;
      _navigateTo(const MainNavigation());
    } else {
      _navigateTo(const LoginPage());
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
