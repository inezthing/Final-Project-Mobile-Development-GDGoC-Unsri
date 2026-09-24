import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../data/location_service.dart';

/// Halaman untuk edit profil user: ubah foto/avatar, username, tanggal lahir,
/// dan lokasi. Avatar bisa berupa foto asli (upload) ATAU emoji preset
/// (pilih salah satu, keduanya saling eksklusif).
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _locationCtrl;

  DateTime? _birthDate;
  String? _selectedEmoji; // avatar emoji yang dipilih (null kalau pakai foto)
  File? _avatarFile; // foto avatar yang diambil dari kamera/galeri
  bool _isSaving = false;
  bool _isFetchingLocation = false;

  Future<void> _detectLocation() async {
    if (_isFetchingLocation) return;
    setState(() => _isFetchingLocation = true);
    try {
      final loc = await LocationService.getCurrentCityOrLocation();
      if (loc != null && mounted) {
        setState(() {
          _locationCtrl.text = loc;
        });
      }
    } catch (_) {
      // Abaikan jika error
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  final _picker = ImagePicker();

  // Daftar emoji preset yang bisa dipilih sebagai avatar
  static const List<String> _emojiOptions = [
    '🐰', '🐶', '🐱', '🦊', '🐻',
    '🐼', '🦄', '🐸', '🐨', '🐯',
    '🐹', '🐥',
  ];

  @override
  void initState() {
    super.initState();
    // Isi form dengan data profil yang sudah ada (biar user tinggal edit,
    // bukan mulai dari kosong)
    final profile = context.read<AppState>().userProfile;
    _usernameCtrl = TextEditingController(
      text: (profile?['username'] as String?) ?? '',
    );
    _locationCtrl = TextEditingController(
      text: (profile?['location'] as String?) ?? '',
    );
    _birthDate = _parseDate(profile?['birth_date']);

    // avatar_url bisa berisi URL foto (diawali "http") atau emoji polos.
    // Kalau bukan URL, berarti itu emoji -> tandai sebagai emoji terpilih.
    final currentAvatar = profile?['avatar_url'] as String?;
    if (currentAvatar != null && !currentAvatar.startsWith('http')) {
      _selectedEmoji = currentAvatar;
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  /// Ubah string tanggal dari database jadi DateTime, atau null kalau gagal.
  DateTime? _parseDate(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  /// Format DateTime jadi string "YYYY-MM-DD" untuk disimpan ke database.
  String _formatDateForDb(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Format tanggal jadi lebih enak dibaca (misal "21 Apr 2003") untuk ditampilkan di UI.
  String _formatDateForDisplay(DateTime? date) {
    if (date == null) return 'Pilih tanggal lahir';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  /// Buka date picker bawaan Flutter untuk memilih tanggal lahir.
  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      // Default tampil di usia 20 tahun kalau belum ada tanggal lahir tersimpan
      initialDate: _birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now, // tidak boleh pilih tanggal di masa depan
      helpText: 'Pilih tanggal lahir',
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  /// Tampilkan bottom sheet untuk pilih sumber foto (kamera atau galeri),
  /// lalu buka picker sesuai pilihan user.
  Future<void> _pickAvatarSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dari kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85, // kompres kualitas biar ukuran file tidak terlalu besar
        maxWidth: 800,
      );
      if (pickedFile != null) {
        setState(() {
          _avatarFile = File(pickedFile.path);
          _selectedEmoji = null; // foto menggantikan avatar emoji
        });
      }
    } catch (e) {
      debugPrint('Error picking avatar image: $e');
    }
  }

  /// Simpan perubahan profil ke Supabase lewat AppState.
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await context.read<AppState>().updateProfile(
            username: _usernameCtrl.text.trim(),
            birthDate: _birthDate != null ? _formatDateForDb(_birthDate!) : '',
            location: _locationCtrl.text.trim(),
            avatarFile: _avatarFile,
            // Emoji hanya dikirim kalau tidak ada foto yang dipilih
            avatarEmoji: _avatarFile == null ? _selectedEmoji : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profil berhasil diperbarui! ✨'),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui profil: $e'),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ==== Avatar (foto atau emoji) + tombol kamera kecil di pojok ====
              Center(
                child: GestureDetector(
                  onTap: _pickAvatarSource,
                  child: Stack(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: AppTheme.blush,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.rose, width: 2),
                          // Kalau ada file foto yang dipilih, tampilkan sebagai background image
                          image: _avatarFile != null
                              ? DecorationImage(
                                  image: FileImage(_avatarFile!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        // Kalau tidak ada foto, tampilkan emoji di tengah lingkaran
                        child: _avatarFile == null
                            ? Center(
                                child: Text(
                                  _selectedEmoji ?? '🐰',
                                  style: const TextStyle(fontSize: 40),
                                ),
                              )
                            : null,
                      ),
                      // Ikon kamera kecil di pojok kanan bawah avatar
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Ketuk untuk unggah foto profil',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Pilihan avatar emoji preset (kalau tidak mau unggah foto)
              Text(
                'Atau pilih avatar',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              // Wrap: grid emoji otomatis pindah baris kalau kolomnya penuh
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _emojiOptions.map((emoji) {
                  final isSelected =
                      _avatarFile == null && _selectedEmoji == emoji;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedEmoji = emoji;
                      _avatarFile = null; // pilih emoji -> batalkan foto yang tadi dipilih
                    }),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withOpacity(0.15)
                            : (isDark ? Colors.white10 : AppTheme.blush),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isSelected ? AppTheme.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
              // ==== Form kolom username ====
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => v == null || v.trim().length < 3
                    ? 'Minimal 3 karakter'
                    : null,
              ),
              const SizedBox(height: 14),

              // ==== Kolom tanggal lahir (bukan TextFormField biasa, tapi
              // tampilan yang mirip input, dibuka lewat date picker saat di-tap) ====
              GestureDetector(
                onTap: _pickBirthDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Lahir',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  child: Text(
                    _formatDateForDisplay(_birthDate),
                    style: TextStyle(
                      fontSize: 14,
                      color: _birthDate == null
                          ? Colors.grey[400]
                          : textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ==== Kolom lokasi ====
              TextFormField(
                controller: _locationCtrl,
                decoration: InputDecoration(
                  labelText: 'Lokasi',
                  hintText: 'Contoh: Palembang, Sumatra Selatan',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: _isFetchingLocation
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.my_location),
                          tooltip: 'Dapatkan lokasi otomatis',
                          onPressed: _detectLocation,
                        ),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Lokasi tidak boleh kosong'
                    : null,
              ),

              const SizedBox(height: 28),
              // Tombol simpan, jadi spinner selagi proses simpan berjalan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan Perubahan'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}