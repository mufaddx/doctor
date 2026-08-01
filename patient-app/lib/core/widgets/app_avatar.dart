import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Network avatar that degrades to coloured initials, so a missing or broken
/// image never leaves an empty grey circle in a list.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 44,
    this.showOnlineDot = false,
    this.isOnline = false,
  });

  final String? imageUrl;
  final String name;
  final double size;
  final bool showOnlineDot;
  final bool isOnline;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  /// Deterministic hue from the name so the same person keeps the same colour.
  Color _colorFor(BuildContext context) {
    final int hash = name.codeUnits.fold(0, (sum, unit) => sum + unit);
    final List<Color> palette = [
      const Color(0xFF0F766E),
      const Color(0xFF7C3AED),
      const Color(0xFFDB2777),
      const Color(0xFF2563EB),
      const Color(0xFFEA580C),
    ];
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final Widget avatar = ClipOval(
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => _fallback(context),
              errorWidget: (_, __, ___) => _fallback(context),
            )
          : _fallback(context),
    );

    if (!showOnlineDot) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFF16A34A) : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: _colorFor(context),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
