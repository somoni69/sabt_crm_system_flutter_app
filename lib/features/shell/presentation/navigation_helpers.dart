import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/app_state.dart';

/// Asks the shell to switch to one of its tabs (`home`, `tasks`, `work`,
/// `checks`, `more`) from any pushed screen or dashboard widget.
void openShellTab(WidgetRef ref, String id) {
  ref.read(navigationServiceProvider).requestedSection.value = id;
}
