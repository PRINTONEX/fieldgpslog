import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/log_service.dart';

class VoiceNoteService extends GetxService {
  final SpeechToText _speechToText = SpeechToText();
  final RxBool isListening = false.obs;
  final RxString lastWords = "".obs;
  bool _isInitialized = false;

  Future<bool> init() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) => LogService.log("Voice Recognition Error: $error", level: 'ERROR'),
        onStatus: (status) => LogService.log("Voice Status: $status"),
      );
      return _isInitialized;
    } catch (e) {
      LogService.log("Speech initialization failed: $e", level: 'ERROR');
      return false;
    }
  }

  Future<void> startListening(Function(String) onResult) async {
    final ready = await init();
    if (!ready) return;

    isListening.value = true;
    lastWords.value = "";
    
    await _speechToText.listen(
      onResult: (result) {
        lastWords.value = result.recognizedWords;
        if (result.finalResult) {
          isListening.value = false;
          onResult(result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      cancelOnError: true,
      partialResults: true,
    );
  }

  Future<void> stopListening() async {
    await _speechToText.stop();
    isListening.value = false;
  }
}
