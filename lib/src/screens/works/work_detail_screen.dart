
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../repos/repo_interfaces.dart';

import '../../models/types.dart';
import '../../services/inventory_service.dart';

import '../../utils/item_presentation.dart';

import '../../ui/common/delete_more_menu.dart';

// ⬇️ l10n
import '../../l10n/l10n.dart';
import '../../models/work.dart';
import '../../ui/common/ui.dart';
import 'package:flutter/material.dart';
import 'work_detail_view.dart';

class WorkDetailScreen extends StatelessWidget {
  final Work work;

  const WorkDetailScreen({
    super.key,
    required this.work,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.work_detail_title),
      ),
      body: WorkDetailView(
        workId: work.id,
        embedded: false,
      ),
    );
  }
}
