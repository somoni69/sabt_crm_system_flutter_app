import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';

class WebOnlyPage extends StatelessWidget {
  const WebOnlyPage({super.key, required this.path});

  final String path;

  Future<void> _open(BuildContext context) async {
    final url = '${AppEnv.webBaseUrl}$path';
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть браузер')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть браузер')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      showBottomBarSpace: false,
      header: AppHeader(
        title: 'Веб-версия',
        subtitle: 'Полный инструмент Sabt',
        onBack: () => context.pop(),
      ),
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppHeroCard(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                radius: 26,
                child: Column(
                  children: [
                    SurfaceIcon(
                      icon: Icons.desktop_windows_outlined,
                      color: context.palette.accentBright,
                      size: 72,
                      radius: 22,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Этот раздел живёт в браузере',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Тяжёлые таблицы, канбан, финансы и настройки доступа удобнее на большом экране. Мобильное приложение остаётся вашим daily-драйвером: задачи, SMM-календарь, сторис и клиенты.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTypography.family,
                        fontSize: 12,
                        height: 1.55,
                        color: context.palette.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.palette.surface2,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: context.palette.borderSoft),
                      ),
                      child: Text(
                        path,
                        style: TextStyle(
                          fontFamily: AppTypography.family,
                          fontSize: 10.5,
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Открыть в браузере',
                icon: Icons.open_in_new_rounded,
                onPressed: () => _open(context),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Вернуться в приложение',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.pop(),
              ),
              const SizedBox(height: 24),
              AccentNote(
                icon: Icons.sync_rounded,
                color: context.palette.success,
                text: 'Все изменения синхронизируются через один аккаунт Sabt. Авторизуйтесь в браузере тем же логином — данные уже будут на месте.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
