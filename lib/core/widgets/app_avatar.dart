import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/api_urls.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.name,
    this.avatar,
    this.size = 42,
    this.ring = false,
    this.onTap,
  });

  final String? name;
  final String? avatar;
  final double size;
  final bool ring;
  final VoidCallback? onTap;

  String get _initials {
    final source = (name ?? '').trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  Color get _fallbackColor {
    final value = (name ?? '').codeUnits.fold<int>(0, (a, b) => a + b);
    const colors = [
      Color(0xFF6B4FCF),
      Color(0xFF3A6EA5),
      Color(0xFF2F7E73),
      Color(0xFF8A5A2B),
      Color(0xFF8A3E62),
      Color(0xFF4C5B9E),
    ];
    return colors[value % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final url = ApiUrls.avatar(avatar);

    Widget avatarWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: url.isEmpty
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _fallbackColor.withValues(alpha: 0.95),
                  _fallbackColor.withValues(alpha: 0.55),
                ],
              )
            : null,
        border: ring
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.4,
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Center(
              child: Text(
                _initials,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: Colors.white,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              width: size,
              height: size,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (context, _) => ColoredBox(
                color: AppColors.surface3,
                child: Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: size * 0.32,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              errorWidget: (context, _, __) => ColoredBox(
                color: AppColors.surface3,
                child: Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      fontFamily: AppTypography.family,
                      fontSize: size * 0.32,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
    );

    if (onTap != null) {
      avatarWidget = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: avatarWidget,
      );
    }

    if (size <= 0) return const SizedBox.shrink();
    return Semantics(label: name, image: true, child: avatarWidget);
  }
}

class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.people,
    this.size = 24,
    this.max = 4,
  });

  final List<({String? name, String? avatar})> people;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final visible = people.take(max).toList();
    final rest = people.length - visible.length;
    return SizedBox(
      height: size,
      width: size + (visible.length - 1) * size * 0.66 + (rest > 0 ? size * 0.66 : 0),
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * size * 0.66,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface1, width: 1.6),
                ),
                child: AppAvatar(
                  name: visible[i].name,
                  avatar: visible[i].avatar,
                  size: size,
                ),
              ),
            ),
          if (rest > 0)
            Positioned(
              left: visible.length * size * 0.66,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.surface3,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface1, width: 1.6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$rest',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
