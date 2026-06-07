import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';

class TeacherPortfolioScreen extends ConsumerStatefulWidget {
  final String teacherId;
  const TeacherPortfolioScreen({super.key, required this.teacherId});

  @override
  ConsumerState<TeacherPortfolioScreen> createState() => _TeacherPortfolioScreenState();
}

class _TeacherPortfolioScreenState extends ConsumerState<TeacherPortfolioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _ratings;
  bool _loading = true;
  bool _isOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final myId = ref.read(authStateProvider).value?.user?['id'];
      _isOwnProfile = myId == widget.teacherId;

      final futures = await Future.wait([
        api.get('/users/${widget.teacherId}'),
        api.get('/education/teachers/${widget.teacherId}/ratings'),
      ]);

      setState(() {
        _profile = Map<String, dynamic>.from(futures[0].data);
        _ratings = Map<String, dynamic>.from(futures[1].data);
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Profil introuvable'))
              : NestedScrollView(
                  headerSliverBuilder: (_, __) => [_buildHeader()],
                  body: TabBarView(
                    controller: _tabs,
                    children: [
                      _buildAbout(),
                      _buildRatings(),
                      _buildStats(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    final p = _profile!;
    final trust = num.tryParse(p['trustScore']?.toString() ?? '')?.toInt() ?? 0;
    final avg = num.tryParse(_ratings?['average']?.toString() ?? '')?.toDouble() ?? 0.0;
    final total = num.tryParse(_ratings?['total']?.toString() ?? '')?.toInt() ?? 0;

    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: const Color(0xFF1976D2),
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(height: 40),
              // Photo
              Stack(alignment: Alignment.bottomRight, children: [
                CircleAvatar(
                  radius: 45,
                  backgroundImage: p['profilePhotoUrl'] != null
                      ? NetworkImage(p['profilePhotoUrl']) : null,
                  backgroundColor: Colors.white24,
                  child: p['profilePhotoUrl'] == null
                      ? const Icon(Icons.person, size: 45, color: Colors.white) : null,
                ),
                if (trust >= 80)
                  Container(
                    width: 24, height: 24,
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    child: const Icon(Icons.verified, size: 14, color: Colors.white),
                  ),
              ]),
              const SizedBox(height: 10),
              Text(p['name'] ?? 'Enseignant',
                  style: const TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w700)),
              if (p['city'] != null)
                Text(p['city'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              // Stats rapides
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _quickStat(Icons.star_rounded, avg > 0 ? avg.toStringAsFixed(1) : 'Nouveau', Colors.amber),
                const SizedBox(width: 20),
                _quickStat(Icons.check_circle_outline, '$total avis', Colors.greenAccent),
                const SizedBox(width: 20),
                _quickStat(Icons.shield_outlined, '$trust%', Colors.lightBlueAccent),
              ]),
            ]),
          ),
        ),
      ),
      bottom: TabBar(
        controller: _tabs,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: Colors.white,
        tabs: const [
          Tab(text: 'Profil'),
          Tab(text: 'Avis'),
          Tab(text: 'Stats'),
        ],
      ),
    );
  }

  Widget _quickStat(IconData icon, String value, Color color) => Row(children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(width: 4),
    Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
  ]);

  Widget _buildAbout() {
    final p = _profile!;
    final professions = p['professions'] as List? ?? [];
    final bio = p['bio'] as String?;

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Matières enseignées
      if (professions.isNotEmpty) ...[
        _sectionTitle('📚 Matières enseignées'),
        Wrap(spacing: 8, runSpacing: 6,
          children: professions.map<Widget>((m) => Chip(
            label: Text(m.toString(), style: const TextStyle(fontSize: 12)),
            backgroundColor: const Color(0xFF1976D2).withOpacity(0.1),
            side: const BorderSide(color: Color(0xFF1976D2), width: 0.5),
          )).toList(),
        ),
        const SizedBox(height: 16),
      ],

      // Biographie
      if (bio != null && bio.isNotEmpty) ...[
        _sectionTitle('👤 À propos'),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(bio, style: const TextStyle(fontSize: 14, height: 1.5)),
          ),
        ),
        const SizedBox(height: 16),
      ],

      // Diplômes & certifications
      _sectionTitle('🎓 Diplômes & certifications'),
      _buildDiplomasSection(p),
      const SizedBox(height: 16),

      // Niveaux enseignés
      _sectionTitle('📊 Niveaux enseignés'),
      _buildLevelsSection(p),
    ]);
  }

  Widget _buildDiplomasSection(Map<String, dynamic> p) {
    final diplomas = p['diplomas'] as List? ?? [];
    if (diplomas.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text('Aucun diplôme renseigné',
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
        ),
      );
    }
    return Column(children: diplomas.map<Widget>((d) => Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: const Icon(Icons.school_outlined, color: Color(0xFF1976D2)),
        title: Text(d['title'] as String? ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(d['institution'] as String? ?? '',
            style: const TextStyle(fontSize: 12)),
        trailing: Text(d['year']?.toString() ?? '',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ),
    )).toList());
  }

  Widget _buildLevelsSection(Map<String, dynamic> p) {
    final levels = p['teachingLevels'] as List? ??
        ['CM1', 'CM2', '6ème', '5ème', '4ème', '3ème'];
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(spacing: 8, runSpacing: 6,
          children: levels.map<Widget>((l) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Text(l.toString(),
                style: const TextStyle(fontSize: 12, color: Colors.green,
                    fontWeight: FontWeight.w500)),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildRatings() {
    if (_ratings == null) return const Center(child: CircularProgressIndicator());
    final ratings = _ratings!['ratings'] as List? ?? [];
    final breakdown = _ratings!['breakdown'] as Map<String, dynamic>? ?? {};
    final avg = num.tryParse(_ratings!['average']?.toString() ?? '')?.toDouble() ?? 0.0;

    if (ratings.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.star_border_rounded, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('Aucun avis pour l\'instant',
            style: TextStyle(color: Colors.grey, fontSize: 15)),
      ]));
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Résumé notes
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Text(avg.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800,
                      color: Color(0xFF1976D2))),
              const Text('/5', style: TextStyle(fontSize: 22, color: Colors.grey)),
              const SizedBox(width: 20),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _breakdownRow('Ponctualité', breakdown['punctuality'] ?? 0),
                  _breakdownRow('Pédagogie',   breakdown['pedagogy']      ?? 0),
                  _breakdownRow('Communication', breakdown['communication'] ?? 0),
                ],
              )),
            ]),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      // Liste des avis
      ...ratings.map((r) => _RatingCard(rating: Map<String, dynamic>.from(r))),
    ]);
  }

  Widget _breakdownRow(String label, dynamic value) {
    final v = num.tryParse(value?.toString() ?? '')?.toDouble() ?? 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))),
        Expanded(child: LinearProgressIndicator(
          value: v / 5,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(Color(0xFF1976D2)),
          minHeight: 6,
        )),
        const SizedBox(width: 6),
        Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildStats() {
    final p = _profile!;
    final totalSessions = num.tryParse(p['totalSessions']?.toString() ?? '')?.toInt() ?? 0;
    final trust = num.tryParse(p['trustScore']?.toString() ?? '')?.toInt() ?? 0;
    final avg = num.tryParse(_ratings?['average']?.toString() ?? '')?.toDouble() ?? 0.0;

    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: _StatCard('$totalSessions', 'Séances\neffectuées',
            Icons.event_available_outlined, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard('$trust%', 'Score de\nconfiance',
            Icons.shield_outlined, Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(avg > 0 ? avg.toStringAsFixed(1) : '—', 'Note\nmoyenne',
            Icons.star_rounded, Colors.amber)),
      ]),
    ]);
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
  );
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatCard(this.value, this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Card(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _RatingCard extends StatelessWidget {
  final Map<String, dynamic> rating;
  const _RatingCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    final overall = num.tryParse(rating['overall']?.toString() ?? '')?.toDouble() ?? 0.0;
    final comment = rating['comment'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(radius: 16, backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.person_outline, size: 18, color: Color(0xFF1976D2))),
            const SizedBox(width: 8),
            const Expanded(child: Text('Parent', style: TextStyle(fontWeight: FontWeight.w600))),
            Row(children: List.generate(5, (i) => Icon(
              i < overall ? Icons.star_rounded : Icons.star_border_rounded,
              size: 16, color: Colors.amber,
            ))),
          ]),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comment, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ],
        ]),
      ),
    );
  }
}
