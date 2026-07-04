import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'supabase_service.dart';
import 'secure_storage_service.dart';

// State management global aplikasi (produk, cart, posts, profil, dll)
// menggunakan Provider/ChangeNotifier
class AppState extends ChangeNotifier {
  final _api = SupabaseService();

  bool _isLoading = false;
  ThemeMode _themeMode = ThemeMode.system;
  List<Product> _products = [];
  List<CommunityPost> _posts = [];
  List<CartItem> _cart = [];
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
  Map<String, dynamic>? get userProfile => _userProfile;
  int get cartCount => _cart.fold(0, (sum, item) => sum + item.quantity);
  double get cartTotalPrice =>
      _cart.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));

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
      ]);
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
    await _api.signOut();
    await SecureStorageService.clearAll();
    _clearLocalState();
  }

  // Reset semua data lokal (dipanggil saat logout)
  void _clearLocalState() {
    _products = [];
    _posts = [];
    _cart = [];
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

  // Tambah jumlah item di cart sebanyak 1 (rollback kalau gagal)
  Future<void> incrementCartItem(CartItem item) async {
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

  // Tambah postingan baru ke list lokal (setelah berhasil dikirim ke server)
  Future<void> addPost(CommunityPost post) async {
    _posts.insert(0, post);
    notifyListeners();
  }

  // Toggle like pada postingan komunitas (optimistic update, rollback kalau gagal)
  Future<void> toggleLikePost(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      final newLikeState = !post.isLiked;
      post.isLiked = newLikeState;
      final offset = newLikeState ? 1 : -1;
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
        likesCount: post.likesCount + offset,
        isLiked: newLikeState,
      );
      _posts[index] = newPost;
      notifyListeners();
      try {
        await _api.toggleLikePost(postId, newLikeState);
      } catch (e) {
        // Gagal sync ke server -> kembalikan post ke state semula
        _posts[index] = post;
        notifyListeners();
        debugPrint('Error liking post: $e');
      }
    }
  }

  // ==========================================
  // ACCESSORS & FILTERS
  // ==========================================
  // Filter produk berdasarkan kategori ('All' = tampilkan semua)
  List<Product> getProductsByCategory(String category) {
    if (category == 'All') return _products;
    return _products.where((p) => p.category == category).toList();
  }

  // Cari produk berdasarkan nama, brand, kategori, deskripsi, atau nama seller
  List<Product> searchProducts(String query) {
    if (query.isEmpty) return _products;
    final q = query.toLowerCase();
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.brand.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q) ||
            p.sellerName.toLowerCase().contains(q))
        .toList();
  }

  // TOP PICKS: produk yang pernah di-like (favorite) minimal 1 kali oleh
  // user manapun -> pakai favoritesCount (total like dari semua user),
  // BUKAN isFavorite (yang hanya mencerminkan like dari user yang sedang login).
  List<Product> get topPicksProducts =>
      _products.where((p) => p.favoritesCount >= 1).toList();

  // verifiedProducts tetap ada untuk kompatibilitas
  List<Product> get verifiedProducts =>
      _products.where((p) => p.sellerVerified).toList();
}