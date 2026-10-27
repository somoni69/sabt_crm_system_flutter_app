import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_env.dart';
import '../../../core/dependencies.dart';
import '../../../core/design/motion.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/app_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/theme_mode_provider.dart';
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
      message: 'Будут удалены сохранённые ответы API для всех профилей на этом устройстве. Данные в компании не изменятся; приложение загрузит их заново.',
      confirmLabel: 'Очистить',
      danger: true,
      onConfirm: () async {
        final deps = ref.read(dependenciesProvider);
        await deps.cache.clearAll();
        if (mounted) {
          setState(() => _cacheEntries = deps.cache.entries);
          deps.banners.show(
            const AppBanner(
              title: 'Кэш очищен',
              message:
                  'Свежие данные загрузятся при следующем открытии разделов.',
              tone: BannerTone.success,
            ),
          );
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
        deps.banners.show(
          const AppBanner(
            title: 'Нет соединения',
            message:
                'Устройство не в сети. Проверьте Wi-Fi или мобильный интернет.',
            tone: BannerTone.danger,
            icon: Icons.wifi_off_rounded,
          ),
        );
        return;
      }
      await deps.api.getJson('/auth/me');
      deps.banners.show(
        const AppBanner(
          title: 'Соединение в порядке',
          message: 'API Sabt отвечает, сессия активна.',
          tone: BannerTone.success,
          icon: Icons.wifi_rounded,
        ),
      );
    } on ApiException catch (error) {
      deps.banners.show(
        AppBanner(
          title: 'Проблема с соединением',
          message: error.message,
          tone: BannerTone.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _refreshData() {
    ref.read(dataRevisionProvider.notifier).bump();
    ref
        .read(dependenciesProvider)
        .banners
        .show(
          const AppBanner(
            title: 'Обновление запущено',
            message: 'Открытые разделы подтянут свежие данные.',
            tone: BannerTone.accent,
          ),
        );
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
              const SectionHeader(
                overline: 'ВНЕШНИЙ ВИД',
                title: 'Тема оформления',
              ),
              AppCard(
                padding: const EdgeInsets.all(15),
                radius: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SurfaceIcon(
                          icon: Icons.palette_outlined,
                          color: context.palette.accentBright,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Стекло Sabt',
                                style: TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: context.palette.text,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Тёмный графит или светлый фарфор. Фирменный фиолетовый — якорь обеих тем, выбор сохраняется на устройстве.',
                                style: TextStyle(
                                  fontFamily: AppTypography.family,
                                  fontSize: 10.5,
                                  height: 1.4,
                                  color: context.palette.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ThemeModePicker(
                      mode: ref.watch(themeModeProvider),
                      onChanged: (mode) =>
                          ref.read(themeModeProvider.notifier).set(mode),
                    ),
                    const SizedBox(height: 12),
                    AccentNote(
                      icon: Icons.accessibility_new_rounded,
                      color: context.palette.ice,
                      text: 'При включённой высокой контрастности или уменьшении анимаций в системе стекло автоматически становится плотным, а движение — минимальным.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(
                overline: 'ДАННЫЕ',
                title: 'Кэш и синхронизация',
              ),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                radius: 20,
                child: Column(
                  children: [
                    KeyValueRow(
                      label: 'Сохранённых ответов',
                      value: '$_cacheEntries',
                      icon: Icons.storage_rounded,
                    ),
                    Divider(height: 1, color: context.palette.borderSoft),
                    KeyValueRow(
                      label: 'Очистить кэш',
                      value: 'Удалить',
                      icon: Icons.delete_sweep_outlined,
                      valueColor: context.palette.danger,
                      onTap: _clearCache,
                    ),
                    Divider(height: 1, color: context.palette.borderSoft),
                    KeyValueRow(
                      label: 'Обновить данные',
                      value: 'Синхронизировать',
                      icon: Icons.sync_rounded,
                      onTap: _refreshData,
                    ),
                    Divider(height: 1, color: context.palette.borderSoft),
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
              const SectionHeader(
                overline: 'УВЕДОМЛЕНИЯ',
                title: 'Каналы доставки',
              ),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                radius: 20,
                child: Column(
                  children: [
                    KeyValueRow(
                      label: 'Push (Firebase)',
                      value: firebase.messagingEnabled
                          ? 'Подключён'
                          : 'Не настроен',
                      icon: Icons.notifications_active_outlined,
                      valueColor: firebase.messagingEnabled
                          ? context.palette.success
                          : context.palette.textTertiary,
                    ),
                    Divider(height: 1, color: context.palette.borderSoft),
                    KeyValueRow(
                      label: 'Realtime (Socket.IO)',
                      value: realtime ? 'Подключён' : 'Ожидает',
                      icon: Icons.bolt_outlined,
                      valueColor: realtime
                          ? context.palette.success
                          : context.palette.warning,
                    ),
                    Divider(height: 1, color: context.palette.borderSoft),
                    KeyValueRow(
                      label: 'Локальные напоминания',
                      value: firebase.messagingEnabled
                          ? 'Резерв включён'
                          : 'Только в приложении',
                      icon: Icons.vibration_rounded,
                    ),
                    Divider(height: 1, color: context.palette.borderSoft),
                    KeyValueRow(
                      label: 'Сеть',
                      value: online ? 'Онлайн' : 'Офлайн',
                      icon: online
                          ? Icons.wifi_rounded
                          : Icons.wifi_off_rounded,
                      valueColor: online
                          ? context.palette.success
                          : context.palette.danger,
                    ),
                  ],
                ),
              ),
              if (!firebase.messagingEnabled) ...[
                const SizedBox(height: 10),
                AccentNote(
                  icon: Icons.settings_ethernet_rounded,
                  color: context.palette.warning,
                  text: 'Push включается на этапе сборки через FIREBASE_* dart-defines и FIREBASE_SERVICE_ACCOUNT_JSON на сервере. Инструкция — в docs/FIREBASE_SETUP.md.',
                ),
              ],
              const SizedBox(height: 20),
              const SectionHeader(overline: 'ДИАГНОСТИКА', title: 'Система'),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 5,
                ),
                radius: 20,
                child: Column(
                  children: [
                    KeyValueRow(
                      label: 'Сервер API',
                      value: AppEnv.apiOrigin,
                      icon: Icons.dns_outlined,
                    ),
                    Divider(height: 1, color: context.palette.borderSoft),
                    KeyValueRow(
                      label: 'Realtime namespace',
                      value: AppEnv.wsNamespaceUrl,
                      icon: Icons.hub_outlined,
                    ),
                    Divider(height: 1, color: context.palette.borderSoft),
                    KeyValueRow(
                      label: 'Хранилище токенов',
                      value: tokens.secureAvailable
                          ? 'Keychain / Keystore'
                          : 'Локальный бокс',
                      icon: Icons.security_rounded,
                      valueColor: tokens.secureAvailable
                          ? context.palette.success
                          : context.palette.warning,
                    ),
                    Divider(height: 1, color: context.palette.borderSoft),
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
                    Divider(height: 1, color: context.palette.borderSoft),
                    KeyValueRow(
                      label: 'Firebase project',
                      value: firebase.initialized
                          ? (AppEnv.firebaseProjectId.isEmpty
                                ? 'Подключён'
                                : AppEnv.firebaseProjectId)
                          : 'Не инициализирован',
                      icon: Icons.local_fire_department_outlined,
                      valueColor: firebase.initialized
                          ? context.palette.success
                          : context.palette.textTertiary,
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
                  message: 'Локальный кэш этого профиля будет очищен. Данные в компании останутся без изменений.',
                  confirmLabel: 'Выйти',
                  danger: true,
                  onConfirm: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: Text(
                  'Sabt CRM · Liquid Glass · ${DateTime.now().year}',
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 10,
                    color: context.palette.textDisabled,
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

/// Dark / light / system picker. Three equal tiles; the active one
/// carries the accent rim and a filled icon, so the current theme is
/// readable at a glance without opening anything.
class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _option(
          context,
          mode: ThemeMode.dark,
          icon: Icons.dark_mode_rounded,
          label: 'Тёмная',
        ),
        const SizedBox(width: 8),
        _option(
          context,
          mode: ThemeMode.light,
          icon: Icons.light_mode_rounded,
          label: 'Светлая',
        ),
        const SizedBox(width: 8),
        _option(
          context,
          mode: ThemeMode.system,
          icon: Icons.brightness_auto_rounded,
          label: 'Системная',
        ),
      ],
    );
  }

  Widget _option(
    BuildContext context, {
    required ThemeMode mode,
    required IconData icon,
    required String label,
  }) {
    final palette = context.palette;
    final selected = this.mode == mode;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Тема: $label',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Motion.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? palette.accent.withValues(alpha: 0.14)
                  : palette.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? palette.accent : palette.borderSoft,
                width: selected ? 1.3 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? palette.accentBright : palette.textTertiary,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? palette.text : palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
