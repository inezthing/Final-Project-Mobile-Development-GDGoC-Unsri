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

/// Wrapper tipis di atas Google's Perspective API (Comment Analyzer) buat
/// deteksi toxicity/insult/profanity/threat/identity-attack sebelum sebuah
/// postingan/balasan komunitas diizinkan tersimpan ke server.
///
/// SETUP:
/// 1. Aktifkan "Perspective Comment Analyzer API" di Google Cloud Console
///    (https://console.cloud.google.com/apis/library/commentanalyzer.googleapis.com)
///    -- API ini GRATIS tapi butuh approval akses dulu, isi form di
///    https://developers.perspectiveapi.com/s/docs-get-started
/// 2. Bikin API key di Cloud Console (Credentials > Create API Key),
///    restrict ke "Perspective Comment Analyzer API" saja.
/// 3. Tambahkan ke file .env:
///      PERSPECTIVE_API_KEY=API_KEY_kamu_di_sini
///
/// PENTING -- BATASAN Perspective API: API ini HANYA bisa menilai skor
/// toxicity/insult/profanity/threat/identity-attack dari sebuah teks. API
/// ini TIDAK bisa menilai apakah sebuah postingan "nyambung topik" dengan
/// komunitasnya atau tidak (itu butuh model klasifikasi topik terpisah,
/// di luar cakupan Perspective). Makanya di sini kita pisah jadi 2 lapis:
///   - checkToxicity()  -> BLOKIR KERAS kalau toxic/insult/dll (real, akurat)
///   - looksOffTopic()  -> heuristik kata kunci RINGAN, cuma dipakai buat
///                         kasih KONFIRMASI (bukan blokir keras) karena
///                         gampang false-positive kalau dijadikan blokir wajib.
class PerspectiveService {
  static String get _apiKey => dotenv.isInitialized
      ? (dotenv.maybeGet('PERSPECTIVE_API_KEY') ?? '')
      : '';

  static bool get isConfigured => _apiKey.trim().isNotEmpty;

  static const _endpoint =
      'https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze';

  // Ambang batas skor (0.0 - 1.0). Di atas ini dianggap melanggar guideline.
  // Boleh disetel lebih ketat/longgar sesuai kebutuhan komunitas.
  static const Map<String, double> _thresholds = {
    'TOXICITY': 0.75,
    'SEVERE_TOXICITY': 0.6,
    'INSULT': 0.75,
    'PROFANITY': 0.85,
    'THREAT': 0.6,
    'IDENTITY_ATTACK': 0.7,
  };

  /// Cek toxicity/insult/dll ke Perspective API. Kalau API key belum
  /// dikonfigurasi ATAU pemanggilan API gagal (kuota habis/network error/
  /// timeout), sengaja di-ALLOW (fail-open) supaya fitur posting komunitas
  /// tidak ikut mati total hanya gara-gara moderasi lagi bermasalah --
  /// tapi errornya tetap dicatat di debug log.
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
              'comment': {'text': trimmed},
              // 'id' = Bahasa Indonesia. Perspective dukung id sejak beberapa
              // model komunitas -- kalau belum kesupport buat bahasa
              // tertentu, API otomatis fallback / kasih error yang kita
              // tangkap di catch (fail-open).
              'languages': ['id', 'en'],
              'requestedAttributes': {
                for (final key in _thresholds.keys) key: {},
              },
              'doNotStore': true,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint(
          'Perspective API error ${response.statusCode}: ${response.body}',
        );
        return ModerationResult(isAllowed: true);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final attrScores =
          data['attributeScores'] as Map<String, dynamic>? ?? {};

      final scores = <String, double>{};
      String? violatedAttribute;
      for (final entry in attrScores.entries) {
        final summary = (entry.value as Map)['summaryScore'] as Map?;
        final value = (summary?['value'] as num?)?.toDouble() ?? 0;
        scores[entry.key] = value;
        final threshold = _thresholds[entry.key];
        if (threshold != null && value >= threshold) {
          violatedAttribute ??= entry.key;
        }
      }

      if (violatedAttribute != null) {
        return ModerationResult(
          isAllowed: false,
          reason: _friendlyViolationMessage(violatedAttribute),
          scores: scores,
        );
      }
      return ModerationResult(isAllowed: true, scores: scores);
    } catch (e) {
      debugPrint('Perspective API call failed, fail-open (allow): $e');
      return ModerationResult(isAllowed: true);
    }
  }

  static String _friendlyViolationMessage(String attribute) {
    switch (attribute) {
      case 'INSULT':
        return 'Postingan terdeteksi mengandung kata-kata menghina. Yuk jaga obrolan tetap nyaman buat semua orang 🌷 (tidak bisa diposting)';
      case 'THREAT':
        return 'Postingan terdeteksi mengandung ancaman, ini melanggar guideline komunitas dan tidak bisa diposting.';
      case 'SEVERE_TOXICITY':
      case 'TOXICITY':
        return 'Postingan terdeteksi mengandung bahasa kasar/toxic. Coba tulis ulang dengan lebih santai ya, biar bisa diposting.';
      case 'PROFANITY':
        return 'Postingan terdeteksi mengandung kata kasar. Yuk perhalus bahasanya dulu biar bisa diposting.';
      case 'IDENTITY_ATTACK':
        return 'Postingan terdeteksi menyerang identitas seseorang/kelompok. Ini melanggar guideline komunitas dan tidak bisa diposting.';
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
