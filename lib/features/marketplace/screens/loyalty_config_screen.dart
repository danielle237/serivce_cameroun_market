import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../providers/extras_providers.dart';

class LoyaltyConfigScreen extends ConsumerStatefulWidget {
  const LoyaltyConfigScreen({super.key});

  @override
  ConsumerState<LoyaltyConfigScreen> createState() => _LoyaltyConfigScreenState();
}

class _LoyaltyConfigScreenState extends ConsumerState<LoyaltyConfigScreen> {
  final _p1000Ctrl     = TextEditingController();
  final _silverCtrl    = TextEditingController();
  final _goldCtrl      = TextEditingController();
  final _vipCtrl       = TextEditingController();
  final _bronzeDiscCtrl= TextEditingController();
  final _silverDiscCtrl= TextEditingController();
  final _goldDiscCtrl  = TextEditingController();
  final _vipDiscCtrl   = TextEditingController();
  final _pointValCtrl  = TextEditingController();
  bool _isActive = true;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_p1000Ctrl,_silverCtrl,_goldCtrl,_vipCtrl,
        _bronzeDiscCtrl,_silverDiscCtrl,_goldDiscCtrl,_vipDiscCtrl,_pointValCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadConfig(Map<String, dynamic> cfg) {
    if (_loaded) return;
    _p1000Ctrl.text      = '${cfg['pointsPer1000'] ?? 10}';
    _silverCtrl.text     = '${cfg['silverThreshold'] ?? 500}';
    _goldCtrl.text       = '${cfg['goldThreshold'] ?? 2000}';
    _vipCtrl.text        = '${cfg['vipThreshold'] ?? 5000}';
    _bronzeDiscCtrl.text = '${cfg['bronzeDiscount'] ?? 0}';
    _silverDiscCtrl.text = '${cfg['silverDiscount'] ?? 5}';
    _goldDiscCtrl.text   = '${cfg['goldDiscount'] ?? 10}';
    _vipDiscCtrl.text    = '${cfg['vipDiscount'] ?? 15}';
    _pointValCtrl.text   = '${cfg['pointValue'] ?? 10}';
    _isActive = cfg['isActive'] as bool? ?? true;
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(loyaltyConfigProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('⚙️ Config Programme Fidélité'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (cfg) {
          _loadConfig(cfg);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Activer/désactiver
              _Section(title: '🔘 Statut', child: SwitchListTile(
                title: const Text('Programme fidélité actif'),
                subtitle: const Text('Désactiver arrête le cumul de points'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
              )),
              const SizedBox(height: 12),

              // Gain de points
              _Section(
                title: '📊 Gain de points',
                child: _Field(_p1000Ctrl, 'Points par 1 000 FCFA dépensés', suffix: 'pts'),
              ),
              const SizedBox(height: 12),

              // Seuils de niveau
              _Section(
                title: '🏆 Seuils de niveau',
                child: Column(children: [
                  _Field(_silverCtrl, '🥈 Silver à partir de', suffix: 'pts'),
                  const SizedBox(height: 10),
                  _Field(_goldCtrl, '🥇 Gold à partir de', suffix: 'pts'),
                  const SizedBox(height: 10),
                  _Field(_vipCtrl, '👑 VIP à partir de', suffix: 'pts'),
                ]),
              ),
              const SizedBox(height: 12),

              // Réductions par niveau
              _Section(
                title: '🎁 Réductions automatiques par niveau',
                child: Column(children: [
                  _Field(_bronzeDiscCtrl, '🥉 Bronze', suffix: '%'),
                  const SizedBox(height: 10),
                  _Field(_silverDiscCtrl, '🥈 Silver', suffix: '%'),
                  const SizedBox(height: 10),
                  _Field(_goldDiscCtrl, '🥇 Gold', suffix: '%'),
                  const SizedBox(height: 10),
                  _Field(_vipDiscCtrl, '👑 VIP', suffix: '%'),
                ]),
              ),
              const SizedBox(height: 12),

              // Valeur d'un point
              _Section(
                title: '💎 Valeur d\'un point',
                child: _Field(_pointValCtrl, '1 point =', suffix: 'FCFA'),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('💾 Enregistrer la configuration',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/marketplace/loyalty/config', data: {
        'pointsPer1000':    int.tryParse(_p1000Ctrl.text)     ?? 10,
        'silverThreshold':  int.tryParse(_silverCtrl.text)    ?? 500,
        'goldThreshold':    int.tryParse(_goldCtrl.text)      ?? 2000,
        'vipThreshold':     int.tryParse(_vipCtrl.text)       ?? 5000,
        'bronzeDiscount':   int.tryParse(_bronzeDiscCtrl.text) ?? 0,
        'silverDiscount':   int.tryParse(_silverDiscCtrl.text) ?? 5,
        'goldDiscount':     int.tryParse(_goldDiscCtrl.text)  ?? 10,
        'vipDiscount':      int.tryParse(_vipDiscCtrl.text)   ?? 15,
        'pointValue':       int.tryParse(_pointValCtrl.text)  ?? 10,
        'isActive':         _isActive,
      });
      ref.invalidate(loyaltyConfigProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Configuration sauvegardée'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          child,
        ]),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? suffix;
  const _Field(this.ctrl, this.label, {this.suffix});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}
