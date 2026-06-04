import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../models/product.dart';
import '../models/shop_product.dart';
import '../providers/marketplace_providers.dart';

// ── Modèle léger pour le formulaire ──────────────────────────────────────────
class _Variant {
  String variant1;
  String? variant2;
  int stock;
  _Variant({required this.variant1, this.variant2, required this.stock});
}

class _PriceTier {
  int minQty;
  int? maxQty;
  double price;
  _PriceTier({required this.minQty, this.maxQty, required this.price});
}

// ═════════════════════════════════════════════════════════════════════════════
class VendorProductFormScreen extends ConsumerStatefulWidget {
  /// null = création, non-null = modification
  final ShopProduct? product;

  const VendorProductFormScreen({super.key, this.product});

  @override
  ConsumerState<VendorProductFormScreen> createState() =>
      _VendorProductFormScreenState();
}

class _VendorProductFormScreenState
    extends ConsumerState<VendorProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Champs texte
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _retailPriceCtrl = TextEditingController();
  final _oldPriceCtrl = TextEditingController();

  // Sélections
  String _category = 'textile';
  String _badge = 'none';
  bool _isActive = true;
  bool _isPinned = false;

  // Photos
  final List<String> _existingPhotos = []; // URLs déjà en BDD
  final List<XFile> _newPhotos = [];       // Fichiers à uploader
  bool _uploadingPhotos = false;

  // Couleurs
  final List<String> _colors = [];
  final _colorCtrl = TextEditingController();

  // Variantes
  final List<_Variant> _variants = [];

  // Paliers prix gros
  final List<_PriceTier> _tiers = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _nameCtrl.text = p.name;
      _descCtrl.text = p.description ?? '';
      _retailPriceCtrl.text = p.retailPrice.toStringAsFixed(0);
      _oldPriceCtrl.text = p.oldPrice?.toStringAsFixed(0) ?? '';
      _category = p.category.name;
      _badge = p.badge.name;
      _isActive = p.isActive;
      _isPinned = p.isPinned;
      _existingPhotos.addAll(p.photos);
      _colors.addAll(p.colors);
      for (final v in p.variants) {
        _variants.add(_Variant(
          variant1: v.variant1 ?? '',
          variant2: v.variant2,
          stock: v.stock,
        ));
      }
      for (final t in p.priceTiers) {
        _tiers.add(_PriceTier(
          minQty: t.minQty,
          maxQty: t.maxQty,
          price: t.price.toDouble(),
        ));
      }
    } else {
      // Variante par défaut
      _variants.add(_Variant(variant1: 'M', stock: 0));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _retailPriceCtrl.dispose();
    _oldPriceCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  // ── Picker photos ─────────────────────────────────────────────────────────
  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    // Redimensionner à 800px max et 80% qualité directement au pick
    // (évite d'uploader des photos 12MP depuis les Android camerounais)
    final picked = await picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked.isEmpty) return;

    final remaining = 5 - _existingPhotos.length - _newPhotos.length;
    if (remaining <= 0) {
      _snack('Maximum 5 photos par produit');
      return;
    }
    setState(() => _newPhotos.addAll(picked.take(remaining)));
  }

  // ── Upload vers /media/image ──────────────────────────────────────────────
  Future<List<String>> _uploadNewPhotos() async {
    if (_newPhotos.isEmpty) return [];
    final api = ref.read(apiClientProvider);
    final urls = <String>[];

    for (final xfile in _newPhotos) {
      try {
        // Les photos ont déjà été redimensionnées (800px max, 80% qualité)
        // par image_picker au moment du pick — upload direct.
        final FormData form;
        if (kIsWeb) {
          final bytes = await xfile.readAsBytes();
          form = FormData.fromMap({
            'file': MultipartFile.fromBytes(bytes, filename: xfile.name),
          });
        } else {
          form = FormData.fromMap({
            'file': await MultipartFile.fromFile(xfile.path, filename: xfile.name),
          });
        }
        final res = await api.postForm('/media/image', data: form);
        final url = res.data['url'] as String;
        urls.add(url);
      } catch (e) {
        debugPrint('Upload photo erreur: $e');
      }
    }
    return urls;
  }

  // ── Sauvegarder ──────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_existingPhotos.isEmpty && _newPhotos.isEmpty) {
      _snack('Ajoutez au moins une photo');
      return;
    }

    setState(() => _saving = true);

    try {
      // 1. Upload nouvelles photos
      setState(() => _uploadingPhotos = true);
      final newUrls = await _uploadNewPhotos();
      setState(() => _uploadingPhotos = false);

      final allPhotos = [..._existingPhotos, ...newUrls];

      // 2. Construire le body
      final body = {
        'shopId':       AppConfig.shopId,
        'name':         _nameCtrl.text.trim(),
        'description':  _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'category':     _category,
        'photos':       allPhotos,
        'retailPrice':  double.parse(_retailPriceCtrl.text.trim()),
        'oldPrice':     _oldPriceCtrl.text.trim().isEmpty
            ? null
            : double.parse(_oldPriceCtrl.text.trim()),
        'priceTiers':   _tiers.map((t) => {
              'minQty': t.minQty,
              'maxQty': t.maxQty,
              'price':  t.price,
            }).toList(),
        'variants': _variants.map((v) => {
              'id':       '${v.variant1}_${DateTime.now().millisecondsSinceEpoch}',
              'variant1': v.variant1.isEmpty ? null : v.variant1,
              'variant2': v.variant2,
              'stock':    v.stock,
            }).toList(),
        'colors':    _colors,
        'badge':     _badge,
        'isActive':  _isActive,
        'isPinned':  _isPinned,
      };

      final api = ref.read(apiClientProvider);
      if (widget.product == null) {
        await api.post(
            '/marketplace/shops/${AppConfig.shopId}/products', data: body);
      } else {
        await api.patch(
            '/marketplace/products/${widget.product!.id}', data: body);
      }

      // Invalider les caches
      ref.invalidate(productsProvider(AppConfig.shopId));
      ref.invalidate(featuredProductsProvider(AppConfig.shopId));

      if (mounted) {
        _snack(widget.product == null
            ? '✅ Produit créé !'
            : '✅ Produit mis à jour !');
        context.pop();
      }
    } catch (e) {
      _snack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(isEdit ? 'Modifier le produit' : 'Nouveau produit'),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Enregistrer',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Photos ──────────────────────────────────────────────────────
            _Section(
              title: '📸 Photos (${_existingPhotos.length + _newPhotos.length}/5)',
              child: Column(
                children: [
                  SizedBox(
                    height: 110,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Photos existantes
                        ..._existingPhotos.asMap().entries.map((e) =>
                            _PhotoThumb(
                              url: e.value,
                              onRemove: () => setState(
                                  () => _existingPhotos.removeAt(e.key)),
                            )),
                        // Nouvelles photos (pas encore uploadées)
                        ..._newPhotos.asMap().entries.map((e) =>
                            _LocalPhotoThumb(
                              file: e.value,
                              onRemove: () =>
                                  setState(() => _newPhotos.removeAt(e.key)),
                            )),
                        // Bouton ajouter
                        if (_existingPhotos.length + _newPhotos.length < 5)
                          _AddPhotoButton(onTap: _pickPhotos),
                      ],
                    ),
                  ),
                  if (_uploadingPhotos)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Infos de base ────────────────────────────────────────────────
            _Section(
              title: '📝 Informations',
              child: Column(children: [
                _Field(
                  controller: _nameCtrl,
                  label: 'Nom du produit *',
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _descCtrl,
                  label: 'Description',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                // Catégorie
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: _inputDeco('Catégorie *'),
                  items: const [
                    DropdownMenuItem(value: 'textile', child: Text('👗 Textile')),
                    DropdownMenuItem(value: 'chaussures', child: Text('👟 Chaussures')),
                    DropdownMenuItem(value: 'electronique', child: Text('📱 Électronique')),
                    DropdownMenuItem(value: 'lit', child: Text('🛏️ Lit & Literie')),
                    DropdownMenuItem(value: 'marmite', child: Text('🥘 Marmite & Cuisine')),
                    DropdownMenuItem(value: 'autre', child: Text('🏠 Autre')),
                  ],
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Prix ─────────────────────────────────────────────────────────
            _Section(
              title: '💰 Prix',
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: _Field(
                      controller: _retailPriceCtrl,
                      label: 'Prix détail (FCFA) *',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requis';
                        if (double.tryParse(v) == null) return 'Invalide';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Field(
                      controller: _oldPriceCtrl,
                      label: 'Ancien prix (barré)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('💼 Paliers prix gros',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter'),
                      onPressed: () => setState(() => _tiers.add(
                          _PriceTier(minQty: 10, maxQty: null, price: 0))),
                    ),
                  ],
                ),
                ..._tiers.asMap().entries.map((e) =>
                    _TierRow(
                      tier: e.value,
                      index: e.key,
                      onRemove: () =>
                          setState(() => _tiers.removeAt(e.key)),
                      onChanged: () => setState(() {}),
                    )),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Variantes ─────────────────────────────────────────────────────
            _Section(
              title: '📦 Variantes & Stock',
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _categoryVariantLabel,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ajouter'),
                      onPressed: () => setState(() =>
                          _variants.add(_Variant(variant1: '', stock: 0))),
                    ),
                  ],
                ),
                ..._variants.asMap().entries.map((e) =>
                    _VariantRow(
                      variant: e.value,
                      index: e.key,
                      label: _categoryVariantLabel,
                      onRemove: () =>
                          setState(() => _variants.removeAt(e.key)),
                      onChanged: () => setState(() {}),
                    )),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Couleurs ──────────────────────────────────────────────────────
            _Section(
              title: '🎨 Couleurs disponibles',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _colors.map((c) => Chip(
                          label: Text(c),
                          onDeleted: () =>
                              setState(() => _colors.remove(c)),
                          deleteIconColor: Colors.red,
                        )).toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _colorCtrl,
                        decoration: _inputDeco('Ex: Rouge, Bleu...'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final c = _colorCtrl.text.trim();
                        if (c.isNotEmpty && !_colors.contains(c)) {
                          setState(() => _colors.add(c));
                          _colorCtrl.clear();
                        }
                      },
                      child: const Text('Ajouter'),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Badge & Options ───────────────────────────────────────────────
            _Section(
              title: '⚙️ Options',
              child: Column(children: [
                DropdownButtonFormField<String>(
                  value: _badge,
                  decoration: _inputDeco('Badge produit'),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('Aucun badge')),
                    DropdownMenuItem(value: 'featured', child: Text('⭐ Coup de cœur')),
                    DropdownMenuItem(value: 'trending', child: Text('🔥 Tendance')),
                    DropdownMenuItem(value: 'popular', child: Text('👁️ Populaire')),
                    DropdownMenuItem(value: 'topRated', child: Text('⭐ Top qualité')),
                    DropdownMenuItem(value: 'newProduct', child: Text('🆕 Nouveau')),
                    DropdownMenuItem(value: 'lastItems', child: Text('⚡ Dernières pièces')),
                    DropdownMenuItem(value: 'seasonal', child: Text('📅 Saison')),
                  ],
                  onChanged: (v) => setState(() => _badge = v!),
                ),
                SwitchListTile(
                  title: const Text('Produit actif'),
                  subtitle: const Text('Visible dans la boutique'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Épingler en vedette'),
                  subtitle: const Text('Affiché en tête de liste'),
                  value: _isPinned,
                  onChanged: (v) => setState(() => _isPinned = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ]),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, MediaQuery.of(context).padding.bottom + 12),
        child: ElevatedButton(
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
              : Text(
                  isEdit ? '💾 Enregistrer les modifications' : '✅ Créer le produit',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  String get _categoryVariantLabel {
    switch (_category) {
      case 'textile':     return 'Taille (XS/S/M/L/XL/XXL)';
      case 'chaussures':  return 'Pointure (36–45)';
      case 'electronique':return 'Capacité (64Go/128Go...)';
      case 'lit':         return 'Dimensions (140x190, 160x200...)';
      case 'marmite':     return 'Contenance (5L/10L/15L...)';
      default:            return 'Variante';
    }
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}

// ── Widgets helpers ───────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}

// ── Vignette photo existante ──────────────────────────────────────────────────
class _PhotoThumb extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;
  const _PhotoThumb({required this.url, required this.onRemove});

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Container(
            width: 100, height: 100,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                  image: NetworkImage(url), fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 2, right: 10,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
}

// ── Vignette photo locale ─────────────────────────────────────────────────────
class _LocalPhotoThumb extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;
  const _LocalPhotoThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Container(
            width: 100, height: 100,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: kIsWeb
                  ? Image.network(file.path, fit: BoxFit.cover)
                  : Image.file(File(file.path), fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 2, right: 10,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
          // Badge "À uploader"
          Positioned(
            bottom: 4, left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Nouveau',
                  style: TextStyle(color: Colors.white, fontSize: 9)),
            ),
          ),
        ],
      );
}

// ── Bouton ajouter photo ──────────────────────────────────────────────────────
class _AddPhotoButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddPhotoButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 100, height: 100,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            border: Border.all(
                color: const Color(0xFF1A237E), width: 2,
                style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF1A237E).withOpacity(0.05),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  color: Color(0xFF1A237E), size: 32),
              SizedBox(height: 4),
              Text('Ajouter',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF1A237E))),
            ],
          ),
        ),
      );
}

// ── Ligne palier prix ─────────────────────────────────────────────────────────
class _TierRow extends StatefulWidget {
  final _PriceTier tier;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _TierRow({required this.tier, required this.index,
      required this.onRemove, required this.onChanged});

  @override
  State<_TierRow> createState() => _TierRowState();
}

class _TierRowState extends State<_TierRow> {
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _minCtrl   = TextEditingController(text: '${widget.tier.minQty}');
    _maxCtrl   = TextEditingController(
        text: widget.tier.maxQty?.toString() ?? '');
    _priceCtrl = TextEditingController(
        text: widget.tier.price.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _minCtrl.dispose(); _maxCtrl.dispose(); _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _minCtrl,
              keyboardType: TextInputType.number,
              decoration: _d('Qté min'),
              onChanged: (v) {
                widget.tier.minQty = int.tryParse(v) ?? 0;
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _maxCtrl,
              keyboardType: TextInputType.number,
              decoration: _d('Qté max (vide=∞)'),
              onChanged: (v) {
                widget.tier.maxQty = int.tryParse(v);
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: _d('Prix FCFA'),
              onChanged: (v) {
                widget.tier.price = double.tryParse(v) ?? 0;
                widget.onChanged();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: widget.onRemove,
          ),
        ]),
      );

  InputDecoration _d(String l) => InputDecoration(
        labelText: l,
        labelStyle: const TextStyle(fontSize: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
      );
}

// ── Ligne variante ────────────────────────────────────────────────────────────
class _VariantRow extends StatefulWidget {
  final _Variant variant;
  final int index;
  final String label;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _VariantRow({required this.variant, required this.index,
      required this.label, required this.onRemove, required this.onChanged});

  @override
  State<_VariantRow> createState() => _VariantRowState();
}

class _VariantRowState extends State<_VariantRow> {
  late final TextEditingController _v1Ctrl;
  late final TextEditingController _stockCtrl;

  @override
  void initState() {
    super.initState();
    _v1Ctrl    = TextEditingController(text: widget.variant.variant1);
    _stockCtrl = TextEditingController(text: '${widget.variant.stock}');
  }

  @override
  void dispose() {
    _v1Ctrl.dispose(); _stockCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _v1Ctrl,
              decoration: _d(widget.label),
              onChanged: (v) {
                widget.variant.variant1 = v;
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _stockCtrl,
              keyboardType: TextInputType.number,
              decoration: _d('Stock'),
              onChanged: (v) {
                widget.variant.stock = int.tryParse(v) ?? 0;
                widget.onChanged();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: widget.onRemove,
          ),
        ]),
      );

  InputDecoration _d(String l) => InputDecoration(
        labelText: l,
        labelStyle: const TextStyle(fontSize: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
      );
}
