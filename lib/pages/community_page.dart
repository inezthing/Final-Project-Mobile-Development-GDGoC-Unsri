import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../data/supabase_service.dart';

// Halaman komunitas: filter by komunitas, list postingan, buat post baru
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  String _selectedCommunity = 'All';

  // Daftar tab komunitas yang bisa difilter
  final List<String> _communities = [
    'All',
    'Hirono',
    'Nyota',
    'TCG Pokemon',
    'Trinket',
    'Mofusand',
    'Snoopy',
    'Labubu',
    'Molly',
  ];

  // Warna badge berdasarkan tipe postingan (WTS/WTB/Discussion)
  final Map<String, Color> _typeColors = {
    'WTS': const Color(0xFFE91E8C),
    'WTB': const Color(0xFF4CAF50),
    'Discussion': const Color(0xFF2196F3),
  };

  // Format tanggal jadi teks relatif (mis. "5m yang lalu")
  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m yang lalu';
    if (diff.inHours < 24) return '${diff.inHours}j yang lalu';
    return '${diff.inDays}h yang lalu';
  }

  // Tampilkan bottom sheet form untuk membuat postingan baru
  void _showAddPostDialog(BuildContext context) {
    final state = context.read<AppState>();
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String selectedType = 'Discussion';
    String selectedCommunity = 'Hirono';
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D1B2E) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Buat Postingan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Type + community row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedType,
                            decoration: const InputDecoration(
                              labelText: 'Tipe',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: ['WTS', 'WTB', 'Discussion']
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setModalState(() => selectedType = v!),
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF2D1B2E),
                              fontSize: 13,
                            ),
                            dropdownColor: isDark
                                ? const Color(0xFF2D1B2E)
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedCommunity,
                            decoration: const InputDecoration(
                              labelText: 'Komunitas',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: _communities
                                .where((c) => c != 'All')
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setModalState(() => selectedCommunity = v!),
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF2D1B2E),
                              fontSize: 13,
                            ),
                            dropdownColor: isDark
                                ? const Color(0xFF2D1B2E)
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Judul postingan',
                        hintText: '[WTB] Cari Hirono Macaron...',
                      ),
                      validator: (v) => v == null || v.trim().length < 5
                          ? 'Minimal 5 karakter'
                          : null,
                    ),

                    const SizedBox(height: 10),
                    TextFormField(
                      controller: contentCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Konten',
                        hintText: 'Tulis detail, budget, lokasi...',
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => v == null || v.trim().length < 10
                          ? 'Minimal 10 karakter'
                          : null,
                    ),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          // Kirim post baru ke server, lalu update state lokal
                          try {
                            final post = await SupabaseService().createPost(
                              community: selectedCommunity,
                              type: selectedType,
                              title: titleCtrl.text.trim(),
                              content: contentCtrl.text.trim(),
                            );
                            state.addPost(post);
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Postingan berhasil dibuat! 🎉',
                                  ),
                                  backgroundColor: AppTheme.primary,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal mengirim postingan: $e'),
                                  backgroundColor: Colors.red[400],
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Posting Sekarang'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Buka bottom sheet percakapan/balasan untuk sebuah postingan
  void _showConversation(BuildContext context, CommunityPost post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConversationBottomSheet(post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Filter postingan sesuai komunitas yang dipilih
    final filteredPosts = _selectedCommunity == 'All'
        ? state.posts
        : state.posts.where((p) => p.community == _selectedCommunity).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Komunitas 💬'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter chip komunitas (scroll horizontal)
            SizedBox(
              height: 46,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                itemCount: _communities.length,
                itemBuilder: (context, index) {
                  final comm = _communities[index];
                  final isSelected = comm == _selectedCommunity;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCommunity = comm),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : (isDark ? Colors.white24 : Colors.grey[300]!),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        comm,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white60 : Colors.grey[600]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Daftar postingan (atau state kosong kalau belum ada)
            Expanded(
              child: filteredPosts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('💬', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada postingan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white54 : Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextButton(
                            onPressed: () => _showAddPostDialog(context),
                            child: const Text(
                              'Jadilah yang pertama posting!',
                              style: TextStyle(color: AppTheme.primary),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredPosts.length,
                      itemBuilder: (context, index) {
                        final post = filteredPosts[index];
                        final typeColor =
                            _typeColors[post.type] ?? AppTheme.primary;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () => _showConversation(context, post),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppTheme.blush,
                                        child: Text(
                                          post.userAvatar,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '@${post.userName}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white
                                                    : const Color(0xFF2D1B2E),
                                              ),
                                            ),
                                            Text(
                                              '${post.community} • ${_timeAgo(post.postedAt)}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isDark
                                                    ? Colors.white38
                                                    : Colors.grey[400],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: typeColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          post.type,
                                          style: TextStyle(
                                            color: typeColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    post.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF2D1B2E),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    post.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline,
                                        size: 14,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.grey[400],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${post.repliesCount} balasan',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.white38
                                              : Colors.grey[400],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      GestureDetector(
                                        onTap: () =>
                                            state.toggleLikePost(post.id),
                                        child: Row(
                                          children: [
                                            Icon(
                                              post.isLiked
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              size: 14,
                                              color: post.isLiked
                                                  ? AppTheme.primary
                                                  : (isDark
                                                        ? Colors.white38
                                                        : Colors.grey[400]),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${post.likesCount}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: post.isLiked
                                                    ? AppTheme.primary
                                                    : (isDark
                                                          ? Colors.white38
                                                          : Colors.grey[400]),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPostDialog(context),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// Bottom sheet detail postingan + form balasan (mirip thread chat)
class ConversationBottomSheet extends StatefulWidget {
  final CommunityPost post;
  const ConversationBottomSheet({super.key, required this.post});

  @override
  State<ConversationBottomSheet> createState() =>
      _ConversationBottomSheetState();
}

class _ConversationBottomSheetState extends State<ConversationBottomSheet> {
  final _replyCtrl = TextEditingController();
  final _api = SupabaseService();
  late Future<List<Map<String, dynamic>>> _repliesFuture;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _repliesFuture = _api.fetchReplies(widget.post.id);
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  // Muat ulang daftar balasan dari server
  void _refreshReplies() {
    setState(() {
      _repliesFuture = _api.fetchReplies(widget.post.id);
    });
  }

  // Kirim balasan baru, lalu refresh list balasan & jumlah reply di post
  Future<void> _sendReply() async {
    final content = _replyCtrl.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await _api.createReply(widget.post.id, content);
      _replyCtrl.clear();
      _refreshReplies();
      if (mounted) {
        context.read<AppState>().loadPosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengirim balasan: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D1B2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.post.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Divider(color: isDark ? Colors.white12 : Colors.grey[200]),
          // List konten post + semua balasan, load async dari server
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _repliesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  );
                }

                final repliesList = snapshot.data ?? [];

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF3D2040)
                            : AppTheme.blush,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.post.content,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.grey[800],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (repliesList.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            'Belum ada balasan. Jadilah yang pertama!',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.grey[400],
                            ),
                          ),
                        ),
                      )
                    else
                      ...repliesList.map((r) {
                        final senderProfile =
                            r['profiles'] as Map<String, dynamic>?;
                        final senderName = senderProfile?['username'] ?? 'User';
                        final senderAvatar =
                            senderProfile?['avatar_url'] ?? '🐰';
                        final content = r['content'] as String;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppTheme.blush,
                                child: Text(
                                  senderAvatar,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      senderName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white60
                                            : Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white10
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        content,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ),
          // Input untuk kirim balasan baru
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyCtrl,
                    decoration: InputDecoration(
                      hintText: 'Tambah balasan...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[400],
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF2D1B2E),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSending ? null : _sendReply,
                  child: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Kirim'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
