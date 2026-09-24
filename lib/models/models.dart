// Model data produk yang dijual di marketplace
class Product {
  final String id;
  final String name;
  final String brand;
  final String description;
  final String category;
  final double price;
  final String condition;
  final String size;
  final String sellerId;
  final String sellerName;
  final bool sellerVerified;
  final String? imageUrl;
  final String imageEmoji;
  final String imageColor;
  final DateTime listedAt;
  final List<String> paymentMethods;
  bool isFavorite;
  int favoritesCount;
  int stock;
  // Berapa kali produk ini (baris produk yang sama persis, bukan per-varian)
  // sudah laku terjual ke pembeli lain -- dihitung server-side dari
  // order_items (lihat VIEW product_purchase_stats di SQL migrasi). Dipakai
  // buat badge "Sudah dibeli X kali" di Detail Produk dan buat nentuin
  // "Top Picks" (minimal 2 kali beli oleh akun lain, bukan lagi berbasis favorit).
  int purchaseCount;

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.description,
    required this.category,
    required this.price,
    required this.condition,
    required this.size,
    required this.sellerId,
    required this.sellerName,
    required this.sellerVerified,
    this.imageUrl,
    this.imageEmoji = '\u{1F4E6}',
    this.imageColor = '#E3F2FD',
    required this.listedAt,
    required this.paymentMethods,
    this.isFavorite = false,
    this.favoritesCount = 0,
    this.stock = 1,
    this.purchaseCount = 0,
  });

  // Bikin objek Product dari data JSON (response Supabase)
  factory Product.fromJson(
    Map<String, dynamic> json, {
    bool isFav = false,
    String? currentUserId,
  }) {
    final sellerProfile = json['profiles'] as Map<String, dynamic>?;

    // Hitung status favorit & jumlah favorit dari relasi 'favorites'
    var favorited = isFav;
    var favCount = 0;
    if (json['favorites'] is List) {
      final favList = json['favorites'] as List;
      favCount = favList.length;
      if (currentUserId != null) {
        favorited = favList.any(
          (f) => f is Map && f['user_id'] == currentUserId,
        );
      } else {
        favorited = favList.isNotEmpty;
      }
    }

    return Product(
      id: _readString(json['id']),
      name: _readString(json['name'], fallback: 'Produk tanpa nama'),
      brand: _readString(json['brand'], fallback: 'No Brand'),
      description: _readString(json['description']),
      category: _readString(json['category'], fallback: 'Lainnya'),
      price: _readDouble(json['price']),
      condition: _readString(json['condition'], fallback: 'Preloved - Good'),
      size: _readString(json['size'], fallback: 'One Size'),
      sellerId: _readString(json['seller_id']),
      sellerName: sellerProfile != null
          ? _readString(sellerProfile['username'], fallback: 'seller')
          : 'seller',
      sellerVerified: sellerProfile != null
          ? _readBool(sellerProfile['is_verified'])
          : false,
      imageUrl: json['image_url'] as String?,
      imageEmoji: _readString(json['image_emoji'], fallback: '\u{1F4E6}'),
      imageColor: _readString(json['image_color'], fallback: '#E3F2FD'),
      listedAt: _readDateTime(json['listed_at'] ?? json['created_at']),
      paymentMethods: _readStringList(json['payment_methods']),
      isFavorite: favorited,
      favoritesCount: favCount,
      // Kalau kolom 'stock' belum ada di baris lama (sebelum migrasi),
      // default-nya 1 supaya produk lama tidak dianggap habis.
      stock: json['stock'] is int
          ? json['stock'] as int
          : int.tryParse(json['stock']?.toString() ?? '') ?? 1,
      // 'purchase_count' datang dari VIEW product_purchase_stats yang di-join
      // manual di fetchProducts() (lihat SupabaseService) -- default 0 kalau
      // baris belum pernah laku / kolomnya belum ke-attach.
      purchaseCount: json['purchase_count'] is int
          ? json['purchase_count'] as int
          : int.tryParse(json['purchase_count']?.toString() ?? '') ?? 0,
    );
  }

  // Helper parsing aman: ambil string, fallback kalau null/kosong
  static String _readString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  // Helper parsing aman: ambil angka double dari num/string
  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(normalized) ?? 0;
    }
    return 0;
  }

  // Helper parsing aman: ambil boolean dari bool/string/num
  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return false;
  }

  // Helper parsing aman: ambil tanggal, default ke waktu sekarang kalau gagal
  static DateTime _readDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  // Helper parsing aman: ubah jadi list of string
  static List<String> _readStringList(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const [];
  }
}

// Model data postingan di halaman komunitas
class CommunityPost {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String community;
  final String type;
  final String title;
  final String content;
  final DateTime postedAt;
  final List<String> replies;
  final int repliesCount;
  // Skor bersih upvote-downvote (pengganti sistem like lama)
  final int voteScore;
  // Vote user saat ini di post ini: 1 (upvote), -1 (downvote), atau 0 (belum vote)
  int myVote;

  CommunityPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.community,
    required this.type,
    required this.title,
    required this.content,
    required this.postedAt,
    this.replies = const [],
    int? repliesCount,
    this.voteScore = 0,
    this.myVote = 0,
  }) : repliesCount = repliesCount ?? replies.length;

  // Bikin objek CommunityPost dari data JSON (response Supabase)
  factory CommunityPost.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final profile = json['profiles'] as Map<String, dynamic>?;

    // Hitung skor bersih (jumlah value +1/-1) & vote milik user saat ini
    // dari daftar mentah post_votes yang di-join
    var voteScore = 0;
    var myVote = 0;
    if (json['post_votes'] is List) {
      final votes = json['post_votes'] as List;
      for (final v in votes) {
        if (v is! Map) continue;
        final value = (v['value'] as num?)?.toInt() ?? 0;
        voteScore += value;
        if (currentUserId != null && v['user_id'] == currentUserId) {
          myVote = value;
        }
      }
    }

    // Ambil jumlah balasan, prioritaskan count dari server, fallback hitung dari list
    var repliesCount = 0;
    if (json['community_replies_count'] is int) {
      repliesCount = json['community_replies_count'] as int;
    } else if (json['community_replies'] is List) {
      repliesCount = (json['community_replies'] as List).length;
    }

    return CommunityPost(
      id: _readString(json['id']),
      userId: _readString(json['user_id']),
      userName: profile != null
          ? _readString(profile['username'], fallback: 'user')
          : 'user',
      userAvatar: profile != null
          ? _readString(profile['avatar_url'], fallback: '\u{1F464}')
          : '\u{1F464}',
      community: _readString(json['community'], fallback: 'General'),
      type: _readString(json['type'], fallback: 'Discussion'),
      title: _readString(json['title'], fallback: 'Tanpa judul'),
      content: _readString(json['content']),
      postedAt: _readDateTime(json['posted_at'] ?? json['created_at']),
      repliesCount: repliesCount,
      voteScore: voteScore,
      myVote: myVote,
    );
  }

  // Helper parsing aman: ambil string, fallback kalau null/kosong
  static String _readString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  // Helper parsing aman: ambil tanggal, default ke waktu sekarang kalau gagal
  static DateTime _readDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

// Model 1 komunitas (katalog) -- beda dari `community` (text) di
// CommunityPost, ini yang dipakai buat sistem follow ala X, halaman "Buat
// Komunitas Baru", dan browse/cari komunitas.
class Community {
  final String id;
  final String name;
  final String? description;
  final String? rules;
  final String? createdBy;
  final DateTime createdAt;
  final bool isFollowing;
  final int followerCount;

  Community({
    required this.id,
    required this.name,
    this.description,
    this.rules,
    this.createdBy,
    required this.createdAt,
    this.isFollowing = false,
    this.followerCount = 0,
  });

  factory Community.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    var isFollowing = false;
    var followerCount = 0;
    if (json['community_follows'] is List) {
      final follows = json['community_follows'] as List;
      followerCount = follows.length;
      if (currentUserId != null) {
        isFollowing = follows.any((f) => f is Map && f['user_id'] == currentUserId);
      }
    }
    return Community(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description'] as String?,
      rules: json['rules'] as String?,
      createdBy: json['created_by']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      isFollowing: isFollowing,
      followerCount: followerCount,
    );
  }
}

// Model satu percakapan chat antara pembeli & penjual (untuk 1 produk).
// Dua orang yang sama, produk yang sama -> selalu 1 baris conversation yang
// sama, jadi histori chat-nya nyambung terus, tidak bikin thread baru tiap kali.
class ChatConversation {
  final String id;
  final String productId;
  final String productName;
  final String? productImageUrl;
  final double productPrice;
  final String buyerId;
  final String sellerId;
  final String otherUserId; // lawan bicara dari sudut pandang user saat ini
  final String otherUsername;
  final String otherAvatar;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  ChatConversation({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    this.productPrice = 0,
    required this.buyerId,
    required this.sellerId,
    required this.otherUserId,
    required this.otherUsername,
    required this.otherAvatar,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  // Bikin objek ChatConversation dari data JSON (response Supabase),
  // butuh currentUserId supaya tahu siapa "lawan bicara"-nya.
  factory ChatConversation.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    final product = json['products'] as Map<String, dynamic>?;
    final buyerId = _readString(json['buyer_id']);
    final sellerId = _readString(json['seller_id']);
    final isBuyer = currentUserId == buyerId;
    final otherProfile = isBuyer
        ? json['seller_profile'] as Map<String, dynamic>?
        : json['buyer_profile'] as Map<String, dynamic>?;

    return ChatConversation(
      id: _readString(json['id']),
      productId: _readString(json['product_id']),
      productName: product != null
          ? _readString(product['name'], fallback: 'Produk')
          : 'Produk',
      productImageUrl: product?['image_url'] as String?,
      productPrice: product != null
          ? (product['price'] as num? ?? 0).toDouble()
          : 0,
      buyerId: buyerId,
      sellerId: sellerId,
      otherUserId: isBuyer ? sellerId : buyerId,
      otherUsername: otherProfile != null
          ? _readString(otherProfile['username'], fallback: 'user')
          : 'user',
      otherAvatar: otherProfile != null
          ? _readString(otherProfile['avatar_url'], fallback: '\u{1F464}')
          : '\u{1F464}',
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.tryParse(json['last_message_at'].toString())
          : null,
      unreadCount: json['unread_count'] is int ? json['unread_count'] as int : 0,
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }
}

// Model satu pesan chat di dalam sebuah conversation
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'].toString(),
      conversationId: json['conversation_id'].toString(),
      senderId: json['sender_id'].toString(),
      content: (json['content'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
              DateTime.now(),
      isRead: json['is_read'] == true,
    );
  }
}

// Model alamat pengiriman milik user (mirip "Alamat Saya" di Shopee) --
// bisa punya beberapa alamat tersimpan, salah satunya ditandai default.
class Address {
  final String id;
  final String label; // Rumah, Kantor, Lainnya
  final String recipientName;
  final String phone;
  final String fullAddress;
  final String? landmark; // patokan, misal "dekat minimarket biru"
  final String city;
  final String province;
  final String? postalCode;
  final bool isDefault;
  // Koordinat hasil Google Geocoding/Places -- dipakai buat hitung ongkir
  // berdasarkan jarak ke penjual. Nullable karena alamat lama (sebelum fitur
  // picker lokasi ini ada) belum tentu punya koordinat.
  final double? latitude;
  final double? longitude;

  Address({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.fullAddress,
    this.landmark,
    required this.city,
    required this.province,
    this.postalCode,
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'].toString(),
      label: (json['label'] ?? 'Rumah').toString(),
      recipientName: (json['recipient_name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      fullAddress: (json['full_address'] ?? '').toString(),
      landmark: json['landmark'] as String?,
      city: (json['city'] ?? '').toString(),
      province: (json['province'] ?? '').toString(),
      postalCode: json['postal_code'] as String?,
      isDefault: json['is_default'] == true,
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
    );
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  // Ringkasan alamat 1-2 baris buat ditampilkan di kartu checkout
  String get shortSummary {
    final parts = [fullAddress, city, province]
        .where((p) => p.trim().isNotEmpty)
        .join(', ');
    return parts;
  }
}

// Model item di keranjang belanja (produk + jumlah)
class CartItem {
  final String id;
  final Product product;
  int quantity;
  // Harga hasil nego (chat "Ajukan Tawaran") yang sudah di-ACC seller,
  // KHUSUS untuk pembeli pemilik cart ini -- bukan harga produk yang
  // berubah secara global. Null artinya pakai harga normal product.price.
  // Diisi dari tabel `product_offers` (status='accepted') lewat
  // SupabaseService.fetchAcceptedOffer / disimpan di cart_items.negotiated_price.
  double? negotiatedPrice;

  CartItem({
    required this.id,
    required this.product,
    this.quantity = 1,
    this.negotiatedPrice,
  });

  // Harga per-unit yang sebenarnya dipakai untuk hitung subtotal & checkout:
  // harga nego kalau ada, kalau tidak ya harga normal produk.
  double get effectivePrice => negotiatedPrice ?? product.price;
  bool get isNegotiated => negotiatedPrice != null && negotiatedPrice! < product.price;
}

// Status tawaran nego harga di dalam sebuah percakapan chat.
class OfferStatus {
  static const pending = 'pending';
  static const accepted = 'accepted';
  static const rejected = 'rejected';
  static const cancelled = 'cancelled';
}

// Model 1 tawaran nego harga (hasil fitur "Ajukan Tawaran" di chat room).
// Satu conversation bisa punya beberapa offer (riwayat tawar-menawar), tapi
// cuma boleh ada 1 offer berstatus 'accepted' aktif per (product, buyer) --
// itu yang dipakai sebagai negotiatedPrice khusus buyer itu di keranjangnya.
class ProductOffer {
  final String id;
  final String conversationId;
  final String productId;
  final String buyerId;
  final String sellerId;
  final double originalPrice;
  final double offeredPrice;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  ProductOffer({
    required this.id,
    required this.conversationId,
    required this.productId,
    required this.buyerId,
    required this.sellerId,
    required this.originalPrice,
    required this.offeredPrice,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory ProductOffer.fromJson(Map<String, dynamic> json) {
    return ProductOffer(
      id: json['id'].toString(),
      conversationId: (json['conversation_id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      buyerId: (json['buyer_id'] ?? '').toString(),
      sellerId: (json['seller_id'] ?? '').toString(),
      originalPrice: (json['original_price'] as num? ?? 0).toDouble(),
      offeredPrice: (json['offered_price'] as num? ?? 0).toDouble(),
      status: (json['status'] ?? OfferStatus.pending).toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'].toString())
          : null,
    );
  }
}

// Opsi pengiriman (Reguler/Express) beserta estimasi harga & durasi.
// Harganya dihitung di sisi klien berdasarkan jarak (Haversine) antara
// koordinat alamat pembeli dan penjual -- lihat GeocodingService.distanceKm
// dan AppState.buildShippingOptions.
class ShippingOption {
  final String code; // 'reguler' | 'express'
  final String name;
  final String etaLabel;
  final double price;

  ShippingOption({
    required this.code,
    required this.name,
    required this.etaLabel,
    required this.price,
  });
}

// Status pesanan sepanjang siklus hidupnya. Disimpan sebagai teks di kolom
// `orders.status` (lihat SQL migrasi) supaya gampang dibaca langsung dari DB.
class OrderStatus {
  static const waitingSeller = 'menunggu_konfirmasi';
  static const processing = 'diproses';
  static const shipped = 'dikirim';
  static const completed = 'selesai';
  static const cancelled = 'dibatalkan';

  static String label(String status) {
    switch (status) {
      case processing:
        return 'Barang Disiapkan Seller';
      case shipped:
        return 'Sedang Dalam Perjalanan';
      case completed:
        return 'Selesai';
      case cancelled:
        return 'Dibatalkan';
      case waitingSeller:
      default:
        return 'Menunggu Konfirmasi Seller';
    }
  }

  // Urutan step buat progress tracker di POV pembeli. "Pesanan Dibuat"
  // sengaja jadi step ke-0 yang statusnya sendiri tidak pernah tersimpan
  // di DB (begitu order dibuat langsung mulai dari waitingSeller) tapi
  // tetap ditampilkan sebagai step pertama yang otomatis selesai.
  static const trackingSteps = [
    waitingSeller,
    processing,
    shipped,
    completed,
  ];

  static const trackingLabels = {
    waitingSeller: 'Pesanan Dibuat',
    processing: 'Disiapkan Seller',
    shipped: 'Dalam Perjalanan',
    completed: 'Sampai Tujuan',
  };

  // Index step saat ini di trackingSteps -- dipakai buat gambar progress
  // bar/stepper. Status 'dibatalkan' dikembalikan -1 (di luar alur normal).
  static int stepIndex(String status) {
    final i = trackingSteps.indexOf(status);
    return i;
  }
}

// Model 1 notifikasi (pesanan baru, status berubah, dst). Dibuat otomatis
// oleh function Postgres (place_order, mark_order_processing, dst) --
// bukan diinsert langsung dari app.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? relatedOrderId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.relatedOrderId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      type: (json['type'] ?? 'info').toString(),
      relatedOrderId: json['related_order_id']?.toString(),
      isRead: json['is_read'] == true,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

// Model 1 baris produk di dalam sebuah order (snapshot harga & qty saat
// checkout, supaya kalau harga produk berubah setelahnya histori order
// tidak ikut berubah).
class OrderItem {
  final String id;
  final String productId;
  final String productName;
  final String? productImageUrl;
  final double priceAtPurchase;
  final int quantity;

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.priceAtPurchase,
    required this.quantity,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final product = json['products'] as Map<String, dynamic>?;
    return OrderItem(
      id: json['id'].toString(),
      productId: (json['product_id'] ?? '').toString(),
      productName: product != null
          ? (product['name'] ?? 'Produk').toString()
          : 'Produk',
      productImageUrl: product?['image_url'] as String?,
      priceAtPurchase: (json['price_at_purchase'] as num? ?? 0).toDouble(),
      quantity: json['quantity'] is int
          ? json['quantity'] as int
          : int.tryParse(json['quantity']?.toString() ?? '') ?? 1,
    );
  }
}

// Model 1 pesanan (order) -- mencakup alamat kirim (snapshot, bukan
// referensi hidup ke tabel addresses, supaya kalau alamat itu dihapus/diubah
// nanti histori order tetap utuh), metode pengiriman & pembayaran, serta
// daftar item di dalamnya.
class Order {
  final String id;
  final String buyerId;
  final String sellerId;
  final String? sellerName;
  final String? buyerName;
  final String status;
  final String recipientName;
  final String recipientPhone;
  final String shippingAddress;
  final double? destLatitude;
  final double? destLongitude;
  final String shippingMethod; // 'reguler' | 'express'
  final double shippingCost;
  final String paymentMethod;
  final String? note;
  final double totalPrice;
  final DateTime createdAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    this.sellerName,
    this.buyerName,
    required this.status,
    required this.recipientName,
    required this.recipientPhone,
    required this.shippingAddress,
    this.destLatitude,
    this.destLongitude,
    required this.shippingMethod,
    required this.shippingCost,
    required this.paymentMethod,
    this.note,
    required this.totalPrice,
    required this.createdAt,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final sellerProfile = json['seller_profile'] as Map<String, dynamic>?;
    final buyerProfile = json['buyer_profile'] as Map<String, dynamic>?;
    final itemsJson = json['order_items'] as List? ?? [];
    return Order(
      id: json['id'].toString(),
      buyerId: (json['buyer_id'] ?? '').toString(),
      sellerId: (json['seller_id'] ?? '').toString(),
      sellerName: sellerProfile?['username'] as String?,
      buyerName: buyerProfile?['username'] as String?,
      status: (json['status'] ?? OrderStatus.waitingSeller).toString(),
      recipientName: (json['recipient_name'] ?? '').toString(),
      recipientPhone: (json['recipient_phone'] ?? '').toString(),
      shippingAddress: (json['shipping_address'] ?? '').toString(),
      destLatitude: json['dest_latitude'] != null
          ? double.tryParse(json['dest_latitude'].toString())
          : null,
      destLongitude: json['dest_longitude'] != null
          ? double.tryParse(json['dest_longitude'].toString())
          : null,
      shippingMethod: (json['shipping_method'] ?? 'reguler').toString(),
      shippingCost: (json['shipping_cost'] as num? ?? 0).toDouble(),
      paymentMethod: (json['payment_method'] ?? '').toString(),
      note: json['note'] as String?,
      totalPrice: (json['total_price'] as num? ?? 0).toDouble(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
              DateTime.now(),
      items: itemsJson
          .map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}
