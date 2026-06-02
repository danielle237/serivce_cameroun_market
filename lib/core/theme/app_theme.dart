import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PALETTE AFRICAINE W2D
// Inspirée des couleurs du Cameroun et de la Côte d'Ivoire :
// - Terre cuite / terracotta
// - Or Akan
// - Vert forêt équatoriale
// - Ocre et crème chaud
// ═════════════════════════════════════════════════════════════════════════════
class AppColors {
  // ── Couleurs principales ────────────────────────────────────────────────────
  static const primary     = Color(0xFFB5451B); // Terracotta / Terre brûlée
  static const primaryLight= Color(0xFFE8682A); // Orange vif
  static const primaryDark = Color(0xFF7D2E0E); // Terre foncée
  static const secondary   = Color(0xFFD4A017); // Or Akan / Gold
  static const accent      = Color(0xFF2D6A4F); // Vert forêt équatoriale

  // ── Fonds et surfaces ───────────────────────────────────────────────────────
  static const background  = Color(0xFFFDF6EC); // Crème ivoire chaud
  static const surface     = Color(0xFFFFFFFF);
  static const surfaceWarm = Color(0xFFFFF3E0); // Fond orangé très clair
  static const surfaceDark = Color(0xFF1C1008); // Nuit africaine

  // ── Kente accent (motif décoratif) ──────────────────────────────────────────
  static const kente1 = Color(0xFFD4A017); // Or
  static const kente2 = Color(0xFFB5451B); // Terracotta
  static const kente3 = Color(0xFF2D6A4F); // Vert
  static const kente4 = Color(0xFF1A1A1A); // Noir

  // ── Texte ────────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFF1C1008); // Brun très sombre
  static const textSecondary = Color(0xFF6B5C4A); // Brun moyen
  static const textLight     = Color(0xFFA89880); // Sable

  // ── Statuts ──────────────────────────────────────────────────────────────────
  static const success  = Color(0xFF2D6A4F); // Vert forêt
  static const warning  = Color(0xFFD4A017); // Or
  static const error    = Color(0xFFC0392B); // Rouge Cameroun
  static const info     = Color(0xFF1A6B8A); // Bleu Atlantique

  // ── Escrow ───────────────────────────────────────────────────────────────────
  static const escrowColor = Color(0xFF6B3FA0); // Violet royal africain
}

// ═════════════════════════════════════════════════════════════════════════════
// THÈME PRINCIPAL
// ═════════════════════════════════════════════════════════════════════════════
class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      background: AppColors.background,
    ),
    scaffoldBackgroundColor: AppColors.background,

    // ── AppBar ────────────────────────────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: Colors.white,
        letterSpacing: 0.3,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),

    // ── Boutons ───────────────────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 3,
        shadowColor: AppColors.primary.withOpacity(0.4),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(double.infinity, 54),
        side: const BorderSide(color: AppColors.primary, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    // ── Inputs ───────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.textLight.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      hintStyle: TextStyle(color: AppColors.textLight, fontSize: 14),
      prefixIconColor: AppColors.primary,
    ),

    // ── Cards ────────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shadowColor: AppColors.primary.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.primary.withOpacity(0.06)),
      ),
      margin: const EdgeInsets.only(bottom: 10),
    ),

    // ── Navigation du bas ─────────────────────────────────────────────────────
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textLight,
      type: BottomNavigationBarType.fixed,
      elevation: 16,
      selectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
      unselectedLabelStyle: TextStyle(fontSize: 10),
    ),

    // ── SnackBar ──────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),

    // ── Chips ─────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceWarm,
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
    ),

    // ── Divider ───────────────────────────────────────────────────────────────
    dividerTheme: DividerThemeData(
      color: AppColors.textLight.withOpacity(0.3),
      thickness: 1,
      space: 1,
    ),

    // ── Switch / Checkbox ─────────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.primary : Colors.grey.shade400),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.primary.withOpacity(0.4)
              : Colors.grey.shade200),
    ),

    // ── Progress ─────────────────────────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: Color(0x22B5451B),
    ),
  );

  static ThemeData get darkTheme => lightTheme.copyWith(
    scaffoldBackgroundColor: AppColors.surfaceDark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.primaryLight,
      secondary: AppColors.secondary,
      surface: const Color(0xFF2C1A10),
      background: AppColors.surfaceDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF2C1A10),
      foregroundColor: Colors.white,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGETS DÉCORATIFS AFRICAINS
// ═════════════════════════════════════════════════════════════════════════════

/// Motif géométrique kente en arrière-plan (très discret)
class KentePattern extends StatelessWidget {
  final double opacity;
  const KentePattern({super.key, this.opacity = 0.04});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _KentePainter(opacity: opacity),
      child: const SizedBox.expand(),
    );
  }
}

class _KentePainter extends CustomPainter {
  final double opacity;
  _KentePainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 24.0;
    final colors = [
      AppColors.kente1.withOpacity(opacity),
      AppColors.kente2.withOpacity(opacity),
      AppColors.kente3.withOpacity(opacity),
    ];

    final paint = Paint()..style = PaintingStyle.fill;

    for (var x = 0.0; x < size.width; x += tileSize) {
      for (var y = 0.0; y < size.height; y += tileSize) {
        final idx = ((x / tileSize).toInt() + (y / tileSize).toInt()) % colors.length;
        paint.color = colors[idx];
        canvas.drawRect(Rect.fromLTWH(x, y, tileSize - 1, tileSize - 1), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_KentePainter old) => old.opacity != opacity;
}

/// Séparateur décoratif avec motif africain
class AfricanDivider extends StatelessWidget {
  final String? label;
  const AfricanDivider({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Row(children: [
        Expanded(child: Container(height: 1,
            color: AppColors.primary.withOpacity(0.15))),
        Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              color: AppColors.secondary, shape: BoxShape.circle)),
        Expanded(child: Container(height: 1,
            color: AppColors.primary.withOpacity(0.15))),
      ]);
    }
    return Row(children: [
      Expanded(child: Container(height: 1,
          color: AppColors.primary.withOpacity(0.15))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(label!, style: TextStyle(
          fontSize: 12, color: AppColors.textLight,
          fontWeight: FontWeight.w600,
        )),
      ),
      Expanded(child: Container(height: 1,
          color: AppColors.primary.withOpacity(0.15))),
    ]);
  }
}

/// Badge de score de confiance style africain
class TrustBadge extends StatelessWidget {
  final double score;
  final bool compact;
  const TrustBadge({super.key, required this.score, this.compact = false});

  Color get _color {
    if (score >= 4.0) return AppColors.success;
    if (score >= 2.5) return AppColors.secondary;
    return AppColors.error;
  }

  String get _label {
    if (score >= 4.5) return '⭐ Excellent';
    if (score >= 4.0) return '✅ Très bien';
    if (score >= 3.0) return '👍 Bien';
    if (score >= 2.0) return '⚠️ Passable';
    return '❌ Faible';
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _color.withOpacity(0.4)),
        ),
        child: Text('${score.toStringAsFixed(1)}/5',
            style: TextStyle(
                fontSize: 11, color: _color, fontWeight: FontWeight.w700)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.shield_outlined, size: 14, color: _color),
        const SizedBox(width: 5),
        Text(_label, style: TextStyle(
            fontSize: 12, color: _color, fontWeight: FontWeight.w700)),
        const SizedBox(width: 5),
        Text('${score.toStringAsFixed(1)}',
            style: TextStyle(fontSize: 12, color: _color)),
      ]),
    );
  }
}
