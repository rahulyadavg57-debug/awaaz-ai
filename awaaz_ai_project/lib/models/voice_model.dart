class VoiceItem {
  final String id;
  final String name;
  final String category;
  final bool isCustomClone;
  final String description;

  VoiceItem({
    required this.id,
    required this.name,
    this.category = 'premade',
    this.isCustomClone = false,
    this.description = '',
  });

  factory VoiceItem.fromJson(Map<String, dynamic> json) {
    return VoiceItem(
      id: json['voice_id'] ?? json['id'] ?? '',
      name: json['name'] ?? 'Unknown Voice',
      category: json['category'] ?? 'premade',
      isCustomClone: (json['category'] == 'cloned') || (json['isCustomClone'] == true),
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'isCustomClone': isCustomClone,
      'description': description,
    };
  }
}

class GenerationHistoryItem {
  final String id;
  final String text;
  final String voiceName;
  final String voiceId;
  final String audioPath;
  final DateTime createdAt;

  GenerationHistoryItem({
    required this.id,
    required this.text,
    required this.voiceName,
    required this.voiceId,
    required this.audioPath,
    required this.createdAt,
  });

  factory GenerationHistoryItem.fromJson(Map<String, dynamic> json) {
    return GenerationHistoryItem(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      voiceName: json['voiceName'] ?? '',
      voiceId: json['voiceId'] ?? '',
      audioPath: json['audioPath'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'voiceName': voiceName,
      'voiceId': voiceId,
      'audioPath': audioPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
