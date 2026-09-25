import 'package:flutter_test/flutter_test.dart';
import 'package:whimsify/data/content_moderation_service.dart';

void main() {
  group('Community topic relevance heuristic', () {
    test('recognizes content containing a community keyword', () {
      expect(
        ContentModerationService.looksOffTopic(
          communityName: 'Anime Collectors',
          communityDescription: 'Diskusi koleksi figure anime',
          content: 'Saya punya koleksi figure anime baru.',
        ),
        isFalse,
      );
    });

    test('flags unrelated content without blocking the post by itself', () {
      expect(
        ContentModerationService.looksOffTopic(
          communityName: 'Anime Collectors',
          communityDescription: 'Diskusi koleksi figure anime',
          content: 'Mencari resep nasi goreng sederhana.',
        ),
        isTrue,
      );
    });

    test('does not flag when there are no useful community keywords', () {
      expect(
        ContentModerationService.looksOffTopic(
          communityName: 'Dan Yang',
          content: 'Topik bebas untuk semua orang.',
        ),
        isFalse,
      );
    });
  });
}
