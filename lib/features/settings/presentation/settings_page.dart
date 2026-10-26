import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_env.dart';
import '../../../core/dependencies.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_controls.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_surfaces.dart';
import '../../auth/presentation/auth_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late int _cacheEntries = ref.read(dependenciesProvider).cache.entries;
  bool _checking = false;

  Future<void> _clearCache() async {
    await showConfirmSheet(
      context: context,
      title: 'Очистить кэш?',
      message:
          'Будут удалены сохранённые ответы API для всех профилей на этом устройстве. Данные в компании не изменятся; приложение загрузит их заново.',
      confirmLabel: 'Очистить',
      danger: true,
      onConfirm: () async {
        final deps = ref.read(dependenciesProvider);
        await deps.cache.clearAll();
        if (mounted) {
          setState(() => _cacheEntries = deps.cache.entries);
          deps.banners.show(const AppBanner(
            title: 'Кэш очищен',
            message: 'Свежие данные загрузятся при следующем открытии разделов.',
            tone: BannerTone.success,
          ));
          ref.read(dataRevisionProvider.notifier).bump();
        }
      },
    );
  }

  Future<void> _checkConnection() async {
    if (_checking) return;
    setState(() => _checking = true);
    final deps = ref.read(dependenciesProvider);
    try {
      final online = await deps.connectivity.refresh();
      if (!online) {
        deps.banners.show(const AppBanner(
          title: 'Нет соединения',
          message: 'Устройство не в сети. Проверьте Wi-Fi или мобильный интернет.',
          tone: BannerTone.danger,
          icon: Icons.wifi_off_rounded,
        ));
        return;
      }
      await deps.api.getJson('/auth/me');
      deps.banners.show(const AppBanner(
        title: 'Соединение в порядке',
        message: 'API Sabt отвечает, сессия активна.',
        tone: BannerTone.success,
        icon: Icons.wifi_rounded,
      ));
    } on ApiException catch (error) {
      deps.banners.show(AppBanner(
        title: 'Проблема с соединением',
        message: error.message,
        tone: BannerTone.danger,
      ));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _refreshData() {
    ref.read(dataRevisionProvider.notifier).bump();
    ref.read(dependenciesProvider).banners.show(const AppBanner(
          title: 'Обновление запущено',
          message: 'Открытые разделы подтянут свежие данные.',
          tone: BannerTone.accent,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final deps = ref.watch(dependenciesProvider);
    final online = ref.watch(onlineProvider);
    final realtime = ref.watch(realtimeConnectedProvider);
    final firebase = deps.firebase;
    final tokens = deps.tokens;

    return AppPage(
      showBottomBarSpace: false,
      header: AppHeader(
        title: 'Настройки',
        subtitle: 'Sabt ${AppEnv.appVersion}',
        onBack: () => context.pop(),
      ),
      slivers: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(overline: 'ВНЕШНИЙ ВИД', title: 'Liquid Graphite'),
              AppCard(
                padding: const EdgeInsets.all(15),
                radius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const SurfaceIcon(
                          icon: Icons.palette_outlined,
                          color: AppColors.accentBright,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Тёмное стекло Sabt',
                                style: TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Брендовая тема зафиксирована для всех ролей и устройств.',
                                style: TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: 10.5,
                                  height: 1.4,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const AccentNote(
                      icon: Icons.accessibility_new_rounded,
                      color: AppColors.ice,
                      text:
                          'При включённой высокой контрастности или уменьшении анимаций в системе стекло автоматически становится плотным, а движение — минимальным.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(overline: 'ДАННЫЕ', title: 'Кэш и синхронизация'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                radius: 20,
                child: Column(
                  children: [
                    KeyValueRow(
                      label: 'Сохранённых ответов',
                      value: '$_cacheEntries',
                      icon: Icons.storage_rounded,
                    ),
                    const Divider(height: 1, color: AppColors.borderSoft),
                    KeyValueRow(
                      label: 'Очистить кэш',
                      value: 'Удалить',
                      icon: Icons.delete_sweep_outlined,
                      valueColor: AppColors.danger,
                      onTap: _clearCache,
                    ),
                    const Divider(height: 1, color: AppColors.borderSoft),
                    KeyValueRow(
                      label: 'Обновить данные',
                      value: 'Синхронизировать',
                      icon: Icons.sync_rounded,
                      onTap: _refreshData,
                    ),
                    const Divider(height: 1, color: AppColors.borderSoft),
                    KeyValueRow(
                      label: 'Проверить соединение',
                      value: _checking ? 'Проверяем…' : 'Тест API',
                      icon: Icons.network_check_rounded,
                      onTap: _checking ? null : _checkConnection,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(overline: 'УВЕДОМЛЕНИЯ', title: 'Каналы доставки'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                radius: 20,
                child: Column(
                  children: [
                    KeyValueRow(
                      label: 'Push (Firebase)',
                      value: firebase.messagingEnabled ? 'Подключён' : 'Не настроен',
                      icon: Icons.notifications_active_outlined,
                      valueColor: firebase.messagingEnabled
                          ? AppColors.success
                          : AppColors.textTertiary,
                    ),
                    const Divider(height: 1, color: AppColors.borderSoft),
                    KeyValueRow(
                      label: 'Realtime (Socket.IO)',
                      value: realtime ? 'Подключён' : 'Ожидает',
                      icon: Icons.bolt_outlined,
                      valueColor: realtime ? AppColors.success : AppColors.warning,
                    ),
                    const Divider(height: 1, color: AppColors.borderSoft),
                    KeyValueRow(
                      label: 'Локальные напоминания',
                      value: firebase.messagingEnabled
                          ? 'Резерв включён'
                          : 'Только в приложении',
                      icon: Icons.vibration_rounded,
                    ),
                    const Divider(height: 1, color: AppColors.borderSoft),
                    KeyValueRow(
                      label: 'Сеть',
                      value: online ? 'Онлайн' : 'Офлайн',
                      icon: online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      valueColor: online ? AppColors.success : AppColors.danger,
                    ),
                  ],
                ),
              ),
              if (!firebase.messagingEnabled) ...[
                const SizedBox(height: 10),
                const AccentNote(
                  icon: Icons.settings_ethernet_rounded,
                  color: AppColors.warning,
                  text:
                      'Push включается на этапе сборки через FIREBASE_* dart-defines и FIREBASE_SERVICE_ACCOUNT_JSON на сервере. Инструкция — в docs/FIREBASE_SETUP.md.',
                ),
              ],
              const SizedBox(height: 20),
              const SectionHeader(overline: 'ДИАГНОСТИКА', title: 'Система'),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                radius: 20,
                child: Column(
                  children: [
                    KeyValueRow(
                      label: 'Сервер API',
                      value: AppEnv.apiOrigin,
                      icon: Icons.dns_outlined,
                    ),
                    const Divider(height: 1, color: AppColors.borderSoft),
                    KeyValueRow(
                      label: 'Realtime namespace',
                      value: AppEnv.wsNamespaceUrl,
                      icon: Icons.hub_outlined,
                    ),
                    const Divider(height: 1, color: AppColors.borderSoft),
                    KeyValueRow(
                      label: 'Хранилище токенов',
                      value: tokens.secureAvailable ? 'Keychain / Keystore' : 'Локальный бокс',
                      icon: Icons.security_rounded,
                      valueColor: tokens.secureAvailable
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const Divider(height: 1, color: AppColors.borderSoft),
                    KeyValueRow(
                      label: 'Платформа',
                      value: AppEnv.isWeb
                          ? 'Web'
                          : AppEnv.isAndroid
                              ? 'Android'
                              : AppEnv.isIOS
                                  ? 'iOS'
                                  : 'Desktop',
                      icon: Icons.devices_other_rounded,
                    ),
                    const Divider(height: 1, color: AppColors.borderSoft),
                    KeyValueRow(
                      label: 'Firebase project',
                      value: firebase.initialized
                          ? (AppEnv.firebaseProjectId.isEmpty
                              ? 'Подключён'
                              : AppEnv.firebaseProjectId)
                          : 'Не инициализирован',
                      icon: Icons.local_fire_department_outlined,
                      valueColor:
                          firebase.initialized ? AppColors.success : AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(overline: 'АККАУНТ', title: 'Сессия'),
              AppButton(
                label: 'Выйти из аккаунта',
                icon: Icons.logout_rounded,
                variant: AppButtonVariant.ghost,
                onPressed: () => showConfirmSheet(
                  context: context,
                  title: 'Выйти из Sabt?',
                  message:
                      'Локальный кэш этого профиля будет очищен. Данные в компании останутся без изменений.',
                  confirmLabel: 'Выйти',
                  danger: true,
                  onConfirm: () => ref.read(authControllerProvider.notifier).logout(),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: Text(
                  'Sabt CRM · Liquid Graphite · ${DateTime.now().year}',
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10,
                    color: AppColors.textDisabled,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}
