import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../data/geocoding_service.dart';
import '../theme/app_theme.dart';

/// Hasil akhir yang dikembalikan picker ke pemanggilnya (address_form_page,
/// order_detail_page, atau form registrasi).
class PickedLocation {
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String city;
  final String province;
  final String? postalCode;

  PickedLocation({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    required this.city,
    required this.province,
    this.postalCode,
  });
}

/// Halaman picker lokasi ala Shopee/Gojek: peta dengan pin di tengah yang
/// diam (map-nya yang digeser), search box di atas buat cari alamat lewat
/// Google Places Autocomplete, dan tombol "lokasi saat ini" pakai GPS.
/// Begitu peta berhenti digeser (onCameraIdle), koordinat tengah layar
/// di-reverse-geocode otomatis lewat Google Geocoding API.
class LocationPickerPage extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const LocationPickerPage({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const _defaultCenter = LatLng(-2.9909, 104.7566); // Palembang, fallback

  GoogleMapController? _mapController;
  final _searchController = TextEditingController();
  String _sessionToken = const Uuid().v4();
  Timer? _debounce;
  // Kalau `onMapCreated` tidak kunjung terpanggil dalam beberapa detik,
  // hampir pasti native Maps SDK-nya gagal init (API key Android/iOS belum
  // di-setting / salah / Maps SDK belum diaktifkan di Cloud Console) --
  // BUKAN masalah dari kode Dart di file ini. Lihat MAPS_SETUP_GUIDE.md.
  Timer? _mapReadyTimeoutTimer;
  bool _mapCreated = false;
  bool _mapLikelyMisconfigured = false;

  List<PlaceSuggestion> _suggestions = [];
  GeocodedLocation? _resolved;
  LatLng _center = _defaultCenter;
  bool _isResolving = false;
  bool _isLocating = false;
  bool _isSearching = false;
  // Mode darurat: kalau peta gagal render / user memilih skip, tetap bisa
  // lanjut pilih lokasi lewat search + GPS saja tanpa widget GoogleMap,
  // supaya alur Daftar/Jual Barang tidak macet total gara-gara native
  // config Maps belum benar.
  bool _mapFallbackMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _center = LatLng(widget.initialLat!, widget.initialLng!);
    } else {
      _detectCurrentLocation(moveCamera: false);
    }
    _mapReadyTimeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && !_mapCreated) {
        setState(() => _mapLikelyMisconfigured = true);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapReadyTimeoutTimer?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _resolveCenter() async {
    setState(() => _isResolving = true);
    final result = await GeocodingService.reverseGeocode(
      _center.latitude,
      _center.longitude,
    );
    if (!mounted) return;
    setState(() {
      _resolved = result;
      _isResolving = false;
    });
  }

  Future<void> _detectCurrentLocation({bool moveCamera = true}) async {
    setState(() => _isLocating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin lokasi ditolak. Cari manual lewat search ya.'),
            ),
          );
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _center = LatLng(position.latitude, position.longitude);
      if (moveCamera && _mapController != null) {
        try {
          await _mapController!.animateCamera(CameraUpdate.newLatLng(_center));
        } catch (e) {
          // PlatformException dari native Maps SDK (misal renderer belum
          // siap / API key bermasalah) -- jangan sampai nge-crash seluruh
          // halaman cuma karena animasi kamera gagal, lokasi tetap kepakai.
          debugPrint('animateCamera gagal (diabaikan): $e');
        }
      }
      await _resolveCenter();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mendapat lokasi GPS.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    // Debounce 400ms supaya tidak nembak API tiap ketikan huruf (hemat kuota)
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isSearching = true);
      final results = await GeocodingService.searchPlaces(query, _sessionToken);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion s) async {
    setState(() {
      _suggestions = [];
      _searchController.text = s.description;
      _isResolving = true;
    });
    final detail = await GeocodingService.getPlaceDetails(s.placeId, _sessionToken);
    // Sesi autocomplete selesai begitu Details dipanggil -> generate token baru
    _sessionToken = const Uuid().v4();
    if (!mounted || detail == null) return;
    _center = LatLng(detail.latitude, detail.longitude);
    try {
      await _mapController?.animateCamera(CameraUpdate.newLatLng(_center));
    } catch (e) {
      debugPrint('animateCamera gagal (diabaikan): $e');
    }
    setState(() {
      _resolved = detail;
      _isResolving = false;
    });
  }

  void _confirm() {
    if (_resolved == null) return;
    Navigator.pop(
      context,
      PickedLocation(
        latitude: _resolved!.latitude,
        longitude: _resolved!.longitude,
        formattedAddress: _resolved!.formattedAddress,
        city: _resolved!.city,
        province: _resolved!.province,
        postalCode: _resolved!.postalCode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!GeocodingService.isConfigured) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pilih Lokasi')),
        body: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'GOOGLE_MAPS_API_KEY belum diisi di file .env.\n\n'
              'Tambahkan baris ini ke file .env di root project:\n'
              'GOOGLE_MAPS_API_KEY=API_KEY_kamu\n\n'
              'Lihat SETUP_GUIDE.md untuk langkah lengkapnya.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          if (!_mapFallbackMode)
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _center, zoom: 16),
              onMapCreated: (c) {
                _mapController = c;
                _mapReadyTimeoutTimer?.cancel();
                if (mounted) {
                  setState(() {
                    _mapCreated = true;
                    _mapLikelyMisconfigured = false;
                  });
                }
                _resolveCenter();
              },
              onCameraMove: (pos) => _center = pos.target,
              onCameraIdle: _resolveCenter,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            )
          else
            // ==== MODE FALLBACK (tanpa widget GoogleMap) ====
            // Dipakai kalau peta gagal render / user pilih skip supaya alur
            // Daftar/Jual Barang tetap bisa lanjut lewat search alamat +
            // GPS saja, tanpa nunggu native Maps API key dibenerin dulu.
            Container(
              color: Colors.grey[200],
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 56, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'Peta tidak ditampilkan.\nCari alamat lewat kotak pencarian di atas, '
                        'atau pakai tombol lokasi saat ini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Peringatan kalau peta kelihatannya gagal ke-load (native API key
          // Android/iOS kemungkinan belum benar -- lihat MAPS_SETUP_GUIDE.md)
          if (_mapLikelyMisconfigured && !_mapFallbackMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 70, 12, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Peta belum kelihatan. Kemungkinan API key Maps native '
                              'Android/iOS belum di-setting (lihat MAPS_SETUP_GUIDE.md).',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => setState(() {
                            _mapFallbackMode = true;
                            _mapLikelyMisconfigured = false;
                          }),
                          child: const Text('Lanjut tanpa peta (pakai search saja)'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Pin tetap di tengah layar (yang "bergerak" adalah peta di baliknya)
          if (!_mapFallbackMode)
            const IgnorePointer(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 36),
                  child: Icon(Icons.location_on, size: 44, color: AppTheme.primary),
                ),
              ),
            ),
          // Search bar + hasil autocomplete
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          elevation: 2,
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Cari alamat, jalan, atau area...',
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _isSearching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = _suggestions[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.place_outlined, size: 20),
                            title: Text(s.description, style: const TextStyle(fontSize: 13)),
                            onTap: () => _selectSuggestion(s),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Tombol "lokasi saat ini"
          Positioned(
            right: 12,
            bottom: 220,
            child: FloatingActionButton.small(
              heroTag: 'my-location-fab',
              backgroundColor: Colors.white,
              onPressed: _isLocating ? null : _detectCurrentLocation,
              child: _isLocating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, color: AppTheme.primary),
            ),
          ),
          // Panel bawah: alamat hasil resolve + tombol konfirmasi
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lokasi terpilih',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  _isResolving
                      ? const Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Mendeteksi alamat...'),
                          ],
                        )
                      : Text(
                          _resolved?.formattedAddress ?? 'Geser peta untuk pilih lokasi',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_resolved == null || _isResolving) ? null : _confirm,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Gunakan Lokasi Ini'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
