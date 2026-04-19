import 'package:flutter_tts/flutter_tts.dart';

/// Wrapper around flutter_tts providing multilingual offline TTS.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  String _locale = 'en-IN';
  double _speechRate = 0.5;
  double _pitch = 1.0;
  bool _isSpeaking = false;

  Future<void> initialize() async {
    await _tts.setLanguage(_locale);
    await _tts.setSpeechRate(_speechRate);
    await _tts.setPitch(_pitch);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((_) => _isSpeaking = false);
  }

  Future<void> setLanguage(String locale) async {
    _locale = locale;
    await _tts.setLanguage(locale);
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate;
    await _tts.setSpeechRate(rate);
  }

  Future<void> speak(String text) async {
    if (_isSpeaking) await _tts.stop();
    _isSpeaking = true;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<List<String>> availableLanguages() async {
    final langs = await _tts.getLanguages;
    return (langs as List).cast<String>();
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}
