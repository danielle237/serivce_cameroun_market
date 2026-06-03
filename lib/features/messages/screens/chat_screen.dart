import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

// Import conditionnel : mobile = service actif, web = stub vide
import 'audio_service_stub.dart'
    if (dart.library.io) 'audio_service_mobile.dart';
import 'video_service_stub.dart'
    if (dart.library.io) 'video_service_mobile.dart';

const _wsBaseUrl = 'http://51.83.40.138:3005';

// ═════════════════════════════════════════════════════════════════════════════
class ChatScreen extends ConsumerStatefulWidget {
  final String contactId;
  // Contexte optionnel : proposition de contrat enseignant
  final String? applicationId;
  final Map<String, dynamic>? applicationData;
  // Contexte optionnel : devis artisan
  final Map<String, dynamic>? quoteData;
  // Contexte optionnel : marketplace (produit ou commande)
  final Map<String, dynamic>? marketplaceData;

  const ChatScreen({
    super.key,
    required this.contactId,
    this.applicationId,
    this.applicationData,
    this.quoteData,
    this.marketplaceData,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _storage     = const FlutterSecureStorage(
    webOptions: WebOptions(dbName: 'w2d_secure', publicKey: 'w2d_pub_key'),
  );

  IO.Socket? _socket;
  List<Map<String, dynamic>> _messages = [];
  bool _isTyping      = false;
  bool _contactTyping = false;

  // Contexte contrat
  Map<String, dynamic>? _appData;
  bool _appActionLoading = false;

  // ── Audio recording ───────────────────────────────────────────────────────
  final AudioService _audio = AudioService();
  bool _isRecording    = false;
  bool _audioUploading = false;
  int  _recordSeconds  = 0;
  Timer? _recordTimer;
  String? _recordPath;

  // Oscilloscope : historique des 40 dernières amplitudes normalisées
  final List<double> _waveformBars = List.filled(40, 0.0);
  StreamSubscription<double>? _ampSubscription;
  bool _recordLocked = false;   // enregistrement verrouillé (drag up)

  // ── Video recording ───────────────────────────────────────────────────────
  final VideoService _video = VideoService();
  bool _isRecordingVideo = false;
  bool _videoUploading   = false;
  int  _videoSeconds     = 0;
  Timer? _videoTimer;
  static const int _maxVideoSeconds = 10;

  @override
  void initState() {
    super.initState();
    _appData = widget.applicationData;
    _loadMessages();
    _connectSocket();
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _recordTimer?.cancel();
    _videoTimer?.cancel();
    _ampSubscription?.cancel();
    _audio.dispose();
    _video.dispose();
    super.dispose();
  }

  // ── Charger l'historique ──────────────────────────────────────────────────
  Future<void> _loadMessages() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/messages/conversation/${widget.contactId}');
      setState(() {
        _messages = List<Map<String, dynamic>>.from(res.data).reversed.toList();
      });
      _scrollToBottom();
    } catch (_) {}
  }

  // ── WebSocket ─────────────────────────────────────────────────────────────
  Future<void> _connectSocket() async {
    final token = await _storage.read(key: 'access_token');
    _socket = IO.io('$_wsBaseUrl/chat',
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token})
        .build(),
    );

    _socket!.on('new_message', (data) {
      if (!mounted) return;
      final m = Map<String, dynamic>.from(data);
      if (m['sender_id'] == widget.contactId || m['receiver_id'] == widget.contactId) {
        setState(() => _messages.add(m));
        _scrollToBottom();
      }
    });

    _socket!.on('message_sent', (data) {
      if (!mounted) return;
      setState(() => _messages.add(Map<String, dynamic>.from(data)));
      _scrollToBottom();
    });

    _socket!.on('typing', (data) {
      if (!mounted) return;
      if (data['userId'] == widget.contactId) {
        setState(() => _contactTyping = data['isTyping']);
      }
    });

    _socket!.emit('mark_read', {'conversationUserId': widget.contactId});
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Envoyer message texte ────────────────────────────────────────────────
  void _sendText() {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;
    _socket?.emit('send_message', {
      'receiverId': widget.contactId,
      'content': text,
      'messageType': 'text',
    });
    _messageCtrl.clear();
    _socket?.emit('typing', {'receiverId': widget.contactId, 'isTyping': false});
    _isTyping = false;
  }

  void _onTyping(String v) {
    final typing = v.isNotEmpty;
    if (typing != _isTyping) {
      _isTyping = typing;
      _socket?.emit('typing', {'receiverId': widget.contactId, 'isTyping': typing});
    }
  }

  // ── Actions sur la proposition de contrat ────────────────────────────────
  Future<void> _acceptApplication() async {
    if (widget.applicationId == null || _appData == null) return;
    final requestId = _appData!['requestId'] as String?;
    if (requestId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accepter la proposition ?'),
        content: Text(
          'Vous allez accepter la proposition de ${_appData!['teacher']?['name'] ?? 'l\'enseignant'}.\n\n'
          'Le montant convenu sera placé en séquestre jusqu\'à la fin de la première séance.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Accepter'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _appActionLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.patch(
        '/education/requests/$requestId/applications/${widget.applicationId}/accept',
      );
      if (mounted) {
        setState(() => _appData = {..._appData!, 'status': 'accepted'});
        _snack('✅ Proposition acceptée ! Contrat créé.', Colors.green);
        // Message système dans le chat
        _socket?.emit('send_message', {
          'receiverId': widget.contactId,
          'content': '✅ J\'ai accepté votre proposition de contrat. Vous pouvez planifier la première séance.',
          'messageType': 'text',
        });
      }
    } catch (e) {
      if (mounted) _snack('Erreur: $e', Colors.red);
    }
    if (mounted) setState(() => _appActionLoading = false);
  }

  Future<void> _rejectApplication() async {
    if (widget.applicationId == null || _appData == null) return;
    final requestId = _appData!['requestId'] as String?;
    if (requestId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Refuser la proposition ?'),
        content: const Text('L\'enseignant sera notifié par SMS du refus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _appActionLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.patch(
        '/education/requests/$requestId/applications/${widget.applicationId}/reject',
      );
      if (mounted) {
        setState(() => _appData = {..._appData!, 'status': 'rejected'});
        _snack('Proposition refusée.', Colors.orange);
        _socket?.emit('send_message', {
          'receiverId': widget.contactId,
          'content': '❌ Je n\'ai pas retenu votre proposition cette fois. Merci de votre intérêt.',
          'messageType': 'text',
        });
      }
    } catch (e) {
      if (mounted) _snack('Erreur: $e', Colors.red);
    }
    if (mounted) setState(() => _appActionLoading = false);
  }

  // ── Démarrer l'enregistrement ────────────────────────────────────────────
  Future<void> _startRecording() async {
    if (!_audio.isSupported) {
      _snack('🎤 Messages vocaux disponibles sur l\'app Android', Colors.blue);
      return;
    }
    final ok = await _audio.hasPermission();
    if (!ok) {
      _snack('Autorisez le micro dans les paramètres', Colors.orange);
      return;
    }
    _recordPath = await _audio.getTempPath();
    await _audio.start(_recordPath!);

    // Réinitialiser le waveform
    for (var i = 0; i < _waveformBars.length; i++) _waveformBars[i] = 0.0;

    // S'abonner au stream d'amplitude → oscilloscope
    _ampSubscription?.cancel();
    _ampSubscription = _audio.amplitudeStream.listen((amp) {
      if (!mounted) return;
      setState(() {
        _waveformBars.removeAt(0);
        _waveformBars.add(amp);
      });
    });

    setState(() { _isRecording = true; _recordSeconds = 0; _recordLocked = false; });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  // ── Annuler l'enregistrement ─────────────────────────────────────────────
  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    _ampSubscription?.cancel();
    await _audio.stop();
    setState(() {
      _isRecording = false; _recordLocked = false;
      _recordSeconds = 0; _recordPath = null;
      for (var i = 0; i < _waveformBars.length; i++) _waveformBars[i] = 0.0;
    });
  }

  // ── Terminer et envoyer l'audio ──────────────────────────────────────────
  Future<void> _stopAndSendAudio() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    _ampSubscription?.cancel();
    final path = await _audio.stop();
    final duration = _recordSeconds;
    setState(() {
      _isRecording = false; _recordLocked = false;
      _audioUploading = true; _recordSeconds = 0;
    });

    if (path == null || duration < 1) {
      setState(() => _audioUploading = false);
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: 'voice.m4a'),
      });
      final res = await api.uploadFile('/media/audio', formData);
      final audioUrl = res.data['url'] as String;

      _socket?.emit('send_message', {
        'receiverId': widget.contactId,
        'content': '🎤 Message vocal',
        'messageType': 'audio',
        'mediaUrl': audioUrl,
        'audioDuration': duration,
      });
    } catch (_) {
      _snack('Erreur envoi audio', Colors.red);
    }
    setState(() { _audioUploading = false; _recordPath = null; });
  }

  // ── Démarrer l'enregistrement vidéo ─────────────────────────────────────
  Future<void> _startVideoRecording() async {
    if (!_video.isSupported) {
      _snack('📹 Messages vidéo disponibles sur l\'app Android', Colors.blue);
      return;
    }
    final ok = await _video.hasPermission();
    if (!ok) {
      _snack('Autorisez la caméra dans les paramètres', Colors.orange);
      return;
    }
    await _video.initialize();
    setState(() { _isRecordingVideo = true; _videoSeconds = 0; });

    // Countdown et auto-stop à 10s
    _videoTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _videoSeconds++);
      if (_videoSeconds >= _maxVideoSeconds) {
        t.cancel();
        _stopAndSendVideo();
      }
    });

    // Lance l'enregistrement (auto-stop géré par le timer)
    _video.recordAndStop(_maxVideoSeconds).then((path) {
      _videoTimer?.cancel();
      if (path != null) _uploadAndSendVideo(path);
    });
  }

  Future<void> _cancelVideoRecording() async {
    _videoTimer?.cancel();
    await _video.stopRecording();
    setState(() { _isRecordingVideo = false; _videoSeconds = 0; });
  }

  Future<void> _stopAndSendVideo() async {
    _videoTimer?.cancel();
    setState(() { _isRecordingVideo = false; _videoUploading = true; _videoSeconds = 0; });
    try {
      await _video.stopRecording();
    } catch (_) {}
    // L'upload est déclenché par le .then() de recordAndStop
    if (mounted) setState(() => _videoUploading = false);
  }

  Future<void> _uploadAndSendVideo(String path) async {
    if (!mounted) return;
    setState(() => _videoUploading = true);
    try {
      final api = ref.read(apiClientProvider);
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: 'video.mp4'),
      });
      final res = await api.uploadFile('/media/video', formData);
      final videoUrl = res.data['url'] as String;
      _socket?.emit('send_message', {
        'receiverId': widget.contactId,
        'content': '📹 Message vidéo',
        'messageType': 'video',
        'mediaUrl': videoUrl,
        'videoDuration': _maxVideoSeconds,
      });
    } catch (e) {
      _snack('Erreur envoi vidéo', Colors.red);
    }
    if (mounted) setState(() { _videoUploading = false; _isRecordingVideo = false; });
  }

  bool _isDifferentDay(Map a, Map b) {
    try {
      final da = DateTime.parse(a['created_at'].toString());
      final db = DateTime.parse(b['created_at'].toString());
      return da.day != db.day || da.month != db.month || da.year != db.year;
    } catch (_) { return false; }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color));
  }

  String _formatDuration(int s) =>
    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // ── Nom du contact ────────────────────────────────────────────────────────
  String get _contactName {
    if (_appData != null) {
      final teacher = _appData!['teacher'] as Map<String, dynamic>?;
      if (teacher != null) return teacher['name'] as String? ?? 'Enseignant';
      final parent = _appData!['parent'] as Map<String, dynamic>?;
      if (parent != null) return parent['name'] as String? ?? 'Parent';
    }
    return 'Contact';
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.read(authStateProvider).value?.user?['id'];
    final appStatus = _appData?['status'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFE5DDD5), // fond Telegram (motif bois clair)
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.25),
            child: Text(
              _contactName.isNotEmpty ? _contactName[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_contactName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _contactTyping ? 'en train d\'écrire…' : 'en ligne',
                key: ValueKey(_contactTyping),
                style: TextStyle(
                  fontSize: 12,
                  color: _contactTyping
                      ? Colors.greenAccent.shade100
                      : Colors.white70,
                  fontStyle: _contactTyping ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ])),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: null),
          IconButton(icon: const Icon(Icons.call_outlined), onPressed: null),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: _loadMessages),
        ],
      ),
      body: Column(
        children: [
          // ── Bandeau marketplace (produit ou commande) ────────────────────
          if (widget.marketplaceData != null)
            _MarketplaceBanner(data: widget.marketplaceData!),

          // ── Bandeau devis artisan (si contexte fourni) ───────────────────
          if (widget.quoteData != null)
            _QuoteBanner(
              quoteData: widget.quoteData!,
              inputController: _messageCtrl,
              onSendMessage: (msg) {
                _socket?.emit('send_message', {
                  'receiverId': widget.contactId,
                  'content': msg,
                  'messageType': 'text',
                });
                _scrollToBottom();
              },
            ),

          // ── Bandeau contrat enseignant (si contexte fourni) ──────────────
          if (_appData != null)
            _ContractBanner(
              appData: _appData!,
              appStatus: appStatus,
              loading: _appActionLoading,
              onAccept: _acceptApplication,
              onReject: _rejectApplication,
              inputController: _messageCtrl,
              onSendMessage: (msg) {
                _socket?.emit('send_message', {
                  'receiverId': widget.contactId,
                  'content': msg,
                  'messageType': 'text',
                });
                _scrollToBottom();
              },
            ),

          // ── Liste des messages ───────────────────────────────────────────
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('Commencez la conversation',
                          style: TextStyle(color: AppColors.textSecondary)),
                      if (_appData != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Discutez des détails avant d\'accepter le contrat',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ]),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final isMe = msg['sender_id'] == myId;
                      // Afficher la date si changement de jour
                      final showDate = i == 0 ||
                          _isDifferentDay(_messages[i - 1], msg);
                      return Column(children: [
                        if (showDate) _DateSeparator(msg['created_at']),
                        _MessageBubble(message: msg, isMe: isMe),
                      ]);
                    },
                  ),
          ),

          // ── Indicateur de frappe ────────────────────────────────────────
          if (_contactTyping)
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 6),
              child: Align(alignment: Alignment.centerLeft, child: _TypingIndicator()),
            ),

          // ── Barre de saisie Telegram ────────────────────────────────────
          Container(
            color: const Color(0xFFF0F0F0),
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
            child: _isRecordingVideo
                ? _buildVideoRecordingBar()
                : _isRecording
                    ? _buildRecordingBar()
                    : _buildInputBar(),
          ),
        ],
      ),
    );
  }

  // ── Barre de texte Telegram ───────────────────────────────────────────────
  Widget _buildInputBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Zone de saisie
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4, offset: const Offset(0, 1),
              )],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              // Emoji / pièce jointe (décoratif)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Icon(Icons.sentiment_satisfied_alt_outlined,
                    color: Colors.grey.shade400, size: 24),
              ),
              Expanded(
                child: TextField(
                  controller: _messageCtrl,
                  onChanged: _onTyping,
                  maxLines: 5,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    hintStyle: TextStyle(color: Color(0xFFAAAAAA), fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                ),
              ),
              // Caméra vidéo
              Padding(
                padding: const EdgeInsets.only(right: 4, bottom: 4),
                child: GestureDetector(
                  onTap: _videoUploading ? null : _startVideoRecording,
                  child: _videoUploading
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : Icon(Icons.videocam_outlined,
                          color: Colors.grey.shade400, size: 24),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 6),

        // Bouton envoi / micro
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _messageCtrl,
          builder: (_, val, __) {
            final hasText = val.text.trim().isNotEmpty;
            return GestureDetector(
              onTap: hasText ? _sendText : null,
              onLongPressStart: hasText ? null : (_) => _startRecording(),
              onLongPressEnd: hasText ? null : (_) => _stopAndSendAudio(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF1976D2).withOpacity(0.4),
                    blurRadius: 8, offset: const Offset(0, 2),
                  )],
                ),
                child: Icon(
                  hasText ? Icons.send_rounded : Icons.mic_rounded,
                  color: Colors.white, size: 22,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Barre d'enregistrement style Telegram ────────────────────────────────
  Widget _buildRecordingBar() {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          // Bouton annuler (poubelle)
          GestureDetector(
            onTap: _cancelRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            ),
          ),
          const SizedBox(width: 8),

          // Oscilloscope + timer
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(21),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                )],
              ),
              child: Row(children: [
                // Point rouge clignotant
                _PulseDot(),
                const SizedBox(width: 8),
                // Timer
                Text(
                  _formatDuration(_recordSeconds),
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
                // Oscilloscope waveform
                Expanded(
                  child: CustomPaint(
                    painter: _WaveformPainter(
                      bars: List.from(_waveformBars),
                      color: const Color(0xFF1976D2),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Hint slide to cancel
                const Text(
                  '← annuler',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),

          // Bouton envoyer
          GestureDetector(
            onTap: _stopAndSendAudio,
            child: Container(
              width: 42, height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFF1976D2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── Barre d'enregistrement vidéo ─────────────────────────────────────────
  Widget _buildVideoRecordingBar() {
    final progress = _videoSeconds / _maxVideoSeconds;
    final remaining = _maxVideoSeconds - _videoSeconds;

    return Row(children: [
      // Annuler
      GestureDetector(
        onTap: _cancelVideoRecording,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.shade50, shape: BoxShape.circle,
            border: Border.all(color: Colors.red.shade200),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
        ),
      ),
      const SizedBox(width: 10),
      // Barre de progression
      Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            _PulseDot(),
            const SizedBox(width: 8),
            const Icon(Icons.videocam, color: Colors.red, size: 16),
            const SizedBox(width: 6),
            Text(
              '${_formatDuration(_videoSeconds)}  |  -${remaining}s',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.red.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              minHeight: 4,
            ),
          ),
        ]),
      ),
      const SizedBox(width: 10),
      // Envoyer maintenant
      GestureDetector(
        onTap: _stopAndSendVideo,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
        ),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BANDEAU MARKETPLACE — contexte produit ou commande Tchokos
// ═════════════════════════════════════════════════════════════════════════════
class _MarketplaceBanner extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MarketplaceBanner({required this.data});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? 'product';
    final isOrder = type == 'order';

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Photo produit ou icône commande
          if (!isOrder && data['productPhoto'] != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                data['productPhoto'] as String,
                width: 48, height: 48, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _icon(),
              ),
            )
          else
            _icon(isOrder: isOrder),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOrder ? '📦 Commande ${data['orderRef']}' : '🛍️ ${data['productName'] ?? 'Produit'}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isOrder
                      ? '${data['orderStatus']} · ${_fmt((data['orderTotal'] as num?)?.toDouble() ?? 0)} FCFA'
                      : '${_fmt((data['productPrice'] as num?)?.toDouble() ?? 0)} FCFA',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF1976D2),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
        ],
      ),
    );
  }

  Widget _icon({bool isOrder = false}) => Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1976D2).withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          isOrder ? Icons.receipt_long : Icons.shopping_bag_outlined,
          color: const Color(0xFF1976D2), size: 24,
        ),
      );

  String _fmt(double v) => v.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

// ═════════════════════════════════════════════════════════════════════════════
// BANDEAU DEVIS ARTISAN — collapsible, chips de modification
// ═════════════════════════════════════════════════════════════════════════════
class _QuoteBanner extends StatefulWidget {
  final Map<String, dynamic> quoteData;
  final void Function(String) onSendMessage;
  final TextEditingController inputController;

  const _QuoteBanner({
    required this.quoteData,
    required this.onSendMessage,
    required this.inputController,
  });

  @override
  State<_QuoteBanner> createState() => _QuoteBannerState();
}

class _QuoteBannerState extends State<_QuoteBanner> {
  bool _expanded = true;

  static String _fmt(dynamic v) {
    if (v == null) return '0';
    final n = v is int ? v : (v is double ? v.toInt() : int.tryParse(v.toString()) ?? 0);
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }

  void _sendOrPrefill(String msg, {bool prefill = false}) {
    if (prefill) {
      widget.inputController.text = msg;
      widget.inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: msg.length),
      );
    } else {
      widget.onSendMessage(msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Message envoyé à l\'artisan'),
        ]),
        backgroundColor: const Color(0xFF1976D2),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerName = widget.quoteData['providerName'] as String? ?? 'Artisan';
    final amount       = widget.quoteData['amount'];
    final description  = widget.quoteData['description'] as String?;
    final estimatedDays = widget.quoteData['estimatedDays'];
    final status       = widget.quoteData['status'] as String? ?? 'pending';
    final isPending    = status == 'pending';
    final isAccepted   = status == 'accepted';

    final accentColor = isAccepted ? Colors.green : const Color(0xFF1976D2);
    final bgColor     = isAccepted ? Colors.green.shade50 : Colors.blue.shade50;
    final borderColor = isAccepted ? Colors.green.shade200 : Colors.blue.shade200;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [BoxShadow(
          color: accentColor.withOpacity(0.08),
          blurRadius: 8, offset: const Offset(0, 3),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── En-tête cliquable ──────────────────────────────────────────────
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(16),
            bottom: _expanded ? Radius.zero : const Radius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAccepted ? Icons.verified_outlined : Icons.request_quote_outlined,
                  size: 18, color: accentColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  isAccepted ? 'Devis accepté ✅' : 'Devis en négociation',
                  style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13, color: accentColor,
                  ),
                ),
                Text(providerName,
                    style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ])),
              // Montant badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_fmt(amount)} FCFA',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey.shade400, size: 20),
            ]),
          ),
        ),

        // ── Corps dépliable ────────────────────────────────────────────────
        if (_expanded) ...[
          const Divider(height: 1, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Infos devis
              if (description != null && description.isNotEmpty)
                _infoRow(Icons.description_outlined, description, maxLines: 2),
              if (estimatedDays != null) ...[
                const SizedBox(height: 4),
                _infoRow(Icons.schedule_outlined,
                    'Durée estimée : $estimatedDays jour${_toInt(estimatedDays) > 1 ? 's' : ''}'),
              ],

              if (isAccepted) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'Fonds placés en séquestre. Ils seront libérés après validation des travaux.',
                      style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
                    )),
                  ]),
                ),
              ],

              // Chips modification — seulement si en attente
              if (isPending) ...[
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.edit_note_outlined, size: 15, color: Colors.grey),
                  const SizedBox(width: 6),
                  const Text('Demander une modification :',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _chip('💰 Négocier le prix',
                      'Bonjour, votre devis m\'intéresse. Le montant de ${_fmt(amount)} FCFA dépasse mon budget — pouvez-vous faire un effort sur le prix ?'),
                  _chip('📅 Raccourcir le délai',
                      'Bonjour, est-il possible de terminer les travaux plus rapidement ? Combien de jours minimum vous faut-il ?'),
                  _chip('📋 Décomposer le devis',
                      'Bonjour, pourriez-vous m\'envoyer le détail poste par poste (main d\'œuvre, matériaux, déplacement…) ?'),
                  _chip('🔧 Ajouter une tâche',
                      'Bonjour, pourriez-vous inclure également cette prestation dans le devis : ',
                      prefill: true),
                  _chip('🗓️ Planifier une visite',
                      'Bonjour, avant d\'accepter je souhaiterais que vous passiez faire une visite sur place. Êtes-vous disponible cette semaine ?'),
                ]),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _infoRow(IconData icon, String text, {int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 13, color: Colors.grey.shade500),
      const SizedBox(width: 6),
      Expanded(child: Text(text,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
          maxLines: maxLines, overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _chip(String label, String message, {bool prefill = false}) => ActionChip(
    avatar: prefill ? const Icon(Icons.edit_outlined, size: 13) : null,
    label: Text(label, style: const TextStyle(fontSize: 11)),
    backgroundColor: Colors.white,
    side: BorderSide(color: const Color(0xFF1976D2).withOpacity(0.4)),
    labelStyle: const TextStyle(color: Color(0xFF1976D2)),
    elevation: 1,
    shadowColor: Colors.black12,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    onPressed: () => _sendOrPrefill(message, prefill: prefill),
  );

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BANDEAU PROPOSITION ENSEIGNANT — collapsible, chips de négociation
// ═════════════════════════════════════════════════════════════════════════════
class _ContractBanner extends StatefulWidget {
  final Map<String, dynamic> appData;
  final String? appStatus;
  final bool loading;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final void Function(String) onSendMessage;
  final TextEditingController inputController;

  const _ContractBanner({
    required this.appData,
    required this.appStatus,
    required this.loading,
    required this.onAccept,
    required this.onReject,
    required this.onSendMessage,
    required this.inputController,
  });

  @override
  State<_ContractBanner> createState() => _ContractBannerState();
}

class _ContractBannerState extends State<_ContractBanner> {
  bool _expanded = true;

  void _sendOrPrefill(String msg, {bool prefill = false}) {
    if (prefill) {
      widget.inputController.text = msg;
      widget.inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: msg.length),
      );
    } else {
      widget.onSendMessage(msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Message envoyé à l\'enseignant'),
        ]),
        backgroundColor: const Color(0xFF1976D2),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacher    = widget.appData['teacher']  as Map<String, dynamic>?;
    final request    = widget.appData['request']  as Map<String, dynamic>?;
    final subject    = request?['subject']    as String? ?? widget.appData['subject']    as String? ?? '';
    final level      = request?['classLevel'] as String? ?? widget.appData['classLevel'] as String? ?? '';
    final rate       = widget.appData['proposedRate'] ?? request?['budgetPerSession'];
    final message    = widget.appData['message'] as String?;
    final schedule   = widget.appData['proposedSchedule'] as String?;
    final isPending  = widget.appStatus == 'pending' || widget.appStatus == null;
    final isAccepted = widget.appStatus == 'accepted';
    final isRejected = widget.appStatus == 'rejected';

    Color accentColor;
    Color bgColor;
    Color borderColor;
    if (isAccepted) {
      accentColor = Colors.green; bgColor = Colors.green.shade50; borderColor = Colors.green.shade200;
    } else if (isRejected) {
      accentColor = Colors.grey; bgColor = Colors.grey.shade100; borderColor = Colors.grey.shade300;
    } else {
      accentColor = const Color(0xFF1976D2); bgColor = Colors.blue.shade50; borderColor = Colors.blue.shade200;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [BoxShadow(
          color: accentColor.withOpacity(0.08),
          blurRadius: 8, offset: const Offset(0, 3),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── En-tête cliquable ──────────────────────────────────────────────
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(16),
            bottom: _expanded ? Radius.zero : const Radius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAccepted ? Icons.school : Icons.assignment_outlined,
                  size: 18, color: accentColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  isAccepted
                    ? 'Contrat signé 🎉'
                    : isRejected
                      ? 'Proposition refusée'
                      : 'Proposition de l\'enseignant',
                  style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13, color: accentColor,
                  ),
                ),
                if (teacher != null)
                  Text(teacher['name'] as String? ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ])),
              // Tarif badge
              if (rate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$rate FCFA/séance',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 6),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey.shade400, size: 20),
            ]),
          ),
        ),

        // ── Corps dépliable ────────────────────────────────────────────────
        if (_expanded) ...[
          const Divider(height: 1, indent: 14, endIndent: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Détails de la proposition
              if (subject.isNotEmpty)
                _infoRow(Icons.menu_book_outlined,
                    '$subject${level.isNotEmpty ? ' · $level' : ''}'),
              if (schedule != null && schedule.isNotEmpty) ...[
                const SizedBox(height: 4),
                _infoRow(Icons.calendar_today_outlined, schedule),
              ],
              if (message != null && message.isNotEmpty) ...[
                const SizedBox(height: 4),
                _infoRow(Icons.format_quote_outlined, message, maxLines: 3),
              ],

              // État accepté
              if (isAccepted) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(children: [
                    Icon(Icons.celebration_outlined, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(child: Text(
                      'Contrat actif ! L\'enseignant peut planifier la première séance.',
                      style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
                    )),
                  ]),
                ),
              ],

              // Boutons Refuser / Accepter
              if (isPending) ...[
                const SizedBox(height: 12),
                widget.loading
                    ? const Center(child: SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                    : Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onReject,
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Décliner', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.onAccept,
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Accepter', style: TextStyle(fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ]),

                // Chips de négociation éducation
                const SizedBox(height: 14),
                Row(children: [
                  const Icon(Icons.edit_note_outlined, size: 15, color: Colors.grey),
                  const SizedBox(width: 6),
                  const Text('Demander une modification :',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _chip('💰 Négocier le tarif',
                      'Bonjour, votre proposition m\'intéresse. Le tarif de $rate FCFA/séance est un peu élevé pour moi — pouvez-vous proposer un ajustement ?'),
                  _chip('📅 Modifier les horaires',
                      'Bonjour, les horaires proposés ne me conviennent pas tout à fait. Seriez-vous disponible en semaine en fin d\'après-midi ou le week-end matin ?'),
                  _chip('🎯 Préciser la méthode',
                      'Bonjour, pourriez-vous me décrire votre méthode pédagogique et la façon dont vous évaluez la progression de l\'élève ?'),
                  _chip('📚 Ajouter une matière',
                      'Bonjour, seriez-vous en mesure de couvrir également la matière suivante : ',
                      prefill: true),
                  _chip('🧪 Proposer une séance d\'essai',
                      'Bonjour, serait-il possible de commencer par une séance d\'essai avant de signer le contrat définitif ?'),
                ]),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _infoRow(IconData icon, String text, {int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 13, color: Colors.grey.shade500),
      const SizedBox(width: 6),
      Expanded(child: Text(text,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
          maxLines: maxLines, overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _chip(String label, String message, {bool prefill = false}) => ActionChip(
    avatar: prefill ? const Icon(Icons.edit_outlined, size: 13) : null,
    label: Text(label, style: const TextStyle(fontSize: 11)),
    backgroundColor: Colors.white,
    side: BorderSide(color: const Color(0xFF1976D2).withOpacity(0.4)),
    labelStyle: const TextStyle(color: Color(0xFF1976D2)),
    elevation: 1,
    shadowColor: Colors.black12,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    onPressed: () => _sendOrPrefill(message, prefill: prefill),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// BULLE DE MESSAGE
// ═════════════════════════════════════════════════════════════════════════════
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  // Couleurs Telegram
  static const _myColor    = Color(0xFF5497DB); // bleu Telegram
  static const _theirColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final type = message['message_type'] as String? ?? 'text';
    final isMedia = type == 'audio' || type == 'video' || type == 'image';

    return Padding(
      padding: EdgeInsets.only(
        bottom: 3,
        left: isMe ? 48 : 6,
        right: isMe ? 6 : 48,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: CustomPaint(
          // Queue de bulle style Telegram
          painter: _BubbleTailPainter(
            isMe: isMe,
            color: isMe ? _myColor : _theirColor,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
              minWidth: 80,
            ),
            margin: EdgeInsets.only(
              left: isMe ? 0 : 6,
              right: isMe ? 6 : 0,
            ),
            decoration: BoxDecoration(
              color: isMe ? _myColor : _theirColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 2),
                bottomRight: Radius.circular(isMe ? 2 : 16),
              ),
              boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 3, offset: const Offset(0, 1),
              )],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 7, 10, isMedia ? 8 : 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (type == 'audio')
                    _AudioBubble(
                      audioUrl: message['media_url'] as String? ?? '',
                      duration: message['audio_duration'] as int? ?? 0,
                      isMe: isMe,
                    )
                  else if (type == 'video' && message['media_url'] != null)
                    _VideoBubble(
                      videoUrl: message['media_url'] as String,
                      duration: message['video_duration'] as int? ?? 10,
                      isMe: isMe,
                    )
                  else if (type == 'image' && message['media_url'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(message['media_url'],
                          height: 180, width: 220, fit: BoxFit.cover),
                    )
                  else
                    Text(
                      message['content'] ?? '',
                      style: TextStyle(
                        color: isMe ? Colors.white : const Color(0xFF1A1A1A),
                        fontSize: 15, height: 1.4,
                      ),
                    ),

                  // Heure + lu — aligné en bas à droite dans le texte
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Spacer(),
                      Text(
                        _formatTime(message['created_at']?.toString()),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isMe
                              ? Colors.white.withOpacity(0.75)
                              : Colors.grey.shade500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        Icon(
                          message['is_read'] == true
                              ? Icons.done_all_rounded
                              : Icons.done_rounded,
                          size: 14,
                          color: message['is_read'] == true
                              ? Colors.lightBlueAccent.shade100
                              : Colors.white60,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(String? s) {
    if (s == null) return '';
    try { return s.substring(11, 16); } catch (_) { return ''; }
  }
}

// Queue de bulle style Telegram
class _BubbleTailPainter extends CustomPainter {
  final bool isMe;
  final Color color;
  const _BubbleTailPainter({required this.isMe, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    if (isMe) {
      // Queue en bas à droite
      path.moveTo(size.width + 6, size.height - 4);
      path.lineTo(size.width + 6, size.height + 4);
      path.quadraticBezierTo(
          size.width + 6, size.height + 8, size.width + 2, size.height + 6);
      path.lineTo(size.width - 2, size.height - 2);
    } else {
      // Queue en bas à gauche
      path.moveTo(-6, size.height - 4);
      path.lineTo(-6, size.height + 4);
      path.quadraticBezierTo(
          -6, size.height + 8, -2, size.height + 6);
      path.lineTo(2, size.height - 2);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BubbleTailPainter old) => old.isMe != isMe || old.color != color;
}

// ═════════════════════════════════════════════════════════════════════════════
// BULLE AUDIO avec lecture / barre de progression
// ═════════════════════════════════════════════════════════════════════════════
class _AudioBubble extends StatefulWidget {
  final String audioUrl;
  final int duration;
  final bool isMe;
  const _AudioBubble({required this.audioUrl, required this.duration, required this.isMe});

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _total    = Duration.zero;
  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;

  @override
  void initState() {
    super.initState();
    _total = Duration(seconds: widget.duration);
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
    _posSub = _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _durSub = _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _total = d);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.audioUrl));
    }
  }

  String _fmt(Duration d) =>
    '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isPlaying = _state == PlayerState.playing;
    final progress = _total.inSeconds > 0
        ? _position.inSeconds / _total.inSeconds
        : 0.0;
    final iconColor  = widget.isMe ? Colors.white : AppColors.primary;
    final trackColor = widget.isMe ? Colors.white38 : Colors.grey.shade300;
    final activeColor = widget.isMe ? Colors.white : AppColors.primary;

    return SizedBox(
      width: 220,
      child: Row(children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: widget.isMe ? Colors.white24 : AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: iconColor, size: 22,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: activeColor,
                  inactiveTrackColor: trackColor,
                  thumbColor: activeColor,
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: (v) {
                    final pos = Duration(seconds: (_total.inSeconds * v).round());
                    _player.seek(pos);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  isPlaying ? _fmt(_position) : _fmt(_total),
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isMe ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.mic, size: 16,
            color: widget.isMe ? Colors.white60 : Colors.grey.shade400),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BULLE VIDÉO avec lecture inline
// ═════════════════════════════════════════════════════════════════════════════
class _VideoBubble extends StatefulWidget {
  final String videoUrl;
  final int duration;
  final bool isMe;
  const _VideoBubble({required this.videoUrl, required this.duration, required this.isMe});

  @override
  State<_VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<_VideoBubble> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
    _ctrl.addListener(() {
      if (mounted) setState(() => _playing = _ctrl.value.isPlaying);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isMe ? Colors.white : AppColors.primary;
    final bgColor   = widget.isMe ? Colors.white24 : AppColors.primary.withOpacity(0.1);

    return SizedBox(
      width: 220,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Aperçu vidéo
        GestureDetector(
          onTap: () {
            if (!_initialized) return;
            _playing ? _ctrl.pause() : _ctrl.play();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(alignment: Alignment.center, children: [
              _initialized
                  ? AspectRatio(
                      aspectRatio: _ctrl.value.aspectRatio,
                      child: VideoPlayer(_ctrl),
                    )
                  : Container(
                      height: 130, width: 220,
                      color: widget.isMe ? Colors.white12 : Colors.grey.shade200,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
              // Bouton play/pause
              if (_initialized)
                AnimatedOpacity(
                  opacity: _playing ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                    child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: iconColor, size: 28),
                  ),
                ),
              // Badge durée
              if (!_playing)
                Positioned(
                  bottom: 6, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _initialized
                          ? _fmt(_ctrl.value.duration)
                          : '0:${widget.duration.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        // Barre de progression (si lecture)
        if (_initialized && _playing)
          VideoProgressIndicator(
            _ctrl,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: widget.isMe ? Colors.white : AppColors.primary,
              bufferedColor: widget.isMe ? Colors.white30 : Colors.grey.shade300,
              backgroundColor: widget.isMe ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
        // Icône vidéo
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(Icons.videocam_outlined, size: 13,
                color: widget.isMe ? Colors.white60 : Colors.grey.shade400),
            const SizedBox(width: 4),
            Text('Vidéo · ${widget.duration}s',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isMe ? Colors.white60 : AppColors.textSecondary,
                )),
          ]),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WAVEFORM OSCILLOSCOPE PAINTER
// ═════════════════════════════════════════════════════════════════════════════
class _WaveformPainter extends CustomPainter {
  final List<double> bars;
  final Color color;

  const _WaveformPainter({required this.bars, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    final barCount = bars.length;
    final spacing = size.width / barCount;
    final midY = size.height / 2;
    final maxH = size.height * 0.45;

    for (var i = 0; i < barCount; i++) {
      final x = i * spacing + spacing / 2;
      // Hauteur min = 3px pour un aspect naturel même au silence
      final h = (bars[i] * maxH).clamp(2.5, maxH);
      paint.color = color.withOpacity(0.3 + bars[i] * 0.7);
      canvas.drawLine(Offset(x, midY - h), Offset(x, midY + h), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => old.bars != bars;
}

// ═════════════════════════════════════════════════════════════════════════════
// SÉPARATEUR DE DATE
// ═════════════════════════════════════════════════════════════════════════════
class _DateSeparator extends StatelessWidget {
  final dynamic timestamp;
  const _DateSeparator(this.timestamp);

  String _label() {
    if (timestamp == null) return '';
    try {
      final d = DateTime.parse(timestamp.toString()).toLocal();
      final now = DateTime.now();
      if (d.day == now.day && d.month == now.month && d.year == now.year) {
        return "Aujourd'hui";
      }
      final yesterday = now.subtract(const Duration(days: 1));
      if (d.day == yesterday.day && d.month == yesterday.month) return 'Hier';
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final label = _label();
    if (label.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGETS UTILITAIRES
// ═════════════════════════════════════════════════════════════════════════════
class _CircleBtn extends StatelessWidget {
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? child;
  const _CircleBtn({required this.color, this.icon, this.onTap, this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: child ?? Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.5 + _ctrl.value * 0.5),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        _Dot(delay: 0), SizedBox(width: 4),
        _Dot(delay: 150), SizedBox(width: 4),
        _Dot(delay: 300),
      ]),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Opacity(
      opacity: 0.3 + _ctrl.value * 0.7,
      child: Container(
        width: 8, height: 8,
        decoration: const BoxDecoration(
          color: AppColors.textSecondary,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}
