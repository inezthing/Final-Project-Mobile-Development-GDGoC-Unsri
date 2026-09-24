import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API key Google Maps/Places/Geocoding.
///
/// Diisi lewat file `.env` di root project (SAMA seperti SUPABASE_URL &
/// SUPABASE_ANON_KEY yang sudah ada) -- tambahkan baris baru:
///   GOOGLE_MAPS_API_KEY=API_KEY_kamu_di_sini
///
/// Key yang sama ini juga dipakai di:
///  - android/app/src/main/AndroidManifest.xml (meta-data com.google.android.geo.API_KEY)
///  - ios/Runner/AppDelegate.swift (GMSServices.provideAPIKey)
/// Lihat SETUP_GUIDE.md untuk langkah lengkapnya.
class ApiKeys {
  static String get googleMapsApiKey =>
      dotenv.isInitialized ? (dotenv.maybeGet('GOOGLE_MAPS_API_KEY') ?? '') : '';
}

/// Satu hasil saran alamat dari Google Places Autocomplete.
class PlaceSuggestion {
  final String placeId;
  final String description;

  PlaceSuggestion({required this.placeId, required this.description});
}

/// Hasil lengkap 1 lokasi: koordinat + komponen alamat yang sudah dipecah
/// (kota, provinsi, kode pos) supaya bisa langsung ngisi form alamat.
class GeocodedLocation {
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String city;
  final String province;
  final String? postalCode;

  GeocodedLocation({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    required this.city,
    required this.province,
    this.postalCode,
  });
}

/// Wrapper tipis di atas Google Places API (Autocomplete + Details) dan
/// Google Geocoding API (forward & reverse geocoding), plus helper hitung
/// jarak lurus (Haversine) yang dipakai buat estimasi ongkir.
///
/// Catatan root-cause kenapa dipisah jadi service sendiri (bukan nempel di
/// LocationService yang lama): LocationService lama pakai package
/// `geocoding` yang manggil geocoder BAWAAN OS (native), bukan Google API
/// beneran -- makanya hasilnya kadang beda-beda tiap HP dan gak ada
/// autocomplete/search box. Service ini yang HTTP call langsung ke Google,
/// sesuai yang diminta.
class GeocodingService {
  static const _base = 'https://maps.googleapis.com/maps/api';

  static bool get isConfigured => ApiKeys.googleMapsApiKey.isNotEmpty;

  /// Autocomplete pencarian alamat (dipakai di search bar picker lokasi).
  /// `sessionToken` sebaiknya di-generate 1x per sesi pencarian (hemat biaya
  /// billing Google -- Autocomplete + Details dalam 1 sesi dihitung 1 request).
  static Future<List<PlaceSuggestion>> searchPlaces(
    String query,
    String sessionToken,
  ) async {
    if (query.trim().isEmpty || !isConfigured) return [];
    final uri = Uri.parse('$_base/place/autocomplete/json').replace(
      queryParameters: {
        'input': query,
        'key': ApiKeys.googleMapsApiKey,
        'sessiontoken': sessionToken,
        'language': 'id',
        'components': 'country:id',
      },
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return [];
    final predictions = data['predictions'] as List;
    return predictions
        .map((p) => PlaceSuggestion(
              placeId: p['place_id'] as String,
              description: p['description'] as String,
            ))
        .toList();
  }

  /// Ambil detail (lat/lng + alamat lengkap) dari 1 place_id hasil autocomplete.
  static Future<GeocodedLocation?> getPlaceDetails(
    String placeId,
    String sessionToken,
  ) async {
    if (!isConfigured) return null;
    final uri = Uri.parse('$_base/place/details/json').replace(
      queryParameters: {
        'place_id': placeId,
        'key': ApiKeys.googleMapsApiKey,
        'sessiontoken': sessionToken,
        'language': 'id',
        'fields': 'geometry,formatted_address,address_component',
      },
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;
    final result = data['result'] as Map<String, dynamic>;
    return _fromGoogleResult(result);
  }

  /// Reverse geocoding: dari koordinat (misal hasil drag pin di peta atau
  /// GPS user) -> alamat lengkap + kota/provinsi/kode pos.
  static Future<GeocodedLocation?> reverseGeocode(
    double lat,
    double lng,
  ) async {
    if (!isConfigured) return null;
    final uri = Uri.parse('$_base/geocode/json').replace(
      queryParameters: {
        'latlng': '$lat,$lng',
        'key': ApiKeys.googleMapsApiKey,
        'language': 'id',
      },
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;
    final results = data['results'] as List;
    if (results.isEmpty) return null;
    return _fromGoogleResult(results.first as Map<String, dynamic>);
  }

  /// Forward geocoding: dari teks alamat -> koordinat. Berguna kalau user
  /// ngetik alamat manual dan mau di-autofill kota/provinsi/kode pos-nya
  /// tanpa buka peta.
  static Future<GeocodedLocation?> geocodeAddress(String address) async {
    if (address.trim().isEmpty || !isConfigured) return null;
    final uri = Uri.parse('$_base/geocode/json').replace(
      queryParameters: {
        'address': address,
        'key': ApiKeys.googleMapsApiKey,
        'language': 'id',
        'region': 'id',
      },
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 'OK') return null;
    final results = data['results'] as List;
    if (results.isEmpty) return null;
    return _fromGoogleResult(results.first as Map<String, dynamic>);
  }

  static GeocodedLocation _fromGoogleResult(Map<String, dynamic> result) {
    final geometry = result['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;
    final components = (result['address_components'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    String pick(List<String> types) {
      for (final c in components) {
        final t = (c['types'] as List).cast<String>();
        if (types.any(t.contains)) return c['long_name'] as String;
      }
      return '';
    }

    // Kota/kabupaten: Google kadang naruhnya di administrative_area_level_2,
    // kadang di locality tergantung wilayahnya -- ambil yang ada duluan.
    final city = pick(['administrative_area_level_2', 'locality']);
    final province = pick(['administrative_area_level_1']);
    final postal = pick(['postal_code']);

    return GeocodedLocation(
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
      formattedAddress: result['formatted_address'] as String? ?? '',
      city: city,
      province: province,
      postalCode: postal.isEmpty ? null : postal,
    );
  }

  /// Jarak lurus (garis lurus, bukan jarak jalan) antara 2 koordinat dalam
  /// KM, pakai rumus Haversine. Dipakai buat estimasi ongkir supaya TIDAK
  /// perlu manggil Distance Matrix API berbayar setiap kali harga dihitung
  /// ulang (misal tiap ganti kurir). Kalau nanti mau upgrade ke jarak jalan
  /// beneran, tinggal ganti fungsi ini dengan call ke Directions/Distance
  /// Matrix API -- struktur pemanggilnya (ShippingOption) tidak perlu berubah.
  static double distanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const R = 6371.0; // radius bumi dalam km
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180);
}
