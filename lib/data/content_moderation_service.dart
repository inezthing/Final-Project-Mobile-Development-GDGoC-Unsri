import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Hasil pengecekan moderasi 1 teks (judul+konten postingan, atau balasan).
class ModerationResult {
  final bool isAllowed;
  // Pesan ramah buat ditunjukkin ke user kalau isAllowed == false
  final String? reason;
  final Map<String, double> scores;

  ModerationResult({
    required this.isAllowed,
    this.reason,
    this.scores = const {},
  });
}

/// Wrapper tipis di atas **Google Cloud Natural Language API — `moderateText`**
/// buat deteksi toxicity/insult/profanity/dll sebelum sebuah postingan/
/// balasan komunitas diizinkan tersimpan ke server.
///
/// GANTI DARI PERSPECTIVE API: Google resmi mengumumkan Perspective API
/// (comment-analyzer) di-SUNSET -- tutup layanan per 31 Desember 2026, dan
/// per Februari 2026 sudah TIDAK menerima pendaftaran akses baru sama
/// sekali. Jadi Perspective API bukan lagi opsi buat integrasi baru.
/// Penggantinya di sini pakai `moderateText` dari Cloud Natural Language
/// API -- masih dari Google/tim yang sama, kategori hasilnya mirip banget
/// (Toxic, Insult, Profanity, Derogatory, Violent, Sexual, dll), dan
/// SUDAH RESMI DUKUNG BAHASA INDONESIA (kode bahasa `id`).
///
/// SETUP:
/// 1. Aktifkan "Cloud Natural Language API" di Google Cloud Console:
///    https://console.cloud.google.com/apis/library/language.googleapis.com
/// 2. Pastikan billing aktif di project itu (API ini berbayar per-request,
///    TAPI ada free tier bulanan yang cukup besar buat traffic komunitas
///    skala kecil-menengah -- cek angka & harga terbaru di
///    https://cloud.google.com/natural-language/pricing sebelum
///    mengandalkan ini di produksi, supaya tidak kaget tagihan).
/// 3. Bikin API key di Cloud Console (Credentials > Create API Key),
///    restrict ke "Cloud Natural Language API" saja.
/// 4. Tambahkan ke file .env:
///      CLOUD_NL_API_KEY=API_KEY_kamu_di_sini
///
/// PENTING -- BATASAN: sama seperti Perspective dulu, `moderateText` HANYA
/// menilai skor toxicity/insult/profanity/dll dari sebuah teks. API ini
/// TIDAK bisa menilai apakah sebuah postingan "nyambung topik" dengan
/// komunitasnya atau tidak (itu butuh model klasifikasi topik terpisah,
/// di luar cakupan API ini). Makanya tetap dipisah jadi 2 lapis:
///   - checkToxicity()  -> BLOKIR KERAS kalau toxic/insult/dll (real, akurat)
///   - looksOffTopic()  -> heuristik kata kunci RINGAN, cuma dipakai buat
///                         kasih KONFIRMASI (bukan blokir keras) karena
///                         gampang false-positive kalau dijadikan blokir wajib.
class ContentModerationService {
  static String get _apiKey => dotenv.isInitialized
      ? (dotenv.maybeGet('CLOUD_NL_API_KEY') ?? '')
      : '';

  static bool get isConfigured => _apiKey.trim().isNotEmpty;

  static const _endpoint =
      'https://language.googleapis.com/v2/documents:moderateText';

  // Ambang batas confidence (0.0 - 1.0) per kategori dari moderateText.
  // Boleh disetel lebih ketat/longgar sesuai kebutuhan komunitas.
  // (Nama kategori resmi Cloud NL API: "Toxic", "Insult", "Profanity",
  // "Derogatory", "Violent", "Sexual", dst.)
  static const Map<String, double> _thresholds = {
    'Toxic': 0.75,
    'Insult': 0.75,
    'Profanity': 0.85,
    'Derogatory': 0.75,
    'Violent': 0.7,
    'Death, Harm & Tragedy': 0.85, // ambang tinggi -- gampang false-positive di diskusi wajar
  };

  /// Cek toxicity/insult/dll ke Cloud Natural Language API. Kalau API key
  /// belum dikonfigurasi ATAU pemanggilan API gagal (kuota habis/network
  /// error/timeout/bahasa belum kesupport), sengaja di-ALLOW (fail-open)
  /// supaya fitur posting komunitas tidak ikut mati total hanya gara-gara
  /// moderasi lagi bermasalah -- tapi errornya tetap dicatat di debug log.
  static Future<ModerationResult> checkToxicity(String text) async {
    final trimmed = text.trim();
    if (!isConfigured || trimmed.isEmpty) {
      return ModerationResult(isAllowed: true);
    }
    try {
      final response = await http
          .post(
            Uri.parse('$_endpoint?key=$_apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'document': {
                'type': 'PLAIN_TEXT',
                'content': trimmed,
                // 'id' = Bahasa Indonesia -- moderateText resmi mendukung
                // ini (lihat dokumentasi language support Cloud NL API).
                'language': 'id',
              },
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint(
          'Cloud NL moderateText error ${response.statusCode}: ${response.body}',
        );
        return ModerationResult(isAllowed: true);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final categories = data['moderationCategories'] as List<dynamic>? ?? [];

      final scores = <String, double>{};
      String? violatedCategory;
      for (final cat in categories) {
        final name = (cat['name'] ?? '').toString();
        final confidence = (cat['confidence'] as num?)?.toDouble() ?? 0;
        scores[name] = confidence;
        final threshold = _thresholds[name];
        if (threshold != null && confidence >= threshold) {
          violatedCategory ??= name;
        }
      }

      if (violatedCategory != null) {
        return ModerationResult(
          isAllowed: false,
          reason: _friendlyViolationMessage(violatedCategory),
          scores: scores,
        );
      }
      return ModerationResult(isAllowed: true, scores: scores);
    } catch (e) {
      debugPrint('Cloud NL moderateText call failed, fail-open (allow): $e');
      return ModerationResult(isAllowed: true);
    }
  }

  static String _friendlyViolationMessage(String category) {
    switch (category) {
      case 'Insult':
      case 'Derogatory':
        return 'Postingan terdeteksi mengandung kata-kata menghina. Yuk jaga obrolan tetap nyaman buat semua orang 🌷 (tidak bisa diposting)';
      case 'Violent':
        return 'Postingan terdeteksi mengandung unsur kekerasan, ini melanggar guideline komunitas dan tidak bisa diposting.';
      case 'Toxic':
        return 'Postingan terdeteksi mengandung bahasa kasar/toxic. Coba tulis ulang dengan lebih santai ya, biar bisa diposting.';
      case 'Profanity':
        return 'Postingan terdeteksi mengandung kata kasar. Yuk perhalus bahasanya dulu biar bisa diposting.';
      default:
        return 'Postingan tidak sesuai guideline komunitas dan tidak bisa diposting.';
    }
  }

  /// Heuristik RINGAN buat nebak apakah konten "nyambung" dengan topik
  /// komunitasnya, berdasarkan overlap kata kunci nama/deskripsi/rules
  /// komunitas vs isi postingan. INI BUKAN deteksi AI beneran, cuma
  /// pencocokan kata -- makanya dipakai buat KONFIRMASI ke user
  /// ("yakin mau posting ini di komunitas X?"), bukan buat blokir keras.
  static bool looksOffTopic({
    required String communityName,
    String? communityRules,
    String? communityDescription,
    required String content,
  }) {
    final haystack = content.toLowerCase();
    final keywords = <String>{
      ...communityName.toLowerCase().split(RegExp(r'[\s,./-]+')),
      if (communityDescription != null && communityDescription.trim().isNotEmpty)
        ...communityDescription.toLowerCase().split(RegExp(r'[\s,./-]+')),
      if (communityRules != null && communityRules.trim().isNotEmpty)
        ...communityRules.toLowerCase().split(RegExp(r'[\s,./-]+')),
    }..removeWhere((w) => w.length < 4 || _stopwords.contains(w));

    // Tidak ada dasar kata kunci yang cukup -> jangan menilai apa-apa,
    // daripada salah tebak.
    if (keywords.isEmpty) return false;
    return !keywords.any((k) => haystack.contains(k));
  }

  static const _stopwords = {
    'yang', 'untuk', 'dengan', 'dari', 'akan', 'juga', 'atau', 'tidak',
    'adalah', 'kami', 'kamu', 'anda', 'saja', 'this', 'that', 'with', 'from',
  };
}
