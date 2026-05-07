import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/storage_location.dart';
import '../../../repos/repo_interfaces.dart';

Future<StorageLocation?> showStorageLocationPickerSheet(
  BuildContext context,
) async {
  final repo = context.read<StorageLocationRepo>();
  final locations = await repo.searchLocations('');
  if (!context.mounted) return null;

  if (locations.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('등록된 보관 위치가 없습니다.')),
    );
    return null;
  }

  return showModalBottomSheet<StorageLocation>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final searchC = TextEditingController();
      var query = '';

      String pathLabel(StorageLocation location) {
        final byId = {for (final loc in locations) loc.id: loc};
        final names = <String>[location.name];
        var cursor = location.parentId == null ? null : byId[location.parentId];
        while (cursor != null) {
          names.insert(0, cursor.name);
          cursor = cursor.parentId == null ? null : byId[cursor.parentId];
        }
        return names.join(' > ');
      }

      return StatefulBuilder(
        builder: (context, setSheetState) {
          final q = query.toLowerCase();
          final filtered = q.isEmpty
              ? locations
              : locations.where((location) {
                  return pathLabel(location).toLowerCase().contains(q) ||
                      StorageLocationType.label(location.type)
                          .toLowerCase()
                          .contains(q) ||
                      (location.memo ?? '').toLowerCase().contains(q);
                }).toList();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.76,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '보관 위치 선택',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('취소'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: searchC,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: '위치 검색',
                        hintText: '창고, 선반, 박스 이름으로 찾기',
                      ),
                      onChanged: (value) {
                        setSheetState(() => query = value.trim());
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('검색된 위치가 없습니다'))
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final location = filtered[index];
                                return ListTile(
                                  leading:
                                      const Icon(Icons.location_on_outlined),
                                  title: Text(pathLabel(location)),
                                  subtitle: Text(
                                    StorageLocationType.label(location.type),
                                  ),
                                  onTap: () =>
                                      Navigator.of(sheetContext).pop(location),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
