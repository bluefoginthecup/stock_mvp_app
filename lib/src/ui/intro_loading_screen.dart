import 'dart:io' show Platform;

import 'package:flutter/material.dart';

class IntroLoadingScreen extends StatelessWidget {
  static const puppyAsset = 'assets/images/chalstock_puppy.png';
  static const introAsset = 'assets/images/chalstock_intro.png';
  static const macosIntroAsset = 'assets/images/chalstock_intro_macos.png';

  const IntroLoadingScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Image.asset(
          Platform.isMacOS ? macosIntroAsset : introAsset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
