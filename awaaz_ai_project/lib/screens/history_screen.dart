import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import '../models/voice_model.dart';
import '../services/storage_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<GenerationHistoryItem> _items = [];
  bool _isLoading = true;
  String? _currentlyPlayingId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted && state == PlayerState.completed) {
        setState(() => _currentlyPlayingId = null);
      }
    });
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await StorageService.getHistory();
    if (mounted) {
      setState(() {
        _items = history;
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePlay(GenerationHistoryItem item) async {
    if (_currentlyPlayingId == item.id) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingId = null);
    } else {
      if (File(item.audioPath).existsSync()) {
        await _audioPlayer.stop();
        await _audioPlayer.play(DeviceFileSource(item.audioPath));
        setState(() => _currentlyPlayingId = item.id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ऑडियो फ़ाइल नहीं मिली (File not found)')),
        );
      }
    }
  }

  Future<void> _share(GenerationHistoryItem item) async {
    if (File(item.audioPath).existsSync()) {
      await Share.shareXFiles(
        [XFile(item.audioPath)],
        text: 'Awaaz AI (${item.voiceName}):\n${item.text}',
      );
    }
  }

  Future<void> _delete(GenerationHistoryItem item) async {
    await StorageService.deleteHistoryItem(item.id);
    try {
      final f = File(item.audioPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    _loadHistory();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('इतिहास (Generated Audio History)'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear All',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('सभी हटाएं? (Clear All)'),
                    content: const Text('क्या आप सारा इतिहास मिटाना चाहते हैं?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete All')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await StorageService.clearHistory();
                  _loadHistory();
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, size: 72, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'कोई पिछला ऑडियो नहीं मिला',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final isPlaying = _currentlyPlayingId == item.id;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isPlaying ? Colors.orange : Colors.indigo.shade50,
                                  child: IconButton(
                                    icon: Icon(
                                      isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: isPlaying ? Colors.white : Colors.indigo,
                                    ),
                                    onPressed: () => _togglePlay(item),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.voiceName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year} • ${item.createdAt.hour}:${item.createdAt.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.share, size: 20),
                                  onPressed: () => _share(item),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                  onPressed: () => _delete(item),
                                ),
                              ],
                            ),
                            const Divider(height: 18),
                            Text(
                              item.text,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
