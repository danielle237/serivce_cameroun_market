import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show FontFeature;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';

class SessionActiveScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const SessionActiveScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionActiveScreen> createState() => _SessionActiveScreenState();
}

class _SessionActiveScreenState extends ConsumerState<SessionActiveScreen> {
  Map<String, dynamic>? _session;
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;

  // OTP end-session
  final _otpController = TextEditingController();
  int _otpAttemptsLeft = 3;

  // Notes privées persistantes
  final _privateNotesCtrl = TextEditingController();
  bool _notesSaving = false;
  bool _notesSaved = false;

  // Bilan form
  final _homeworkController = TextEditingController();
  final _notesController = TextEditingController();
  final _suggestionsController = TextEditingController();
  String _studentState = 'good';
  bool _showBilan = false;

  // Chronomètre
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _alerted10min = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _homeworkController.dispose();
    _notesController.dispose();
    _suggestionsController.dispose();
    super.dispose();
  }

  void _startTimer(String startTime) {
    _timer?.cancel();
    // Calculer le temps déjà écoulé depuis le début de séance
    try {
      final now = TimeOfDay.now();
      final parts = startTime.split(':');
      final sessionStart = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
      final elapsedMin = (now.hour * 60 + now.minute) -
          (sessionStart.hour * 60 + sessionStart.minute);
      if (elapsedMin > 0) {
        _elapsed = Duration(minutes: elapsedMin);
      }
    } catch (_) {}

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
      // Alerte 10min avant la fin
      if (!_alerted10min && _session != null) {
        final endTime = _session!['endTime'] as String?;
        if (endTime != null) {
          try {
            final parts = endTime.split(':');
            final end = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
            final now = TimeOfDay.now();
            final remaining = (end.hour * 60 + end.minute) - (now.hour * 60 + now.minute);
            if (remaining <= 10 && remaining > 0) {
              _alerted10min = true;
              _showSnack('⏰ Plus que 10 minutes avant la fin de la séance !', Colors.orange);
            }
          } catch (_) {}
        }
      }
    });
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Duration _plannedDuration() {
    if (_session == null) return Duration.zero;
    try {
      final start = (_session!['startTime'] as String).split(':');
      final end = (_session!['endTime'] as String).split(':');
      final startMin = int.parse(start[0]) * 60 + int.parse(start[1]);
      final endMin = int.parse(end[0]) * 60 + int.parse(end[1]);
      return Duration(minutes: (endMin - startMin).abs());
    } catch (_) {
      return const Duration(hours: 2);
    }
  }

  Future<void> _loadSession() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/education/sessions/${widget.sessionId}');
      final session = Map<String, dynamic>.from(res.data);
      setState(() { _session = session; _loading = false; });
      // Pré-remplir notes privées si existantes
      if (session['providerNotes'] != null) {
        _privateNotesCtrl.text = session['providerNotes'].toString();
      }
      // Démarrer le timer si séance en cours
      if (session['status'] == 'in_progress') {
        _startTimer(session['startTime'] as String? ?? '00:00');
      }
    } catch (e) {
      setState(() { _error = 'Impossible de charger la séance'; _loading = false; });
    }
  }

  Future<void> _startSession() async {
    setState(() { _actionLoading = true; });
    try {
      double lat = 0.0, lng = 0.0;
      try {
        LocationPermission perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          lat = pos.latitude;
          lng = pos.longitude;
        }
      } catch (_) {
        // GPS indisponible — le backend ignore le check si la séance n'a pas de coords
      }

      final api = ref.read(apiClientProvider);
      await api.post('/education/sessions/${widget.sessionId}/start',
          data: {'currentLat': lat, 'currentLng': lng});

      _showSnack('Séance démarrée ✅  OTP envoyé au parent par SMS', Colors.green);
      _elapsed = Duration.zero;
      _alerted10min = false;
      _startTimer(_session?['startTime'] as String? ?? '00:00');
      await _loadSession();
    } catch (e) {
      final msg = _extractError(e);
      _showSnack(msg, Colors.red);
    }
    setState(() { _actionLoading = false; });
  }

  Future<void> _endSession() async {
    if (_otpController.text.trim().length != 6) {
      _showSnack('Entrez le code OTP à 6 chiffres reçu du parent', Colors.orange);
      return;
    }
    setState(() { _actionLoading = true; });
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/education/sessions/${widget.sessionId}/end', data: {
        'otpCode': _otpController.text.trim(),
        if (_homeworkController.text.trim().isNotEmpty)
          'homeworkLeft': _homeworkController.text.trim(),
        'studentState': _studentState,
        if (_suggestionsController.text.trim().isNotEmpty)
          'suggestions': _suggestionsController.text.trim(),
        if (_notesController.text.trim().isNotEmpty)
          'providerNotes': _notesController.text.trim(),
      });

      _showSnack('Séance validée avec succès ✅', Colors.green);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) context.push('/education');
    } catch (e) {
      final msg = _extractError(e);
      _showSnack(msg, Colors.red);
      if (msg.contains('tentative') || msg.contains('incorrect')) {
        setState(() { _otpAttemptsLeft = (_otpAttemptsLeft - 1).clamp(0, 3); });
      }
    }
    setState(() { _actionLoading = false; });
  }

  Future<void> _resendOtp() async {
    setState(() => _actionLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/education/sessions/${widget.sessionId}/resend-otp');
      _showSnack('Code OTP renvoyé au parent par SMS ✅', Colors.green);
    } catch (e) {
      _showSnack(_extractError(e), Colors.orange);
    }
    setState(() => _actionLoading = false);
  }

  Future<void> _saveNotes() async {
    setState(() { _notesSaving = true; _notesSaved = false; });
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/education/sessions/${widget.sessionId}/notes', data: {
        'providerNotes': _privateNotesCtrl.text.trim(),
      });
      setState(() { _notesSaved = true; });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _notesSaved = false);
    } catch (e) {
      _showSnack('Erreur sauvegarde: $e', Colors.red);
    }
    setState(() => _notesSaving = false);
  }

  String _extractError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map && data['message'] != null) return data['message'].toString();
    } catch (_) {}
    return 'Erreur réseau';
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Séance'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        actions: [
          // Bouton message vers le parent / l'enseignant
          if (_session != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Envoyer un message',
              onPressed: () {
                // L'interlocuteur est l'autre partie
                final s = _session!;
                final auth = ref.read(authStateProvider).value?.user;
                final myId = auth?['id'];
                final contactId = s['providerId'] == myId
                    ? s['clientId']
                    : s['providerId'];
                if (contactId != null) {
                  context.push('/messages/chat/$contactId');
                }
              },
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadSession),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _loadSession, child: const Text('Réessayer')),
                  ],
                ))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final s = _session!;
    final status = s['status'] as String? ?? 'scheduled';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(s, status),
          const SizedBox(height: 16),
          if (status == 'scheduled') _buildStartSection(),
          if (status == 'in_progress') ...[
            _buildOtpSection(),
            const SizedBox(height: 16),
            if (_showBilan) _buildBilanForm(),
          ],
          if (status == 'validated') _buildValidatedCard(s),
          if (status == 'cancelled' || status == 'missed') _buildCancelledCard(status),
          // Notes privées — visibles pour l'enseignant dans tous les statuts
          if (s['providerId'] == ref.read(authStateProvider).value?.user?['id']) ...[
            const SizedBox(height: 16),
            _buildPrivateNotes(),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(Map<String, dynamic> s, String status) {
    final statusColors = {
      'scheduled': Colors.blue,
      'in_progress': Colors.orange,
      'validated': Colors.green,
      'cancelled': Colors.red,
      'missed': Colors.grey,
    };
    final statusLabels = {
      'scheduled': 'Planifiée',
      'in_progress': 'En cours',
      'validated': 'Validée',
      'cancelled': 'Annulée',
      'missed': 'Manquée',
    };

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (statusColors[status] ?? Colors.grey).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColors[status] ?? Colors.grey),
                  ),
                  child: Text(
                    statusLabels[status] ?? status,
                    style: TextStyle(color: statusColors[status], fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                if (s['isRattrapage'] == true) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.purple),
                    ),
                    child: const Text('Rattrapage', style: TextStyle(color: Colors.purple, fontSize: 12)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.calendar_today, 'Date', _formatDate(s['sessionDate'])),
            _infoRow(Icons.access_time, 'Horaire', '${s['startTime'] ?? '--:--'} → ${s['endTime'] ?? '--:--'}'),
            _infoRow(Icons.location_on, 'Lieu', s['locationAddress'] ?? 'Non précisé'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1976D2)),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black54)),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildStartSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.play_circle_outline, color: Color(0xFF1976D2)),
                SizedBox(width: 8),
                Text('Démarrer la séance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'En appuyant sur Démarrer :\n'
                      '• Votre position GPS sera vérifiée (≤ 200m du domicile)\n'
                      '• Un code OTP à 6 chiffres sera envoyé par SMS au parent\n'
                      '• Le parent vous dictera ce code uniquement en fin de séance',
                      style: TextStyle(fontSize: 13, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _actionLoading ? null : _startSession,
                icon: _actionLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow),
                label: const Text('Démarrer la séance', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpSection() {
    final planned = _plannedDuration();
    final progress = planned.inSeconds > 0
        ? (_elapsed.inSeconds / planned.inSeconds).clamp(0.0, 1.0)
        : 0.0;
    final isOvertime = _elapsed > planned;

    return Column(children: [
      // ── Chronomètre ─────────────────────────────────────────────────────
      Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: isOvertime ? Colors.red.shade50 : Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Temps écoulé',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(
                  _formatElapsed(_elapsed),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: isOvertime ? Colors.red : Colors.green.shade700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Durée prévue',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(
                  _formatElapsed(planned),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
              ]),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOvertime ? Colors.red : progress > 0.8
                      ? Colors.orange
                      : Colors.green,
                ),
              ),
            ),
            if (isOvertime)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '⚠️ Dépassement de ${_formatElapsed(_elapsed - planned)}',
                  style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 12),

      // ── Section OTP ──────────────────────────────────────────────────────
      Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_clock, color: Colors.orange),
                SizedBox(width: 8),
                Text('Terminer la séance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sms, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Le parent a reçu un code OTP par SMS au début de la séance.\n'
                      'Demandez-lui de vous le dicter maintenant pour valider la fin.',
                      style: TextStyle(fontSize: 13, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Code OTP dicté par le parent',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 10),
              decoration: InputDecoration(
                counterText: '',
                hintText: '• • • • • •',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
                ),
              ),
            ),
            if (_otpAttemptsLeft < 3) ...[
              const SizedBox(height: 6),
              Text(
                '$_otpAttemptsLeft tentative${_otpAttemptsLeft > 1 ? 's' : ''} restante${_otpAttemptsLeft > 1 ? 's' : ''}',
                style: TextStyle(
                    color: _otpAttemptsLeft == 1 ? Colors.red : Colors.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ],
            const SizedBox(height: 16),
            // Renvoyer OTP si parent hors réseau
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _actionLoading ? null : _resendOtp,
                    icon: const Icon(Icons.sms_failed_outlined, color: Colors.grey),
                    label: const Text('Parent n\'a pas reçu le code ?',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ),
              ],
            ),
            if (!_showBilan)
              TextButton.icon(
                onPressed: () => setState(() => _showBilan = true),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Remplir le bilan de séance (optionnel)'),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _actionLoading ? null : _endSession,
                icon: _actionLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Valider la fin de séance', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    )]);
  }

  Widget _buildBilanForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_outlined, color: Color(0xFF1976D2)),
                const SizedBox(width: 8),
                const Text('Bilan de séance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _showBilan = false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('État de l\'élève', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _stateChip('good', '😊 Bon', Colors.green),
                _stateChip('average', '😐 Moyen', Colors.orange),
                _stateChip('struggling', '😟 Difficile', Colors.red),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _homeworkController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Devoir laissé',
                hintText: 'Ex: Exercices page 45, révision leçon 3...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _suggestionsController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Suggestions pour les parents',
                hintText: 'Ex: Acheter le cahier de maths...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes privées (non partagées)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stateChip(String value, String label, Color color) {
    final selected = _studentState == value;
    return GestureDetector(
      onTap: () => setState(() => _studentState = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: selected ? color : Colors.grey.shade600,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildPrivateNotes() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.lock_outline, color: Colors.purple, size: 20),
            const SizedBox(width: 8),
            const Text('Notes privées', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_notesSaved)
              const Row(children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text('Sauvegardé', style: TextStyle(color: Colors.green, fontSize: 12)),
              ]),
          ]),
          const SizedBox(height: 6),
          Text(
            'Visible uniquement par vous — non partagé avec le parent',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _privateNotesCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Observations, difficultés spécifiques, méthodes efficaces...',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.purple, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _notesSaving ? null : _saveNotes,
              icon: _notesSaving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Sauvegarder les notes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildValidatedCard(Map<String, dynamic> s) {
    return Card(
      elevation: 2,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('Séance validée ✅',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            if (s['homeworkLeft'] != null && s['homeworkLeft'] != '')
              _infoRow(Icons.book_outlined, 'Devoir', s['homeworkLeft']),
            if (s['studentState'] != null)
              _infoRow(Icons.face, 'État élève', _stateLabel(s['studentState'])),
            if (s['suggestions'] != null && s['suggestions'] != '')
              _infoRow(Icons.lightbulb_outline, 'Suggestions', s['suggestions']),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/education'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Retour aux séances'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledCard(String status) {
    return Card(
      elevation: 2,
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(status == 'missed' ? Icons.event_busy : Icons.cancel_outlined,
                color: Colors.grey, size: 40),
            const SizedBox(height: 8),
            Text(
              status == 'missed' ? 'Séance manquée' : 'Séance annulée',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/education'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Retour aux séances'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stateLabel(String state) {
    switch (state) {
      case 'good': return '😊 Bon';
      case 'average': return '😐 Moyen';
      case 'struggling': return '😟 Difficile';
      default: return state;
    }
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return '--';
    try {
      final d = DateTime.parse(raw.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) { return raw.toString(); }
  }
}
