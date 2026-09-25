import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whimsify/widgets/avatar_widget.dart';

void main() {
  testWidgets('renders the default emoji avatar accessibly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AvatarWidget(avatar: '🐰', radius: 20)),
      ),
    );

    expect(find.text('🐰'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });

  testWidgets('renders a person fallback when avatar URL fails',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AvatarWidget(avatar: 'https://invalid.test/avatar.png'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
