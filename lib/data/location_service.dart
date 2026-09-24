import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  /// Mendapatkan lokasi terkini user berupa nama kota dan provinsi secara otomatis.
  /// Jika layanan mati, tidak diizinkan, atau geocoding error, akan mengembalikan null
  /// atau fallback ke koordinat.
  static Future<String?> getCurrentCityOrLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Cek apakah layanan GPS aktif
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Cek izin akses lokasi
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Ambil posisi koordinat dengan akurasi rendah untuk efisiensi
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Terjemahkan koordinat menjadi alamat/kota (reverse geocoding)
      try {
        final geocoding = Geocoding();
        final placemarks = await geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          // subAdministrativeArea biasanya kota/kabupaten
          // locality biasanya kecamatan/kelurahan
          // administrativeArea biasanya provinsi
          final city = place.subAdministrativeArea ?? place.locality ?? place.administrativeArea ?? '';
          final province = place.administrativeArea ?? '';
          
          if (city.isNotEmpty && province.isNotEmpty && city != province) {
            return '$city, $province';
          } else if (city.isNotEmpty) {
            return city;
          }
        }
      } catch (_) {
        // Jika gagal geocoding, gunakan koordinat sebagai fallback
        return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }
      
      return '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    } catch (_) {
      return null;
    }
  }
}
