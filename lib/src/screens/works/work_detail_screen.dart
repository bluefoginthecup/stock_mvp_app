
import '../../models/work.dart';
import '../../ui/common/ui.dart';
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
