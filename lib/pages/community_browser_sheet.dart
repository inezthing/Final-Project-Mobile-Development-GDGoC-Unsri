import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'create_community_page.dart';

/// Bottom sheet "Cari/Tambah Komunitas" -- cari komunitas yang ada, toggle
/// follow/unfollow (ala follow komunitas di X), atau bikin komunitas baru
/// lewat halaman terpisah.
class CommunityBrowserSheet extends StatefulWidget {
  const CommunityBrowserSheet({super.key});

  @override
  State<CommunityBrowserSheet> createState() => _CommunityBrowserSheetState();
}

class _CommunityBrowserSheetState extends State<CommunityBrowserSheet> {
  final _searchCtrl = TextEditingController();
  List<Community> _results = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    final results = await context.read<AppState>().searchAllCommunities(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  Future<void> _toggleFollow(Community c) async {
    final state = context.read<AppState>();
    // Optimistic update lokal di list hasil pencarian
    setState(() {
      final index = _results.indexWhere((r) => r.id == c.id);
      if (index != -1) {
        _results[index] = Community(
          id: c.id,
          name: c.name,
          description: c.description,
          rules: c.rules,
          createdBy: c.createdBy,
          createdAt: c.createdAt,
          isFollowing: !c.isFollowing,
          followerCount: c.followerCount + (c.isFollowing ? -1 : 1),
        );
      }
    });
    try {
      if (c.isFollowing) {
        await state.unfollowCommunity(c.id);
      } else {
        await state.followCommunity(c.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        _search(_searchCtrl.text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D1B2E);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D1B2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cari Komunitas',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textColor),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final created = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateCommunityPage()),
                      );
                      if (created == true) _search(_searchCtrl.text);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Buat Baru'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Cari nama komunitas...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            'Komunitas tidak ditemukan. Coba bikin baru?',
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _results.length,
                          itemBuilder: (ctx, i) {
                            final c = _results[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.blush,
                                child: Text(
                                  c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800),
                                ),
                              ),
                              title: Text(c.name, style: TextStyle(fontWeight: FontWeight.w700, color: textColor)),
                              subtitle: Text(
                                c.description?.isNotEmpty == true
                                    ? c.description!
                                    : '${c.followerCount} pengikut',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
                              trailing: OutlinedButton(
                                onPressed: () => _toggleFollow(c),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: c.isFollowing ? Colors.transparent : AppTheme.primary,
                                  foregroundColor: c.isFollowing ? AppTheme.primary : Colors.white,
                                  side: const BorderSide(color: AppTheme.primary),
                                ),
                                child: Text(c.isFollowing ? 'Following' : 'Follow'),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
