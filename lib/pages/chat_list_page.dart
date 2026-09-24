import 'package:flutter/material.dart';
import '../data/supabase_service.dart';
import '../models/models.dart';
import '../widgets/avatar_widget.dart';
import 'chat_room_page.dart';

/// Halaman daftar semua percakapan (inbox) milik user yang sedang login --
/// gabungan chat di mana dia berperan sebagai pembeli MAUPUN sebagai
/// penjual, semuanya tampil di satu tempat yang sama.
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _api = SupabaseService();
  late Future<List<ChatConversation>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchConversations();
  }

  Future<void> _refresh() async {
    setState(() => _future = _api.fetchConversations());
    await _future;
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}j';
    return '${diff.inDays}h';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);

    return Scaffold(
      appBar: AppBar(title: const Text('Pesan')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<ChatConversation>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final conversations = snapshot.data ?? [];
            if (conversations.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Belum ada percakapan.\nChat seller dari halaman produk!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? Colors.white12 : Colors.grey[200],
              ),
              itemBuilder: (context, index) {
                final convo = conversations[index];
                return ListTile(
                  leading: AvatarWidget(avatar: convo.otherAvatar, radius: 22),
                  title: Text(
                    '@${convo.otherUsername}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: textColor),
                  ),
                  subtitle: Text(
                    convo.lastMessage?.isNotEmpty == true
                        ? convo.lastMessage!
                        : 'Tentang: ${convo.productName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                  trailing: Text(
                    _timeAgo(convo.lastMessageAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatRoomPage(
                          conversationId: convo.id,
                          otherUsername: convo.otherUsername,
                          otherAvatar: convo.otherAvatar,
                          productName: convo.productName,
                          productId: convo.productId,
                          productPrice: convo.productPrice,
                          sellerId: convo.sellerId,
                        ),
                      ),
                    );
                    if (mounted) _refresh();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
