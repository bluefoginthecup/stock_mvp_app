import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/main_tab_controller.dart';
import '../../services/entitlement_service.dart';

class FantasyDashboardConfig {
  static const enabled = true;

  // Turn this on when the screen becomes a paid add-on.
  static const entitlementGateEnabled = false;

  static const assetPath =
      'assets/images/experiments/fantasy_dashboard/workshop_dashboard.png';
}

class FantasyDashboardScreen extends StatelessWidget {
  const FantasyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!FantasyDashboardConfig.enabled) {
      return const _FantasyDashboardUnavailable();
    }

    if (!FantasyDashboardConfig.entitlementGateEnabled) {
      return const _FantasyWorkshopView();
    }

    return FutureBuilder(
      future: context.read<EntitlementService>().loadEntitlement(),
      builder: (context, snapshot) {
        final entitlement = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (entitlement?.canUseProFeatures == true) {
          return const _FantasyWorkshopView();
        }
        return const _FantasyDashboardLocked();
      },
    );
  }
}

class _FantasyWorkshopView extends StatelessWidget {
  const _FantasyWorkshopView();

  void _selectTab(BuildContext context, String tabId) {
    context.read<MainTabController>().setTabId(tabId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111816),
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const imageSize = Size(934, 1600);
            final fitted = _coverRect(
              inputSize: imageSize,
              outputSize: constraints.biggest,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  FantasyDashboardConfig.assetPath,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.none,
                ),
                _Hotspot(
                  fittedRect: fitted,
                  rect: const Rect.fromLTWH(0.13, 0.29, 0.27, 0.06),
                  label: '재고',
                  onTap: () => _selectTab(context, 'stock'),
                ),
                _Hotspot(
                  fittedRect: fitted,
                  rect: const Rect.fromLTWH(0.67, 0.29, 0.26, 0.06),
                  label: '발주',
                  onTap: () => _selectTab(context, 'purchases'),
                ),
                _Hotspot(
                  fittedRect: fitted,
                  rect: const Rect.fromLTWH(0.58, 0.49, 0.27, 0.06),
                  label: '입고',
                  onTap: () => _selectTab(context, 'txns'),
                ),
                _Hotspot(
                  fittedRect: fitted,
                  rect: const Rect.fromLTWH(0.09, 0.76, 0.25, 0.06),
                  label: '실사',
                  onTap: () => _selectTab(context, 'stock'),
                ),
                _Hotspot(
                  fittedRect: fitted,
                  rect: const Rect.fromLTWH(0.68, 0.85, 0.24, 0.06),
                  label: '통계',
                  onTap: () => _selectTab(
                    context,
                    MainTabController.dashboardTabId,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Hotspot extends StatelessWidget {
  final Rect fittedRect;
  final Rect rect;
  final String label;
  final VoidCallback onTap;

  const _Hotspot({
    required this.fittedRect,
    required this.rect,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: fittedRect.left + fittedRect.width * rect.left,
      top: fittedRect.top + fittedRect.height * rect.top,
      width: fittedRect.width * rect.width,
      height: fittedRect.height * rect.height,
      child: Semantics(
        button: true,
        label: label,
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: Colors.white.withValues(alpha: 0.16),
              highlightColor: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }
}

Rect _coverRect({
  required Size inputSize,
  required Size outputSize,
}) {
  if (inputSize.isEmpty || outputSize.isEmpty) return Offset.zero & outputSize;

  final scale = math.max(
    outputSize.width / inputSize.width,
    outputSize.height / inputSize.height,
  );
  final width = inputSize.width * scale;
  final height = inputSize.height * scale;

  return Rect.fromLTWH(
    (outputSize.width - width) / 2,
    (outputSize.height - height) / 2,
    width,
    height,
  );
}

class _FantasyDashboardLocked extends StatelessWidget {
  const _FantasyDashboardLocked();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('작업실')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium_rounded, size: 56),
              const SizedBox(height: 16),
              Text(
                '작업실 확장팩',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                '이 화면은 유료 확장팩으로 전환할 수 있게 분리되어 있습니다.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FantasyDashboardUnavailable extends StatelessWidget {
  const _FantasyDashboardUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('작업실 실험 기능이 꺼져 있습니다.')),
    );
  }
}
