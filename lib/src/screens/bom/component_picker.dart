// lib/src/screens/bom/component_picker.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/item.dart';
import '../../models/bom.dart';
import '../../repos/repo_interfaces.dart';        // ✅ 인터페이스 의존
import '../../ui/common/search_field.dart';       // ✅ 디바운스 내장 검색 필드
import '../../ui/common/suggestion_panel.dart';   // ✅ 공용 결과 패널
import '../../utils/item_presentation.dart';      // ✅ ItemLabel / 라벨 유틸

/// BOM 구성품 선택 다이얼로그.
/// 선택 시 itemId(String)를 pop으로 반환한다.
class ComponentPicker extends StatefulWidget {
  final BomRoot root;              // finished 또는 semi 용으로 호출
  final String initialQuery;       // 초기 검색어
  /// 필요하면 외부에서 도메인 제약(예: 세미/원자재만)을 주입할 수 있음
  final bool Function(Item)? predicate;

  const ComponentPicker({
    super.key,
    required this.root,
    this.initialQuery = '',
    this.predicate,
  });

  @override
  State<ComponentPicker> createState() => _ComponentPickerState();
}

class _ComponentPickerState extends State<ComponentPicker> {
  final _searchC = TextEditingController();
  List<Item> _results = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _searchC.text = widget.initialQuery;
    if (widget.initialQuery.trim().isNotEmpty) {
      _onSearchChanged(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String keyword) async {
    final k = keyword.trim();
    if (k.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final repo = context.read<ItemRepo>();
      var list = await repo.searchItemsGlobal(k);

      // 필요 시 외부 도메인 제약(predicate) 적용
      if (widget.predicate != null) {
        list = list.where(widget.predicate!).toList();
      } else {
        // 기본 제약 샘플: 완제품 BOM 편집 중이면 구성품으로 "완제품 제외"
        // (실제 필드명은 프로젝트 모델에 맞게 교체)
        // if (widget.root == BomRoot.finished) {
        //   list = list.where((it) => it.kind != ItemKind.finished).toList();
        // }
      }

      setState(() => _results = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    // 화면 비율 기반으로 넉넉한 크기 계산
    final dialogW = (size.width * 0.9).clamp(640.0, 1100.0); // 최소 640, 최대 1100
    final dialogH = (size.height * 0.9).clamp(520.0, 900.0); // 최소 520, 최대 900

    return Dialog(
      insetPadding: const EdgeInsets.all(16), // 바깥 여백 조금만
      child: SizedBox(
        width: dialogW,
        height: dialogH,
        child: Column(
          children: [
            // 상단 타이틀바 (AlertDialog 대체)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Text('구성품 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: '닫기',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 본문
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    AppSearchField(
                      controller: _searchC,
                      hint: '구성품 검색',
                      onChanged: _onSearchChanged, // 🔍 디바운스 적용
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                        child: LinearProgressIndicator(),
                      ),
                    Expanded(
                      child: _results.isEmpty
                          ? Center(
                        child: Text(
                          _searchC.text.trim().isEmpty ? '검색어를 입력하세요' : '검색 결과가 없습니다',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      )
                          : SuggestionPanel<Item>(
                        items: _results,
                        itemBuilder: (ctx, it) => ListTile(
                          leading: const Icon(Icons.widgets_outlined),
                          // B안: repo에서 라벨/경로 비동기 생성
                          title: ItemLabel(itemId: it.id, full: false),
                          subtitle: ItemLabel(itemId: it.id, full: true),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, it.id),
                          // 보기 편하게 줄간격 약간 촘촘하게
                          visualDensity: const VisualDensity(vertical: -1),
                        ),
                        rowHeight: 56,
                        separated: true,
                        elevation: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
