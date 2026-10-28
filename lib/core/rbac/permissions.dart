import '../../features/auth/domain/user.dart';

/// Mirror of the web permission matrix (`frontend/src/lib/permissions.ts`) and
/// backend grants (`backend/src/modules/auth/permissions.ts`).
/// The server is the source of truth; this layer gates UI controls, tabs, and
/// client routes so every role sees only what belongs to it.
abstract final class Perm {
  static const dashboard = 'dashboard';

  // Tasks
  static const tasksView = 'tasks.view';
  static const tasksCreate = 'tasks.create';
  static const tasksEdit = 'tasks.edit';
  static const tasksDelete = 'tasks.delete';
  static const tasksAssign = 'tasks.assign';
  static const tasksApprove = 'tasks.approve';
  static const tasksReturn = 'tasks.return';
  static const tasksBulk = 'tasks.bulk';
  static const tasksExport = 'tasks.export';
  static const tasksOverdueView = 'tasks.overdue.view';

  // Calendar
  static const calendarView = 'calendar.view';
  static const calendarCreate = 'calendar.create';

  // Projects
  static const projectsView = 'projects.view';
  static const projectsCreate = 'projects.create';
  static const projectsEdit = 'projects.edit';
  static const projectsDelete = 'projects.delete';
  static const projectsArchive = 'projects.archive';
  static const projectsMembersManage = 'projects.members.manage';
  static const projectsManagerChange = 'projects.manager.change';
  static const projectsPaymentsView = 'projects.payments.view';
  static const projectsPaymentsRequest = 'projects.payments.request';
  static const projectsBriefManage = 'projects.brief.manage';
  static const projectsBriefClear = 'projects.brief.clear';
  static const projectsLaunchManage = 'projects.launch.manage';

  // Board & Content Plan
  static const boardView = 'board.view';
  static const contentPlanManage = 'content-plan.manage';
  static const contentPlanCreate = 'content-plan.create';
  static const contentPlanEdit = 'content-plan.edit';
  static const contentPlanDelete = 'content-plan.delete';

  // Clients
  static const clientsView = 'clients.view';
  static const clientsCreate = 'clients.create';
  static const clientsEdit = 'clients.edit';
  static const clientsDelete = 'clients.delete';

  // Employees & Team
  static const employeesView = 'employees.view';
  static const employeesCreate = 'employees.create';
  static const employeesEdit = 'employees.edit';
  static const employeesDelete = 'employees.delete';
  static const employeesRoleChange = 'employees.role.change';
  static const employeesSalaryView = 'employees.salary.view';
  static const usersManage = 'users.manage';
  static const teamActivityView = 'team-activity.view';
  static const organizerDirectory = 'organizer.directory';

  // Analytics & Reports & Risks
  static const analyticsView = 'analytics.view';
  static const reportsView = 'reports.view';
  static const reportsCreate = 'reports.create';
  static const risksView = 'risks.view';
  static const archiveView = 'archive.view';
  static const securityLogView = 'security-log.view';

  // Stories
  static const storiesManage = 'stories.manage';
  static const storiesView = 'stories.view';

  // Finance & Tariffs
  static const financeManage = 'finance.manage';
  static const tariffsManage = 'tariffs.manage';
  static const tariffsDelete = 'tariffs.delete';

  // Dev Tracker
  static const devTrackerView = 'dev-tracker.view';
  static const devTrackerManage = 'dev-tracker.manage';

  // Files & Tools
  static const filesView = 'files.view';
  static const filesUpload = 'files.upload';
  static const filesDelete = 'files.delete';
  static const filesDeleteAny = 'files.delete.any';
  static const timeTrackerView = 'time-tracker.use';
  static const notesUse = 'notes.use';
  static const aiChat = 'ai.chat';
}

const Map<String, String> roleLabels = {
  'founder': 'Основатель',
  'admin': 'Администратор',
  'smm_director': 'Директор SMM',
  'smm_specialist': 'SMM-специалист',
  'designer': 'Дизайнер',
  'videographer': 'Видеограф',
  'video_editor': 'Видеомонтажёр',
  'targetologist': 'Таргетолог',
  'dev_director': 'Директор по разработке',
  'pm_dev': 'ПМ Разработки',
  'developer': 'Разработчик',
  'sales_manager_smm': 'Менеджер по продажам SMM',
  'sales_manager_dev': 'Менеджер по продажам Dev',
  'stories_checker': 'Проверяющий сторис',
  'employee': 'Сотрудник',
};

String roleLabel(String role) => roleLabels[role] ?? role;

const Map<String, Set<String>> _permissions = {
  'admin': {
    Perm.dashboard,
    Perm.projectsView, Perm.projectsCreate, Perm.projectsEdit, Perm.projectsDelete,
    Perm.projectsArchive, Perm.projectsMembersManage, Perm.projectsManagerChange,
    Perm.projectsPaymentsView, Perm.projectsPaymentsRequest,
    Perm.projectsBriefManage, Perm.projectsBriefClear, Perm.projectsLaunchManage,
    Perm.boardView, Perm.contentPlanManage, Perm.contentPlanCreate,
    Perm.contentPlanEdit, Perm.contentPlanDelete,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksAssign, Perm.tasksApprove, Perm.tasksReturn, Perm.tasksBulk,
    Perm.tasksExport, Perm.tasksOverdueView,
    Perm.employeesView, Perm.employeesCreate, Perm.employeesEdit,
    Perm.employeesDelete, Perm.employeesRoleChange, Perm.employeesSalaryView,
    Perm.usersManage, Perm.teamActivityView, Perm.organizerDirectory,
    Perm.analyticsView, Perm.reportsView, Perm.reportsCreate,
    Perm.archiveView, Perm.filesView, Perm.filesUpload, Perm.filesDelete,
    Perm.filesDeleteAny, Perm.storiesManage, Perm.storiesView,
    Perm.timeTrackerView, Perm.notesUse, Perm.tariffsManage, Perm.tariffsDelete,
    Perm.risksView, Perm.clientsView, Perm.clientsCreate, Perm.clientsEdit,
    Perm.clientsDelete, Perm.securityLogView, Perm.aiChat,
    Perm.devTrackerView, Perm.devTrackerManage,
  },
  'founder': {
    Perm.dashboard,
    Perm.projectsView, Perm.projectsCreate, Perm.projectsEdit, Perm.projectsDelete,
    Perm.projectsArchive, Perm.projectsMembersManage, Perm.projectsManagerChange,
    Perm.projectsPaymentsView, Perm.projectsPaymentsRequest,
    Perm.projectsBriefManage, Perm.projectsBriefClear, Perm.projectsLaunchManage,
    Perm.boardView, Perm.contentPlanManage, Perm.contentPlanCreate,
    Perm.contentPlanEdit, Perm.contentPlanDelete,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksAssign, Perm.tasksApprove, Perm.tasksReturn, Perm.tasksBulk,
    Perm.tasksExport, Perm.tasksOverdueView,
    Perm.employeesView, Perm.employeesCreate, Perm.employeesEdit,
    Perm.employeesDelete, Perm.employeesRoleChange, Perm.employeesSalaryView,
    Perm.usersManage, Perm.teamActivityView, Perm.organizerDirectory,
    Perm.analyticsView, Perm.reportsView, Perm.reportsCreate, Perm.archiveView,
    Perm.filesView, Perm.filesUpload, Perm.filesDelete, Perm.filesDeleteAny,
    Perm.storiesManage, Perm.storiesView, Perm.timeTrackerView, Perm.notesUse,
    Perm.tariffsManage, Perm.tariffsDelete, Perm.risksView, Perm.financeManage,
    Perm.clientsView, Perm.clientsCreate, Perm.clientsEdit, Perm.clientsDelete,
    Perm.securityLogView, Perm.aiChat, Perm.devTrackerView, Perm.devTrackerManage,
  },
  'smm_director': {
    Perm.dashboard,
    Perm.projectsView, Perm.projectsCreate, Perm.projectsEdit, Perm.projectsDelete,
    Perm.projectsArchive, Perm.projectsMembersManage, Perm.projectsManagerChange,
    Perm.projectsPaymentsView, Perm.projectsPaymentsRequest,
    Perm.projectsBriefManage, Perm.projectsBriefClear, Perm.projectsLaunchManage,
    Perm.boardView, Perm.contentPlanManage, Perm.contentPlanCreate,
    Perm.contentPlanEdit, Perm.contentPlanDelete,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksAssign, Perm.tasksApprove, Perm.tasksReturn, Perm.tasksBulk,
    Perm.tasksExport, Perm.tasksOverdueView,
    Perm.employeesView, Perm.employeesCreate, Perm.employeesEdit,
    Perm.organizerDirectory,
    Perm.analyticsView, Perm.reportsView, Perm.reportsCreate, Perm.archiveView,
    Perm.filesView, Perm.filesUpload, Perm.filesDelete, Perm.filesDeleteAny,
    Perm.storiesManage, Perm.storiesView, Perm.timeTrackerView, Perm.notesUse,
    Perm.aiChat, Perm.tariffsManage, Perm.tariffsDelete, Perm.risksView,
  },
  'smm_specialist': {
    Perm.dashboard,
    Perm.projectsView, Perm.projectsCreate,
    Perm.projectsBriefManage, Perm.projectsLaunchManage,
    Perm.boardView, Perm.contentPlanManage, Perm.contentPlanCreate,
    Perm.contentPlanEdit, Perm.contentPlanDelete,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksExport, Perm.organizerDirectory,
    Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.filesUpload, Perm.filesDelete,
    Perm.storiesManage, Perm.storiesView,
    Perm.timeTrackerView, Perm.notesUse, Perm.aiChat,
  },
  'designer': {
    Perm.dashboard, Perm.projectsView, Perm.boardView, Perm.contentPlanEdit,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksExport, Perm.organizerDirectory,
    Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.filesUpload, Perm.filesDelete,
    Perm.storiesView, Perm.timeTrackerView, Perm.notesUse, Perm.aiChat,
  },
  'sales_manager_smm': {
    Perm.dashboard,
    Perm.projectsView, Perm.projectsCreate, Perm.projectsEdit, Perm.projectsDelete,
    Perm.projectsArchive, Perm.projectsPaymentsView, Perm.projectsPaymentsRequest,
    Perm.projectsBriefManage, Perm.projectsLaunchManage,
    Perm.boardView, Perm.contentPlanManage, Perm.contentPlanCreate,
    Perm.contentPlanEdit, Perm.contentPlanDelete,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksExport, Perm.calendarView, Perm.calendarCreate,
    Perm.organizerDirectory, Perm.archiveView, Perm.analyticsView,
    Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.filesUpload, Perm.filesDelete,
    Perm.storiesView, Perm.timeTrackerView, Perm.notesUse, Perm.aiChat,
    Perm.clientsView, Perm.clientsCreate, Perm.clientsEdit, Perm.clientsDelete,
  },
  'sales_manager_dev': {
    Perm.dashboard,
    Perm.projectsView, Perm.projectsCreate, Perm.projectsEdit, Perm.projectsDelete,
    Perm.projectsArchive, Perm.boardView,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksExport, Perm.calendarView, Perm.calendarCreate,
    Perm.organizerDirectory, Perm.archiveView, Perm.analyticsView,
    Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.filesUpload, Perm.filesDelete,
    Perm.storiesView, Perm.timeTrackerView, Perm.notesUse, Perm.aiChat,
    Perm.clientsView, Perm.clientsCreate, Perm.clientsEdit, Perm.clientsDelete,
  },
  'dev_director': {
    Perm.dashboard,
    Perm.projectsView, Perm.projectsCreate, Perm.projectsEdit, Perm.projectsDelete,
    Perm.projectsArchive, Perm.projectsMembersManage, Perm.projectsManagerChange,
    Perm.projectsPaymentsView, Perm.projectsPaymentsRequest,
    Perm.projectsBriefManage, Perm.projectsBriefClear, Perm.projectsLaunchManage,
    Perm.boardView, Perm.contentPlanManage, Perm.contentPlanCreate,
    Perm.contentPlanEdit, Perm.contentPlanDelete,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksAssign, Perm.tasksApprove, Perm.tasksReturn, Perm.tasksBulk,
    Perm.tasksExport, Perm.tasksOverdueView,
    Perm.employeesView, Perm.employeesCreate, Perm.employeesEdit,
    Perm.organizerDirectory,
    Perm.analyticsView, Perm.risksView, Perm.reportsView, Perm.reportsCreate,
    Perm.archiveView, Perm.filesView, Perm.filesUpload, Perm.filesDelete,
    Perm.filesDeleteAny, Perm.storiesView, Perm.timeTrackerView, Perm.notesUse,
    Perm.aiChat, Perm.devTrackerView, Perm.devTrackerManage,
  },
  'pm_dev': {
    Perm.dashboard, Perm.projectsView, Perm.boardView, Perm.contentPlanEdit,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksExport, Perm.organizerDirectory,
    Perm.analyticsView, Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.filesUpload, Perm.filesDelete,
    Perm.storiesView, Perm.timeTrackerView, Perm.notesUse, Perm.aiChat,
    Perm.devTrackerView, Perm.devTrackerManage,
  },
  'developer': {
    Perm.dashboard, Perm.projectsView, Perm.boardView, Perm.contentPlanEdit,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksExport, Perm.organizerDirectory,
    Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.filesUpload, Perm.filesDelete,
    Perm.storiesView, Perm.timeTrackerView, Perm.notesUse, Perm.aiChat,
    Perm.devTrackerView,
  },
  'videographer': {
    Perm.dashboard, Perm.projectsView, Perm.boardView, Perm.contentPlanEdit,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksExport, Perm.organizerDirectory,
    Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.filesUpload, Perm.filesDelete,
    Perm.storiesView, Perm.timeTrackerView, Perm.notesUse, Perm.aiChat,
  },
  'video_editor': {
    Perm.dashboard, Perm.projectsView, Perm.boardView, Perm.contentPlanEdit,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksExport, Perm.organizerDirectory,
    Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.filesUpload, Perm.filesDelete,
    Perm.storiesView, Perm.timeTrackerView, Perm.notesUse, Perm.aiChat,
  },
  'targetologist': {
    Perm.dashboard, Perm.projectsView, Perm.boardView, Perm.contentPlanEdit,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksExport, Perm.organizerDirectory,
    Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.filesUpload, Perm.filesDelete,
    Perm.storiesView, Perm.timeTrackerView, Perm.notesUse, Perm.aiChat,
  },
  'stories_checker': {
    Perm.dashboard, Perm.storiesView,
  },
  'employee': {
    Perm.dashboard, Perm.projectsView, Perm.boardView,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksExport, Perm.organizerDirectory,
    Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.storiesView, Perm.timeTrackerView, Perm.notesUse,
    Perm.aiChat,
  },
};

const Map<String, List<String>> _implies = {
  'projects.create': ['projects.view'],
  'projects.edit': ['projects.view'],
  'clients.create': ['clients.view'],
  'dev-tracker.manage': ['dev-tracker.view'],
};

/// Returns permissions inherent to [role] and [secondaryRole] (plus sub-admin),
/// before personal `extraPermissions` or `deniedPermissions` are applied.
Set<String> rolePermissionsFor({
  required String role,
  String? secondaryRole,
  bool isSubAdmin = false,
}) {
  final result = <String>{
    ...(_permissions[role] ?? const {}),
    if (secondaryRole != null) ...(_permissions[secondaryRole] ?? const {}),
    if (isSubAdmin) ...(_permissions['admin'] ?? const {}),
  };
  return result;
}

List<String> effectivePermissions(UserModel? user) {
  if (user == null) return const [];
  final result = rolePermissionsFor(
    role: user.role,
    secondaryRole: user.secondaryRole,
    isSubAdmin: user.isSubAdmin,
  );
  for (final grant in user.extraPermissions) {
    result.add(grant);
    result.addAll(_implies[grant] ?? const []);
  }
  result.removeAll(user.deniedPermissions);
  return result.toList();
}

bool userCan(UserModel? user, String permission) {
  if (user == null) return false;
  return effectivePermissions(user).contains(permission);
}

bool userCanAny(UserModel? user, List<String> permissions) =>
    permissions.any((permission) => userCan(user, permission));

bool _hasRole(UserModel? user, List<String> allowed) {
  if (user == null) return false;
  return allowed.contains(user.role) ||
      (user.secondaryRole != null && allowed.contains(user.secondaryRole));
}

bool canSeeSmmSection(UserModel? user) => _hasRole(user, const [
      'founder',
      'admin',
      'smm_director',
      'smm_specialist',
      'sales_manager_smm',
      'sales_manager_dev',
    ]);

bool isSmmViewOnly(UserModel? user) {
  if (user == null) return false;
  return (user.role == 'sales_manager_smm' || user.role == 'sales_manager_dev') &&
      !_hasRole(user, const ['founder', 'admin', 'smm_director', 'smm_specialist']);
}

bool isStoryWriter(UserModel? user) => _hasRole(user, const [
      'admin',
      'founder',
      'smm_director',
      'smm_specialist',
    ]);

bool canCheckStories(UserModel? user) {
  if (user == null) return false;
  return _hasRole(user, const ['stories_checker', 'admin', 'founder', 'smm_director']) &&
      userCan(user, Perm.storiesView);
}

bool isDevDirector(UserModel? user) => _hasRole(user, const [
      'founder',
      'admin',
      'dev_director',
    ]);

bool isDevLead(UserModel? user) => _hasRole(user, const [
      'dev_director',
      'pm_dev',
    ]);

bool canSeeDevSection(UserModel? user) {
  if (user == null) return false;
  return _hasRole(user, const [
        'founder',
        'admin',
        'dev_director',
        'pm_dev',
        'developer',
      ]) ||
      userCan(user, Perm.devTrackerView) ||
      userCan(user, Perm.devTrackerManage);
}

bool canManageAccess(UserModel? user) =>
    user != null && _hasRole(user, const ['admin', 'founder']);

bool isSalesManagerRole(UserModel? user) => _hasRole(user, const [
      'sales_manager_smm',
      'sales_manager_dev',
    ]);

bool canSeeProjects(UserModel? user) => userCan(user, Perm.projectsView);

bool canCreateTask(UserModel? user) => userCan(user, Perm.tasksCreate);

bool canCreateProject(UserModel? user) => userCan(user, Perm.projectsCreate);

bool canUseCalendar(UserModel? user) => userCan(user, Perm.calendarView);

bool canUseAi(UserModel? user) => userCan(user, Perm.aiChat);

bool canSeeClients(UserModel? user) => userCan(user, Perm.clientsView);

bool canSeeEmployees(UserModel? user) => userCan(user, Perm.employeesView);

bool canSeeFinance(UserModel? user) => userCan(user, Perm.financeManage);

/// Route guard matching `frontend/src/lib/permissions.ts:canAccessRoute` plus
/// mobile-specific route aliases (`/ai`, `/my-notes`, `/dev/projects`, `/profile`, `/settings`, `/transport`).
bool canAccessRoute(UserModel? user, String rawRoute) {
  if (user == null) return false;
  final route = Uri.parse(rawRoute).path;

  // Stories checker has a restricted workspace: dashboard, stories-check, notifications, profile/settings/more.
  if (user.isStoriesChecker &&
      !_hasRole(user, const ['admin', 'founder', 'smm_director'])) {
    return route == '/' ||
        route == '/more' ||
        route == '/profile' ||
        route == '/settings' ||
        route == '/notifications' ||
        route.startsWith('/stories-check');
  }

  if (route == '/' ||
      route == '/more' ||
      route == '/profile' ||
      route == '/settings' ||
      route == '/notifications' ||
      route == '/transport' ||
      route == '/work-shifts') {
    return true;
  }

  if (route == '/tasks' || route.startsWith('/tasks/')) {
    return userCan(user, Perm.tasksView);
  }
  if (route == '/calendar') return userCan(user, Perm.calendarView);
  if (route == '/archive') return userCan(user, Perm.archiveView);
  if (route == '/notes' || route == '/my-notes') {
    return userCan(user, Perm.notesUse);
  }
  if (route == '/files') return userCan(user, Perm.filesView);
  if (route == '/time-tracker') return userCan(user, Perm.timeTrackerView);
  if (route == '/ai-assistant' || route == '/ai') {
    return userCan(user, Perm.aiChat);
  }
  if (route == '/analytics') return userCan(user, Perm.analyticsView);
  if (route == '/reports') return userCan(user, Perm.reportsView);
  if (route == '/risks') return userCan(user, Perm.risksView);
  if (route == '/tariffs') return userCan(user, Perm.tariffsManage);
  if (route == '/security-log') return userCan(user, Perm.securityLogView);
  if (route.startsWith('/stories-check')) return canCheckStories(user);
  if (route == '/smm/control') return canSeeSmmSection(user);

  if (route == '/employee-access') return canManageAccess(user);

  // Strict founder/admin subpages
  if (route == '/employees/sales-plan') {
    return _hasRole(user, const ['founder']);
  }
  if (route == '/employees/kpi' ||
      route == '/employees/week' ||
      route == '/employees/activity' ||
      route == '/team-activity') {
    return _hasRole(user, const ['founder', 'admin']);
  }
  if (route.startsWith('/employees')) {
    return userCan(user, Perm.employeesView);
  }

  if (route.startsWith('/projects')) {
    return userCan(user, Perm.projectsView);
  }

  if (route == '/onboarding') {
    return isSalesManagerRole(user) && userCan(user, Perm.clientsView);
  }
  if (route.startsWith('/clients')) {
    return userCan(user, Perm.clientsView);
  }

  if (route.startsWith('/finance')) {
    return userCan(user, Perm.financeManage);
  }

  if (route == '/dev-board/reports') {
    return isDevDirector(user) ||
        isDevLead(user) ||
        userCan(user, Perm.devTrackerManage);
  }
  if (route.startsWith('/dev-board') || route.startsWith('/dev/projects')) {
    return canSeeDevSection(user);
  }

  return true;
}
