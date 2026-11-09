import 'dart:math' as math;

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
    // Route pushes are occasional and spatial: up to 300ms, and the pop
    // is never slower than the push.
    expect(Motion.page.inMilliseconds, lessThanOrEqualTo(300));
    expect(
      Motion.pageExit.inMilliseconds,
      lessThan(Motion.page.inMilliseconds),
    );
    // The nav spring is underdamped, like UIKit's: one soft overshoot.
    final ratio =
        Motion.springSnap.damping /
        (2 * math.sqrt(Motion.springSnap.mass * Motion.springSnap.stiffness));
    expect(ratio, inInclusiveRange(0.5, 0.9));
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

    // The wrapper stays mounted (state inside must survive settling),
    // but it renders at full opacity and no ticker is scheduled.
    expect(_appearOpacity(tester), 1);
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

  testWidgets('a route transition slides like the iOS push', (tester) async {
    final controller = AnimationController(
      vsync: tester,
      duration: Motion.page,
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
      find.descendant(of: transition, matching: find.byType(SlideTransition)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: transition, matching: find.byType(ScaleTransition)),
      findsNothing,
    );

    // Starts fully off-screen to the right, lands at rest.
    final slide = tester.widget<SlideTransition>(
      find.descendant(of: transition, matching: find.byType(SlideTransition)),
    );
    expect(slide.position.value, const Offset(0.06, 0));
    controller.value = 1;
    await tester.pump();
    expect(slide.position.value, Offset.zero);
    expect(find.text('Экран'), findsOneWidget);
  });

  testWidgets('the covered page parallaxes under the incoming one', (
    tester,
  ) async {
    final primary = AnimationController(
      vsync: tester,
      duration: Motion.page,
      value: 1,
    );
    final secondary = AnimationController(
      vsync: tester,
      duration: Motion.page,
      value: 0,
    );
    addTearDown(primary.dispose);
    addTearDown(secondary.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MotionPageTransition(
          animation: primary,
          secondaryAnimation: secondary,
          child: const Text('Фон'),
        ),
      ),
    );

    secondary.value = 1;
    await tester.pump();

    final transform = tester.widget<Transform>(
      find
          .ancestor(of: find.text('Фон'), matching: find.byType(Transform))
          .first,
    );
    // A quarter of an 800-wide test surface to the left.
    expect(transform.transform.getTranslation().x, -200);
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
