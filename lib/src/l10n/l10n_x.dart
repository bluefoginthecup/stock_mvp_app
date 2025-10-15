import 'package:flutter/widgets.dart';
import 'l10n.dart';

extension L10nX on BuildContext {
  L10n get t => L10n.of(this);
}
