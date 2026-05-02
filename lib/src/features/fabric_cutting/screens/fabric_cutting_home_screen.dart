import 'package:flutter/material.dart';

import 'fabric_cutting_screen.dart';
import 'roll_fabric_optimizer_screen.dart';

enum _FabricToolTab {
  product,
  roll,
}

class FabricCuttingHomeScreen extends StatefulWidget {
  const FabricCuttingHomeScreen({super.key});

  @override
  State<FabricCuttingHomeScreen> createState() =>
      _FabricCuttingHomeScreenState();
}

class _FabricCuttingHomeScreenState extends State<FabricCuttingHomeScreen> {
  var _selected = _FabricToolTab.product;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final textTheme = base.textTheme;
    final localTheme = base.copyWith(
      textTheme: textTheme.copyWith(
        bodySmall: textTheme.bodySmall?.copyWith(fontSize: 13.5),
        bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 15.5),
        bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 16.5),
        titleSmall: textTheme.titleSmall?.copyWith(fontSize: 17),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        isDense: false,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: const OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(fontSize: 15.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          textStyle: const TextStyle(fontSize: 15.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 42),
          textStyle: const TextStyle(fontSize: 15),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ),
    );

    return Theme(
      data: localTheme,
      child: Scaffold(
        appBar: AppBar(title: const Text('배색 원단 재단')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<_FabricToolTab>(
                  segments: const [
                    ButtonSegment(
                      value: _FabricToolTab.product,
                      icon: Icon(Icons.view_quilt_outlined),
                      label: Text('제품 배색'),
                    ),
                    ButtonSegment(
                      value: _FabricToolTab.roll,
                      icon: Icon(Icons.auto_awesome_motion_outlined),
                      label: Text('롤 최적화'),
                    ),
                  ],
                  selected: {_selected},
                  onSelectionChanged: (values) {
                    setState(() => _selected = values.first);
                  },
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selected.index,
                children: const [
                  FabricCuttingScreen(showAppBar: false),
                  RollFabricOptimizerScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
