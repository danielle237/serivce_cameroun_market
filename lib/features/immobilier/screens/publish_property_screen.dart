import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class PublishPropertyScreen extends ConsumerStatefulWidget {
  const PublishPropertyScreen({super.key});
  @override
  ConsumerState<PublishPropertyScreen> createState() => _PublishPropertyState();
}

class _PublishPropertyState extends ConsumerState<PublishPropertyScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _title    = TextEditingController();
  final _desc     = TextEditingController();
  final _prix     = TextEditingController();
  final _surface  = TextEditingController();
  final _pieces   = TextEditingController();
  final _phone    = TextEditingController();
  final _agence   = TextEditingController();
  final _quartier = TextEditingController();

  String _categorySlug = 'location';
  String _ville = 'Yaoundé';
  String _prixPeriode = 'mois';
  bool _loading = false;

  // Photos
  final List<XFile> _photos = [];
  final _picker = ImagePicker();
  bool _uploadingPhotos = false;
  List<String> _uploadedUrls = [];

  Future<void> _pickPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80, limit: 8);
    if (picked.isEmpty) return;
    setState(() { _photos.clear(); _photos.addAll(picked); _uploadedUrls = []; });
  }

  Future<List<String>> _uploadAllPhotos() async {
    if (_photos.isEmpty) return [];
    setState(() => _uploadingPhotos = true);
    final api = ref.read(apiClientProvider);
    final urls = <String>[];
    for (final photo in _photos) {
      try {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(photo.path, filename: photo.name),
        });
        final res = await api.postForm('/media/image', data: formData);
        final url = res.data['url'] as String? ?? res.data as String? ?? '';
        if (url.isNotEmpty) urls.add(url);
      } catch (e) {
        // photo ignorée si upload échoue
      }
    }
    setState(() => _uploadingPhotos = false);
    return urls;
  }

  static const _categories = [
    {'slug': 'location',         'label': 'Location',        'emoji': '🏠'},
    {'slug': 'vente',            'label': 'Vente',           'emoji': '🏗️'},
    {'slug': 'bureau',           'label': 'Bureau/Commerce', 'emoji': '🏢'},
    {'slug': 'colocation',       'label': 'Colocation',      'emoji': '🛏️'},
    {'slug': 'meuble_journalier','label': 'Meublé / jour',   'emoji': '🛋️'},
  ];

  static const _villes = ['Yaoundé', 'Douala', 'Bafoussam', 'Garoua', 'Bamenda'];
  static const _periodes = [
    {'value': 'jour', 'label': 'Par jour'},
    {'value': 'mois', 'label': 'Par mois'},
    {'value': 'an',   'label': 'Par an'},
    {'value': 'total','label': 'Prix total'},
  ];

  @override
  void dispose() {
    _title.dispose(); _desc.dispose(); _prix.dispose();
    _surface.dispose(); _pieces.dispose(); _phone.dispose();
    _agence.dispose(); _quartier.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins une photo')));
      return;
    }
    setState(() => _loading = true);
    try {
      // 1. Upload photos
      final photoUrls = await _uploadAllPhotos();

      final api = ref.read(apiClientProvider);
      await api.post('/immobilier/publish', data: {
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'categorySlug': _categorySlug,
        'ville': _ville,
        'quartier': _quartier.text.trim(),
        'prix': int.tryParse(_prix.text.trim()) ?? 0,
        'prixPeriode': _prixPeriode,
        if (_surface.text.isNotEmpty) 'surface': double.tryParse(_surface.text),
        if (_pieces.text.isNotEmpty) 'pieces': int.tryParse(_pieces.text),
        if (_phone.text.isNotEmpty) 'contactPhone': _phone.text.trim(),
        if (_agence.text.isNotEmpty) 'agencyName': _agence.text.trim(),
        if (photoUrls.isNotEmpty) 'photoPrincipale': photoUrls.first,
        if (photoUrls.length > 1) 'photos': photoUrls.sublist(1),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Annonce soumise ! En attente de validation.'),
          backgroundColor: Color(0xFF1B5E20)));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red.shade700));
      }
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Publier une annonce'),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Photos ───────────────────────────────────────────────────
            _SectionTitle('Photos du bien'),
            const SizedBox(height: 4),
            Text('Minimum 1 photo — max 8. La première sera la photo principale.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickPhotos,
              child: _photos.isEmpty
                ? Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 36, color: Colors.grey.shade400),
                      const SizedBox(height: 6),
                      Text('Appuyer pour ajouter des photos',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    ])))
                : SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length + 1,
                      itemBuilder: (_, i) {
                        if (i == _photos.length) {
                          return GestureDetector(
                            onTap: _pickPhotos,
                            child: Container(
                              width: 100, margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200)),
                              child: Icon(Icons.add_rounded, color: Colors.grey.shade400, size: 28)));
                        }
                        return Stack(children: [
                          Container(
                            width: 100, margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                image: FileImage(File(_photos[i].path)),
                                fit: BoxFit.cover)),
                          ),
                          if (i == 0)
                            Positioned(bottom: 4, left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B5E20),
                                  borderRadius: BorderRadius.circular(4)),
                                child: const Text('Principale',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))),
                          Positioned(top: 4, right: 12,
                            child: GestureDetector(
                              onTap: () => setState(() => _photos.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 12, color: Colors.white)))),
                        ]);
                      },
                    )),
            ),
            if (_uploadingPhotos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text('Upload des photos en cours…',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ])),
            const SizedBox(height: 20),

            // ── Type de bien ──────────────────────────────────────────────
            _SectionTitle('Type de bien'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: _categories.map((cat) {
              final sel = _categorySlug == cat['slug'];
              return GestureDetector(
                onTap: () => setState(() => _categorySlug = cat['slug'] as String),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF1B5E20) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? const Color(0xFF1B5E20) : Colors.grey.shade300)),
                  child: Text('${cat['emoji']} ${cat['label']}',
                    style: TextStyle(
                      color: sel ? Colors.white : Colors.grey.shade700,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13)),
                ),
              );
            }).toList()),

            const SizedBox(height: 20),
            _SectionTitle('Informations principales'),
            const SizedBox(height: 10),

            // Titre
            _Field(controller: _title, label: 'Titre de l\'annonce',
              hint: 'Ex : Appartement F3 meublé à Bastos',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null),
            const SizedBox(height: 12),

            // Ville + quartier
            Row(children: [
              Expanded(child: _DropdownField<String>(
                label: 'Ville', value: _ville, items: _villes,
                itemLabel: (v) => v, onChanged: (v) => setState(() => _ville = v!),
              )),
              const SizedBox(width: 12),
              Expanded(child: _Field(controller: _quartier, label: 'Quartier',
                hint: 'Ex : Bastos', validator: null)),
            ]),
            const SizedBox(height: 12),

            // Prix + période
            Row(children: [
              Expanded(child: _Field(controller: _prix, label: 'Prix (FCFA)',
                hint: '150000', keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requis';
                  if (int.tryParse(v) == null) return 'Nombre invalide';
                  return null;
                })),
              const SizedBox(width: 12),
              Expanded(child: _DropdownField<String>(
                label: 'Période', value: _prixPeriode,
                items: _periodes.map((p) => p['value'] as String).toList(),
                itemLabel: (v) => _periodes.firstWhere((p) => p['value'] == v)['label'] as String,
                onChanged: (v) => setState(() => _prixPeriode = v!),
              )),
            ]),
            const SizedBox(height: 12),

            // Surface + pièces
            Row(children: [
              Expanded(child: _Field(controller: _surface, label: 'Surface (m²)',
                hint: '80', keyboardType: TextInputType.number, validator: null)),
              const SizedBox(width: 12),
              Expanded(child: _Field(controller: _pieces, label: 'Nbre de pièces',
                hint: '3', keyboardType: TextInputType.number, validator: null)),
            ]),
            const SizedBox(height: 12),

            // Description
            _Field(controller: _desc, label: 'Description',
              hint: 'Décrivez votre bien en détail…', maxLines: 5, validator: null),
            const SizedBox(height: 20),

            _SectionTitle('Contact'),
            const SizedBox(height: 10),

            _Field(controller: _agence, label: 'Nom agence / propriétaire',
              hint: 'Optionnel', validator: null),
            const SizedBox(height: 12),
            _Field(controller: _phone, label: 'Téléphone contact',
              hint: '6XX XXX XXX', keyboardType: TextInputType.phone, validator: null),

            const SizedBox(height: 32),

            // Soumettre
            SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Soumettre l\'annonce', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )),
            const SizedBox(height: 8),
            Text('Votre annonce sera visible après validation par notre équipe.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller, required this.label,
    this.hint, this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller, maxLines: maxLines, keyboardType: keyboardType,
    validator: validator,
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label, required this.value, required this.items,
    required this.itemLabel, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value, isExpanded: true,
        items: items.map((v) => DropdownMenuItem<T>(
          value: v, child: Text(itemLabel(v), style: const TextStyle(fontSize: 14)))).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}
