import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dependencies.dart';
import '../../../core/rbac/permissions.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/access_models.dart';

class AccessRepository {
  AccessRepository(this.deps);

  final AppDependencies deps;

  Future<List<AccessUser>> getAccessUsers() async {
    final res = await deps.api.getJson('/users/access');
    final list = res is List ? res : (asMap(res)?['data'] as List? ?? const []);
    return list
        .map(asMap)
        .whereType<Map<String, dynamic>>()
        .map(AccessUser.fromJson)
        .toList();
  }

  Future<List<AccessCapability>> getAccessCatalog() async {
    try {
      final res = await deps.api.getJson('/users/access/catalog');
      final list = res is List ? res : (asMap(res)?['data'] as List? ?? const []);
      final parsed = list
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .map(AccessCapability.fromJson)
          .where((c) => c.key.isNotEmpty)
          .toList();
      if (parsed.isNotEmpty) return parsed;
    } catch (_) {
      // Fall back to the built-in catalog synced with backend GRANTABLE.
    }
    return defaultAccessCatalog;
  }

  Future<void> setAccess(
    String userId, {
    required List<String> permissions,
    required List<String> denied,
  }) async {
    await deps.api.patchJson('/users/$userId/access', body: {
      'permissions': permissions,
      'denied': denied,
    });
  }

  Future<void> updatePermissions(
    String userId,
    List<String> extraPermissions, {
    List<String> deniedPermissions = const [],
  }) =>
      setAccess(
        userId,
        permissions: extraPermissions,
        denied: deniedPermissions,
      );
}

List<String> _rolesWithPerm(String key) {
  return roleLabels.keys
      .where((role) => rolePermissionsFor(role: role).contains(key))
      .toList();
}

final List<AccessCapability> defaultAccessCatalog = [
  AccessCapability(
    key: 'projects.view',
    label: 'Видеть раздел Проекты',
    description: 'Доступ к списку проектов, доске и контент-плану',
    category: 'Проекты',
    roles: _rolesWithPerm('projects.view'),
  ),
  AccessCapability(
    key: 'projects.create',
    label: 'Создавать проекты',
    description: 'Кнопка «+ Новый проект» и мастер создания',
    category: 'Проекты',
    roles: _rolesWithPerm('projects.create'),
  ),
  AccessCapability(
    key: 'projects.edit',
    label: 'Редактировать проекты',
    description: 'Менять название, команду, тариф и настройки проекта',
    category: 'Проекты',
    roles: _rolesWithPerm('projects.edit'),
  ),
  AccessCapability(
    key: 'projects.archive',
    label: 'Архивировать и восстанавливать проекты',
    description: 'Переводить проекты в архив и возвращать обратно',
    category: 'Проекты',
    roles: _rolesWithPerm('projects.archive'),
  ),
  AccessCapability(
    key: 'projects.delete',
    label: 'Удалять проекты навсегда',
    description: 'Безвозвратное удаление проекта со всеми задачами',
    category: 'Проекты',
    danger: true,
    roles: _rolesWithPerm('projects.delete'),
  ),
  AccessCapability(
    key: 'tasks.view',
    label: 'Видеть раздел Задачи',
    description: 'Доступ к списку задач и канбану',
    category: 'Задачи',
    roles: _rolesWithPerm('tasks.view'),
  ),
  AccessCapability(
    key: 'tasks.create',
    label: 'Создавать задачи',
    description: 'Ставить задачи себе и коллегам',
    category: 'Задачи',
    roles: _rolesWithPerm('tasks.create'),
  ),
  AccessCapability(
    key: 'tasks.edit',
    label: 'Редактировать задачи',
    description: 'Менять описание, дедлайн, приоритет, чек-лист',
    category: 'Задачи',
    roles: _rolesWithPerm('tasks.edit'),
  ),
  AccessCapability(
    key: 'tasks.delete',
    label: 'Удалять задачи',
    description: 'Удалять задачи в списке и на доске',
    category: 'Задачи',
    danger: true,
    roles: _rolesWithPerm('tasks.delete'),
  ),
  AccessCapability(
    key: 'tasks.approve',
    label: 'Принимать и возвращать задачи',
    description: 'Одобрять задачи на проверке и отправлять на доработку',
    category: 'Задачи',
    roles: _rolesWithPerm('tasks.approve'),
  ),
  AccessCapability(
    key: 'tasks.bulk',
    label: 'Массовые операции с задачами',
    description: 'Массовое изменение статуса или удаление',
    category: 'Задачи',
    roles: _rolesWithPerm('tasks.bulk'),
  ),
  AccessCapability(
    key: 'clients.view',
    label: 'Видеть базу клиентов (CRM)',
    description: 'Доступ к разделу Клиенты и воронке лидов',
    category: 'Клиенты и продажи',
    roles: _rolesWithPerm('clients.view'),
  ),
  AccessCapability(
    key: 'clients.create',
    label: 'Добавлять и редактировать клиентов',
    description: 'Создание карточек лидов, смена этапа, заметки',
    category: 'Клиенты и продажи',
    roles: _rolesWithPerm('clients.create'),
  ),
  AccessCapability(
    key: 'clients.delete',
    label: 'Удалять клиентов',
    description: 'Безвозвратное удаление карточек из CRM',
    category: 'Клиенты и продажи',
    danger: true,
    roles: _rolesWithPerm('clients.delete'),
  ),
  AccessCapability(
    key: 'calendar.view',
    label: 'Календарь и планер',
    description: 'Доступ к календарю звонков, встреч и съёмок',
    category: 'Клиенты и продажи',
    roles: _rolesWithPerm('calendar.view'),
  ),
  AccessCapability(
    key: 'stories.view',
    label: 'Просматривать сторис',
    description: 'Доступ к разделу проверки и истории сторис',
    category: 'Контент и сторис',
    roles: _rolesWithPerm('stories.view'),
  ),
  AccessCapability(
    key: 'stories.manage',
    label: 'Публиковать и редактировать сторис',
    description: 'Добавлять записи о вышедших сторис в проектах',
    category: 'Контент и сторис',
    roles: _rolesWithPerm('stories.manage'),
  ),
  AccessCapability(
    key: 'files.view',
    label: 'Видеть файлы',
    description: 'Просмотр и скачивание файлов проектов',
    category: 'Контент и сторис',
    roles: _rolesWithPerm('files.view'),
  ),
  AccessCapability(
    key: 'files.upload',
    label: 'Загружать файлы',
    description: 'Добавлять медиа и документы в хранилище',
    category: 'Контент и сторис',
    roles: _rolesWithPerm('files.upload'),
  ),
  AccessCapability(
    key: 'dev-tracker.view',
    label: 'Видеть трекер разработки',
    description: 'Доступ к доске разработки и этапам Dev-проектов',
    category: 'Разработка',
    roles: _rolesWithPerm('dev-tracker.view'),
  ),
  AccessCapability(
    key: 'dev-tracker.manage',
    label: 'Управлять трекером разработки',
    description: 'Создавать Dev-проекты, этапы и назначать разработчиков',
    category: 'Разработка',
    roles: _rolesWithPerm('dev-tracker.manage'),
  ),
  AccessCapability(
    key: 'employees.view',
    label: 'Видеть раздел Сотрудники',
    description: 'Список команды, карточки сотрудников и нагрузка',
    category: 'Команда и аналитика',
    roles: _rolesWithPerm('employees.view'),
  ),
  AccessCapability(
    key: 'analytics.view',
    label: 'Аналитика',
    description: 'Графики выполнения задач, эффективности и KPI',
    category: 'Команда и аналитика',
    roles: _rolesWithPerm('analytics.view'),
  ),
  AccessCapability(
    key: 'reports.view',
    label: 'Видеть отчёты',
    description: 'Доступ к еженедельным и ежемесячным отчётам',
    category: 'Команда и аналитика',
    roles: _rolesWithPerm('reports.view'),
  ),
  AccessCapability(
    key: 'reports.create',
    label: 'Создавать отчёты',
    description: 'Формировать и отправлять отчёты по проектам',
    category: 'Команда и аналитика',
    roles: _rolesWithPerm('reports.create'),
  ),
  AccessCapability(
    key: 'risks.view',
    label: 'Видеть панель рисков',
    description: 'Проекты под угрозой срыва, просрочки и узкие места',
    category: 'Команда и аналитика',
    roles: _rolesWithPerm('risks.view'),
  ),
  AccessCapability(
    key: 'archive.view',
    label: 'Видеть архив',
    description: 'Доступ к архивным проектам и завершённым задачам',
    category: 'Команда и аналитика',
    roles: _rolesWithPerm('archive.view'),
  ),
  AccessCapability(
    key: 'finance.manage',
    label: 'Финансы (ДДС, P&L, счета, зарплаты)',
    description: 'Полный доступ ко всем финансовым разделам компании',
    category: 'Финансы и безопасность',
    danger: true,
    roles: _rolesWithPerm('finance.manage'),
  ),
  AccessCapability(
    key: 'tariffs.manage',
    label: 'Управлять тарифами',
    description: 'Создавать и редактировать тарифные планы услуг',
    category: 'Финансы и безопасность',
    roles: _rolesWithPerm('tariffs.manage'),
  ),
  AccessCapability(
    key: 'security-log.view',
    label: 'Журнал безопасности',
    description: 'Просмотр входов, действий и критических операций',
    category: 'Финансы и безопасность',
    danger: true,
    roles: _rolesWithPerm('security-log.view'),
  ),
  AccessCapability(
    key: 'time-tracker.use',
    label: 'Тайм-трекер',
    description: 'Учёт рабочего времени по задачам',
    category: 'Инструменты',
    roles: _rolesWithPerm('time-tracker.use'),
  ),
  AccessCapability(
    key: 'notes.use',
    label: 'Личные заметки',
    description: 'Раздел быстрых заметок и чек-листов',
    category: 'Инструменты',
    roles: _rolesWithPerm('notes.use'),
  ),
  AccessCapability(
    key: 'ai.chat',
    label: 'AI-ассистент',
    description: 'Чат с ИИ для текстов, идей и анализа',
    category: 'Инструменты',
    roles: _rolesWithPerm('ai.chat'),
  ),
];

final accessRepositoryProvider = Provider<AccessRepository>((ref) {
  return AccessRepository(ref.watch(dependenciesProvider));
});
