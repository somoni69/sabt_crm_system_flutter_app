import '../../features/auth/domain/user.dart';

/// Mirror of the web permission matrix and backend grants. The server is the
/// source of truth; this layer only hides controls the user cannot use and
/// shows the right tabs for their role.
abstract final class Perm {
  static const dashboard = 'dashboard';
  static const tasksView = 'tasks.view';
  static const tasksCreate = 'tasks.create';
  static const tasksEdit = 'tasks.edit';
  static const tasksDelete = 'tasks.delete';
  static const tasksApprove = 'tasks.approve';
  static const tasksReturn = 'tasks.return';
  static const tasksBulk = 'tasks.bulk';
  static const calendarView = 'calendar.view';
  static const calendarCreate = 'calendar.create';
  static const projectsView = 'projects.view';
  static const projectsCreate = 'projects.create';
  static const projectsEdit = 'projects.edit';
  static const clientsView = 'clients.view';
  static const clientsCreate = 'clients.create';
  static const clientsEdit = 'clients.edit';
  static const clientsDelete = 'clients.delete';
  static const employeesView = 'employees.view';
  static const analyticsView = 'analytics.view';
  static const reportsView = 'reports.view';
  static const reportsCreate = 'reports.create';
  static const storiesManage = 'stories.manage';
  static const storiesView = 'stories.view';
  static const aiChat = 'ai.chat';
  static const financeManage = 'finance.manage';
  static const tariffsManage = 'tariffs.manage';
  static const devTrackerView = 'dev-tracker.view';
  static const devTrackerManage = 'dev-tracker.manage';
  static const notesUse = 'notes.use';
  static const filesView = 'files.view';
  static const filesUpload = 'files.upload';
  static const timeTrackerView = 'time-tracker.use';
  static const securityLogView = 'security-log.view';
  static const archiveView = 'archive.view';
  static const risksView = 'risks.view';
}

const Map<String, Set<String>> _permissions = {
  'admin': {
    Perm.dashboard, Perm.projectsView, Perm.projectsCreate, Perm.projectsEdit,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksApprove, Perm.tasksReturn, Perm.tasksBulk,
    Perm.employeesView, Perm.analyticsView, Perm.reportsView, Perm.reportsCreate,
    Perm.archiveView, Perm.filesView, Perm.filesUpload, Perm.storiesManage,
    Perm.storiesView, Perm.timeTrackerView, Perm.notesUse, Perm.tariffsManage,
    Perm.risksView, Perm.clientsView, Perm.clientsCreate, Perm.clientsEdit,
    Perm.clientsDelete, Perm.securityLogView, Perm.aiChat,
    Perm.devTrackerView, Perm.devTrackerManage,
  },
  'founder': {
    Perm.dashboard, Perm.projectsView, Perm.projectsCreate, Perm.projectsEdit,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksApprove, Perm.tasksReturn, Perm.tasksBulk, Perm.employeesView,
    Perm.analyticsView, Perm.reportsView, Perm.reportsCreate, Perm.archiveView,
    Perm.filesView, Perm.filesUpload, Perm.storiesManage, Perm.storiesView,
    Perm.timeTrackerView, Perm.notesUse, Perm.tariffsManage, Perm.risksView,
    Perm.financeManage, Perm.clientsView, Perm.clientsCreate, Perm.clientsEdit,
    Perm.clientsDelete, Perm.securityLogView, Perm.aiChat,
    Perm.devTrackerView, Perm.devTrackerManage,
  },
  'smm_director': {
    Perm.dashboard, Perm.projectsView, Perm.projectsCreate, Perm.projectsEdit,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksApprove, Perm.tasksReturn, Perm.tasksBulk, Perm.employeesView,
    Perm.analyticsView, Perm.reportsView, Perm.reportsCreate, Perm.archiveView,
    Perm.filesView, Perm.filesUpload, Perm.storiesManage, Perm.storiesView,
    Perm.timeTrackerView, Perm.notesUse, Perm.aiChat, Perm.tariffsManage,
    Perm.risksView,
  },
  'smm_specialist': {
    Perm.dashboard, Perm.projectsView, Perm.projectsCreate, Perm.tasksView,
    Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete, Perm.reportsView,
    Perm.reportsCreate, Perm.filesView, Perm.filesUpload, Perm.storiesManage,
    Perm.storiesView, Perm.timeTrackerView, Perm.notesUse, Perm.aiChat,
  },
  'designer': {
    Perm.dashboard, Perm.projectsView, Perm.tasksView, Perm.tasksCreate,
    Perm.tasksEdit, Perm.tasksDelete, Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.filesUpload, Perm.timeTrackerView, Perm.notesUse,
    Perm.aiChat,
  },
  'sales_manager_smm': {
    Perm.dashboard, Perm.projectsView, Perm.projectsEdit, Perm.tasksView,
    Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete, Perm.calendarView,
    Perm.calendarCreate, Perm.archiveView, Perm.analyticsView, Perm.reportsView,
    Perm.reportsCreate, Perm.filesView, Perm.filesUpload, Perm.timeTrackerView,
    Perm.notesUse, Perm.aiChat, Perm.clientsView, Perm.clientsCreate,
    Perm.clientsEdit, Perm.clientsDelete,
  },
  'sales_manager_dev': {
    Perm.dashboard, Perm.projectsView, Perm.tasksView, Perm.tasksCreate,
    Perm.tasksEdit, Perm.tasksDelete, Perm.calendarView, Perm.calendarCreate,
    Perm.archiveView, Perm.analyticsView, Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.filesUpload, Perm.timeTrackerView, Perm.notesUse,
    Perm.aiChat, Perm.clientsView,
  },
  'dev_director': {
    Perm.dashboard, Perm.projectsView, Perm.projectsCreate, Perm.projectsEdit,
    Perm.tasksView, Perm.tasksCreate, Perm.tasksEdit, Perm.tasksDelete,
    Perm.tasksApprove, Perm.tasksReturn, Perm.tasksBulk, Perm.employeesView,
    Perm.analyticsView, Perm.risksView, Perm.reportsView, Perm.reportsCreate,
    Perm.archiveView, Perm.filesView, Perm.filesUpload, Perm.timeTrackerView,
    Perm.notesUse, Perm.aiChat, Perm.devTrackerView, Perm.devTrackerManage,
  },
  'pm_dev': {
    Perm.dashboard, Perm.projectsView, Perm.tasksView, Perm.tasksCreate,
    Perm.tasksEdit, Perm.tasksDelete, Perm.analyticsView, Perm.reportsView,
    Perm.reportsCreate, Perm.filesView, Perm.filesUpload, Perm.timeTrackerView,
    Perm.notesUse, Perm.aiChat, Perm.devTrackerView, Perm.devTrackerManage,
  },
  'developer': {
    Perm.dashboard, Perm.projectsView, Perm.tasksView, Perm.tasksCreate,
    Perm.tasksEdit, Perm.tasksDelete, Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.filesUpload, Perm.timeTrackerView, Perm.notesUse,
    Perm.aiChat, Perm.devTrackerView,
  },
  'videographer': {
    Perm.dashboard, Perm.projectsView, Perm.tasksView, Perm.tasksCreate,
    Perm.tasksEdit, Perm.tasksDelete, Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.filesUpload, Perm.timeTrackerView, Perm.notesUse,
    Perm.aiChat,
  },
  'video_editor': {
    Perm.dashboard, Perm.projectsView, Perm.tasksView, Perm.tasksCreate,
    Perm.tasksEdit, Perm.tasksDelete, Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.filesUpload, Perm.timeTrackerView, Perm.notesUse,
    Perm.aiChat,
  },
  'targetologist': {
    Perm.dashboard, Perm.projectsView, Perm.tasksView, Perm.tasksCreate,
    Perm.tasksEdit, Perm.tasksDelete, Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.filesUpload, Perm.timeTrackerView, Perm.notesUse,
    Perm.aiChat,
  },
  'stories_checker': {
    Perm.dashboard, Perm.storiesView,
  },
  'employee': {
    Perm.dashboard, Perm.projectsView, Perm.tasksView, Perm.tasksCreate,
    Perm.tasksEdit, Perm.tasksDelete, Perm.reportsView, Perm.reportsCreate,
    Perm.filesView, Perm.timeTrackerView, Perm.notesUse, Perm.aiChat,
  },
};

const Map<String, List<String>> _implies = {
  'projects.create': ['projects.view'],
  'projects.edit': ['projects.view'],
  'clients.create': ['clients.view'],
  'dev-tracker.manage': ['dev-tracker.view'],
};

List<String> effectivePermissions(UserModel? user) {
  if (user == null) return const [];
  final result = <String>{};
  result.addAll(_permissions[user.role] ?? const {});
  if (user.secondaryRole != null) {
    result.addAll(_permissions[user.secondaryRole!] ?? const {});
  }
  for (final grant in user.extraPermissions) {
    result.add(grant);
    result.addAll(_implies[grant] ?? const []);
  }
  if (user.isSubAdmin) {
    result.addAll(_permissions['admin'] ?? const {});
  }
  result.removeAll(user.deniedPermissions);
  // A denied permission also removes implied parents? The web only checks the
  // requested key against denied; implications stay as additive grants.
  return result.toList();
}

bool userCan(UserModel? user, String permission) {
  if (user == null) return false;
  return effectivePermissions(user).contains(permission);
}

bool userCanAny(UserModel? user, List<String> permissions) =>
    permissions.any((permission) => userCan(user, permission));

bool canSeeSmmSection(UserModel? user) {
  if (user == null) return false;
  return ['founder', 'admin', 'smm_director', 'smm_specialist', 'sales_manager_smm', 'sales_manager_dev']
      .contains(user.role);
}

bool isSmmViewOnly(UserModel? user) {
  if (user == null) return false;
  return user.role == 'sales_manager_smm' || user.role == 'sales_manager_dev';
}

bool isStoryWriter(UserModel? user) {
  if (user == null) return false;
  final roles = [user.role, user.secondaryRole];
  return roles.any((role) => ['admin', 'founder', 'smm_director', 'smm_specialist'].contains(role));
}

bool canCheckStories(UserModel? user) {
  if (user == null) return false;
  final roles = [user.role, user.secondaryRole];
  return roles.any((role) => ['stories_checker', 'admin', 'founder', 'smm_director'].contains(role)) &&
      userCan(user, Perm.storiesView);
}

bool canSeeDevSection(UserModel? user) {
  if (user == null) return false;
  return ['founder', 'admin', 'dev_director', 'pm_dev', 'developer'].contains(user.role);
}

bool isDevLead(UserModel? user) {
  if (user == null) return false;
  return [user.role, user.secondaryRole]
      .any((role) => role == 'dev_director' || role == 'pm_dev');
}

bool canManageAccess(UserModel? user) =>
    user != null && (user.role == 'admin' || user.role == 'founder');

bool canSeeProjects(UserModel? user) => userCan(user, Perm.projectsView);

bool canCreateTask(UserModel? user) => userCan(user, Perm.tasksCreate);

bool canCreateProject(UserModel? user) => userCan(user, Perm.projectsCreate);

bool canUseCalendar(UserModel? user) => userCan(user, Perm.calendarView);

bool canUseAi(UserModel? user) => userCan(user, Perm.aiChat);

bool canSeeClients(UserModel? user) => userCan(user, Perm.clientsView);

bool canSeeEmployees(UserModel? user) => userCan(user, Perm.employeesView);

bool canSeeFinance(UserModel? user) => userCan(user, Perm.financeManage);
