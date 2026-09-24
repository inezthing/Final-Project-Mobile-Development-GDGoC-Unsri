import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../data/supabase_service.dart';
import '../data/content_moderation_service.dart';
import '../widgets/avatar_widget.dart';
import 'community_browser_sheet.dart';

// Halaman komunitas: filter by komunitas, list postingan, buat post baru
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  String _selectedCommunity = 'All';

  @override
  void initState() {
    super.initState();
    // Refresh daftar komunitas yang di-follow tiap halaman ini dibuka,
    // biar kalau baru follow/bikin komunitas di sheet lain langsung sinkron
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadFollowedCommunities();
    });
  }

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
    final followedNames = state.followedCommunities.map((c) => c.name).toList();
    String? selectedCommunity = followedNames.isNotEmpty ? followedNames.first : null;
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

                    if (followedNames.isEmpty) ...[
                      // Belum follow komunitas manapun -- tidak bisa posting
                      // sebelum follow/bikin komunitas dulu
                      Text(
                        'Kamu belum follow komunitas manapun. Follow atau '
                        'buat komunitas dulu sebelum posting.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openCommunityBrowser(context);
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Cari / Buat Komunitas'),
                        ),
                      ),
                    ] else ...[
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
                              items: [
                                ...followedNames.map(
                                  (c) => DropdownMenuItem(value: c, child: Text(c)),
                                ),
                                const DropdownMenuItem(
                                  value: '__browse__',
                                  child: Text('+ Cari/Buat Komunitas...'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v == '__browse__') {
                                  Navigator.pop(ctx);
                                  _openCommunityBrowser(context);
                                  return;
                                }
                                setModalState(() => selectedCommunity = v);
                              },
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
                            if (selectedCommunity == null) return;

                            final title = titleCtrl.text.trim();
                            final content = contentCtrl.text.trim();

                            // ==== LAPIS 1: cek toxicity/insult/dll (blokir keras) ====
                            final moderation = await ContentModerationService
                                .checkToxicity('$title. $content');
                            if (!moderation.isAllowed) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      moderation.reason ??
                                          'Postingan tidak sesuai guideline komunitas.',
                                    ),
                                    backgroundColor: Colors.red[400],
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                              return; // batal posting, tidak sampai ke server
                            }

                            // ==== LAPIS 2: cek kemungkinan out-of-topic (konfirmasi ringan) ====
                            final community = state.followedCommunities
                                .where((c) => c.name == selectedCommunity)
                                .toList();
                            final offTopic = community.isNotEmpty &&
                                ContentModerationService.looksOffTopic(
                                  communityName: community.first.name,
                                  communityDescription: community.first.description,
                                  communityRules: community.first.rules,
                                  content: '$title $content',
                                );
                            if (offTopic && ctx.mounted) {
                              final proceed = await showDialog<bool>(
                                context: ctx,
                                builder: (dctx) => AlertDialog(
                                  title: const Text('Sepertinya di luar topik?'),
                                  content: Text(
                                    'Postingan ini kelihatannya kurang nyambung dengan '
                                    'topik komunitas "$selectedCommunity". Tetap lanjut posting?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dctx, false),
                                      child: const Text('Edit dulu'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(dctx, true),
                                      child: const Text('Tetap Posting'),
                                    ),
                                  ],
                                ),
                              );
                              if (proceed != true) return;
                            }

                            // Kirim post baru ke server, lalu update state lokal
                            try {
                              final post = await SupabaseService().createPost(
                                community: selectedCommunity!,
                                type: selectedType,
                                title: title,
                                content: content,
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

  // Bikin 1 chip filter komunitas (dipakai buat "Semua" + tiap komunitas
  // yang di-follow)
  Widget _communityChip(String value, String label, bool isDark) {
    final isSelected = value == _selectedCommunity;
    return GestureDetector(
      onTap: () => setState(() => _selectedCommunity = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.primary : (isDark ? Colors.white24 : Colors.grey[300]!),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : (isDark ? Colors.white60 : Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  // Buka bottom sheet "Cari/Tambah Komunitas" -- browse semua komunitas yang
  // ada, follow/unfollow, atau bikin komunitas baru
  void _openCommunityBrowser(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const CommunityBrowserSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Nama komunitas yang di-follow user (buat filter tab) -- selalu ada
    // opsi "Semua" di depan buat lihat gabungan semua komunitas yang diikuti
    final followedNames = state.followedCommunities.map((c) => c.name).toList();
    // Filter postingan: "Semua" = gabungan semua komunitas yang diikuti (mirip
    // feed "Following" di X), bukan seluruh post di semua komunitas yang ada
    final filteredPosts = _selectedCommunity == 'All'
        ? state.posts.where((p) => followedNames.contains(p.community)).toList()
        : state.posts.where((p) => p.community == _selectedCommunity).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Komunitas 💬'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter chip komunitas (scroll horizontal) -- HANYA komunitas
            // yang di-follow user (ala tab "Following" di X), plus tombol "+"
            // buat cari komunitas lain / bikin baru
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                children: [
                  _communityChip('All', 'Semua', isDark),
                  ...followedNames.map((c) => _communityChip(c, c, isDark)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _openCommunityBrowser(context),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primary),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.add, size: 18, color: AppTheme.primary),
                    ),
                  ),
                ],
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
                                      AvatarWidget(
                                        avatar: post.userAvatar,
                                        radius: 16,
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
                                      // Menu titik tiga: block user / laporkan
                                      // (disembunyikan untuk post milik sendiri)
                                      if (post.userId != SupabaseService().currentUser?.id)
                                        PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(
                                            Icons.more_vert,
                                            size: 16,
                                            color: isDark ? Colors.white38 : Colors.grey[400],
                                          ),
                                          onSelected: (value) {
                                            if (value == 'block') {
                                              _confirmBlockUser(context, post.userId, post.userName);
                                            } else if (value == 'report') {
                                              _showReportDialog(context, post);
                                            }
                                          },
                                          itemBuilder: (ctx) => const [
                                            PopupMenuItem(
                                              value: 'block',
                                              child: Text('Block user ini'),
                                            ),
                                            PopupMenuItem(
                                              value: 'report',
                                              child: Text('Laporkan postingan'),
                                            ),
                                          ],
                                        )
                                      else
                                        // Post milik sendiri -> boleh dihapus
                                        // (bukan block/report, itu buat post orang lain)
                                        PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          icon: Icon(
                                            Icons.more_vert,
                                            size: 16,
                                            color: isDark ? Colors.white38 : Colors.grey[400],
                                          ),
                                          onSelected: (value) {
                                            if (value == 'delete') {
                                              _confirmDeletePost(context, post.id);
                                            }
                                          },
                                          itemBuilder: (ctx) => const [
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Hapus postingan', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
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
                                      // Downvote
                                      GestureDetector(
                                        onTap: () => state.voteOnPost(post.id, -1),
                                        child: Icon(
                                          Icons.arrow_downward,
                                          size: 15,
                                          color: post.myVote == -1
                                              ? Colors.blueAccent
                                              : (isDark ? Colors.white38 : Colors.grey[400]),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${post.voteScore}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: post.myVote == 1
                                              ? AppTheme.primary
                                              : post.myVote == -1
                                                  ? Colors.blueAccent
                                                  : (isDark ? Colors.white38 : Colors.grey[400]),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Upvote
                                      GestureDetector(
                                        onTap: () => state.voteOnPost(post.id, 1),
                                        child: Icon(
                                          Icons.arrow_upward,
                                          size: 15,
                                          color: post.myVote == 1
                                              ? AppTheme.primary
                                              : (isDark ? Colors.white38 : Colors.grey[400]),
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

  // Dialog konfirmasi sebelum block user -- postingan mereka langsung
  // hilang dari feed kita setelah di-block
  void _confirmDeletePost(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus postingan ini?'),
        content: const Text('Postingan ini akan dihapus permanen dan tidak bisa dikembalikan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<AppState>().deletePost(postId);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                  );
                }
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _confirmBlockUser(BuildContext context, String userId, String userName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block user ini?'),
        content: Text('Postingan @$userName tidak akan muncul lagi di feed kamu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<AppState>().blockUser(userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('@$userName sudah di-block.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400]),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  // Dialog laporkan postingan -- alasan opsional, backend yang urus
  // notifikasi ke yang dilaporkan & auto-suspend kalau sudah 3 laporan
  void _showReportDialog(BuildContext context, CommunityPost post) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Laporkan Postingan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Laporkan postingan @${post.userName}?',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Alasan (opsional)',
                border: OutlineInputBorder(),
                hintText: 'Misal: spam, konten tidak pantas, dsb.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<AppState>().reportContent(
                      reportedUserId: post.userId,
                      postId: post.id,
                      reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Laporan terkirim. Terima kasih sudah menjaga komunitas.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                  );
                }
              }
            },
            child: const Text('Kirim Laporan'),
          ),
        ],
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

    // Cek toxicity/insult/dll dulu sebelum balasan tersimpan ke server --
    // sama seperti pengecekan di form buat postingan baru.
    final moderation = await ContentModerationService.checkToxicity(content);
    if (!moderation.isAllowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              moderation.reason ?? 'Balasan tidak sesuai guideline komunitas.',
            ),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

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
                            (senderProfile?['avatar_url'] as String?) ?? '🐰';
                        final content = r['content'] as String;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AvatarWidget(
                                avatar: senderAvatar,
                                radius: 14,
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
