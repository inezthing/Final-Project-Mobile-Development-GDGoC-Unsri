import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../data/supabase_service.dart';
import '../data/app_state.dart';
import 'main_navigation.dart';

/// Halaman Login sekaligus Registrasi (satu halaman, formnya berubah-ubah
/// tergantung mode _isRegister). Setelah login/daftar berhasil, langsung
/// diarahkan ke MainNavigation.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Key untuk validasi form (Form widget butuh ini untuk cek semua validator)
  final _formKey = GlobalKey<FormState>();
  // Controller tiap kolom input, dipakai untuk baca teks yang diketik user
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isRegister = false; // false = mode Login, true = mode Daftar
  bool _isLoading = false; // true selagi proses submit ke server berjalan
  bool _obscurePassword = true; // true = password disembunyikan (titik-titik)
  final _api = SupabaseService();

  // Wajib dispose semua TextEditingController supaya tidak memory leak
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _birthDateController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  /// Pindah ke MainNavigation dan hapus semua history halaman sebelumnya
  /// (supaya user tidak bisa tekan "back" balik ke halaman login).
  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (_) => false,
    );
  }

  /// Proses submit form: validasi dulu, lalu panggil signUp atau signIn
  /// tergantung mode yang aktif.
  Future<void> _submit() async {
    // Kalau ada validator yang gagal (misal email kosong), berhenti di sini
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    // Simpan referensi ScaffoldMessenger sebelum async gap, supaya aman
    // dipakai nanti walau context sempat berubah
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      if (_isRegister) {
        // Sign Up
        final response = await _api.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          username: _usernameController.text.trim(),
          birthDate: _birthDateController.text.trim(),
          location: _locationController.text.trim(),
        );

        if (response.session != null && mounted) {
          // Kalau Supabase langsung kasih session (auto-confirm email aktif),
          // langsung load data & masuk ke halaman utama
          await context.read<AppState>().loadAllData();
          if (!mounted) return;
          _goToHome();
        } else {
          // Kalau butuh verifikasi email dulu, kasih tahu user lalu
          // arahkan balik ke mode Login (bukan Daftar)
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Registrasi berhasil. Cek email untuk verifikasi, lalu masuk.',
              ),
              backgroundColor: AppTheme.primary,
            ),
          );
          setState(() => _isRegister = false);
        }
      } else {
        // Sign In
        await _api.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          // Trigger loading all data
          await context.read<AppState>().loadAllData();
          if (!mounted) return;
          _goToHome();
        }
      }
    } catch (e) {
      // Tampilkan pesan error (sudah diubah jadi ramah oleh SupabaseService)
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red[400],
        ),
      );
    } finally {
      // Matikan loading spinner apapun hasilnya (berhasil/gagal),
      // asal widget-nya masih ada di layar (mounted)
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF2D1B2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);
    return Scaffold(
      body: Container(
        // Background gradasi lembut dari atas ke bawah
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A0D1A), const Color(0xFF2D1B2E)]
                : [AppTheme.blush, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            // SingleChildScrollView: supaya form tetap bisa discroll kalau
            // keyboard muncul dan mempersempit ruang layar
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo/Icon Whimsical
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
                  Text(
                    'Beri barang imutmu rumah baru ✨',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // ==== Kartu form Login/Daftar ====
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isRegister ? 'Daftar Akun' : 'Masuk',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Kolom-kolom ini CUMA muncul kalau mode Daftar aktif
                          // (spread operator `...` untuk masukin banyak widget sekaligus)
                          if (_isRegister) ...[
                            TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Username tidak boleh kosong';
                                }
                                if (val.trim().length < 3) {
                                  return 'Minimal 3 karakter';
                                }
                                return null; // null berarti valid, tidak ada error
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _birthDateController,
                              keyboardType: TextInputType.datetime,
                              decoration: const InputDecoration(
                                labelText: 'Tanggal lahir',
                                hintText: 'Contoh: 2003-04-21',
                                prefixIcon: Icon(Icons.cake_outlined),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Tanggal lahir tidak boleh kosong';
                                }
                                final parsed = DateTime.tryParse(val.trim());
                                if (parsed == null) {
                                  return 'Gunakan format YYYY-MM-DD';
                                }
                                if (parsed.isAfter(DateTime.now())) {
                                  return 'Tanggal lahir tidak valid';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                labelText: 'Lokasi',
                                hintText: 'Contoh: Palembang',
                                prefixIcon: Icon(Icons.location_on_outlined),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Lokasi tidak boleh kosong';
                                }
                                if (val.trim().length < 3) {
                                  return 'Lokasi minimal 3 karakter';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Kolom email — selalu tampil (baik Login maupun Daftar)
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Email tidak boleh kosong';
                              }
                              // Regex sederhana untuk cek format "sesuatu@sesuatu.sesuatu"
                              final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                              if (!regex.hasMatch(val.trim())) {
                                return 'Format email tidak valid';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Kolom password, dengan tombol mata untuk show/hide
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Password tidak boleh kosong';
                              }
                              if (val.length < 6) {
                                return 'Password minimal 6 karakter';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          // Tombol submit — teks & aksinya berubah tergantung mode,
                          // dan diganti jadi spinner selagi _isLoading true
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      _isRegister ? 'Daftar' : 'Masuk',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Toggle Login/Register — tombol untuk pindah antara mode
                  // Login dan Daftar, sekalian reset validasi form
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isRegister = !_isRegister;
                        _formKey.currentState?.reset();
                      });
                    },
                    child: Text(
                      _isRegister
                          ? 'Sudah punya akun? Masuk di sini'
                          : 'Belum punya akun? Daftar sekarang',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}