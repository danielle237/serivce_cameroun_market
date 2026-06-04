import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../providers/extras_providers.dart';

class NotificationPrefsScreen extends ConsumerStatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  ConsumerState<NotificationPrefsScreen> createState() =>
      _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState
    extends ConsumerState<NotificationPrefsScreen> {
  // Canaux
  bool _sms       = true;
  bool _whatsapp  = false;
  bool _push      = true;
  // Événements
  bool _priceDrop   = true;
  bool _newProduct  = true;
  bool _orderUpdates= true;
  bool _promoCodes  = true;
  bool _loyalty     = true;

  bool _loaded = false;
  bool _saving = false;

  void _loadPrefs(Map<String, dynamic>? prefs) {
    if (_loaded || prefs == null) return;
    _sms          = prefs['smsEnabled']       as bool? ?? true;
    _whatsapp     = prefs['whatsappEnabled']  as bool? ?? false;
    _push         = prefs['pushEnabled']      as bool? ?? true;
    _priceDrop    = prefs['priceDrop']        as bool? ?? true;
    _newProduct   = prefs['newProduct']       as bool? ?? true;
    _orderUpdates = prefs['orderUpdates']     as bool? ?? true;
    _promoCodes   = prefs['promoCodes']       as bool? ?? true;
    _loyalty      = prefs['loyaltyPoints']    as bool? ?? true;
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(notifPrefsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('🔔 Notifications'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildBody(context),
        data: (prefs) {
          _loadPrefs(prefs);
          return _buildBody(context);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Restez informé des baisses de prix et nouveaux produits Tchokos via SMS ou WhatsApp.',
                style: TextStyle(fontSize: 13),
              )),
            ]),
          ),
          const SizedBox(height: 16),

          // Canaux
          _SwitchSection(
            title: '📡 Canaux de notification',
            items: [
              _SwitchItem(
                icon: Icons.sms_outlined,
                title: 'SMS',
                subtitle: 'Notifications par SMS (MTN/Orange)',
                value: _sms,
                onChanged: (v) => setState(() => _sms = v),
              ),
              _SwitchItem(
                icon: Icons.chat_outlined,
                title: 'WhatsApp',
                subtitle: 'Messages WhatsApp (recommandé)',
                value: _whatsapp,
                onChanged: (v) => setState(() => _whatsapp = v),
                iconColor: Colors.green,
              ),
              _SwitchItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications push',
                subtitle: 'Alertes dans l\'application',
                value: _push,
                onChanged: (v) => setState(() => _push = v),
                iconColor: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Événements
          _SwitchSection(
            title: '📋 Types de notifications',
            items: [
              _SwitchItem(
                icon: Icons.trending_down,
                title: 'Baisse de prix',
                subtitle: 'Quand un produit que vous aimez baisse',
                value: _priceDrop,
                onChanged: (v) => setState(() => _priceDrop = v),
                iconColor: Colors.green,
              ),
              _SwitchItem(
                icon: Icons.new_releases_outlined,
                title: 'Nouveaux produits',
                subtitle: 'Dès qu\'un nouveau produit est ajouté',
                value: _newProduct,
                onChanged: (v) => setState(() => _newProduct = v),
                iconColor: Colors.blue,
              ),
              _SwitchItem(
                icon: Icons.receipt_long_outlined,
                title: 'Suivi de commande',
                subtitle: 'Confirmée, prête, livrée...',
                value: _orderUpdates,
                onChanged: (v) => setState(() => _orderUpdates = v),
                iconColor: Colors.purple,
              ),
              _SwitchItem(
                icon: Icons.local_offer_outlined,
                title: 'Codes promo',
                subtitle: 'Offres exclusives et réductions',
                value: _promoCodes,
                onChanged: (v) => setState(() => _promoCodes = v),
                iconColor: Colors.pink,
              ),
              _SwitchItem(
                icon: Icons.star_outlined,
                title: 'Points fidélité',
                subtitle: 'Quand vous gagnez des points',
                value: _loyalty,
                onChanged: (v) => setState(() => _loyalty = v),
                iconColor: Colors.amber,
              ),
            ],
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
                : const Text('💾 Enregistrer mes préférences',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Vos données ne sont jamais partagées. '
            'Vous pouvez vous désabonner à tout moment.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.put('/marketplace/notifications/prefs', data: {
        'smsEnabled':       _sms,
        'whatsappEnabled':  _whatsapp,
        'pushEnabled':      _push,
        'priceDrop':        _priceDrop,
        'newProduct':       _newProduct,
        'orderUpdates':     _orderUpdates,
        'promoCodes':       _promoCodes,
        'loyaltyPoints':    _loyalty,
      });
      ref.invalidate(notifPrefsProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Préférences sauvegardées'),
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

class _SwitchSection extends StatelessWidget {
  final String title;
  final List<_SwitchItem> items;
  const _SwitchSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            ...items,
          ],
        ),
      );
}

class _SwitchItem extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? iconColor;
  const _SwitchItem({
    required this.icon, required this.title, required this.subtitle,
    required this.value, required this.onChanged, this.iconColor,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
        secondary: Icon(icon, color: iconColor ?? Colors.grey),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        value: value,
        onChanged: onChanged,
        dense: true,
      );
}
