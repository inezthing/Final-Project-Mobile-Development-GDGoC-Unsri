import 'package:flutter/material.dart';

/// Shared Whimsify mark used on the login page and Flutter splash screen.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 90, this.borderRadius = 26});

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/branding/whimsify_logo.jpeg',
        fit: BoxFit.cover,
        semanticLabel: 'Logo Whimsify',
      ),
    );
  }
}
