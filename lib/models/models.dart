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
  });

  factory Product.fromJson(
    Map<String, dynamic> json, {
    bool isFav = false,
    String? currentUserId,
  }) {
    final sellerProfile = json['profiles'] as Map<String, dynamic>?;

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
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(normalized) ?? 0;
    }
    return 0;
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return false;
  }

  static DateTime _readDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static List<String> _readStringList(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const [];
  }
}

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
  final int likesCount;
  bool isLiked;

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
    int? likesCount,
    int? likes,
    this.isLiked = false,
  })  : repliesCount = repliesCount ?? replies.length,
        likesCount = likesCount ?? likes ?? 0;

  factory CommunityPost.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final profile = json['profiles'] as Map<String, dynamic>?;

    var liked = false;
    if (json['post_likes'] is List) {
      final likesList = json['post_likes'] as List;
      if (currentUserId != null) {
        liked = likesList.any((l) => l is Map && l['user_id'] == currentUserId);
      } else {
        liked = likesList.isNotEmpty;
      }
    }

    var likesCount = 0;
    if (json['post_likes_count'] is int) {
      likesCount = json['post_likes_count'] as int;
    } else if (json['post_likes'] is List) {
      likesCount = (json['post_likes'] as List).length;
    }

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
      likesCount: likesCount,
      isLiked: liked,
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static DateTime _readDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

class CartItem {
  final String id;
  final Product product;
  int quantity;

  CartItem({required this.id, required this.product, this.quantity = 1});
}
