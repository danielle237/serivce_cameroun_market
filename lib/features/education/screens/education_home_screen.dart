import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_translations.dart';

final educationSessionsProvider = FutureProvider.autoDispose<List>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/education/sessions');
  final data = res.data;
  return data is List ? data : (data['data'] ?? data['items'] ?? []);
});

final educationStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  try {
    final res = await api.get('/education/stats');
    return Map<String, dynamic>.from(res.data);
  } catch (_) {
    return {};
  }
});

class EducationHomeScreen extends ConsumerWidget {
  const EducationHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.read(authStateProvider).value?.user;
    final isTeacher = user?['activeMode'] == 'provider';
    final sessionsAsync = ref.watch(educationSessionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(AppTranslations.of(context).t('education_module')),
        actions: [
          if (isTeacher) ...[
            IconButton(
              icon: const Icon(Icons.calendar_view_week_outlined),
              tooltip: AppTranslations.of(context).t('weekly_schedule'),
              onPressed: () => context.push('/education/schedule'),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: AppTranslations.of(context).t('schedule_session'),
              onPressed: () => _showScheduleSheet(context, ref),
            ),
          ],
          if (!isTeacher) ...[
            IconButton(
              icon: const Icon(Icons.calendar_view_week_outlined),
              tooltip: AppTranslations.of(context).t('class_schedule'),
              onPressed: () => context.push('/education/schedule-parent'),
            ),
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: AppTranslations.of(context).t('monthly_summary'),
              onPressed: () => context.push('/education/billing'),
            ),
            // Accès direct aux cahiers de suivi des élèves
            IconButton(
              icon: const Icon(Icons.menu_book_outlined),
              tooltip: AppTranslations.of(context).t('follow_up_books'),
              onPressed: () {
                // Cherche le premier contrat actif avec séance validée
                final data = ref.read(educationSessionsProvider).value ?? [];
                final withContract = data.where((s) =>
                    s['contractId'] != null && s['status'] == 'validated').toList();
                if (withContract.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(AppTranslations.of(context).t('no_books_available')),
                    backgroundColor: Colors.orange,
                  ));
                  return;
                }
                // Si un seul contrat → y aller directement
                if (withContract.length == 1) {
                  context.push('/education/notebook/${withContract.first['contractId']}',
                      extra: {'studentName': withContract.first['providerName'] ?? 'Enseignant'});
                  return;
                }
                // Plusieurs → afficher un choix
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                  builder: (_) => _NotebookPickerSheet(sessions: withContract),
                );
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.groups_outlined),
            tooltip: 'Cours en groupe',
            onPressed: () => context.push('/education/groups'),
          ),
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: isTeacher ? 'Voir les annonces' : 'Chercher un enseignant',
            onPressed: () => context.push('/education/requests'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(educationSessionsProvider),
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(error: e.toString(), onRetry: () => ref.invalidate(educationSessionsProvider)),
        data: (sessions) => Column(children: [
          if (isTeacher)
            _TeacherDashboard(sessions: sessions, ref: ref),
          Expanded(child: _SessionList(sessions: sessions, isTeacher: isTeacher, ref: ref)),
        ]),
      ),
    );
  }

  void _showScheduleSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleSessionSheet(onSaved: () => ref.invalidate(educationSessionsProvider)),
    );
  }
}

// ── Tableau de bord enseignant ────────────────────────────────────────────────
class _TeacherDashboard extends StatelessWidget {
  final List sessions;
  final WidgetRef ref;
  const _TeacherDashboard({required this.sessions, required this.ref});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = sessions.where((s) {
      try {
        final d = DateTime.parse(s['sessionDate'].toString());
        return d.month == now.month && d.year == now.year && s['status'] == 'validated';
      } catch (_) { return false; }
    }).toList();

    final activeClients = sessions
        .where((s) => s['status'] != 'cancelled')
        .map((s) => s['clientId'] ?? s['client_id'])
        .toSet()
        .length;

    final nextSession = sessions.where((s) => s['status'] == 'scheduled').firstOrNull;

    final statsAsync = ref.watch(educationStatsProvider);
    final monthRevenue = statsAsync.when(
      data: (d) => d['monthRevenue'] ?? 0,
      loading: () => null,
      error: (_, __) => 0,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF1976D2).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ce mois-ci', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _DashStat(
            icon: Icons.check_circle_outline,
            value: '${thisMonth.length}',
            label: 'Séances validées',
            color: Colors.greenAccent,
          )),
          Expanded(child: _DashStat(
            icon: Icons.people_outline,
            value: '$activeClients',
            label: 'Élèves actifs',
            color: Colors.lightBlueAccent,
          )),
          Expanded(child: _DashStat(
            icon: Icons.account_balance_wallet_outlined,
            value: monthRevenue == null ? '...' : '${monthRevenue} XAF',
            label: 'Revenus',
            color: Colors.amberAccent,
          )),
        ]),
        if (nextSession != null) ...[
          const SizedBox(height: 10),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.upcoming_outlined, color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              'Prochaine séance : ${_fmtDate(nextSession['sessionDate'])} à ${nextSession['startTime'] ?? ''}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ]),
        ],
      ]),
    );
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final d = DateTime.parse(raw.toString());
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    } catch (_) { return raw.toString(); }
  }
}

class _DashStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _DashStat({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10), textAlign: TextAlign.center),
    ]);
  }
}

// ── Liste des séances ─────────────────────────────────────────────────────────
class _SessionList extends StatelessWidget {
  final List sessions;
  final bool isTeacher;
  final WidgetRef ref;
  const _SessionList({required this.sessions, required this.isTeacher, required this.ref});

  @override
  Widget build(BuildContext context) {
    // Séparer par statut
    final active    = sessions.where((s) => s['status'] == 'in_progress').toList();
    final scheduled = sessions.where((s) => s['status'] == 'scheduled').toList();
    final missed    = sessions.where((s) => s['status'] == 'missed').toList();
    final past      = sessions.where((s) => ['validated', 'cancelled'].contains(s['status'])).toList();

    if (sessions.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.school_outlined, size: 80, color: AppColors.textLight),
          const SizedBox(height: 16),
          const Text('Aucune séance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            isTeacher ? 'Planifiez votre première séance avec le + en haut' : 'Votre enseignant n\'a pas encore planifié de séance',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(educationSessionsProvider),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bandeau info OTP inversé
          _InfoBanner(isTeacher: isTeacher),
          const SizedBox(height: 16),

          if (active.isNotEmpty) ...[
            _SectionTitle(title: '🔴 En cours', count: active.length),
            ...active.map((s) => _SessionCard(session: s, isTeacher: isTeacher, highlight: true)),
            const SizedBox(height: 8),
          ],

          if (missed.isNotEmpty) ...[
            _SectionTitle(title: '⚠️ Séances manquées', count: missed.length),
            ...missed.map((s) => _SessionCard(session: s, isTeacher: isTeacher)),
            const SizedBox(height: 8),
          ],

          if (scheduled.isNotEmpty) ...[
            _SectionTitle(title: '📅 Planifiées', count: scheduled.length),
            ...scheduled.map((s) => _SessionCard(session: s, isTeacher: isTeacher)),
            const SizedBox(height: 8),
          ],

          if (past.isNotEmpty) ...[
            _SectionTitle(title: '✅ Historique', count: past.length),
            ...past.map((s) => _SessionCard(session: s, isTeacher: isTeacher)),
          ],
        ],
      ),
    );
  }
}

// ── Carte séance ──────────────────────────────────────────────────────────────
class _SessionCard extends StatelessWidget {
  final dynamic session;
  final bool isTeacher;
  final bool highlight;
  const _SessionCard({required this.session, required this.isTeacher, this.highlight = false});

  Color get _statusColor {
    switch (session['status']) {
      case 'validated':  return AppColors.success;
      case 'in_progress': return AppColors.error;
      case 'scheduled':  return AppColors.primary;
      case 'missed':     return Colors.orange;
      case 'cancelled':  return AppColors.textSecondary;
      default:           return AppColors.textSecondary;
    }
  }

  String get _statusLabel {
    switch (session['status']) {
      case 'validated':   return '✅ Validée';
      case 'in_progress': return '🔴 En cours';
      case 'scheduled':   return '📅 Planifiée';
      case 'missed':      return '⚠️ Manquée';
      case 'cancelled':   return '❌ Annulée';
      default:            return session['status'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRattrapage = session['is_rattrapage'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: highlight ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: highlight ? const BorderSide(color: AppColors.error, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: ['in_progress', 'scheduled'].contains(session['status'])
            ? () => context.push('/education/session/${session['id']}')
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (isRattrapage)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                  child: const Text('RATTRAPAGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(_statusLabel, style: TextStyle(color: _statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Text(
                session['sessionDate'] != null
                    ? DateFormat('dd/MM/yyyy').format(DateTime.tryParse(session['sessionDate'].toString()) ?? DateTime.now())
                    : '',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${session['startTime'] ?? '--:--'} — ${session['endTime'] ?? '--:--'}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ]),
            if (session['location_address'] != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.home_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(session['location_address'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
              ]),
            ],
            if (session['status'] == 'validated' && session['homework_left'] != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.book_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(child: Text('Devoir: ${session['homework_left']}', style: const TextStyle(fontSize: 13))),
              ]),
              if (session['student_state'] != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.emoji_emotions_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('Élève: ${_stateLabel(session['student_state'])}', style: const TextStyle(fontSize: 13)),
                ]),
              ],
            ],
            // Bouton rattrapage si séance manquée et enseignant
            if (session['status'] == 'missed' && isTeacher) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showRattrapageSheet(context, session['id']),
                  icon: const Icon(Icons.event_repeat, size: 18),
                  label: const Text('Planifier un rattrapage'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                ),
              ),
            ],
            // Bouton démarrer si planifiée et enseignant
            if (session['status'] == 'scheduled' && isTeacher) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/education/session/${session['id']}'),
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('Démarrer la séance'),
                ),
              ),
            ],
            // Bouton évaluer — séances validées
            if (session['status'] == 'validated') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push(
                    '/education/rate/${session['id']}',
                    extra: session,
                  ),
                  icon: const Icon(Icons.star_outline_rounded, size: 16),
                  label: const Text('Évaluer cette séance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
            // Bouton litige (parent, séance validée, pas de litige ouvert)
            if (!isTeacher &&
                session['status'] == 'validated' &&
                (session['disputeStatus'] == null || session['disputeStatus'] == 'none')) ...[
              const SizedBox(height: 6),
              _SessionDisputeButton(sessionId: session['id'] as String),
            ],
            if (!isTeacher && session['disputeStatus'] != null && session['disputeStatus'] != 'none') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.gavel_outlined, color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    session['disputeStatus'] == 'open' ? '⚖️ Litige en cours d\'examen' : '✅ Litige résolu',
                    style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            ],

            // Bouton carnet élève — séances validées avec un contrat
            if (session['status'] == 'validated' && session['contractId'] != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/education/notebook/${session['contractId']}',
                    extra: {'studentName': isTeacher
                        ? (session['clientName'] ?? 'Élève')
                        : (session['providerName'] ?? 'Enseignant')},
                  ),
                  icon: const Icon(Icons.menu_book_outlined, size: 16),
                  label: const Text('Carnet de l\'élève'),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1976D2)),
                ),
              ),
            ],
            // Bouton annuler (séances planifiées uniquement)
            if (session['status'] == 'scheduled') ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _CancelSessionButton(session: session),
              ),
            ],

            // Bouton message — toujours visible (sauf séances annulées)
            if (session['status'] != 'cancelled') ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton.icon(
                  onPressed: () {
                    final contactId = isTeacher
                        ? session['client_id']
                        : session['provider_id'];
                    if (contactId != null) {
                      context.push('/messages/chat/$contactId');
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text(
                    isTeacher ? 'Message au parent' : 'Message à l\'enseignant',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  String _stateLabel(String? state) {
    switch (state) {
      case 'good':      return 'Bien 😊';
      case 'average':   return 'Moyen 😐';
      case 'struggling': return 'En difficulté 😟';
      default:          return state ?? '';
    }
  }

  void _showRattrapageSheet(BuildContext context, String sessionId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RattrapageSheet(missedSessionId: sessionId),
    );
  }
}

// ── Sheet planifier séance ────────────────────────────────────────────────────
class _ScheduleSessionSheet extends ConsumerStatefulWidget {
  final VoidCallback onSaved;
  const _ScheduleSessionSheet({required this.onSaved});

  @override
  ConsumerState<_ScheduleSessionSheet> createState() => _ScheduleSessionSheetState();
}

class _ScheduleSessionSheetState extends ConsumerState<_ScheduleSessionSheet> {
  final _addressCtrl    = TextEditingController();
  final _contractCtrl   = TextEditingController();
  DateTime _date        = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime  = const TimeOfDay(hour: 15, minute: 0);
  TimeOfDay _endTime    = const TimeOfDay(hour: 17, minute: 0);
  bool _loading         = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24, right: 24, top: 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Planifier une séance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),

        TextField(
          controller: _contractCtrl,
          decoration: const InputDecoration(labelText: 'ID du contrat', prefixIcon: Icon(Icons.assignment)),
        ),
        const SizedBox(height: 12),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today, color: AppColors.primary),
          title: Text('Date: ${DateFormat('dd/MM/yyyy').format(_date)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: () async {
            final d = await showDatePicker(
              context: context, initialDate: _date,
              firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)),
            );
            if (d != null) setState(() => _date = d);
          },
        ),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.access_time, color: AppColors.primary),
          title: Text('Horaire: ${_startTime.format(context)} → ${_endTime.format(context)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: () async {
            final t1 = await showTimePicker(context: context, initialTime: _startTime);
            if (t1 != null) {
              setState(() => _startTime = t1);
              final t2 = await showTimePicker(context: context, initialTime: _endTime);
              if (t2 != null) setState(() => _endTime = t2);
            }
          },
        ),

        TextField(
          controller: _addressCtrl,
          decoration: const InputDecoration(labelText: 'Adresse du domicile', prefixIcon: Icon(Icons.home)),
        ),

        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Planifier'),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    if (_contractCtrl.text.isEmpty || _addressCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remplissez tous les champs'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/education/sessions', data: {
        'contractId':      _contractCtrl.text.trim(),
        'sessionDate':     DateFormat('yyyy-MM-dd').format(_date),
        'startTime':       '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        'endTime':         '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
        'locationAddress': _addressCtrl.text.trim(),
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Sheet rattrapage ──────────────────────────────────────────────────────────
class _RattrapageSheet extends ConsumerStatefulWidget {
  final String missedSessionId;
  const _RattrapageSheet({required this.missedSessionId});

  @override
  ConsumerState<_RattrapageSheet> createState() => _RattrapageSheetState();
}

class _RattrapageSheetState extends ConsumerState<_RattrapageSheet> {
  final _reasonCtrl    = TextEditingController();
  DateTime _date       = DateTime.now().add(const Duration(days: 2));
  TimeOfDay _startTime = const TimeOfDay(hour: 15, minute: 0);
  TimeOfDay _endTime   = const TimeOfDay(hour: 17, minute: 0);
  bool _loading        = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Planifier un rattrapage', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('La séance manquée sera reprogrammée automatiquement.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 20),

        TextField(
          controller: _reasonCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Raison de l\'absence', prefixIcon: Icon(Icons.info_outline)),
        ),
        const SizedBox(height: 12),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today, color: Colors.orange),
          title: Text('Nouvelle date: ${DateFormat('dd/MM/yyyy').format(_date)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
            if (d != null) setState(() => _date = d);
          },
        ),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.access_time, color: Colors.orange),
          title: Text('Horaire: ${_startTime.format(context)} → ${_endTime.format(context)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          onTap: () async {
            final t1 = await showTimePicker(context: context, initialTime: _startTime);
            if (t1 != null) setState(() => _startTime = t1);
            final t2 = await showTimePicker(context: context, initialTime: _endTime);
            if (t2 != null) setState(() => _endTime = t2);
          },
        ),

        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Confirmer le rattrapage'),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    if (_reasonCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indiquez la raison'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/education/sessions/${widget.missedSessionId}/rattrapage', data: {
        'reason': _reasonCtrl.text.trim(),
        'rattrapageDate': DateFormat('yyyy-MM-dd').format(_date),
        'rattrapageStartTime': '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
        'rattrapageEndTime': '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rattrapage planifié ✅'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Widgets helper ────────────────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  final bool isTeacher;
  const _InfoBanner({required this.isTeacher});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.security, color: AppColors.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(
          isTeacher
              ? '🔒 Système OTP inversé: le code de fin de séance est envoyé par SMS uniquement au parent. Demandez-lui en fin de cours.'
              : '📱 Vous recevrez un SMS avec le code de fin de séance. Dictez-le à l\'enseignant uniquement à la fin du cours.',
          style: const TextStyle(fontSize: 12, color: AppColors.primary),
        )),
      ]),
    );
  }
}

// ── Bouton litige séance éducation ───────────────────────────────────────────
class _SessionDisputeButton extends ConsumerStatefulWidget {
  final String sessionId;
  const _SessionDisputeButton({required this.sessionId});
  @override
  ConsumerState<_SessionDisputeButton> createState() => _SessionDisputeButtonState();
}

class _SessionDisputeButtonState extends ConsumerState<_SessionDisputeButton> {
  bool _loading = false;

  Future<void> _open() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ouvrir un litige'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
            'Expliquez le problème avec cette séance (contenu non conforme, enseignant absent, etc.)',
            style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          TextField(controller: reasonCtrl, maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Raison *', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Text(
              'L\'équipe W2D arbitrera sur la base des informations disponibles.',
              style: TextStyle(fontSize: 12, color: Colors.orange)),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Ouvrir le litige')),
        ],
      ),
    );
    if (ok != true || reasonCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).post(
        '/education/sessions/${widget.sessionId}/dispute',
        data: {'reason': reasonCtrl.text.trim()},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⚖️ Litige ouvert. L\'équipe W2D va examiner.'),
          backgroundColor: Colors.orange,
        ));
        ref.invalidate(educationSessionsProvider);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _loading ? null : _open,
    icon: const Icon(Icons.gavel_outlined, size: 16),
    label: const Text('Signaler un problème', style: TextStyle(fontSize: 12)),
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.red,
      side: const BorderSide(color: Colors.red),
      padding: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

// ── Bouton annulation avec préavis ───────────────────────────────────────────
class _CancelSessionButton extends ConsumerStatefulWidget {
  final Map session;
  const _CancelSessionButton({required this.session});
  @override
  ConsumerState<_CancelSessionButton> createState() => _CancelSessionButtonState();
}

class _CancelSessionButtonState extends ConsumerState<_CancelSessionButton> {
  bool _loading = false;

  String _getPenaltyWarning() {
    final dateStr = widget.session['sessionDate'] as String?;
    final timeStr = widget.session['startTime'] as String?;
    if (dateStr == null) return 'Annulation gratuite si > 24h de préavis.';
    try {
      final dt = DateTime.parse('${dateStr}T${timeStr ?? '08:00'}');
      final hours = dt.difference(DateTime.now()).inHours;
      if (hours < 2) return '⚠️ Moins de 2h : séance décomptée (100%)';
      if (hours < 24) return '⚠️ Moins de 24h : 50% du tarif retenu';
      return '✅ Annulation gratuite (plus de 24h de préavis)';
    } catch (_) { return ''; }
  }

  Future<void> _cancel() async {
    final reasonCtrl = TextEditingController();
    final warning = _getPenaltyWarning();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler la séance ?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: warning.startsWith('⚠️') ? Colors.orange.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(warning, style: TextStyle(
              fontSize: 13,
              color: warning.startsWith('⚠️') ? Colors.orange : Colors.green,
              fontWeight: FontWeight.w600,
            )),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(
              labelText: 'Raison de l\'annulation *',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Garder')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Confirmer l\'annulation'),
          ),
        ],
      ),
    );
    if (ok != true || reasonCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.patch(
        '/education/sessions/${widget.session['id']}/cancel',
        data: {'reason': reasonCtrl.text.trim()},
      );
      if (mounted) {
        final penalty = res.data['penalty'] as String? ?? '';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Séance annulée${penalty.isNotEmpty ? ' — $penalty' : ''}'),
          backgroundColor: Colors.orange,
        ));
        ref.invalidate(educationSessionsProvider);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _loading ? null : _cancel,
    icon: _loading
        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.cancel_outlined, size: 16),
    label: const Text('Annuler cette séance'),
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.red,
      side: const BorderSide(color: Colors.red),
      padding: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

// ── Sélecteur de cahier de suivi ──────────────────────────────────────────────
class _NotebookPickerSheet extends StatelessWidget {
  final List sessions;
  const _NotebookPickerSheet({required this.sessions});

  @override
  Widget build(BuildContext context) {
    // Dédupliquer par contractId
    final seen = <String>{};
    final unique = sessions.where((s) {
      final id = s['contractId'] as String?;
      if (id == null || seen.contains(id)) return false;
      seen.add(id);
      return true;
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        const Text('Choisir un cahier de suivi',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const Divider(),
        ...unique.map((s) => ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0x1A1976D2),
            child: Icon(Icons.menu_book_outlined, color: Color(0xFF1976D2), size: 18),
          ),
          title: Text(s['providerName'] as String? ?? 'Enseignant',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(s['subject'] as String? ?? '',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          onTap: () {
            Navigator.pop(context);
            context.push('/education/notebook/${s['contractId']}',
                extra: {'studentName': s['providerName'] ?? 'Enseignant'});
          },
        )),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  const _SectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Text('$count', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, size: 64, color: AppColors.error),
      const SizedBox(height: 16),
      Text(error, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: onRetry, child: const Text('Réessayer')),
    ]));
    }
}
