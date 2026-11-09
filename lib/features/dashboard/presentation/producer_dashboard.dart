import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';

class ProducerShoot {
  const ProducerShoot({
    required this.id,
    required this.date,
    this.time,
    required this.projectName,
    this.title,
    this.videographer,
    this.done = false,
    this.address,
    this.mapUrl,
    this.contact,
    this.smm,
  });

  final String id;
  final DateTime date;
  final String? time;
  final String projectName;
  final String? title;
  final String? videographer;
  final bool done;
  final String? address;
  final String? mapUrl;
  final String? contact;
  final String? smm;

  factory ProducerShoot.fromJson(Map<String, dynamic> json) => ProducerShoot(
        id: asStringOr(json['id'], ''),
        date: BizDate.parse(json['date']) ?? BizDate.today(),
        time: asString(json['time']),
        projectName: asStringOr(json['projectName'], 'Проект'),
        title: asString(json['title']),
        videographer: asString(json['videographer']),
        done: asBool(json['done']),
        address: asString(json['address']),
        mapUrl: asString(json['mapUrl']),
        contact: asString(json['contact']),
        smm: asString(json['smm']),
      );
}

final producerShootsProvider = FutureProvider.autoDispose
    .family<List<ProducerShoot>, String>((ref, range) async {
  ref.watch(dataRevisionProvider);
  final parts = range.split('|');
  final raw = await ref.read(dependenciesProvider).api.getJson(
        '/producer/shoots',
        query: {'from': parts.first, 'to': parts.last},
      );
  final map = asMap(raw);
  final list = asList(map?['items'] ?? raw);
  return list
      .map(asMap)
      .whereType<Map<String, dynamic>>()
      .map(ProducerShoot.fromJson)
      .where((shoot) => shoot.id.isNotEmpty)
      .toList();
});

/// Неделя съёмок всех SMM-проектов: адрес, контакт и кто снимает.
class ProducerDashboard extends ConsumerStatefulWidget {
  const ProducerDashboard({super.key});

  @override
  ConsumerState<ProducerDashboard> createState() => _ProducerDashboardState();
}

class _ProducerDashboardState extends ConsumerState<ProducerDashboard> {
  late DateTime _monday;

  @override
  void initState() {
    super.initState();
    _monday = _weekStart(BizDate.today());
  }

  DateTime _weekStart(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  String get _rangeKey {
    final end = _monday.add(const Duration(days: 6));
    return '${BizDate.key(_monday)}|${BizDate.key(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final shoots = ref.watch(producerShootsProvider(_rangeKey));
    final items = shoots.value ?? const <ProducerShoot>[];
    final showSunday = items.any((shoot) => shoot.date.weekday == DateTime.sunday);
    final days = showSunday ? 7 : 6;
    final last = _monday.add(Duration(days: days - 1));
    final range = _monday.month == last.month
        ? '${_monday.day}–${BizDate.dateLong(last)}'
        : '${BizDate.dateShort(_monday)} – ${BizDate.dateShort(last)}';

    return AppPage(
      header: AppHeader(
        title: 'Панель',
        subtitle: 'Съёмки по всем SMM-проектам',
        actions: [
          AppIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Прошлая неделя',
            onPressed: () => setState(() {
              _monday = _monday.subtract(const Duration(days: 7));
            }),
          ),
          AppIconButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Следующая неделя',
            onPressed: () => setState(() {
              _monday = _monday.add(const Duration(days: 7));
            }),
          ),
        ],
      ),
      onRefresh: () async {
        ref.invalidate(producerShootsProvider(_rangeKey));
        await ref.read(producerShootsProvider(_rangeKey).future);
      },
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                range,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.palette.text,
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.all(12),
                radius: 14,
                child: Text(
                  'Съёмки приходят в Telegram накануне и раз в неделю. Здесь можно сверить адрес, контакт и кто снимает.',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13,
                    height: 1.4,
                    color: context.palette.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (shoots.isLoading && items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (shoots.hasError && items.isEmpty)
                EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Не удалось загрузить съёмки',
                  message: 'Проверьте соединение и обновите неделю.',
                  actionLabel: 'Повторить',
                  onAction: () => ref.invalidate(producerShootsProvider(_rangeKey)),
                )
              else
                for (var i = 0; i < days; i++)
                  _DayBlock(
                    day: _monday.add(Duration(days: i)),
                    shoots: items
                        .where((shoot) => BizDate.key(shoot.date) ==
                            BizDate.key(_monday.add(Duration(days: i))))
                        .toList(),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({required this.day, required this.shoots});

  final DateTime day;
  final List<ProducerShoot> shoots;

  @override
  Widget build(BuildContext context) {
    final today = BizDate.isToday(day);
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${BizDate.weekdayFull(day)}, ${BizDate.dateShort(day)}',
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 13,
              fontWeight: today ? FontWeight.w700 : FontWeight.w600,
              color: today ? palette.accentBright : palette.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          if (shoots.isEmpty)
            Text(
              'Съёмок нет',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 12.5,
                color: palette.textTertiary,
              ),
            )
          else
            for (final shoot in shoots) ...[
              _ShootCard(shoot: shoot),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _ShootCard extends StatelessWidget {
  const _ShootCard({required this.shoot});

  final ProducerShoot shoot;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final title = (shoot.title ?? '').trim();
    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                (shoot.time ?? '').trim().isEmpty ? 'Весь день' : shoot.time!,
                style: TextStyle(
                  fontFamily: AppTypography.family,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  shoot.projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.textSecondary,
                  ),
                ),
              ),
              if (shoot.done)
                AppChip(label: 'Снято', tone: ChipTone.success, compact: true),
            ],
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 13.5,
                color: palette.text,
              ),
            ),
          ],
          if ((shoot.videographer ?? '').trim().isNotEmpty)
            _Line(icon: Icons.videocam_outlined, text: shoot.videographer!),
          if ((shoot.address ?? '').trim().isNotEmpty)
            _Line(icon: Icons.place_outlined, text: shoot.address!),
          if ((shoot.contact ?? '').trim().isNotEmpty)
            _Line(icon: Icons.phone_outlined, text: shoot.contact!, onTap: () => _call(shoot.contact!)),
          if ((shoot.smm ?? '').trim().isNotEmpty)
            _Line(icon: Icons.person_outline_rounded, text: 'SMM: ${shoot.smm}'),
          if ((shoot.mapUrl ?? '').trim().isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _open(shoot.mapUrl!),
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('Открыть карту'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _call(String contact) async {
    final match = RegExp(r'\+?\d[\d\s\-()]{8,}\d').firstMatch(contact);
    final raw = (match?.group(0) ?? contact).replaceAll(RegExp(r'[^\d+]'), '');
    if (raw.length < 8) return;
    await _open('tel:$raw');
  }

  Future<void> _open(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final row = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: palette.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 12.5,
                height: 1.35,
                color: onTap == null ? palette.textSecondary : palette.accentBright,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(onTap: onTap, child: row);
  }
}
