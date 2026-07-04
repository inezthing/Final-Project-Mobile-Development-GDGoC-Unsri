import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../pages/explore_page.dart';

// Slider kategori horizontal di halaman home, tap untuk ke Explore Page
class CategorySlider extends StatefulWidget {
  const CategorySlider({super.key});

  @override
  State<CategorySlider> createState() => _CategorySliderState();
}

class _CategorySliderState extends State<CategorySlider> {
  int _selected = -1;

  // Daftar kategori statis (nama, emoji, warna latar)
  static const List<_CategoryItem> _categories = [
    _CategoryItem('Woman Fashion', '👗', Color(0xFFFFCCE5)),
    _CategoryItem('Man Fashion', '👔', Color(0xFFCCE5FF)),
    _CategoryItem('Health & Beauty', '💄', Color(0xFFE5CCFF)),
    _CategoryItem('Keychain', '🔑', Color(0xFFFFE5CC)),
    _CategoryItem('Trinket', '⭐', Color(0xFFFFF0CC)),
    _CategoryItem('Shoes', '👟', Color(0xFFCCFFE5)),
    _CategoryItem('Playing Card', '🃏', Color(0xFFFFCCCC)),
    _CategoryItem('Sticker', '🎀', Color(0xFFFFD6E8)),
  ];

  @override
  Widget build(BuildContext context) {
    // Hitung tinggi: circle 54 + gap 6 + text max 2 baris (10px * 1.3 * 2 = ~27) + padding = 100
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selected == index;
          // Tap kategori -> tandai terpilih & buka Explore Page dengan filter kategori itu
          return GestureDetector(
            onTap: () {
              setState(() => _selected = index);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExplorePage(initialCategory: cat.name),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 62,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : cat.color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: AppTheme.primaryDark, width: 2)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          cat.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      cat.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: isSelected
                            ? AppTheme.primary
                            : Theme.of(context).brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Model data satu kategori (nama, emoji, warna)
class _CategoryItem {
  final String name;
  final String emoji;
  final Color color;
  const _CategoryItem(this.name, this.emoji, this.color);
}
