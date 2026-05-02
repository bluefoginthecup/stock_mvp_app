import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/fabric_cutting_project.dart';

class FabricCuttingStorageService {
  const FabricCuttingStorageService();

  Future<File> get _storageFile async {
    final dir = await getApplicationDocumentsDirectory();
    final featureDir = Directory(p.join(dir.path, 'fabric_cutting'));
    if (!await featureDir.exists()) {
      await featureDir.create(recursive: true);
    }
    return File(p.join(featureDir.path, 'projects.json'));
  }

  Future<List<FabricCuttingProject>> loadProjects() async {
    final file = await _storageFile;
    if (!await file.exists()) return [];

    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final projects = decoded
          .whereType<Map>()
          .map((e) =>
              FabricCuttingProject.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return projects;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveProject(FabricCuttingProject project) async {
    final projects = await loadProjects();
    final updated = project.copyWith(updatedAt: DateTime.now());
    final index = projects.indexWhere((e) => e.id == project.id);
    if (index >= 0) {
      projects[index] = updated;
    } else {
      projects.insert(0, updated);
    }
    await _writeProjects(projects);
  }

  Future<void> deleteProject(String id) async {
    final projects = await loadProjects();
    projects.removeWhere((e) => e.id == id);
    await _writeProjects(projects);
  }

  Future<void> _writeProjects(List<FabricCuttingProject> projects) async {
    final file = await _storageFile;
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(
        encoder.convert(projects.map((e) => e.toJson()).toList()));
  }
}
