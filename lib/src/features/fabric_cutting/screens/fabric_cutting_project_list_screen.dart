import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/fabric_cutting_project.dart';
import '../services/fabric_cutting_storage_service.dart';

class FabricCuttingProjectListScreen extends StatefulWidget {
  const FabricCuttingProjectListScreen({super.key});

  @override
  State<FabricCuttingProjectListScreen> createState() =>
      _FabricCuttingProjectListScreenState();
}

class _FabricCuttingProjectListScreenState
    extends State<FabricCuttingProjectListScreen> {
  final _storage = const FabricCuttingStorageService();
  late Future<List<FabricCuttingProject>> _future;

  @override
  void initState() {
    super.initState();
    _future = _storage.loadProjects();
  }

  void _reload() {
    setState(() {
      _future = _storage.loadProjects();
    });
  }

  Future<void> _delete(FabricCuttingProject project) async {
    await _storage.deleteProject(project.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${project.displayName} 삭제됨')),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('저장된 재단 계산')),
      body: FutureBuilder<List<FabricCuttingProject>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final projects = snap.data ?? [];
          if (projects.isEmpty) {
            return const Center(child: Text('저장된 계산 결과가 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: projects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final project = projects[index];
              return Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    child: Text(project.pieces.length.toString()),
                  ),
                  title: Text(project.displayName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${project.quantity}개 / 원단폭 ${_fmt(project.fabricWidthCm)}cm\n${DateFormat('yyyy.MM.dd HH:mm').format(project.updatedAt)}',
                  ),
                  isThreeLine: true,
                  onTap: () => Navigator.pop(context, project),
                  trailing: IconButton(
                    tooltip: '삭제',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(project),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

String _fmt(double n) => n.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
