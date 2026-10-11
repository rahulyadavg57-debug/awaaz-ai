import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/elevenlabs_service.dart';
import '../services/storage_service.dart';

class CloneScreen extends StatefulWidget {
  final VoidCallback onCloneSuccess;

  const CloneScreen({super.key, required this.onCloneSuccess});

  @override
  State<CloneScreen> createState() => _CloneScreenState();
}

class _CloneScreenState extends State<CloneScreen> {
  final TextEditingController _nameController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  int _recordDurationSeconds = 0;
  Timer? _timer;

  String? _sampleAudioPath;
  bool _isPlayingSample = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlayingSample = state == PlayerState.playing);
      }
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_sample_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordDurationSeconds = 0;
          _sampleAudioPath = null;
        });

        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() => _recordDurationSeconds++);
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('माइक की अनुमति (Microphone Permission) नहीं मिली')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording error: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _sampleAudioPath = path;
      });
    } catch (e) {
      setState(() => _isRecording = false);
    }
  }

  Future<void> _pickAudioFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _sampleAudioPath = result.files.single.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File pick error: $e')),
      );
    }
  }

  Future<void> _togglePlaySample() async {
    if (_sampleAudioPath == null) return;
    if (_isPlayingSample) {
      await _audioPlayer.stop();
    } else {
      await _audioPlayer.play(DeviceFileSource(_sampleAudioPath!));
    }
  }

  Future<void> _submitClone() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया अपनी आवाज़ का नाम लिखें (Enter Voice Name)')),
      );
      return;
    }

    if (_sampleAudioPath == null || !File(_sampleAudioPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया अपनी आवाज़ का ऑडियो रिकॉर्ड या अपलोड करें')),
      );
      return;
    }

    final apiKey = await StorageService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings में जाकर API Key डालना आवश्यक है!')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final newVoice = await ElevenLabsService.cloneVoice(
        voiceName: name,
        audioFilePath: _sampleAudioPath!,
        description: 'Voice cloned using Awaaz AI Hindi app',
      );

      if (mounted) {
        setState(() => _isUploading = false);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('क्लोनिंग सफल!'),
              ],
            ),
            content: Text('आपकी आवाज़ "${newVoice.name}" सफलतापूर्वक क्लोन हो गई है! अब आप कोई भी हिंदी टेक्स्ट अपनी आवाज़ में बोलवा सकते हैं।'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onCloneSuccess();
                },
                child: const Text('शुरू करें (Done)'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('अपनी आवाज़ क्लोन करें (Clone Voice)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions Banner
            Card(
              color: Colors.amber.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber),
                        SizedBox(width: 8),
                        Text('सुझाव (Tips for Best Clone):', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('• शांत कमरे में स्पष्ट आवाज़ में 30 से 60 सेकंड बोलें।'),
                    Text('• कोई भी हिंदी कहानी, समाचार या पैराग्राफ लगातार पढ़ें।'),
                    Text('• बैकग्राउंड शोर (Fan / TV) से बचें।'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Voice Name Input
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'आवाज़ का नाम (Voice Profile Name)',
                hintText: 'उदा: मेरी असली आवाज़ / My Real Voice',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 24),

            // Recording Widget Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                child: Column(
                  children: [
                    // Timer Display
                    Text(
                      _isRecording
                          ? 'रिकॉर्डिंग जारी है... 🔴  ${(_recordDurationSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordDurationSeconds % 60).toString().padLeft(2, '0')}'
                          : (_sampleAudioPath != null ? '✅ ऑडियो सैंपल तैयार है!' : 'माइक दबाकर बोलना शुरू करें'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isRecording ? Colors.red : Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Big Record Button
                    GestureDetector(
                      onTap: _isRecording ? _stopRecording : _startRecording,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.red : Colors.deepOrange,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isRecording ? Colors.red : Colors.deepOrange).withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      _isRecording ? 'रोकने के लिए दबाएं (Tap to Stop)' : 'रिकॉर्ड करें (Tap to Record)',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),

                    const SizedBox(height: 16),
                    const Divider(),

                    // Or Upload file
                    TextButton.icon(
                      onPressed: _isRecording ? null : _pickAudioFile,
                      icon: const Icon(Icons.file_upload_outlined),
                      label: const Text('फ़ोन से ऑडियो फ़ाइल चुनें (Upload Audio File)'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Sample Audio Preview Card
            if (_sampleAudioPath != null)
              Card(
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_isPlayingSample ? Icons.pause_circle_filled : Icons.play_circle_fill),
                        iconSize: 36,
                        color: Colors.green.shade800,
                        onPressed: _togglePlaySample,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'रिकॉर्ड किया गया सैंपल सुनें (Preview)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'हटाएं (Discard)',
                        onPressed: () {
                          _audioPlayer.stop();
                          setState(() => _sampleAudioPath = null);
                        },
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Submit / Clone Button
            ElevatedButton.icon(
              onPressed: (_isUploading || _isRecording) ? null : _submitClone,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isUploading ? 'आवाज़ क्लोन हो रही है... (Cloning)' : '🚀 अपनी आवाज़ क्लोन करें (Clone Voice)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
