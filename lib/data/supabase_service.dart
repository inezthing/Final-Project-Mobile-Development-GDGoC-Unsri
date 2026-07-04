import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'package:flutter/foundation.dart';

// Helper untuk mengubah Supabase error jadi pesan yang ramah user
String _friendlyError(Object e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('invalid login credentials') ||
      msg.contains('email not confirmed')) {
    return 'Email atau password salah. Coba lagi.';
  }
  if (msg.contains('user already registered') ||
      msg.contains('already been registered')) {
    return 'Email ini sudah terdaftar. Silakan masuk.';
  }
  if (msg.contains('network') ||
      msg.contains('socket') ||
      msg.contains('connection')) {
    return 'Tidak ada koneksi internet. Periksa jaringanmu.';
  }
  if (msg.contains('rate limit')) {
    return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
  }
  if (msg.contains('jwt') || msg.contains('token')) {
    return 'Sesi kamu sudah habis. Silakan masuk ulang.';
  }
  if (msg.contains('permission') || msg.contains('policy')) {
    return 'Kamu tidak punya akses untuk melakukan ini.';
  }
  return 'Terjadi kesalahan. Coba lagi nanti.';
}

// Service utama buat semua komunikasi ke Supabase (auth, database, storage).
// Dibuat singleton biar instance-nya sama di seluruh aplikasi.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  SupabaseClient get client => _client;

  // ==========================================
  // AUTHENTICATION
  // ==========================================
  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  // Login dengan email & password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // Registrasi akun baru + buat profil di tabel 'profiles'
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    required String birthDate,
    required String location,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'avatar_url': '\u{1F337}',
          'birth_date': birthDate,
          'location': location,
        },
      );

      if (response.session != null && response.user != null) {
        await upsertUserProfile(
          userId: response.user!.id,
          username: username,
          birthDate: birthDate,
          location: location,
        );
      }

      return response;
    } catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  // Simpan/update data profil user (insert kalau belum ada, update kalau sudah)
  Future<void> upsertUserProfile({
    required String userId,
    required String username,
    required String birthDate,
    required String location,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'username': username,
      'avatar_url': '\u{1F337}',
      'birth_date': birthDate,
      'location': location,
    });
  }

  // Logout dari Supabase auth
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Sign out error (ignored): $e');
    }
  }

  // Ambil profil user berdasarkan ID, otomatis perbaiki kalau baris profil hilang
  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data != null) return data;

      // PENTING: kalau baris di tabel profiles belum ada (misal trigger
      // handle_new_user gagal/telat), JANGAN cuma dipalsukan di lokal saja.
      // Kalau dipalsukan, aplikasi terlihat baik-baik saja tapi semua insert
      // lain yang mereferensikan profiles(id) -- seperti bikin postingan
      // komunitas, produk, cart, favorit -- akan gagal dengan error foreign
      // key karena baris user-nya sendiri tidak nyata ada di database.
      // Jadi di sini kita benar-benar buat baris-nya di database.
      if (currentUser?.id == userId) {
        final repaired = await _repairMissingProfile(currentUser!);
        if (repaired != null) return repaired;
        return _profileFromAuthUser(currentUser!);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      if (currentUser?.id == userId) {
        final repaired = await _repairMissingProfile(currentUser!);
        if (repaired != null) return repaired;
        return _profileFromAuthUser(currentUser!);
      }
      return null;
    }
  }

  // Membuat ulang baris profiles yang hilang berdasarkan data auth.users,
  // supaya foreign key ke profiles(id) di tabel lain (products, cart_items,
  // favorites, community_posts, dst) tidak gagal.
  Future<Map<String, dynamic>?> _repairMissingProfile(User user) async {
    try {
      final metadata = user.userMetadata ?? {};
      final fallback = _profileFromAuthUser(user);
      final response = await _client
          .from('profiles')
          .upsert({
            'id': user.id,
            'username': fallback['username'],
            'avatar_url': metadata['avatar_url'] ?? '\u{1F337}',
            'birth_date': metadata['birth_date'],
            'location': metadata['location'],
          })
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('Error repairing missing profile: $e');
      return null;
    }
  }

  // Bikin data profil sementara dari metadata auth (dipakai kalau repair gagal)
  Map<String, dynamic> _profileFromAuthUser(User user) {
    final metadata = user.userMetadata ?? {};
    return {
      'id': user.id,
      'username': metadata['username'] ?? user.email?.split('@').first ?? 'User',
      'avatar_url': metadata['avatar_url'] ?? '\u{1F337}',
      'birth_date': metadata['birth_date'],
      'location': metadata['location'],
      'created_at': user.createdAt,
    };
  }

  // ==========================================
  // UPDATE PROFILE (username, birth_date, location, avatar_url)
  // ==========================================
  // Update data profil (username, tanggal lahir, lokasi, avatar opsional)
  Future<Map<String, dynamic>> updateProfile({
    required String username,
    required String birthDate,
    required String location,
    String? avatarUrl,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      final updates = <String, dynamic>{
        'username': username,
        'birth_date': birthDate,
        'location': location,
      };
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      final response = await _client
          .from('profiles')
          .update(updates)
          .eq('id', currentUser!.id)
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Upload foto profil ke storage bucket 'avatars', return public URL
  Future<String?> uploadAvatar(File file) async {
    try {
      if (currentUser == null) return null;
      final fileName = '${currentUser!.id}/avatar.jpg';
      await _client.storage.from('avatars').upload(
            fileName,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      return _client.storage.from('avatars').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      return null;
    }
  }

  // ==========================================
  // PRODUCTS
  // ==========================================
  // Ambil semua produk beserta data seller & favorit; fallback ke query
  // sederhana kalau query dengan relasi gagal
  Future<List<Product>> fetchProducts() async {
    try {
      final userId = currentUser?.id;
      List<dynamic> response;
      try {
        response = await _client
            .from('products')
            .select('*, profiles!products_seller_id_fkey(*), favorites(*)')
            .order('listed_at', ascending: false);
      } catch (e) {
        debugPrint('Fetch products with relations failed, retrying basic query: $e');
        response = await _client
            .from('products')
            .select()
            .order('listed_at', ascending: false);
      }
      return response.map((json) {
        return Product.fromJson(json, currentUserId: userId);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching products: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Buat produk baru sekaligus set emoji & warna default sesuai kategori
  Future<Product> createProduct({
    required String name,
    required String brand,
    required String description,
    required String category,
    required double price,
    required String condition,
    required String size,
    String? imageUrl,
    required List<String> paymentMethods,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      final userId = currentUser!.id;
      final response = await _client
          .from('products')
          .insert({
            'name': name,
            'brand': brand,
            'description': description,
            'category': category,
            'price': price,
            'condition': condition,
            'size': size,
            'seller_id': userId,
            'image_url': imageUrl,
            'payment_methods': paymentMethods,
            'image_emoji': _getCategoryEmojiSafe(category),
            'image_color': _getCategoryColor(category),
          })
          .select()
          .single();

      final productJson = Map<String, dynamic>.from(response);
      final profile = await fetchUserProfile(userId);
      if (profile != null) {
        productJson['profiles'] = profile;
      }

      return Product.fromJson(productJson, currentUserId: userId);
    } catch (e) {
      debugPrint('Error creating product: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Upload foto produk ke storage bucket 'product_images', return public URL
  Future<String?> uploadProductImage(File file) async {
    try {
      if (currentUser == null) return null;
      final fileName =
          '${currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from('product_images').upload(
            fileName,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );
      return _client.storage.from('product_images').getPublicUrl(fileName);
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // Tambah/hapus produk dari daftar favorit user
  Future<void> toggleFavorite(String productId, bool isFavorite) async {
    if (currentUser == null) return;
    try {
      if (isFavorite) {
        await _client.from('favorites').insert({
          'user_id': currentUser!.id,
          'product_id': productId,
        });
      } else {
        await _client.from('favorites').delete().match({
          'user_id': currentUser!.id,
          'product_id': productId,
        });
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // ==========================================
  // CART
  // ==========================================
  // Ambil isi keranjang user beserta detail produknya
  Future<List<CartItem>> fetchCart() async {
    if (currentUser == null) return [];
    try {
      final response = await _client
          .from('cart_items')
          .select('*, products(*, profiles!products_seller_id_fkey(*))')
          .eq('user_id', currentUser!.id);
      return (response as List).map((json) {
        final productJson = json['products'];
        final product = Product.fromJson(
          productJson,
          currentUserId: currentUser!.id,
        );
        return CartItem(
          id: json['id'] as String,
          product: product,
          quantity: json['quantity'] as int,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching cart: $e');
      return [];
    }
  }

  // Tambah produk ke cart: kalau sudah ada, tambah quantity; kalau belum, insert baru
  Future<CartItem> addToCart(Product product) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      final existing = await _client
          .from('cart_items')
          .select()
          .eq('user_id', currentUser!.id)
          .eq('product_id', product.id)
          .maybeSingle();

      if (existing != null) {
        final newQty = (existing['quantity'] as int) + 1;
        final response = await _client
            .from('cart_items')
            .update({'quantity': newQty})
            .eq('id', existing['id'])
            .select('*, products(*, profiles!products_seller_id_fkey(*))')
            .single();
        final prod = Product.fromJson(
          response['products'],
          currentUserId: currentUser!.id,
        );
        return CartItem(
          id: response['id'] as String,
          product: prod,
          quantity: response['quantity'] as int,
        );
      } else {
        final response = await _client
            .from('cart_items')
            .insert({
              'user_id': currentUser!.id,
              'product_id': product.id,
              'quantity': 1,
            })
            .select('*, products(*, profiles!products_seller_id_fkey(*))')
            .single();
        final prod = Product.fromJson(
          response['products'],
          currentUserId: currentUser!.id,
        );
        return CartItem(
          id: response['id'] as String,
          product: prod,
          quantity: response['quantity'] as int,
        );
      }
    } catch (e) {
      debugPrint('Error adding to cart: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Hapus item dari cart berdasarkan ID
  Future<void> removeFromCart(String cartItemId) async {
    if (currentUser == null) return;
    try {
      await _client.from('cart_items').delete().eq('id', cartItemId);
    } catch (e) {
      debugPrint('Error removing from cart: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Update jumlah quantity item cart
  Future<void> updateCartQuantity(String cartItemId, int quantity) async {
    if (currentUser == null) return;
    try {
      await _client
          .from('cart_items')
          .update({'quantity': quantity}).eq('id', cartItemId);
    } catch (e) {
      debugPrint('Error updating cart quantity: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // ==========================================
  // COMMUNITY
  // ==========================================
  // Ambil semua postingan komunitas beserta profil, like, dan jumlah balasan
  Future<List<CommunityPost>> fetchPosts() async {
    try {
      final userId = currentUser?.id;
      final response = await _client
          .from('community_posts')
          .select('*, profiles!community_posts_user_id_fkey(*), post_likes(*), community_replies(count)')
          .order('posted_at', ascending: false);
      return (response as List).map((json) {
        // Ambil jumlah balasan dari hasil aggregate count
        final repliesCount =
            (json['community_replies'] as List?)?.first?['count'] ?? 0;
        final enrichedJson = Map<String, dynamic>.from(json);
        enrichedJson['community_replies_count'] = repliesCount;
        return CommunityPost.fromJson(enrichedJson, currentUserId: userId);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      return [];
    }
  }

  // Buat postingan komunitas baru
  Future<CommunityPost> createPost({
    required String community,
    required String type,
    required String title,
    required String content,
  }) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      final response = await _client
          .from('community_posts')
          .insert({
            'user_id': currentUser!.id,
            'community': community,
            'type': type,
            'title': title,
            'content': content,
          })
          .select('*, profiles!community_posts_user_id_fkey(*)')
          .single();
      return CommunityPost.fromJson(response, currentUserId: currentUser!.id);
    } catch (e) {
      debugPrint('Error creating post: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Tambah/hapus like pada postingan
  Future<void> toggleLikePost(String postId, bool isLiked) async {
    if (currentUser == null) return;
    try {
      if (isLiked) {
        await _client.from('post_likes').insert({
          'user_id': currentUser!.id,
          'post_id': postId,
        });
      } else {
        await _client.from('post_likes').delete().match({
          'user_id': currentUser!.id,
          'post_id': postId,
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // Ambil daftar balasan untuk satu postingan, urut dari yang terlama
  Future<List<Map<String, dynamic>>> fetchReplies(String postId) async {
    try {
      final response = await _client
          .from('community_replies')
          .select('*, profiles!community_replies_user_id_fkey(*)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching replies: $e');
      return [];
    }
  }

  // Kirim balasan baru ke sebuah postingan
  Future<void> createReply(String postId, String content) async {
    if (currentUser == null) throw Exception('Kamu perlu masuk dulu.');
    try {
      await _client.from('community_replies').insert({
        'post_id': postId,
        'user_id': currentUser!.id,
        'content': content,
      });
    } catch (e) {
      debugPrint('Error creating reply: $e');
      throw Exception(_friendlyError(e));
    }
  }

  // ==========================================
  // HELPER EMOJIS & COLORS (FALLBACK)
  // ==========================================
  // Ambil emoji default berdasarkan kategori produk
  String _getCategoryEmojiSafe(String category) {
    switch (category) {
      case 'Woman Fashion':
        return '\u{1F457}';
      case 'Man Fashion':
        return '\u{1F455}';
      case 'Health & Beauty':
        return '\u{1F484}';
      case 'Keychain':
        return '\u{1F511}';
      case 'Trinket':
        return '\u{1F9F8}';
      case 'Shoes':
        return '\u{1F45F}';
      case 'Playing Card':
        return '\u{1F0CF}';
      case 'Sticker':
        return '\u{1F3F7}\u{FE0F}';
      default:
        return '\u{1F4E6}';
    }
  }

  // Ambil warna latar default berdasarkan kategori produk
  String _getCategoryColor(String category) {
    switch (category) {
      case 'Woman Fashion':
        return '#FFCCD5';
      case 'Man Fashion':
        return '#D8E2DC';
      case 'Health & Beauty':
        return '#FFCAD4';
      case 'Keychain':
        return '#F4ACB7';
      case 'Trinket':
        return '#FFE5D9';
      case 'Shoes':
        return '#D8E2DC';
      case 'Playing Card':
        return '#ECE4DB';
      case 'Sticker':
        return '#FFE5D9';
      default:
        return '#E3F2FD';
    }
  }
}