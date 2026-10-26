import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/snapshot.dart';
import '../../../core/dependencies.dart';
import '../../../core/state/app_state.dart';
import '../../../core/utils/json_utils.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/employee.dart';

final employeesProvider = StreamProvider.autoDispose<Snapshot<List<EmployeeModel>>>(
  (ref) {
    ref.watch(dataRevisionProvider);
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return Stream.value(const Snapshot<List<EmployeeModel>>(data: []));
    }
    final deps = ref.watch(dependenciesProvider);
    return deps.cachedJson
        .watch(
          userId: user.id,
          key: 'employees.all',
          path: '/employees',
        )
        .map((payload) => Snapshot.fromPayload(
              payload,
              (raw) => asList(raw)
                  .map(asMap)
                  .whereType<Map<String, dynamic>>()
                  .map(EmployeeModel.fromJson)
                  .where((employee) => employee.id.isNotEmpty)
                  .toList(),
            ));
  },
);

final employeeProvider =
    StreamProvider.autoDispose.family<Snapshot<EmployeeModel>, String>((ref, id) {
  ref.watch(dataRevisionProvider);
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.error(StateError('Не авторизован'));
  final deps = ref.watch(dependenciesProvider);
  return deps.cachedJson
      .watch(
        userId: user.id,
        key: 'employee.$id',
        path: '/employees/$id',
      )
      .map((payload) => Snapshot.fromPayload(
            payload,
            (raw) => EmployeeModel.fromJson(asMap(raw) ?? const {}),
          ));
});

final assignableEmployeesProvider = Provider.autoDispose<List<EmployeeModel>>((ref) {
  final employees = ref.watch(employeesProvider).value?.data ?? const <EmployeeModel>[];
  final active = employees.where((employee) => employee.isActive).toList()
    ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
  return active;
});
