import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum ChipTone { neutral, accent, success, danger, warning, info }

class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.978,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _pressed && animate ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: const Cubic(0.23, 1, 0.32, 1),
        child: widget.child,
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.onLongPress,
    this.radius = 20,
    this.color,
    this.borderColor,
    this.selected = false,
    this.clip = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final bool selected;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      margin: margin,
      padding: padding,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface1,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.55)
              : (borderColor ?? AppColors.borderSoft),
          width: selected ? 1.3 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap == null && onLongPress == null) return card;
    return PressableScale(
      onTap: onTap,
      onLongPress: onLongPress,
      child: card,
    );
  }
}

class SurfaceIcon extends StatelessWidget {
  const SurfaceIcon({
    super.key,
    required this.icon,
    this.size = 42,
    this.color = AppColors.accent,
    this.filled = false,
    this.radius = 14,
  });

  final IconData icon;
  final double size;
  final Color color;
  final bool filled;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withValues(alpha: filled ? 0.4 : 0.22)),
      ),
      child: Icon(
        icon,
        size: size * 0.48,
        color: filled ? Colors.white : color,
      ),
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.tone = ChipTone.neutral,
    this.icon,
    this.dot = false,
    this.compact = false,
    this.onTap,
  });

  final String label;
  final ChipTone tone;
  final IconData? icon;
  final bool dot;
  final bool compact;
  final VoidCallback? onTap;

  Color get _color => switch (tone) {
        ChipTone.neutral => AppColors.textSecondary,
        ChipTone.accent => AppColors.accentBright,
        ChipTone.success => AppColors.success,
        ChipTone.danger => AppColors.danger,
        ChipTone.warning => AppColors.warning,
        ChipTone.info => AppColors.info,
      };

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: compact ? 11 : 13, color: _color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: compact ? 10.5 : 11.5,
              height: 1.1,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: _color,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: chip,
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.label,
    this.compact = true,
  });

  final String status;
  final String? label;
  final bool compact;

  static const Map<String, String> _labels = {
    'new': 'Новая',
    'in_progress': 'В работе',
    'done': 'Готово',
    'cancelled': 'Отменена',
    'planning': 'Планируется',
    'completed': 'Завершён',
    'archived': 'Архив',
    'on_hold': 'На паузе',
    'planned': 'Запланировано',
    'preparing': 'Готовится',
    'in_production': 'В производстве',
    'on_review': 'На проверке',
    'on_approval': 'На согласовании',
    'approved': 'Согласовано',
    'published': 'Опубликовано',
  };

  ChipTone get _tone => switch (status) {
        'done' || 'completed' || 'published' || 'approved' => ChipTone.success,
        'in_progress' || 'in_production' || 'on_review' || 'on_approval' => ChipTone.info,
        'new' || 'planning' || 'planned' => ChipTone.neutral,
        'cancelled' || 'archived' || 'on_hold' => ChipTone.warning,
        _ => ChipTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    return AppChip(
      label: label ?? _labels[status] ?? status,
      tone: _tone,
      dot: true,
      compact: compact,
    );
  }
}

class PriorityMark extends StatelessWidget {
  const PriorityMark({super.key, required this.priority, this.withLabel = false});

  final String priority;
  final bool withLabel;

  static const Map<String, String> _labels = {
    'low': 'Низкий',
    'medium': 'Средний',
    'high': 'Высокий',
    'critical': 'Критичный',
  };

  @override
  Widget build(BuildContext context) {
    final color = AppColors.priority(priority);
    if (!withLabel) {
      return Tooltip(
        message: _labels[priority] ?? priority,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8),
            ],
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          _labels[priority] ?? priority,
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.overline,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(4, 0, 4, 12),
  });

  final String title;
  final String? overline;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overline != null) ...[
                  Text(
                    overline!.toUpperCase(),
                    style: AppTypography.overline(color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 24 : 42, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SurfaceIcon(
            icon: icon,
            size: compact ? 48 : 62,
            color: AppColors.textTertiary,
            radius: compact ? 16 : 20,
          ),
          SizedBox(height: compact ? 12 : 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: 7),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class InlineError extends StatelessWidget {
  const InlineError({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 13,
                height: 1.4,
                color: Color(0xFFFFC9CB),
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Повторить'),
            ),
        ],
      ),
    );
  }
}

class OfflineRibbon extends StatelessWidget {
  const OfflineRibbon({
    super.key,
    this.cachedAt,
    this.showRetry = false,
    this.onRetry,
  });

  final DateTime? cachedAt;
  final bool showRetry;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 15, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cachedAt == null
                  ? 'Нет сети — показаны сохранённые данные'
                  : 'Нет сети — данные от ${_hhmm(cachedAt!)}',
              style: const TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFFFFD79A),
              ),
            ),
          ),
          if (showRetry && onRetry != null)
            GestureDetector(
              onTap: onRetry,
              child: const Text(
                'Обновить',
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warning,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _hhmm(DateTime date) {
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surface3,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final x = _controller.value * 2 - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
              colors: const [
                AppColors.surface2,
                AppColors.surface3,
                AppColors.surface2,
              ],
            ),
          ),
        );
      },
    );
  }
}

class KeyValueRow extends StatelessWidget {  const KeyValueRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.textTertiary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textSecondary,
                fontFeatures: AppTypography.tabular,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 17, color: AppColors.textTertiary),
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }
}

class AccentNote extends StatelessWidget {
  const AccentNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.color = AppColors.info,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 11,
                height: 1.45,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
