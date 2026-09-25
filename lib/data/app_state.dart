import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'supabase_service.dart';
import 'secure_storage_service.dart';
import 'geocoding_service.dart';
import 'push_notification_service.dart';

// State management global aplikasi (produk, cart, posts, profil, dll)
// menggunakan Provider/ChangeNotifier
class AppState extends ChangeNotifier {
  final _api = SupabaseService();

  bool _isLoading = false;
  ThemeMode _themeMode = ThemeMode.system;
  List<Product> _products = [];
  List<CommunityPost> _posts = [];
  List<CartItem> _cart = [];
  List<Address> _addresses = [];
  List<Order> _myOrders = [];
  List<Order> _sellerOrders = [];
  List<AppNotification> _notifications = [];
  List<Community> _followedCommunities = [];
  List<String> _blockedUserIds = [];
  Map<String, dynamic>? _userProfile;
  String? _errorMessage;

  String? get errorMessage => _errorMessage;
  // Reset pesan error (dipanggil setelah error ditampilkan ke user)
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  bool get isLoading => _isLoading;
  ThemeMode get themeMode => _themeMode;
  List<Product> get products => _products;
  List<CommunityPost> get posts => _posts;
  List<CartItem> get cart => _cart;
  List<Address> get addresses => _addresses;
  List<Order> get myOrders => _myOrders;
  List<Order> get sellerOrders => _sellerOrders;
  List<AppNotification> get notifications => _notifications;
  int get unreadNotificationCount => _notifications.where((n) => !n.isRead).length;
  List<Community> get followedCommunities => _followedCommunities;
  List<String> get blockedUserIds => _blockedUserIds;

  // Kapan akun ini bebas dari suspend (null/masa lalu = tidak disuspend)
  DateTime? get bannedUntil {
    final raw = _userProfile?['banned_until'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  bool get isBanned => bannedUntil != null && bannedUntil!.isAfter(DateTime.now());
  Map<String, dynamic>? get userProfile => _userProfile;
  int get cartCount => _cart.fold(0, (sum, item) => sum + item.quantity);
  double get cartTotalPrice =>
      _cart.fold(0.0, (sum, item) => sum + (item.effectivePrice * item.quantity));

  // Set status loading global & kabari listener (dipakai buat loading indicator)
  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  // ==========================================
  // THEME — PERSISTENT
  // ==========================================
  // Ambil preferensi tema tersimpan dari SharedPreferences saat app dibuka
  Future<void> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('theme_mode') ?? 'system';
      _themeMode = switch (saved) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

  // Ganti tema (light/dark/system) dan simpan pilihannya secara permanen
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      };
      await prefs.setString('theme_mode', modeString);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  // ==========================================
  // DATA LOADING
  // ==========================================
  // Load semua data utama secara paralel (profil, produk, cart, posts)
  Future<void> loadAllData() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      await Future.wait([
        loadUserProfile(),
        loadProducts(),
        loadCart(),
        loadPosts(),
        loadAddresses(),
        loadMyOrders(),
        loadNotifications(),
        loadFollowedCommunities(),
        loadBlockedUserIds(),
      ]);
      // Daftarkan FCM token device ini ke user yang baru login/daftar,
      // supaya push notification (order_placed, order_incoming, dst)
      // bisa nyampe ke HP-nya. Aman dipanggil berkali-kali (upsert).
      unawaited(PushNotificationService.instance.registerToken());
    } catch (e) {
      _errorMessage = 'Gagal memuat data. Periksa koneksi internetmu.';
      debugPrint('Error loading Whimsify data: $e');
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Ambil data profil user yang sedang login
  Future<void> loadUserProfile() async {
    if (_api.currentUser != null) {
      try {
        _userProfile = await _api.fetchUserProfile(_api.currentUser!.id);
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading user profile: $e');
      }
    }
  }

  // Ambil daftar semua produk dari server
  Future<void> loadProducts() async {
    try {
      _products = await _api.fetchProducts();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading products: $e');
    }
  }

  // Ambil isi keranjang belanja user
  Future<void> loadCart() async {
    try {
      _cart = await _api.fetchCart();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }
  }

  // Ambil daftar alamat pengiriman tersimpan milik user
  Future<void> loadAddresses() async {
    try {
      _addresses = await _api.fetchAddresses();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading addresses: $e');
    }
  }

  // Simpan alamat baru / update alamat yang sudah ada, lalu refresh list lokal
  Future<Address> saveAddress({
    String? id,
    required String label,
    required String recipientName,
    required String phone,
    required String fullAddress,
    String? landmark,
    required String city,
    required String province,
    String? postalCode,
    bool isDefault = false,
    double? latitude,
    double? longitude,
  }) async {
    final address = await _api.saveAddress(
      id: id,
      label: label,
      recipientName: recipientName,
      phone: phone,
      fullAddress: fullAddress,
      landmark: landmark,
      city: city,
      province: province,
      postalCode: postalCode,
      isDefault: isDefault,
      latitude: latitude,
      longitude: longitude,
    );
    await loadAddresses();
    return address;
  }

  Future<void> deleteAddress(String addressId) async {
    await _api.deleteAddress(addressId);
    _addresses.removeWhere((a) => a.id == addressId);
    notifyListeners();
  }

  // Proses checkout: kirim ke server (stok dikurangi ATOMIC di sana),
  // lalu bersihkan cart lokal & refresh stok produk supaya UI langsung
  // menampilkan angka stok terbaru tanpa perlu reload manual.
  Future<String> checkout({
    required String addressId,
    required String paymentMethod,
    String? note,
  }) async {
    final orderId = await _api.checkoutCart(
      addressId: addressId,
      paymentMethod: paymentMethod,
      note: note,
    );
    _cart = [];
    notifyListeners();
    // refresh produk di background biar angka stok yang tampil di
    // Explore/Detail semua ikut ter-update
    loadProducts();
    return orderId;
  }

  // ==========================================
  // ORDER DETAIL / TRACKING (checkout item terpilih, ala Shopee)
  // ==========================================

  // Hitung 2 opsi ongkir (Reguler & Express) berdasarkan jarak lurus
  // (Haversine) antara koordinat alamat pembeli & lokasi penjual. Kalau
  // salah satu koordinat tidak ada (alamat lama tanpa GPS, atau seller
  // belum pernah set lokasi), fallback ke ongkir flat supaya checkout
  // tetap bisa jalan (tidak ngeblok user).
  //
  // Formula: harga dasar + (tarif per km * jarak), Express ~1.8x Reguler
  // dan lebih cepat. Ini estimasi sederhana di sisi klien -- kalau nanti
  // mau akurat sampai ke jarak jalan (bukan garis lurus), tinggal ganti
  // GeocodingService.distanceKm dengan panggilan ke Google Distance Matrix
  // API, exact di titik ini saja.
  List<ShippingOption> buildShippingOptions({
    double? buyerLat,
    double? buyerLng,
    double? sellerLat,
    double? sellerLng,
  }) {
    double? distanceKm;
    if (buyerLat != null && buyerLng != null && sellerLat != null && sellerLng != null) {
      distanceKm = GeocodingService.distanceKm(buyerLat, buyerLng, sellerLat, sellerLng);
    }

    const regulerBase = 9000.0;
    const expressBase = 15000.0;
    const perKm = 700.0;

    final regulerPrice = distanceKm == null
        ? regulerBase
        : regulerBase + (distanceKm * perKm);
    final expressPrice = distanceKm == null
        ? expressBase
        : expressBase + (distanceKm * perKm * 1.6);

    final etaReguler = distanceKm == null
        ? '2-4 hari'
        : distanceKm < 10
            ? '1-2 hari'
            : distanceKm < 50
                ? '2-3 hari'
                : '3-5 hari';
    final etaExpress = distanceKm == null
        ? '1-2 hari'
        : distanceKm < 10
            ? 'Hari ini/besok'
            : distanceKm < 50
                ? '1 hari'
                : '1-2 hari';

    return [
      ShippingOption(
        code: 'reguler',
        name: 'Reguler',
        etaLabel: etaReguler,
        price: (regulerPrice / 500).round() * 500, // pembulatan ke 500 terdekat
      ),
      ShippingOption(
        code: 'express',
        name: 'Express',
        etaLabel: etaExpress,
        price: (expressPrice / 500).round() * 500,
      ),
    ];
  }

  // Ambil koordinat seller (dari profiles) buat perhitungan ongkir. Return
  // null kalau seller belum pernah set lokasi -- caller harus fallback ke
  // ongkir flat lewat buildShippingOptions() di atas.
  Future<Map<String, double>?> fetchSellerLocation(String sellerId) {
    return _api.fetchSellerLocation(sellerId);
  }

  // Checkout item TERPILIH dari cart (bukan semua) -- dipakai alur
  // Cart -> pilih item -> Detail Pesanan -> Buat Pesanan yang baru.
  // Setelah sukses: hapus item yang di-checkout dari cart lokal (item yang
  // TIDAK dipilih tetap ada di cart), refresh stok produk.
  Future<String> placeOrder({
    required List<String> cartItemIds,
    required String recipientName,
    required String recipientPhone,
    required String shippingAddress,
    double? destLatitude,
    double? destLongitude,
    required String shippingMethod,
    required double shippingCost,
    required String paymentMethod,
    String? note,
  }) async {
    final orderId = await _api.placeOrder(
      cartItemIds: cartItemIds,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
      shippingAddress: shippingAddress,
      destLatitude: destLatitude,
      destLongitude: destLongitude,
      shippingMethod: shippingMethod,
      shippingCost: shippingCost,
      paymentMethod: paymentMethod,
      note: note,
    );
    _cart.removeWhere((item) => cartItemIds.contains(item.id));
    notifyListeners();
    loadProducts();
    return orderId;
  }

  // Riwayat pesanan milik user sebagai PEMBELI -- buat "Pesanan Saya"
  Future<void> loadMyOrders() async {
    try {
      _myOrders = await _api.fetchMyOrders();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading my orders: $e');
    }
  }

  // Pesanan yang masuk ke toko user sebagai PENJUAL -- buat "Pesanan Masuk"
  Future<void> loadSellerOrders() async {
    try {
      _sellerOrders = await _api.fetchSellerOrders();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading seller orders: $e');
    }
  }

  // Tombol "Proses Pesanan" di POV seller -- langkah PERTAMA setelah order
  // masuk (menunggu_konfirmasi -> diproses), sebelum "Kirim Barang"
  Future<void> processOrder(String orderId) async {
    await _api.markOrderProcessing(orderId);
    await loadSellerOrders();
  }

  // Tombol "Kirim Barang" di POV seller
  Future<void> shipOrder(String orderId) async {
    await _api.markOrderShipped(orderId);
    await loadSellerOrders();
  }

  // Tombol "Pesanan Selesai" di POV pembeli
  Future<void> completeOrder(String orderId) async {
    await _api.markOrderCompleted(orderId);
    await loadMyOrders();
  }

  // ==========================================
  // NOTIFICATIONS
  // ==========================================
  Future<void> loadNotifications() async {
    try {
      _notifications = await _api.fetchNotifications();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1 || _notifications[index].isRead) return;
    // Optimistic update
    _notifications[index] = AppNotification(
      id: _notifications[index].id,
      title: _notifications[index].title,
      body: _notifications[index].body,
      type: _notifications[index].type,
      relatedOrderId: _notifications[index].relatedOrderId,
      isRead: true,
      createdAt: _notifications[index].createdAt,
    );
    notifyListeners();
    await _api.markNotificationRead(notificationId);
  }

  Future<void> markAllNotificationsRead() async {
    _notifications = _notifications
        .map((n) => AppNotification(
              id: n.id,
              title: n.title,
              body: n.body,
              type: n.type,
              relatedOrderId: n.relatedOrderId,
              isRead: true,
              createdAt: n.createdAt,
            ))
        .toList();
    notifyListeners();
    await _api.markAllNotificationsRead();
  }

  // ==========================================
  // KOMUNITAS (follow ala X)
  // ==========================================
  Future<void> loadFollowedCommunities() async {
    try {
      _followedCommunities = await _api.fetchFollowedCommunities();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading followed communities: $e');
    }
  }

  // Buat halaman "Cari/Tambah Komunitas" -- semua komunitas + status follow
  Future<List<Community>> searchAllCommunities(String query) {
    return _api.fetchAllCommunities(query: query);
  }

  Future<void> followCommunity(String communityId) async {
    await _api.followCommunity(communityId);
    await loadFollowedCommunities();
  }

  Future<void> unfollowCommunity(String communityId) async {
    await _api.unfollowCommunity(communityId);
    await loadFollowedCommunities();
  }

  // Bikin komunitas baru (deskripsi & rules boleh kosong/di-skip),
  // otomatis ikut nge-follow-in yang bikin
  Future<Community> createCommunity({
    required String name,
    String? description,
    String? rules,
  }) async {
    final community = await _api.createCommunity(
      name: name,
      description: description,
      rules: rules,
    );
    await loadFollowedCommunities();
    return community;
  }

  // ==========================================
  // BLOCK & REPORT
  // ==========================================
  Future<void> loadBlockedUserIds() async {
    try {
      _blockedUserIds = await _api.fetchBlockedUserIds();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
    }
  }

  // Block user -- postingannya langsung disaring dari feed lokal juga
  // (tanpa nunggu refresh) biar kerasa instan
  Future<void> blockUser(String userId) async {
    _blockedUserIds = [..._blockedUserIds, userId];
    _posts = _posts.where((p) => p.userId != userId).toList();
    notifyListeners();
    try {
      await _api.blockUser(userId);
    } catch (e) {
      debugPrint('Error blocking user: $e');
      await loadBlockedUserIds();
      rethrow;
    }
  }

  Future<void> unblockUser(String userId) async {
    _blockedUserIds = _blockedUserIds.where((id) => id != userId).toList();
    notifyListeners();
    await _api.unblockUser(userId);
    await loadPosts();
  }

  // Laporkan postingan/user. Kalau ini laporan ke-3 dari reporter berbeda
  // ke akun yang sama, backend otomatis suspend akun itu 1 hari + kirim
  // notifikasi (baik notifikasi "dilaporkan" maupun "disuspend").
  Future<void> reportContent({
    required String reportedUserId,
    String? postId,
    String? reason,
  }) {
    return _api.reportContent(
      reportedUserId: reportedUserId,
      postId: postId,
      reason: reason,
    );
  }

  // Ambil daftar postingan komunitas
  Future<void> loadPosts() async {
    try {
      _posts = await _api.fetchPosts();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading posts: $e');
    }
  }

  // ==========================================
  // LOGOUT — bersihkan state + secure storage
  // ==========================================
  // Logout: hapus sesi di server, hapus token tersimpan, reset state lokal
  Future<void> signOut() async {
    // Hapus dulu FCM token SEBELUM session-nya hilang (butuh auth aktif
    // buat query ke tabel device_tokens karena RLS-nya berbasis auth.uid())
    await PushNotificationService.instance.unregisterToken();
    await _api.signOut();
    await SecureStorageService.clearAll();
    _clearLocalState();
  }

  // Dipanggil kalau JWT refresh token sudah tidak valid lagi (lihat
  // _initAuthListener di main.dart) -- BEDA dari signOut() biasa karena di
  // sini sesi di server sudah mati duluan (bukan kita yang minta), jadi
  // tidak perlu (dan tidak bisa) panggil _api.signOut() lagi. Cukup bersihin
  // token lokal & state, biar app konsisten dengan kondisi server.
  Future<void> handleSessionExpired() async {
    await SecureStorageService.clearAll();
    _clearLocalState();
  }

  // Reset semua data lokal (dipanggil saat logout)
  void _clearLocalState() {
    _products = [];
    _posts = [];
    _cart = [];
    _myOrders = [];
    _sellerOrders = [];
    _notifications = [];
    _followedCommunities = [];
    _blockedUserIds = [];
    _userProfile = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  // ==========================================
  // UPDATE PROFILE
  // ==========================================
  // Update profil user (username, tanggal lahir, lokasi, avatar)
  Future<void> updateProfile({
    required String username,
    required String birthDate,
    required String location,
    File? avatarFile,
    String? avatarEmoji,
  }) async {
    try {
      String? newAvatarUrl;
      // Upload foto dulu jika ada, kalau tidak ada foto tapi user memilih
      // salah satu avatar emoji preset, pakai itu.
      if (avatarFile != null) {
        newAvatarUrl = await _api.uploadAvatar(avatarFile);
      } else if (avatarEmoji != null) {
        newAvatarUrl = avatarEmoji;
      }

      final updated = await _api.updateProfile(
        username: username,
        birthDate: birthDate,
        location: location,
        avatarUrl: newAvatarUrl,
      );

      // Merge hasil update ke _userProfile lokal agar langsung reaktif
      _userProfile = {
        ...?_userProfile,
        ...updated,
      };
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  // ==========================================
  // ACTIONS & MUTATIONS
  // ==========================================
  // Toggle status favorit produk (optimistic update, rollback kalau gagal)
  Future<void> toggleFavorite(String productId) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final product = _products[index];
      final newFavState = !product.isFavorite;
      product.isFavorite = newFavState;
      product.favoritesCount += newFavState ? 1 : -1;
      if (product.favoritesCount < 0) product.favoritesCount = 0;
      notifyListeners();
      try {
        await _api.toggleFavorite(productId, newFavState);
      } catch (e) {
        // Gagal sync ke server -> kembalikan state seperti semula
        product.isFavorite = !newFavState;
        product.favoritesCount += newFavState ? -1 : 1;
        if (product.favoritesCount < 0) product.favoritesCount = 0;
        notifyListeners();
        debugPrint('Error toggling favorite: $e');
      }
    }
  }

  // Tambah produk ke keranjang (optimistic update + rollback kalau gagal)
  Future<void> addToCart(Product product) async {
    // Guard: penjual tidak boleh masukkan produk jualannya sendiri ke
    // keranjang (juga dicek ulang di server lewat RLS/checkout_cart, tapi
    // dicek duluan di sini biar user langsung dapat pesan yang jelas)
    if (_api.currentUser != null && _api.currentUser!.id == product.sellerId) {
      throw Exception('Ini produkmu sendiri, tidak bisa dimasukkan ke keranjang.');
    }

    // OPTIMISTIC UPDATE: langsung update cart lokal biar terasa instan,
    // baru sinkronkan ke server di belakang layar.
    final existingIndex =
        _cart.indexWhere((item) => item.product.id == product.id);
    CartItem? previousState;
    var isNewLocalItem = false;

    if (existingIndex != -1) {
      previousState = CartItem(
        id: _cart[existingIndex].id,
        product: _cart[existingIndex].product,
        quantity: _cart[existingIndex].quantity,
      );
      _cart[existingIndex].quantity += 1;
    } else {
      isNewLocalItem = true;
      _cart.add(
        CartItem(
          id: 'temp-${product.id}-${DateTime.now().millisecondsSinceEpoch}',
          product: product,
          quantity: 1,
        ),
      );
    }
    notifyListeners();

    try {
      final newItem = await _api.addToCart(product);
      final index = _cart.indexWhere(
        (item) => item.product.id == product.id,
      );
      if (index != -1) {
        _cart[index] = newItem;
      } else {
        _cart.add(newItem);
      }
      notifyListeners();
    } catch (e) {
      // Rollback jika gagal
      if (isNewLocalItem) {
        _cart.removeWhere((item) => item.product.id == product.id);
      } else if (previousState != null && existingIndex != -1) {
        _cart[existingIndex] = previousState;
      }
      notifyListeners();
      debugPrint('Error adding to cart: $e');
      rethrow;
    }
  }

  // Hapus item dari keranjang
  Future<void> removeFromCart(String cartItemId) async {
    try {
      await _api.removeFromCart(cartItemId);
      _cart.removeWhere((item) => item.id == cartItemId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing from cart: $e');
      rethrow;
    }
  }

  // Tambah jumlah item di cart sebanyak 1 (rollback kalau gagal).
  // Tidak boleh melebihi stok yang tersedia.
  Future<void> incrementCartItem(CartItem item) async {
    if (item.quantity >= item.product.stock) {
      _errorMessage = 'Stok ${item.product.name} cuma tersisa ${item.product.stock}.';
      notifyListeners();
      return;
    }
    final newQty = item.quantity + 1;
    item.quantity = newQty;
    notifyListeners();
    try {
      await _api.updateCartQuantity(item.id, newQty);
    } catch (e) {
      item.quantity = newQty - 1;
      notifyListeners();
      debugPrint('Error updating quantity: $e');
    }
  }

  // Kurangi jumlah item di cart sebanyak 1, atau hapus kalau sisa 1
  Future<void> decrementCartItem(CartItem item) async {
    if (item.quantity <= 1) {
      await removeFromCart(item.id);
      return;
    }
    final newQty = item.quantity - 1;
    item.quantity = newQty;
    notifyListeners();
    try {
      await _api.updateCartQuantity(item.id, newQty);
    } catch (e) {
      item.quantity = newQty + 1;
      notifyListeners();
      debugPrint('Error updating quantity: $e');
    }
  }

  // Tambah produk baru ke list lokal (setelah berhasil upload ke server)
  Future<void> addProduct(Product product) async {
    _products.insert(0, product);
    notifyListeners();
  }

  // Update produk yang sudah ada di list lokal (dipakai setelah restock,
  // supaya angka stok yang tampil di UI langsung ter-update tanpa perlu
  // reload seluruh daftar produk dari server)
  void upsertProduct(Product product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
    } else {
      _products.insert(0, product);
    }
    notifyListeners();
  }

  // Hapus produk sendiri -- optimistic remove dari list lokal dulu (biar UI
  // langsung responsif), rollback kalau server ternyata tolak (misal ada
  // trigger DB yang mencegah hapus produk yang masih ada di order aktif).
  Future<void> deleteProduct(String productId) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) return;
    final removed = _products[index];
    _products.removeAt(index);
    notifyListeners();
    try {
      await _api.deleteProduct(productId);
    } catch (e) {
      _products.insert(index, removed);
      notifyListeners();
      rethrow;
    }
  }

  // Tambah postingan baru ke list lokal (setelah berhasil dikirim ke server)
  Future<void> addPost(CommunityPost post) async {
    _posts.insert(0, post);
    notifyListeners();
  }

  // Hapus postingan sendiri -- sama pola optimistic-update + rollback-nya
  // dengan deleteProduct di atas.
  Future<void> deletePost(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final removed = _posts[index];
    _posts.removeAt(index);
    notifyListeners();
    try {
      await _api.deletePost(postId);
    } catch (e) {
      _posts.insert(index, removed);
      notifyListeners();
      rethrow;
    }
  }

  // Vote (upvote/downvote) pada postingan komunitas -- optimistic update,
  // rollback kalau gagal. `value` yang dikirim: 1 (upvote), -1 (downvote).
  // Kalau user tap tombol yang lagi aktif lagi (misal upvote 2x), berarti
  // BATALIN vote (dikirim value: 0).
  Future<void> voteOnPost(String postId, int tappedValue) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final post = _posts[index];
    final previousVote = post.myVote;
    final previousScore = post.voteScore;

    // Kalau tap tombol yang sama dengan vote saat ini -> batalkan (0),
    // kalau tap tombol lain / belum vote -> set ke value yang ditap
    final newVote = previousVote == tappedValue ? 0 : tappedValue;
    final newScore = previousScore - previousVote + newVote;

    post.myVote = newVote;
    final newPost = CommunityPost(
      id: post.id,
      userId: post.userId,
      userName: post.userName,
      userAvatar: post.userAvatar,
      community: post.community,
      type: post.type,
      title: post.title,
      content: post.content,
      postedAt: post.postedAt,
      repliesCount: post.repliesCount,
      voteScore: newScore,
      myVote: newVote,
    );
    _posts[index] = newPost;
    notifyListeners();
    try {
      await _api.voteOnPost(postId, newVote);
    } catch (e) {
      // Gagal sync ke server -> kembalikan post ke state semula
      _posts[index] = post;
      notifyListeners();
      debugPrint('Error voting on post: $e');
    }
  }

  // ==========================================
  // ACCESSORS & FILTERS
  // ==========================================
  // Produk yang boleh di-BROWSE (Explore, kategori, pencarian, top picks) --
  // sengaja BUKAN buangnya produk milik sendiri dari `_products` mentah
  // (getter `products` tetap utuh) supaya halaman Profil > "Produk Saya"
  // yang filter dari `state.products` tidak ikut kosong.
  List<Product> get browsableProducts {
    final myId = _api.currentUser?.id;
    if (myId == null) return _products;
    return _products.where((p) => p.sellerId != myId).toList();
  }

  // Filter produk berdasarkan kategori ('All' = tampilkan semua) -- dari
  // browsableProducts, jadi produk sendiri otomatis tidak ikut nongol
  List<Product> getProductsByCategory(String category) {
    final source = browsableProducts;
    if (category == 'All') return source;
    return source.where((p) => p.category == category).toList();
  }

  // Cari produk berdasarkan nama, brand, kategori, deskripsi, atau nama seller
  List<Product> searchProducts(String query) {
    final source = browsableProducts;
    if (query.isEmpty) return source;
    final q = query.toLowerCase();
    return source
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.brand.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q) ||
            p.sellerName.toLowerCase().contains(q))
        .toList();
  }

  // TOP PICKS: sekarang berbasis histori PEMBELIAN, bukan lagi favorit --
  // produk yang sudah laku dibeli (oleh akun lain, bukan oleh sellernya
  // sendiri) MINIMAL 2 KALI. purchaseCount dihitung server-side dari VIEW
  // `product_purchase_stats` (lihat SQL migrasi) dan ditempelkan ke tiap
  // Product waktu fetchProducts(). Diurutkan dari yang paling laku duluan.
  List<Product> get topPicksProducts {
    final picks =
        browsableProducts.where((p) => p.purchaseCount >= 2).toList();
    picks.sort((a, b) => b.purchaseCount.compareTo(a.purchaseCount));
    return picks;
  }

  // verifiedProducts tetap ada untuk kompatibilitas
  List<Product> get verifiedProducts =>
      browsableProducts.where((p) => p.sellerVerified).toList();

  // Tambah stok produk milik sendiri secara cepat (dipanggil dari Profil >
  // Produk Saya, tanpa harus buka form "Jual Barang" lengkap lagi) --
  // pakai method restockProduct yang sudah ada (dipakai juga di alur
  // auto-restock waktu listing barang yang sama lewat SellPage).
  Future<void> addProductStock(String productId, int amountToAdd) async {
    if (amountToAdd <= 0) return;
    final product = await _api.restockProduct(
      productId: productId,
      addedStock: amountToAdd,
    );
    upsertProduct(product);
  }
}
