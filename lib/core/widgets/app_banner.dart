import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/glass_surface.dart';
import '../design/glass_tokens.dart';
import '../design/motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum BannerTone { accent, success, danger, warning, info }

class AppBanner {
  const AppBanner({
    required this.title,
    required this.message,
    this.tone = BannerTone.accent,
    this.link,
    this.icon,
    this.sourceId,
  });

  final String title;
  final String message;
  final BannerTone tone;
  final String? link;
  final IconData? icon;
  final String? sourceId;
}

class BannerService {
  final _controller = StreamController<AppBanner>.broadcast();
  final Map<String, DateTime> _recent = {};

  Stream<AppBanner> get stream => _controller.stream;

  void show(AppBanner banner) {
    // The same event can arrive via Socket.IO and FCM. Collapse duplicates.
    final key = banner.sourceId ?? '${banner.title}|${banner.message}';
    final now = DateTime.now();
    final last = _recent[key];
    if (last != null && now.difference(last).inSeconds < 6) return;
    _recent[key] = now;
    _recent.removeWhere((_, value) => now.difference(value).inSeconds > 30);
    _controller.add(banner);
  }

  void notification({
    required String title,
    required String message,
    String? link,
    String? type,
    String? id,
  }) {
    final tone = switch (type) {
      'task_overdue' ||
      'payment_overdue_soon' ||
      'payment_reminder' => BannerTone.danger,
      'task_completed' || 'deadline_tomorrow' => BannerTone.success,
      'review_needed' || 'task_returned' => BannerTone.warning,
      'new_task' ||
      'project_assigned' ||
      'manager_assigned' => BannerTone.accent,
      _ => BannerTone.info,
    };
    show(
      AppBanner(
        title: title,
        message: message,
        tone: tone,
        link: link,
        sourceId: id,
        icon: tone == BannerTone.danger
            ? LucideIcons.triangleAlert
            : tone == BannerTone.success
            ? LucideIcons.circleCheckBig
            : LucideIcons.bellRing,
      ),
    );
  }

  void dispose() => _controller.close();
}

class AppBannerHost extends StatefulWidget {
  const AppBannerHost({super.key, required this.service, required this.onOpen});

  final BannerService service;
  final ValueChanged<String?> onOpen;

  @override
  State<AppBannerHost> createState() => _AppBannerHostState();
}

class _AppBannerHostState extends State<AppBannerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _slideCurve;
  late final CurvedAnimation _fade;
  late final Animation<Offset> _slide;
  final List<AppBanner> _queue = [];
  StreamSubscription<AppBanner>? _subscription;
  Timer? _timer;
  AppBanner? _current;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Motion.standard,
      reverseDuration: Motion.exit,
    );
    _slideCurve = CurvedAnimation(
      parent: _controller,
      curve: Motion.easeOut,
      reverseCurve: Motion.easeOut,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.28),
      end: Offset.zero,
    ).animate(_slideCurve);
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Motion.easeOut,
      reverseCurve: Motion.easeOut,
    );
    _subscription = widget.service.stream.listen(_enqueue);
  }

  void _enqueue(AppBanner banner) {
    if (_current == null) {
      _present(banner);
    } else {
      _queue.add(banner);
      if (_queue.length > 3) _queue.removeAt(0);
    }
  }

  bool get _motion => mounted && Motion.allowed(context);

  Future<void> _present(AppBanner banner) async {
    _timer?.cancel();
    setState(() => _current = banner);
    if (!_motion) {
      _controller.value = 1;
    } else {
      await _controller.forward(from: 0);
    }
    if (!mounted) return;
    _timer = Timer(const Duration(seconds: 5), _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted || _current == null) return;
    if (_motion) {
      await _controller.reverse();
    } else {
      _controller.value = 0;
    }
    if (!mounted) return;
    setState(() => _current = null);
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      await _present(next);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    _slideCurve.dispose();
    _fade.dispose();
    _controller.dispose();
    super.dispose();
  }

  Color _toneColor(BannerTone tone) => switch (tone) {
    BannerTone.accent => context.palette.accentBright,
    BannerTone.success => context.palette.success,
    BannerTone.danger => context.palette.danger,
    BannerTone.warning => context.palette.warning,
    BannerTone.info => context.palette.info,
  };

  @override
  Widget build(BuildContext context) {
    final banner = _current;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: IgnorePointer(
          ignoring: banner == null,
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: banner == null
                        ? const SizedBox.shrink()
                        : GestureDetector(
                            onVerticalDragEnd: (details) {
                              if ((details.primaryVelocity ?? 0) < -260) {
                                _dismiss();
                              }
                            },
                            child: GlassSurface(
                              radius: 22,
                              blur: GlassTokens.blurXl,
                              strong: true,
                              padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: _toneColor(banner.tone)
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                        color: _toneColor(banner.tone)
                                            .withValues(alpha: 0.28),
                                      ),
                                    ),
                                    child: Icon(
                                      banner.icon ?? LucideIcons.bellRing,
                                      size: 18,
                                      color: _toneColor(banner.tone),
                                    ),
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          banner.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:  TextStyle(
                                            fontFamily: AppTypography.family,
                                            fontSize: 13.5,
                                            height: 1.2,
                                            fontWeight: FontWeight.w600,
                                            color: context.palette.text,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          banner.message,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style:  TextStyle(
                                            fontFamily: AppTypography.family,
                                            fontSize: 12,
                                            height: 1.3,
                                            color: context.palette.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  AppBannerCloseButton(onTap: _dismiss),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppBannerCloseButton extends StatelessWidget {
  const AppBannerCloseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child:  SizedBox(
          width: 34,
          height: 34,
          child: Icon(LucideIcons.x, size: 15, color: context.palette.textTertiary),
        ),
      ),
    );
  }
}
