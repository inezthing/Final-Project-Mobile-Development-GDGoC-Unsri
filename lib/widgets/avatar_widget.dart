import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Widget avatar yang bisa dipakai ulang di mana saja (komunitas, chat, profil).
///
/// `avatar_url` di database bisa berisi salah satu dari dua bentuk:
/// 1. Emoji polos (default untuk user baru), contoh: '🐰'
/// 2. URL foto asli (hasil upload ke Supabase Storage),
///    contoh: 'https://xxxx.supabase.co/storage/v1/object/public/avatars/...'
///
/// Sebelum ada widget ini, beberapa halaman (komunitas) selalu menampilkan
/// nilainya sebagai teks emoji, jadi kalau isinya URL beneran, yang muncul
/// di layar cuma tulisan "https://..." — bukan gambar. Widget ini yang
/// memutuskan: kalau nilainya diawali "http", tampilkan sebagai foto
/// (Image.network); kalau bukan, tampilkan sebagai teks emoji.
class AvatarWidget extends StatelessWidget {
  final String avatar;
  final double radius;
  final Color? backgroundColor;

  const AvatarWidget({
    super.key,
    required this.avatar,
    this.radius = 16,
    this.backgroundColor,
  });

  bool get _isNetworkImage =>
      avatar.startsWith('http://') || avatar.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppTheme.blush;

    if (_isNetworkImage) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        // ClipOval + Image.network dipakai (bukan backgroundImage) supaya
        // kalau gambar gagal dimuat (link putus/koneksi jelek), fallback-nya
        // adalah ikon orang, bukan layar merah error.
        child: ClipOval(
          child: Image.network(
            avatar,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                width: radius * 2,
                height: radius * 2,
                child: Center(
                  child: SizedBox(
                    width: radius * 0.8,
                    height: radius * 0.8,
                    child: const CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.person,
              size: radius,
              color: AppTheme.primary,
            ),
          ),
        ),
      );
    }

    // Bukan URL -> tampilkan sebagai emoji teks biasa
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        avatar.isEmpty ? '🐰' : avatar,
        style: TextStyle(fontSize: radius * 0.85),
      ),
    );
  }
}
