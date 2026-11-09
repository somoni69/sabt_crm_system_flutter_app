import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabt_crm/core/design/liquid_glass_bar.dart';

const _items = [
  GlassNavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Главная',
  ),
  GlassNavItem(
    icon: Icons.checklist_outlined,
    activeIcon: Icons.checklist_rounded,
    label: 'Задачи',
  ),
  GlassNavItem(
    icon: Icons.more_horiz_rounded,
    activeIcon: Icons.more_rounded,
    label: 'Ещё',
  ),
];

void main() {
  group('nav lens geometry', () {
    test('width tracks the tab and survives a narrow capsule', () {
      expect(navLensWidth(tabWidth: 100, lift: 0), 90);
      expect(navLensWidth(tabWidth: 100, lift: 1), 96);
      expect(navLensHeight(0), 50);
      expect(navLensHeight(1), 54);
      expect(navLensWidth(tabWidth: 20, lift: 0), 40);
      expect(navLensWidth(tabWidth: 20, lift: 1), 40);
    });

    test(
      'resistNavPosition is linear inside the tabs and stops at the edge',
      () {
        expect(resistNavPosition(1.2, 4), 1.2);
        expect(resistNavPosition(0, 4), 0);
        expect(resistNavPosition(3, 4), 3);
        expect(resistNavPosition(-0.1, 4), closeTo(-0.0166667, 0.0001));
        expect(resistNavPosition(-10, 4), -navEdgeOverscroll);
        expect(resistNavPosition(13, 4), 3 + navEdgeOverscroll);
        expect(resistNavPosition(4, 0), 0);
      },
    );

    test('settleNavIndex follows a flick and stays inside the bar', () {
      expect(settleNavIndex(position: 1.2, velocityTabs: 0, itemCount: 4), 1);
      expect(settleNavIndex(position: 1.4, velocityTabs: 2, itemCount: 4), 2);
      expect(settleNavIndex(position: 1.4, velocityTabs: -2, itemCount: 4), 1);
      expect(settleNavIndex(position: 0.2, velocityTabs: -5, itemCount: 4), 0);
      expect(settleNavIndex(position: 2.2, velocityTabs: 0.5, itemCount: 4), 2);
      expect(settleNavIndex(position: 5.4, velocityTabs: 8, itemCount: 4), 3);
      expect(settleNavIndex(position: -1.2, velocityTabs: -4, itemCount: 4), 0);
      expect(settleNavIndex(position: 1, velocityTabs: 0, itemCount: 0), 0);
    });

    test('navFlingVelocity caps the spring without dropping the sign', () {
      expect(navFlingVelocity(0, 100), 0);
      expect(navFlingVelocity(100, 0), 0);
      expect(navFlingVelocity(100, 100), 1);
      expect(navFlingVelocity(350, 100), 3.5);
      expect(navFlingVelocity(-800, 100), -3.5);
    });
  });

  group('LiquidGlassNavBar', () {
    testWidgets('shows tabs, selects on tap, and idles', (tester) async {
      await tester.pumpWidget(const _Host());
      expect(find.text('Главная'), findsOneWidget);
      expect(find.text('Задачи'), findsOneWidget);
      expect(find.text('Ещё'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LiquidGlassNavBar),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );

      await tester.tap(find.text('Задачи'));
      await _settle(tester);

      final host = _host(tester);
      expect(host.index, 1);
      expect(host.selections, 1);
      expect(_lensLeft(tester), closeTo(_lensLeftFor(tester, 1), 1.5));
    });

    testWidgets('reduced motion snaps the lens on the next frame', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host(reduceMotion: true));
      await tester.tap(find.text('Ещё'));
      await tester.pump(const Duration(milliseconds: 16));

      expect(_host(tester).index, 2);
      expect(_lensLeft(tester), closeTo(_lensLeftFor(tester, 2), 0.5));
    });

    testWidgets('a normal tap has not finished the spring after one frame', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host());
      await tester.tap(find.text('Ещё'));
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        (_lensLeft(tester) - _lensLeftFor(tester, 2)).abs(),
        greaterThan(30),
      );
    });

    testWidgets('a tap settles inside 160ms', (tester) async {
      await tester.pumpWidget(const _Host());
      await tester.tap(find.text('Ещё'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));

      expect(_host(tester).index, 2);
      expect(_lensLeft(tester), closeTo(_lensLeftFor(tester, 2), 1.5));
    });

    testWidgets('keyboard inset hides the bar from taps', (tester) async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(const _Host());
      await tester.tap(find.text('Задачи'), warnIfMissed: false);
      await tester.pump();
      expect(_host(tester).index, 0);
      expect(_host(tester).selections, 0);
    });

    testWidgets('high contrast keeps the labels and skips backdrop blur', (
      tester,
    ) async {
      await tester.pumpWidget(const _Host(highContrast: true));
      expect(find.text('Главная'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LiquidGlassNavBar),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
      await tester.tap(find.text('Ещё'));
      await tester.pump();
      expect(_host(tester).index, 2);
    });

    testWidgets('tabs expose selected button semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const _Host());
      expect(
        tester.getSemantics(find.bySemanticsLabel('Главная')),
        isSemantics(isButton: true, isSelected: true, label: 'Главная'),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Задачи')),
        isSemantics(isButton: true, isSelected: false, label: 'Задачи'),
      );
      expect(find.byIcon(Icons.add_rounded), findsNothing);
      handle.dispose();
    });

    testWidgets('an external selection still moves the lens', (tester) async {
      await tester.pumpWidget(const _Host());
      _host(tester).go(2);
      await _settle(tester);
      expect(_host(tester).index, 2);
      expect(_lensLeft(tester), closeTo(_lensLeftFor(tester, 2), 1.5));
    });
  });
}

Future<void> _settle(WidgetTester tester) {
  return tester.pumpAndSettle(
    const Duration(milliseconds: 20),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 3),
  );
}

class _Host extends StatefulWidget {
  const _Host({this.reduceMotion = false, this.highContrast = false});

  final bool reduceMotion;
  final bool highContrast;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int index = 0;
  int selections = 0;

  void go(int value) => setState(() => index = value);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          final media = MediaQuery.of(context).copyWith(
            disableAnimations: widget.reduceMotion,
            highContrast: widget.highContrast,
          );
          return MediaQuery(
            data: media,
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: LiquidGlassNavBar(
                  items: _items,
                  selectedIndex: index,
                  onSelected: (value) => setState(() {
                    index = value;
                    selections += 1;
                  }),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

_HostState _host(WidgetTester tester) =>
    tester.state<_HostState>(find.byType(_Host));

double _lensLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(LiquidGlassNavBar.lensKey)).dx;

Rect _capsule(WidgetTester tester) =>
    tester.getRect(find.byKey(LiquidGlassNavBar.capsuleKey));

double _lensLeftFor(WidgetTester tester, int index) {
  final capsule = _capsule(tester);
  final tab = capsule.width / _items.length;
  final width = navLensWidth(tabWidth: tab, lift: 0);
  return capsule.left + (index + 0.5) * tab - width / 2;
}
