import 'dart:io' show Platform;

import 'package:flutter/material.dart';

class StartScreen extends StatelessWidget {
  static const asset = 'assets/images/chalstock_start.png';
  static const macosAsset = 'assets/images/chalstock_start_macos.png';

  final VoidCallback onStart;

  const StartScreen({
    super.key,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            Platform.isMacOS ? macosAsset : asset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          SafeArea(
            child: Align(
              alignment: Platform.isMacOS
                  ? const Alignment(0, 0.82)
                  : Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  Platform.isMacOS ? 0 : 32,
                  0,
                  Platform.isMacOS ? 0 : 32,
                  Platform.isMacOS ? 0 : 42,
                ),
                child: Semantics(
                  button: true,
                  label: '시작하기',
                  child: SizedBox(
                    width: Platform.isMacOS ? 520 : double.infinity,
                    height: Platform.isMacOS ? 78 : 82,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(32),
                        onTap: onStart,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
