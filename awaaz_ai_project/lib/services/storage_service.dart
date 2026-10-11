import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/voice_model.dart';

class StorageService {
  static const String _keyApiKey = 'elevenlabs_api_key';
  static const String _keySelectedVoiceId = 'selected_voice_id';
  static const String _keySelectedVoiceName = 'selected_voice_name';
  static const String _keyHistory = 'generation_history';
  static const String _keyClonedVoices = 'cloned_voices_cache';

  // API Key management
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyApiKey);
  }

  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, apiKey.trim());
  }

  // Selected Voice
  static Future<String?> getSelectedVoiceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedVoiceId);
  }

  static Future<String?> getSelectedVoiceName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedVoiceName);
  }

  static Future<void> saveSelectedVoice(String voiceId, String voiceName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedVoiceId, voiceId);
    await prefs.setString(_keySelectedVoiceName, voiceName);
  }

  // Custom Cloned Voices Local Cache
  static Future<List<VoiceItem>> getSavedClonedVoices() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyClonedVoices);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => VoiceItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveClonedVoice(VoiceItem voice) async {
    final list = await getSavedClonedVoices();
    list.removeWhere((item) => item.id == voice.id);
    list.insert(0, voice);
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_keyClonedVoices, jsonStr);
  }

  // History Management
  static Future<List<GenerationHistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyHistory);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => GenerationHistoryItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addToHistory(GenerationHistoryItem item) async {
    final list = await getHistory();
    list.insert(0, item);
    // keep max 50 items
    if (list.length > 50) {
      list.removeRange(50, list.length);
    }
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_keyHistory, jsonStr);
  }

  static Future<void> deleteHistoryItem(String id) async {
    final list = await getHistory();
    list.removeWhere((item) => item.id == id);
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_keyHistory, jsonStr);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHistory);
  }

  // File paths helper
  static Future<String> getAudioStoragePath(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/audio_outputs');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return '${audioDir.path}/$filename';
  }
}
