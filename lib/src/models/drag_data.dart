import '../repos/repo_interfaces.dart'; // EntityKind 사용
import '../repos/inmem_repo.dart';

class DragData {
  final EntityKind kind;        // item or folder
  final List<String> ids;       // 멀티 드래그 지원 (아이템 여러 개)
  const DragData({required this.kind, required this.ids});
}
