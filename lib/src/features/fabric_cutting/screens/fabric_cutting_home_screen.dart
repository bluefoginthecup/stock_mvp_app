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
    return Scaffold(
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
    );
  }
}
