import 'package:flutter/material.dart';
import '../screens/trash/trash_screen.dart';


void openTrashFromNav(NavigatorState nav) {
  nav.push(
    MaterialPageRoute(builder: (_) => const TrashScreen()),
  );
}