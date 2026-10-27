import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabt_crm/core/design/motion.dart';
import 'package:sabt_crm/core/widgets/app_controls.dart';
import 'package:sabt_crm/core/widgets/app_page.dart';
import 'package:sabt_crm/core/widgets/app_surfaces.dart';

void main() {
  test('durations and curves stay on the entrance ladder', () {
    expect(Motion.press.inMilliseconds, lessThanOrEqualTo(120));
    expect(Motion.micro.inMilliseconds, lessThanOrEqualTo(120));
    expect(Motion.standard.inMilliseconds, inInclusiveRange(150, 250));
    expect(Motion.sheet.inMilliseconds, inInclusiveRange(150, 250));
    expect(Motion.exit.inMilliseconds, lessThanOrEqualTo(250));
    expect(Motion.enterScale, inInclusiveRange(0.95, 0.98));
    expect(Motion.pressScale, inInclusiveRange(0.95, 0.99));
    expect(Motion.easeOut.transform(0), 0);
    expect(Motion.easeOut.transform(1), 1);
    expect(Motion.easeOut.transform(0.25), greaterThan(0.25));
    expect(Motion.drawer.transform(0.25), greaterThan(0.25));
    expect(Motion.easeInOut.transform(0), 0);
    expect(Motion.easeInOut.transform(1), 1);
  });

  testWidgets('an appearance fades in and then drops its ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MotionAppear(child: Text('Пусто'))),
    );

    expect(find.text('Пусто'), findsOneWidget);
    expect(_appearOpacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.byType(Opacity), findsNothing);
    expect(find.text('Пусто'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion paints the child on the first frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MotionAppear(child: Text('Сразу')),
        ),
      ),
    );

    expect(find.text('Сразу'), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a route transition is fade and slide', (tester) async {
    final controller = AnimationController(
      vsync: tester,
      duration: Motion.standard,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MotionPageTransition(
          animation: controller,
          child: const Text('Экран'),
        ),
      ),
    );

    final transition = find.byType(MotionPageTransition);
    expect(
      find.descendant(of: transition, matching: find.byType(FadeTransition)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: transition, matching: find.byType(SlideTransition)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: transition, matching: find.byType(ScaleTransition)),
      findsNothing,
    );

    controller.value = 1;
    await tester.pump();
    expect(find.text('Экран'), findsOneWidget);
  });

  testWidgets('segment thumb moves with a transform', (tester) async {
    var value = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return GlassSegmentedControl<int>(
                selected: value,
                onChanged: (next) => setState(() => value = next),
                items: const [
                  SegmentItem(value: 0, label: 'Мои'),
                  SegmentItem(value: 1, label: 'Выданные'),
                ],
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(AnimatedPositioned), findsNothing);
    expect(find.byType(AnimatedSlide), findsOneWidget);

    await tester.tap(find.text('Выданные'));
    await tester.pump();
    expect(value, 1);
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a glass sheet slides without a backdrop blur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showGlassSheet<void>(
                  context: context,
                  title: 'Быстрое действие',
                  child: const Text('Тело листа'),
                );
              },
              child: const Text('Открыть'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();

    expect(find.text('Тело листа'), findsOneWidget);
    expect(find.text('Быстрое действие'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('a skeleton stays still when motion is reduced', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: SkeletonBox(width: 40, height: 12),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

double _appearOpacity(WidgetTester tester) {
  return tester
      .widget<Opacity>(
        find.descendant(
          of: find.byType(MotionAppear),
          matching: find.byType(Opacity),
        ),
      )
      .opacity;
}
