import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:get/get.dart';
import '../services/log_service.dart';

class ProofStorageService extends GetxService {
  Future<String> saveProofImage(File imageFile, String type) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final proofsDir = Directory('${directory.path}/delivery_proofs');
      
      if (!await proofsDir.exists()) {
        await proofsDir.create(recursive: true);
      }

      final fileName = '${type}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final savedFile = await imageFile.copy('${proofsDir.path}/$fileName');
      
      LogService.log("Saved $type proof to: ${savedFile.path}");
      return savedFile.path;
    } catch (e) {
      LogService.log("Error saving proof media: $e", level: 'ERROR');
      rethrow;
    }
  }

  Future<void> deleteProofMedia(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
