import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webrand_app/core/theme/app_palette.dart';
import 'package:webrand_app/core/theme/app_theme.dart';
import 'package:webrand_app/core/theme/app_typography.dart';
import 'package:webrand_app/core/widgets/app_controls.dart';
import 'package:webrand_app/core/widgets/app_form.dart';
import 'package:webrand_app/core/widgets/app_surfaces.dart';

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('hero standard', () {
    test('hero gradient moves with the theme (not always black)', () {
      expect(AppPalette.light.isDark, isFalse);
      for (final stop in AppPalette.light.heroGradient.colors) {
        expect(
          stop.computeLuminance(),
          greaterThan(0.7),
          reason: 'light hero stop $stop must stay light',
        );
      }
      for (final stop in AppPalette.dark.heroGradient.colors) {
        expect(
          stop.computeLuminance(),
          lessThan(0.05),
          reason: 'dark hero stop $stop must stay dark',
        );
      }
    });

    test('hero text contrasts >= 7:1 on every hero stop in both themes', () {
      for (final palette in [AppPalette.light, AppPalette.dark]) {
        for (final stop in palette.heroGradient.colors) {
          expect(
            _contrast(palette.text, stop),
            greaterThan(7),
            reason: 'text on $stop (${palette.brightness})',
          );
          expect(
            _contrast(palette.textSecondary, stop),
            greaterThan(4.5),
            reason: 'secondary on $stop (${palette.brightness})',
          );
        }
      }
    });

    testWidgets('AppHeroCard paints the palette hero gradient', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: AppHeroCard(
                child: Builder(
                  builder: (context) => Text(
                    'Miz',
                    style: TextStyle(color: context.palette.text),
                  ),
                ),
              ),
            ),
          ),
        );
        // Theme changes lerp the palette extension.
        await tester.pump(const Duration(milliseconds: 300));
        final container = tester.widget<Container>(
          find
              .ancestor(of: find.text('Miz'), matching: find.byType(Container))
              .first,
        );
        final decoration = container.decoration! as BoxDecoration;
        final expected = theme.extension<AppPalette>()!;
        expect(decoration.gradient, expected.heroGradient);
        expect(decoration.border?.top.color, expected.heroBorder);
        expect(find.text('Miz'), findsOneWidget);
      }
    });
  });

  group('control standard', () {
    test('selected colour is the web steel primary', () {
      expect(AppPalette.light.controlSelected, const Color(0xFF1E4263));
      expect(AppPalette.dark.controlSelected, const Color(0xFF6E96BE));
      expect(
        AppPalette.light.primaryGradient.colors,
        contains(const Color(0xFF1E4263)),
      );
    });

    testWidgets(
      'AppFilterChip selected is solid brand, unselected is surface',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Row(
                children: [
                  AppFilterChip(label: 'Все', active: true, onTap: () {}),
                  AppFilterChip(label: 'Новые', active: false, onTap: () {}),
                ],
              ),
            ),
          ),
        );
        final containers = tester
            .widgetList<Container>(
              find.ancestor(
                of: find.byType(Text),
                matching: find.byType(Container),
              ),
            )
            .where((c) => c.decoration is BoxDecoration)
            .toList();
        final selected = containers.firstWhere(
          (c) =>
              (c.decoration! as BoxDecoration).color == const Color(0xFF1E4263),
        );
        expect(selected, isNotNull);
        final allText = tester.widgetList<Text>(find.byType(Text)).toList();
        expect(
          allText.firstWhere((t) => t.data == 'Все').style!.color,
          Colors.white,
        );
      },
    );

    testWidgets(
      'AppChoiceChips selected is brand regardless of option colour',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: AppChoiceChips<String>(
                selected: 'medium',
                onChanged: (_) {},
                options: [
                  AppChoice(
                    value: 'low',
                    label: 'Низкий',
                    color: AppPalette.light.info,
                  ),
                  AppChoice(
                    value: 'medium',
                    label: 'Средний',
                    color: AppPalette.light.info,
                  ),
                  AppChoice(
                    value: 'critical',
                    label: 'Критичный',
                    color: AppPalette.light.danger,
                  ),
                ],
              ),
            ),
          ),
        );
        final animated = tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .toList();
        final selected = animated.where((c) {
          final d = c.decoration! as BoxDecoration;
          return d.color == const Color(0xFF1E4263);
        }).toList();
        expect(
          selected,
          hasLength(1),
          reason: 'exactly one segment uses the shared selected colour',
        );
        expect(find.text('Критичный'), findsOneWidget);
      },
    );

    testWidgets('GlassSegmentedControl selected thumb is the brand colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: GlassSegmentedControl<String>(
              items: const [
                SegmentItem(value: 'a', label: 'Мои'),
                SegmentItem(value: 'b', label: 'Команда'),
              ],
              selected: 'a',
              onChanged: (_) {},
            ),
          ),
        ),
      );
      final boxes = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where(
            (b) =>
                (b.decoration as BoxDecoration).color ==
                const Color(0xFF1E4263),
          )
          .toList();
      expect(boxes, hasLength(1));
    });

    testWidgets('AppIconButton is visible on a light header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.add_task_rounded,
              filled: true,
              onPressed: () {},
            ),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.add_task_rounded),
              matching: find.byType(Container),
            )
            .first,
      );
      final bg = (container.decoration! as BoxDecoration).color!;
      expect(_contrast(AppPalette.light.text, bg), greaterThan(4.5));
      expect(bg, isNot(Colors.white));
    });
  });

  group('typography guard', () {
    test('no hero needs a pinned dark scope', () {
      // The regression was dark text computed in the parent build on a
      // black hero. With a theme-following hero the ambient palette is
      // always the right one; assert the two palettes never share a
      // hero lightness.
      expect(
        AppPalette.light.heroGradient.colors.first.computeLuminance(),
        greaterThan(
          AppPalette.dark.heroGradient.colors.first.computeLuminance(),
        ),
      );
      expect(AppTypography.family, isNotEmpty);
    });
  });
}
