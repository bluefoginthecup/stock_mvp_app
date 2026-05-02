import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FabricImageService {
  final ImagePicker _picker;

  FabricImageService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  Future<String?> pickAndCopyImage({
    required ImageSource source,
    required String projectId,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2200,
    );
    if (picked == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(dir.path, 'fabric_cutting', 'images'));
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }

    final ext =
        p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path);
    final fileName =
        '${projectId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final copied =
        await File(picked.path).copy(p.join(imageDir.path, fileName));
    return copied.path;
  }
}
