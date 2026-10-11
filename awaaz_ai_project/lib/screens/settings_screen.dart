import 'package:flutter/material.dart';
import '../services/elevenlabs_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _obscureText = true;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final key = await StorageService.getApiKey();
    if (key != null && mounted) {
      _apiKeyController.text = key;
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API Key')),
      );
      return;
    }

    await StorageService.saveApiKey(key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ API Key सुरक्षित रूप से सेव हो गई! (Saved)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API Key to test')),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final valid = await ElevenLabsService.testApiKey(key);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testSuccess = valid;
        _testResult = valid
            ? '✅ Connection Successful! API Key is active.'
            : '❌ Connection Failed! Please check your API key.';
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('सेटिंग्स (Settings & API Key)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API Key Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.vpn_key_outlined, color: Colors.indigo),
                        SizedBox(width: 8),
                        Text(
                          'ElevenLabs API Key',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AI Voice Cloning aur Hindi TTS ke liye API key yahan daalein:',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureText,
                      decoration: InputDecoration(
                        hintText: 'xi-... या आपकी ElevenLabs API key',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscureText = !_obscureText),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isTesting ? null : _testConnection,
                            icon: _isTesting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.wifi_tethering),
                            label: const Text('Test Key'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saveApiKey,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.save),
                            label: const Text('Save Key'),
                          ),
                        ),
                      ],
                    ),
                    if (_testResult != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _testSuccess ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _testSuccess ? Colors.green.shade300 : Colors.red.shade300,
                          ),
                        ),
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            color: _testSuccess ? Colors.green.shade900 : Colors.red.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // How to get API Key Card
            Card(
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Free API Key कैसे प्राप्त करें?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text('1. अपने ब्राउज़र में elevenlabs.io खोलें।'),
                    SizedBox(height: 4),
                    Text('2. Free Account बनाएं (Google या Email से)।'),
                    SizedBox(height: 4),
                    Text('3. नीचे बाईं ओर Profile Icon पर क्लिक करें -> API Keys चुनें।'),
                    SizedBox(height: 4),
                    Text('4. "+ Create API Key" दबाएं और Key को Copy करके यहाँ Paste कर दें।'),
                    SizedBox(height: 8),
                    Text(
                      'नोट: ElevenLabs हर महीने 10,000 फ्री कैरेक्टर देता है, जो व्यक्तिगत उपयोग के लिए पर्याप्त है!',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // About App
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.info, color: Colors.indigo),
                      title: Text('Awaaz AI (आवाज़ क्लोन)'),
                      subtitle: Text('Version 1.0.0 • Hindi Voice Cloning & TTS'),
                    ),
                    Divider(),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'यह ऐप ElevenLabs Multilingual V2 मॉडल का उपयोग करती है जो हिंदी भाषा और आवाज़ क्लोनिंग में अत्यधिक स्वाभाविक परिणाम देती है।',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
