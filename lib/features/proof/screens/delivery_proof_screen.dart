import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import '../../../models/delivery_proof.dart';
import '../../../services/proof_storage_service.dart';
import '../../../services/database_service.dart';

class DeliveryProofScreen extends StatefulWidget {
  final int stayPointId;
  const DeliveryProofScreen({super.key, required this.stayPointId});

  @override
  State<DeliveryProofScreen> createState() => _DeliveryProofScreenState();
}

class _DeliveryProofScreenState extends State<DeliveryProofScreen> {
  final ProofStorageService _storage = Get.put(ProofStorageService());
  final DatabaseService _db = Get.find<DatabaseService>();
  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  File? _photo;
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _photo = File(pickedFile.path));
    }
  }

  Future<void> _submit() async {
    if (_photo == null) {
      Get.snackbar("Error", "Please take a delivery photo");
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? sigPath;
      if (_sigController.isNotEmpty) {
        final Uint8List? sigData = await _sigController.toPngBytes();
        if (sigData != null) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/sig_temp.png');
          await tempFile.writeAsBytes(sigData);
          sigPath = await _storage.saveProofImage(tempFile, 'signature');
        }
      }

      final photoPath = await _storage.saveProofImage(_photo!, 'parcel');

      final proof = DeliveryProof()
        ..timestamp = DateTime.now()
        ..stayPointId = widget.stayPointId
        ..imagePath = photoPath
        ..signaturePath = sigPath
        ..otp = _otpController.text
        ..customerNote = _noteController.text
        ..status = 'Completed';

      await _db.proofBox.add(proof);
      
      Get.back(result: true);
      Get.snackbar("Success", "Delivery proof saved successfully");
    } catch (e) {
      Get.snackbar("Error", "Failed to save proof: $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Delivery')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Parcel Photo', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildPhotoPicker(),
            const SizedBox(height: 24),
            const Text('Customer Signature', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildSignaturePad(),
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              decoration: const InputDecoration(labelText: 'OTP (if any)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Customer/Delivery Note', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('SUBMIT PROOF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _takePhoto,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: _photo != null 
          ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(_photo!, fit: BoxFit.cover)) 
          : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Icon(Icons.camera_alt, size: 40, color: Colors.grey), Text('Tap to take photo')],
            ),
      ),
    );
  }

  Widget _buildSignaturePad() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Signature(
            controller: _sigController,
            height: 150,
            backgroundColor: Colors.grey[50]!,
          ),
          Container(
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => _sigController.clear(), child: const Text('Clear')),
              ],
            ),
          )
        ],
      ),
    );
  }
}
