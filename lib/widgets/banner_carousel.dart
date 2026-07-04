import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Carousel banner promosi yang auto-slide di halaman home
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final PageController _controller = PageController();
  int _currentIndex = 0;
  Timer? _timer;

  // Data statis banner promosi (emoji, gradient warna, teks)
  static const List<_BannerData> _banners = [
    _BannerData(
      bigEmoji: '🌿',
      decorEmojis: ['🌱', '💚', '🍃'],
      gradient: [Color(0xFFE91E8C), Color(0xFFFF6B9D)],
      title: 'Give it a new home 🏡',
      subtitle: 'Kurangi waste, beri barang preloved-mu kehidupan baru!',
      tag: '#SustainableFashion',
    ),
    _BannerData(
      bigEmoji: '💬',
      decorEmojis: ['🌸', '💕', '✨'],
      gradient: [Color(0xFFC2185B), Color(0xFFE91E8C)],
      title: 'Komunitas kita 💕',
      subtitle: 'Terhubung dengan sesama kolektor & temukan teman baru!',
      tag: '#WhimsifyCommunity',
    ),
    _BannerData(
      bigEmoji: '👸',
      decorEmojis: ['💄', '🌺', '🎀'],
      gradient: [Color(0xFFAD1457), Color(0xFFC2185B)],
      title: 'Promo Kartini 👸',
      subtitle: '21–30 Apr • Diskon 10% pengguna perempuan. Kode: KARTINI25',
      tag: 'Berlaku s/d 30 April',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  // Otomatis geser ke banner berikutnya tiap 4 detik
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (!_controller.hasClients) return;
      final next = (_currentIndex + 1) % _banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  // Bersihkan timer & controller biar tidak memory leak
  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Slider banner yang bisa di-swipe manual atau auto-geser
        SizedBox(
          height: 155,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final b = _banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: b.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // Dekor emoji besar — pakai Positioned agar tidak affect layout
                        Positioned(
                          right: -8,
                          top: -8,
                          child: Text(
                            b.bigEmoji,
                            style: const TextStyle(fontSize: 85),
                          ),
                        ),
                        // Dekor kecil bawah
                        for (int i = 0; i < b.decorEmojis.length; i++)
                          Positioned(
                            right: 16.0 + i * 28,
                            bottom: 8,
                            child: Opacity(
                              opacity: 0.35,
                              child: Text(
                                b.decorEmojis[i],
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        // Konten teks — gunakan Positioned.fill agar tidak overflow
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 14, 110, 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Text(
                                    b.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Flexible(
                                  child: Text(
                                    b.subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.92),
                                      fontSize: 11,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    b.tag,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Titik indikator halaman aktif
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) {
            final isActive = i == _currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primary : AppTheme.rose,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// Model data satu banner (emoji, gradient, judul, subjudul, tag)
class _BannerData {
  final String bigEmoji;
  final List<String> decorEmojis;
  final List<Color> gradient;
  final String title;
  final String subtitle;
  final String tag;

  const _BannerData({
    required this.bigEmoji,
    required this.decorEmojis,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.tag,
  });
}
