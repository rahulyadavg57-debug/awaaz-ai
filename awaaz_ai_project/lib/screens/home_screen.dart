import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import '../models/voice_model.dart';
import '../services/elevenlabs_service.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToClone;
  final VoidCallback onNavigateToSettings;

  const HomeScreen({
    super.key,
    required this.onNavigateToClone,
    required this.onNavigateToSettings,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<VoiceItem> _voices = [];
  VoiceItem? _selectedVoice;
  bool _isLoadingVoices = true;
  bool _isGenerating = false;

  // Player state
  String? _currentAudioPath;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Tuning parameters
  double _stability = 0.50;
  double _similarity = 0.75;
  bool _showAdvancedSettings = false;

  final List<String> _hindiPresets = [
    'नमस्ते! आप कैसे हैं? यह मेरी अपनी आवाज़ है।',
    'शुभ प्रभात! आपका दिन बहुत अच्छा और मंगलमय रहे।',
    'AI तकनीक की मदद से मेरी आवाज़ में यह ऑडियो बनाया गया है।',
    'दोस्तों, आज के इस नए एपिसोड में आप सभी का स्वागत है!',
  ];

  @override
  void initState() {
    super.initState();
    _loadVoices();
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  Future<void> _loadVoices() async {
    setState(() => _isLoadingVoices = true);
    final voices = await ElevenLabsService.getVoices();
    final savedVoiceId = await StorageService.getSelectedVoiceId();

    VoiceItem? defaultSelection;
    if (savedVoiceId != null) {
      try {
        defaultSelection = voices.firstWhere((v) => v.id == savedVoiceId);
      } catch (_) {}
    }

    if (defaultSelection == null && voices.isNotEmpty) {
      // Pick first cloned voice if available, else first voice
      defaultSelection = voices.firstWhere((v) => v.isCustomClone, orElse: () => voices.first);
    }

    if (mounted) {
      setState(() {
        _voices = voices;
        _selectedVoice = defaultSelection;
        _isLoadingVoices = false;
      });
    }
  }

  Future<void> _generateSpeech() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया कुछ टेक्स्ट लिखें (Please enter text)'))
      );
      return;
    }

    final apiKey = await StorageService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      _showApiKeyRequiredDialog();
      return;
    }

    if (_selectedVoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया आवाज़ (Voice) चुनें'))
      );
      return;
    }

    setState(() => _isGenerating = true);
    // Stop any active audio
    await _audioPlayer.stop();

    try {
      final audioPath = await ElevenLabsService.generateSpeech(
        text: text,
        voiceId: _selectedVoice!.id,
        stability: _stability,
        similarityBoost: _similarity,
      );

      // Save to history
      final historyItem = GenerationHistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text,
        voiceName: _selectedVoice!.name,
        voiceId: _selectedVoice!.id,
        audioPath: audioPath,
        createdAt: DateTime.now(),
      );
      await StorageService.addToHistory(historyItem);

      setState(() {
        _currentAudioPath = audioPath;
        _isGenerating = false;
      });

      // Auto play generated audio
      await _audioPlayer.play(DeviceFileSource(audioPath));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ ऑडियो तैयार हो गया! (Audio Generated)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showApiKeyRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('API Key Required'),
          ],
        ),
        content: const Text(
          'Voice generate aur clone karne ke liye ElevenLabs API key zaroori hai. Aap Settings mein jaakar apni free API key daal sakte hain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onNavigateToSettings();
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePlayPause() async {
    if (_currentAudioPath == null) return;
    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(_currentAudioPath!));
    }
  }

  Future<void> _shareAudio() async {
    if (_currentAudioPath == null) return;
    try {
      await Share.shareXFiles(
        [XFile(_currentAudioPath!)],
        text: 'Awaaz AI द्वारा बनाई गई आवाज़:\n"${_textController.text}"',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sharing failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.record_voice_over, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('Awaaz AI (आवाज़)'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload voices',
            onPressed: _loadVoices,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadVoices,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Voice Selection Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'चुनें आवाज़ (Select Voice)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          TextButton.icon(
                            onPressed: widget.onNavigateToClone,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('नई आवाज़ जोड़ें'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _isLoadingVoices
                          ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                          : DropdownButtonFormField<VoiceItem>(
                              isExpanded: true,
                              value: _selectedVoice,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                prefixIcon: Icon(
                                  _selectedVoice?.isCustomClone == true ? Icons.person_pin : Icons.mic,
                                  color: _selectedVoice?.isCustomClone == true ? Colors.deepOrange : Colors.indigo,
                                ),
                              ),
                              items: _voices.map((voice) {
                                return DropdownMenuItem<VoiceItem>(
                                  value: voice,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          voice.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: voice.isCustomClone ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      if (voice.isCustomClone)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.deepOrange.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'CLONED',
                                            style: TextStyle(fontSize: 10, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedVoice = val);
                                  StorageService.saveSelectedVoice(val.id, val.name);
                                }
                              },
                            ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Text Input Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'हिंदी टेक्स्ट लिखें (Enter Hindi Text):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _textController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'यहाँ अपना हिंदी टेक्स्ट लिखें या पेस्ट करें...\nउदा: नमस्ते, आज का दिन बहुत खूबसूरत है!',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Quick Preset Chips
                      const Text('त्वरित वाक्य (Presets):', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _hindiPresets.map((preset) {
                          return ActionChip(
                            label: Text(
                              preset.length > 25 ? '${preset.substring(0, 25)}...' : preset,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              setState(() {
                                _textController.text = preset;
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Fine Tuning Controls
              ExpansionTile(
                title: const Text('आवाज़ सेटिंग्स (Voice Controls)', style: TextStyle(fontSize: 14)),
                leading: const Icon(Icons.tune),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Stability (स्थिरता):'),
                            Text('${(_stability * 100).toInt()}%'),
                          ],
                        ),
                        Slider(
                          value: _stability,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          label: '${(_stability * 100).toInt()}%',
                          onChanged: (val) => setState(() => _stability = val),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Clarity / Similarity (समानता):'),
                            Text('${(_similarity * 100).toInt()}%'),
                          ],
                        ),
                        Slider(
                          value: _similarity,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          label: '${(_similarity * 100).toInt()}%',
                          onChanged: (val) => setState(() => _similarity = val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Generate Action Button
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateSpeech,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  elevation: 4,
                ),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.spatial_audio_off_outlined),
                label: Text(
                  _isGenerating ? 'आवाज़ बनाई जा रही है... (Generating)' : '📢 आवाज़ बनाएं (Generate Voice)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 20),

              // Audio Player Card
              if (_currentAudioPath != null)
                Card(
                  elevation: 4,
                  color: Colors.indigo.shade900,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              iconSize: 42,
                              color: Colors.orangeAccent,
                              icon: Icon(
                                _playerState == PlayerState.playing
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill,
                              ),
                              onPressed: _togglePlayPause,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedVoice?.name ?? 'Cloned Voice',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  Slider(
                                    activeColor: Colors.orangeAccent,
                                    inactiveColor: Colors.white24,
                                    value: _position.inMilliseconds.clamp(0, _duration.inMilliseconds).toDouble(),
                                    max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                                    onChanged: (val) {
                                      _audioPlayer.seek(Duration(milliseconds: val.toInt()));
                                    },
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                        Text(
                                          '${_duration.inMinutes}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.share, color: Colors.white),
                              tooltip: 'Share Audio',
                              onPressed: _shareAudio,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
