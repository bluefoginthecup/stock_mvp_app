import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

NumberFormat n(BuildContext c) =>
    NumberFormat.decimalPattern(Localizations.localeOf(c).toString());

DateFormat d(BuildContext c) =>
    DateFormat.yMMMd(Localizations.localeOf(c).toString());
