import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webrand_app/core/theme/app_theme.dart';
import 'package:webrand_app/core/widgets/app_form.dart';

void main() {
  testWidgets('AppSelectField expands inline, selects, and collapses', (
    tester,
  ) async {
    String? value = 'samad';
    String? picked;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: AppSelectField<String>(
                  value: value,
                  items: const ['none', 'samad', 'payk'],
                  icon: Icons.folder_outlined,
                  labelOf: (id) => switch (id) {
                    'none' => 'Без проекта',
                    'samad' => 'Samad',
                    _ => 'Payk',
                  },
                  onChanged: (next) {
                    picked = next;
                    setState(() => value = next);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // Collapsed: only the current selection is visible.
    expect(find.text('Samad'), findsOneWidget);
    expect(find.text('Payk'), findsNothing);
    expect(find.byType(Expansible), findsOneWidget);

    // Expand inline.
    await tester.tap(find.text('Samad'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Без проекта'), findsOneWidget);
    expect(find.text('Payk'), findsOneWidget);

    // Pick another option: it propagates and the list collapses.
    await tester.tap(find.text('Payk'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(picked, 'payk');
    expect(find.text('Payk'), findsOneWidget); // header shows it
    expect(find.text('Без проекта'), findsNothing); // body is gone

    // Re-expand and re-pick the same value: still collapses cleanly.
    await tester.tap(find.text('Payk'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Samad'), findsWidgets);
  });

  testWidgets('AppSelectField renders instantly under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: AppSelectField<String>(
                value: null,
                items: ['a', 'b'],
                labelOf: _label,
                onChanged: _noop,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Выберите'), findsOneWidget);

    await tester.tap(find.text('Выберите'));
    await tester.pump();
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}

String _label(String value) => value.toUpperCase();
void _noop(String? _) {}
