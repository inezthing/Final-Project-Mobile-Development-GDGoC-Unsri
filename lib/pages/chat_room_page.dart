import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_smart_reply/google_mlkit_smart_reply.dart';
import '../data/supabase_service.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_widget.dart';

/// Halaman ruang obrolan 1-on-1 untuk satu percakapan (product + buyer + seller).
///
/// Room ini dibuka DEFAULT untuk nego harga produk (tombol "Ajukan
/// Tawaran" di appbar untuk pembeli, kartu Terima/Tolak untuk seller), tapi
/// tetap 1 ruang obrolan bebas yang sama -- pembeli/seller boleh nanya hal
/// lain juga di sini, bukan cuma nego harga.
///
/// Fitur ML Kit Smart Reply (on-device, gratis, tanpa API key) dipakai buat
/// nyaranin balasan singkat berdasarkan pesan terakhir lawan bicara --
/// CATATAN: model Smart Reply bawaan Google ini paling akurat untuk
/// percakapan berbahasa INGGRIS; untuk Bahasa Indonesia saran yang muncul
/// bisa kurang related/kosong -- itu batasan model on-device-nya, bukan bug.
class ChatRoomPage extends StatefulWidget {
  final String conversationId;
  final String otherUsername;
  final String otherAvatar;
  final String productName;
  // Dibutuhkan supaya fitur nego harga bisa jalan. Nullable supaya
  // pemanggilan lama (kalau ada) tidak langsung error -- tapi tombol
  // "Ajukan Tawaran" otomatis disembunyikan kalau salah satunya null.
  final String? productId;
  final double? productPrice;
  final String? sellerId;

  const ChatRoomPage({
    super.key,
    required this.conversationId,
    required this.otherUsername,
    required this.otherAvatar,
    required this.productName,
    this.productId,
    this.productPrice,
    this.sellerId,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _api = SupabaseService();
  bool _isSending = false;
  bool _isSendingOffer = false;

  // ---- ML Kit Smart Reply ----
  final SmartReply _smartReply = SmartReply();
  List<String> _suggestions = [];
  String? _lastSuggestedFor; // id pesan terakhir yang sudah di-generate sarannya

  @override
  void initState() {
    super.initState();
    // Tandai pesan lawan bicara sebagai sudah dibaca begitu chat dibuka
    _api.markConversationRead(widget.conversationId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _smartReply.close();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Bangun ulang "memori percakapan" Smart Reply dari histori pesan, lalu
  // minta saran balasan. Cuma jalan kalau pesan TERAKHIR itu dari LAWAN
  // bicara (tidak ada gunanya nyaranin balasan buat pesan sendiri).
  Future<void> _refreshSmartReplies(List<ChatMessage> messages) async {
    if (messages.isEmpty) return;
    final myId = _api.currentUser?.id;
    final last = messages.last;
    if (last.senderId == myId) {
      if (_suggestions.isNotEmpty && mounted) setState(() => _suggestions = []);
      return;
    }
    if (_lastSuggestedFor == last.id) return; // sudah pernah digenerate
    _lastSuggestedFor = last.id;

    _smartReply.clearConversation();
    // Ambil maksimal 10 pesan terakhir sebagai konteks
    final recent = messages.length > 10
        ? messages.sublist(messages.length - 10)
        : messages;
    for (final m in recent) {
      final ts = m.createdAt.millisecondsSinceEpoch;
      if (m.senderId == myId) {
        _smartReply.addMessageToConversationFromLocalUser(m.content, ts);
      } else {
        _smartReply.addMessageToConversationFromRemoteUser(
          m.content,
          ts,
          m.senderId,
        );
      }
    }

    try {
      final result = await _smartReply.suggestReplies();
      if (!mounted) return;
      setState(() {
        _suggestions =
            result.status == SmartReplySuggestionResultStatus.success
                ? result.suggestions.take(3).toList()
                : [];
      });
    } catch (e) {
      // Model belum siap / gagal load -- diamkan saja, suggestion chips
      // cukup tidak muncul, tidak perlu ganggu UX chat dengan error.
      debugPrintSmartReplyError(e);
    }
  }

  Future<void> _send([String? presetText]) async {
    final text = (presetText ?? _messageController.text).trim();
    if (text.isEmpty || _isSending) return;
    // Batas panjang pesan -- jaga-jaga dari paste teks raksasa/spam yang
    // bisa bikin bubble chat berantakan atau membebani payload ke server.
    if (text.length > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesan maksimal 1000 karakter.')),
      );
      return;
    }
    setState(() {
      _isSending = true;
      _suggestions = [];
    });
    _messageController.clear();
    try {
      await _api.sendMessage(
        conversationId: widget.conversationId,
        content: text,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim pesan: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // Dialog "Ajukan Tawaran" -- hanya dipanggil dari sisi PEMBELI.
  Future<void> _showOfferDialog() async {
    final originalPrice = widget.productPrice ?? 0;
    final ctrl = TextEditingController(
      text: originalPrice > 0 ? (originalPrice * 0.85).round().toString() : '',
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Ajukan Tawaran untuk "${widget.productName}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Harga normal: Rp ${originalPrice.toInt()}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Tawaran kamu (Rp)',
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(ctrl.text.trim());
              if (value == null || value <= 0) return;
              if (originalPrice > 0 && value >= originalPrice) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Tawaran harus lebih rendah dari harga normal.'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx, value);
            },
            child: const Text('Kirim Tawaran'),
          ),
        ],
      ),
    );

    if (result == null || widget.productId == null || widget.sellerId == null) return;
    setState(() => _isSendingOffer = true);
    try {
      await _api.createOffer(
        conversationId: widget.conversationId,
        productId: widget.productId!,
        sellerId: widget.sellerId!,
        originalPrice: originalPrice,
        offeredPrice: result,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengirim tawaran: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingOffer = false);
    }
  }

  Future<void> _respondOffer(ProductOffer offer, bool accept) async {
    try {
      await _api.respondToOffer(offerId: offer.id, accept: accept);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal merespon tawaran: $e')),
        );
      }
    }
  }

  // Dipanggil dari kartu tawaran yang sudah diterima (POV pembeli) --
  // tambahkan produk ke keranjang dengan harga nego, HANYA untuk pembeli
  // ini (lihat SupabaseService.addToCart -> fetchAcceptedOfferPrice).
  Future<void> _addNegotiatedToCart(ProductOffer offer) async {
    final placeholder = Product(
      id: offer.productId,
      name: widget.productName,
      brand: '',
      description: '',
      category: '',
      price: offer.originalPrice,
      condition: '',
      size: '',
      sellerId: offer.sellerId,
      sellerName: widget.otherUsername,
      sellerVerified: false,
      listedAt: DateTime.now(),
      paymentMethods: const [],
    );
    try {
      await context.read<AppState>().addToCart(placeholder);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ditambahkan ke keranjang dengan harga nego Rp ${offer.offeredPrice.toInt()}! 🛍️',
            ),
            backgroundColor: AppTheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);
    final myId = _api.currentUser?.id;
    final isSeller = widget.sellerId != null && myId == widget.sellerId;
    final canOffer = !isSeller && widget.productId != null && widget.sellerId != null;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            AvatarWidget(avatar: widget.otherAvatar, radius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '@${widget.otherUsername}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.productName,
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (canOffer)
            IconButton(
              tooltip: 'Ajukan Tawaran',
              onPressed: _isSendingOffer ? null : _showOfferDialog,
              icon: const Icon(Icons.sell_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          // ==== Kartu tawaran aktif (pending/accepted terbaru) ====
          if (widget.productId != null)
            StreamBuilder<List<ProductOffer>>(
              stream: _api.streamOffers(widget.conversationId),
              builder: (context, snapshot) {
                final offers = snapshot.data ?? [];
                if (offers.isEmpty) return const SizedBox.shrink();
                final latest = offers.last;
                if (latest.status == OfferStatus.rejected ||
                    latest.status == OfferStatus.cancelled) {
                  return const SizedBox.shrink();
                }
                final isPending = latest.status == OfferStatus.pending;
                return Container(
                  margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPending
                        ? AppTheme.blush
                        : Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPending ? AppTheme.primary : Colors.green,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPending ? Icons.local_offer_outlined : Icons.check_circle,
                            size: 18,
                            color: isPending ? AppTheme.primary : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isPending
                                  ? 'Tawaran Rp ${latest.offeredPrice.toInt()} menunggu konfirmasi'
                                  : 'Tawaran Rp ${latest.offeredPrice.toInt()} diterima!',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      if (isPending && isSeller) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _respondOffer(latest, false),
                                child: const Text('Tolak'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _respondOffer(latest, true),
                                child: const Text('Terima'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!isPending &&
                          latest.status == OfferStatus.accepted &&
                          !isSeller) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _addNegotiatedToCart(latest),
                            icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                            label: const Text('Tambah ke Keranjang (Harga Nego)'),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _api.streamMessages(widget.conversationId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Mulai obrolan dengan @${widget.otherUsername}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  );
                }
                _scrollToBottom();
                // Generate saran balasan (Smart Reply) di background --
                // tidak nge-block render list pesan.
                _refreshSmartReplies(messages);
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == myId;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.72,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppTheme.primary
                              : (isDark
                                  ? const Color(0xFF2D1B2E)
                                  : AppTheme.blush),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(14),
                            topRight: const Radius.circular(14),
                            bottomLeft: Radius.circular(isMe ? 14 : 2),
                            bottomRight: Radius.circular(isMe ? 2 : 14),
                          ),
                        ),
                        child: Text(
                          msg.content,
                          style: TextStyle(
                            fontSize: 13,
                            color: isMe ? Colors.white : textColor,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ==== Chip saran balasan (ML Kit Smart Reply, on-device) ====
          if (_suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => ActionChip(
                    label: Text(_suggestions[i], style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppTheme.blush,
                    onPressed: () => _messageController.text = _suggestions[i],
                  ),
                ),
              ),
            ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(color: textColor, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Tulis pesan...',
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSending ? null : () => _send(),
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper kecil biar error Smart Reply tidak berisik tapi tetap tercatat
void debugPrintSmartReplyError(Object e) {
  // ignore: avoid_print
  print('Smart Reply error (diabaikan, chip saran cuma tidak muncul): $e');
}