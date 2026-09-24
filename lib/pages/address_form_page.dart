import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../data/location_service.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'location_picker_page.dart';

/// Form tambah/edit alamat pengiriman. Kalau [existing] diisi, artinya mode
/// edit (form ke-prefill dari data lama); kalau null, artinya tambah baru.
class AddressFormPage extends StatefulWidget {
  final Address? existing;

  const AddressFormPage({super.key, this.existing});

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _landmarkController;
  late final TextEditingController _cityController;
  late final TextEditingController _provinceController;
  late final TextEditingController _postalController;
  String _label = 'Rumah';
  bool _isDefault = false;
  bool _isSaving = false;
  bool _isLocating = false;
  // Koordinat hasil picker peta / GPS -- dikirim ke server bareng alamat
  // supaya nanti bisa dipakai hitung ongkir berdasarkan jarak ke penjual.
  double? _latitude;
  double? _longitude;

  static const _labelOptions = ['Rumah', 'Kantor', 'Lainnya'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.recipientName ?? '');
    _phoneController = TextEditingController(text: e?.phone ?? '');
    _addressController = TextEditingController(text: e?.fullAddress ?? '');
    _landmarkController = TextEditingController(text: e?.landmark ?? '');
    _cityController = TextEditingController(text: e?.city ?? '');
    _provinceController = TextEditingController(text: e?.province ?? '');
    _postalController = TextEditingController(text: e?.postalCode ?? '');
    _label = e?.label ?? 'Rumah';
    _isDefault = e?.isDefault ?? false;
    _latitude = e?.latitude;
    _longitude = e?.longitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalController.dispose();
    super.dispose();
  }

  // Fallback lama: isi kota/provinsi pakai GPS + geocoder OS (dipakai kalau
  // user cuma mau isi kota/provinsi cepat tanpa buka peta penuh).
  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    final result = await LocationService.getCurrentCityOrLocation();
    if (!mounted) return;
    setState(() => _isLocating = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa mendeteksi lokasi. Isi manual ya.')),
      );
      return;
    }
    final parts = result.split(',').map((p) => p.trim()).toList();
    setState(() {
      if (parts.isNotEmpty) _cityController.text = parts.first;
      if (parts.length > 1) _provinceController.text = parts[1];
    });
  }

  // Buka picker peta (search + GPS + drag pin) yang terintegrasi Google
  // Geocoding API. Hasilnya langsung ngisi SEMUA field alamat sekaligus
  // (alamat lengkap, kota, provinsi, kode pos) + koordinat presisi.
  Future<void> _openMapPicker() async {
    final picked = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLat: _latitude,
          initialLng: _longitude,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _addressController.text = picked.formattedAddress;
      _cityController.text = picked.city;
      _provinceController.text = picked.province;
      if (picked.postalCode != null) _postalController.text = picked.postalCode!;
      _latitude = picked.latitude;
      _longitude = picked.longitude;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final saved = await context.read<AppState>().saveAddress(
            id: widget.existing?.id,
            label: _label,
            recipientName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            fullAddress: _addressController.text.trim(),
            landmark: _landmarkController.text.trim().isEmpty
                ? null
                : _landmarkController.text.trim(),
            city: _cityController.text.trim(),
            province: _provinceController.text.trim(),
            postalCode: _postalController.text.trim().isEmpty
                ? null
                : _postalController.text.trim(),
            isDefault: _isDefault,
            latitude: _latitude,
            longitude: _longitude,
          );
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan alamat: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(labelText: label, hintText: hint);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Tambah Alamat' : 'Ubah Alamat'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Label alamat: Rumah / Kantor / Lainnya
            Wrap(
              spacing: 8,
              children: _labelOptions.map((opt) {
                final selected = _label == opt;
                return ChoiceChip(
                  label: Text(opt),
                  selected: selected,
                  onSelected: (_) => setState(() => _label = opt),
                  selectedColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : null,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: _decoration('Nama Penerima'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _decoration('Nomor HP', hint: '08xx-xxxx-xxxx'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              maxLines: 3,
              decoration: _decoration(
                'Alamat Lengkap',
                hint: 'Nama jalan, nomor rumah, RT/RW, kelurahan, kecamatan',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _landmarkController,
              decoration: _decoration(
                'Patokan (opsional)',
                hint: 'Contoh: dekat minimarket, gerbang cat hijau',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: _decoration('Kota/Kabupaten'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _provinceController,
                    decoration: _decoration('Provinsi'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _postalController,
              keyboardType: TextInputType.number,
              decoration: _decoration('Kode Pos (opsional)'),
            ),
            const SizedBox(height: 8),
            // Kartu status koordinat -- kasih tahu user apakah alamat ini
            // sudah presisi (dari picker peta) atau belum, karena koordinat
            // ini yang menentukan akurasi hitungan ongkir nanti.
            if (_latitude != null && _longitude != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Titik lokasi presisi sudah tersimpan',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _openMapPicker,
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Cari / pilih di peta'),
                ),
                TextButton.icon(
                  onPressed: _isLocating ? null : _useCurrentLocation,
                  icon: _isLocating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 16),
                  label: const Text('Isi cepat pakai GPS'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
              title: const Text('Jadikan alamat utama'),
              activeThumbColor: AppTheme.primary,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
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
                    : const Text('Simpan Alamat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
