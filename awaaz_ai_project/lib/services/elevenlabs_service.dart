import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/voice_model.dart';
import 'storage_service.dart';

class ElevenLabsService {
  static const String _baseUrl = 'https://api.elevenlabs.io/v1';

  // Default fallback voices suitable for testing
  static final List<VoiceItem> defaultVoices = [
    VoiceItem(
      id: '21m00Tcm4TlvDq8ikWAM',
      name: 'Rachel (Female - Clear)',
      category: 'premade',
      description: 'Natural female voice, works great with Hindi',
    ),
    VoiceItem(
      id: 'pNInz6obpgDQGcFmaJgB',
      name: 'Adam (Male - Deep)',
      category: 'premade',
      description: 'Warm male voice, works great with Hindi',
    ),
    VoiceItem(
      id: 'ErXwobaYiN019PkySvjV',
      name: 'Antoni (Male - Expressive)',
      category: 'premade',
      description: 'Energetic male voice',
    ),
  ];

  /// Fetch all available voices from ElevenLabs account
  static Future<List<VoiceItem>> getVoices() async {
    final apiKey = await StorageService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return defaultVoices;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/voices'),
        headers: {'xi-api-key': apiKey},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> voicesJson = data['voices'] ?? [];
        final List<VoiceItem> fetchedVoices = voicesJson.map((e) => VoiceItem.fromJson(e)).toList();

        // Sort: Cloned voices first, then premade
        fetchedVoices.sort((a, b) {
          if (a.isCustomClone && !b.isCustomClone) return -1;
          if (!a.isCustomClone && b.isCustomClone) return 1;
          return a.name.compareTo(b.name);
        });

        return fetchedVoices.isNotEmpty ? fetchedVoices : defaultVoices;
      } else {
        return defaultVoices;
      }
    } catch (_) {
      return defaultVoices;
    }
  }

  /// Create a cloned voice using audio sample
  static Future<VoiceItem> cloneVoice({
    required String voiceName,
    required String audioFilePath,
    String? description,
  }) async {
    final apiKey = await StorageService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key missing! Please enter your ElevenLabs API key in Settings.');
    }

    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw Exception('Audio sample file not found. Please record again.');
    }

    final uri = Uri.parse('$_baseUrl/voices/add');
    final request = http.MultipartRequest('POST', uri);
    request.headers['xi-api-key'] = apiKey;

    request.fields['name'] = voiceName.trim();
    request.fields['description'] = description ?? 'Custom cloned voice created in Awaaz AI';

    final multipartFile = await http.MultipartFile.fromPath(
      'files',
      audioFilePath,
      filename: 'sample_voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final voiceId = data['voice_id'];
      if (voiceId == null || voiceId.toString().isEmpty) {
        throw Exception('Voice ID missing from server response.');
      }

      final newVoice = VoiceItem(
        id: voiceId,
        name: voiceName,
        category: 'cloned',
        isCustomClone: true,
        description: 'Your cloned voice',
      );

      // Save to local cache
      await StorageService.saveClonedVoice(newVoice);
      await StorageService.saveSelectedVoice(newVoice.id, newVoice.name);

      return newVoice;
    } else {
      String errorMsg = 'Failed to clone voice (${response.statusCode})';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson['detail'] != null) {
          if (errJson['detail'] is Map && errJson['detail']['message'] != null) {
            errorMsg = errJson['detail']['message'];
          } else {
            errorMsg = errJson['detail'].toString();
          }
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  /// Generate Hindi Text to Speech in cloned voice
  static Future<String> generateSpeech({
    required String text,
    required String voiceId,
    double stability = 0.5,
    double similarityBoost = 0.75,
  }) async {
    final apiKey = await StorageService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API Key missing! Please set your ElevenLabs API Key in Settings.');
    }

    if (text.trim().isEmpty) {
      throw Exception('Please enter some text in Hindi.');
    }

    final url = Uri.parse('$_baseUrl/text-to-speech/$voiceId');

    final body = jsonEncode({
      'text': text.trim(),
      // 'eleven_multilingual_v2' is the premier model with fluent Hindi pronunciation
      'model_id': 'eleven_multilingual_v2',
      'voice_settings': {
        'stability': stability,
        'similarity_boost': similarityBoost,
        'style': 0.0,
        'use_speaker_boost': true,
      }
    });

    final response = await http.post(
      url,
      headers: {
        'xi-api-key': apiKey,
        'Content-Type': 'application/json',
        'Accept': 'audio/mpeg',
      },
      body: body,
    ).timeout(const Duration(seconds: 40));

    if (response.statusCode == 200) {
      final fileName = 'awaaz_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final savePath = await StorageService.getAudioStoragePath(fileName);
      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);
      return savePath;
    } else {
      String errorMsg = 'Voice generation failed (${response.statusCode})';
      try {
        final errJson = jsonDecode(response.body);
        if (errJson['detail'] != null) {
          if (errJson['detail'] is Map && errJson['detail']['message'] != null) {
            errorMsg = errJson['detail']['message'];
          } else {
            errorMsg = errJson['detail'].toString();
          }
        }
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }

  /// Test API Key connection
  static Future<bool> testApiKey(String apiKey) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user'),
        headers: {'xi-api-key': apiKey.trim()},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
