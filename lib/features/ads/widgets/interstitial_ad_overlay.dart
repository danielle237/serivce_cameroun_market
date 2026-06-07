import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad_campaign.dart';
import '../../../core/api/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overlay plein-écran affiché sur l'app.
/// - Image : CachedNetworkImage
/// - Vidéo : VideoPlayer en boucle
/// - Tap n'importe où → dismiss
/// - Bouton "Passer" apparaît après [ad.skipAfterSeconds] secondes
/// - Bouton CTA (optionnel) → ouvre [ad.clickUrl]
///
/// Usage :
/// ```dart
/// showInterstitialAd(context, ad);
/// ```
Future<void> showInterstitialAd(BuildContext context, AdCampaign ad, WidgetRef ref) async {
  // Tracker l'impression
  try {
    await ref.read(apiClientProvider).post('/ads/${ad.id}/impression');
  } catch (_) {}

  if (!context.mounted) return;
  await showGeneralDialog(
    context: context,
    barrierDismissible: false, // géré manuellement (tap-to-dismiss)
    barrierColor: Colors.black87,
    pageBuilder: (ctx, anim1, anim2) => _InterstitialAdPage(ad: ad, ref: ref),
    transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(
      opacity: anim1,
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 300),
  );
}

class _InterstitialAdPage extends StatefulWidget {
  final AdCampaign ad;
  final WidgetRef ref;
  const _InterstitialAdPage({required this.ad, required this.ref});

  @override
  State<_InterstitialAdPage> createState() => _InterstitialAdPageState();
}

class _InterstitialAdPageState extends State<_InterstitialAdPage> {
  VideoPlayerController? _videoCtrl;
  bool _skipVisible = false;
  Timer? _skipTimer;
  int _countdown = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdown = widget.ad.skipAfterSeconds;

    if (widget.ad.isVideo) {
      _initVideo();
    }

    // Rendre le bouton "Passer" visible après N secondes
    if (widget.ad.skipAfterSeconds > 0) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) { t.cancel(); return; }
        setState(() {
          _countdown--;
          if (_countdown <= 0) {
            _skipVisible = true;
            t.cancel();
            _countdownTimer = null;
          }
        });
      });
    } else {
      _skipVisible = true;
    }
  }

  Future<void> _initVideo() async {
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.ad.mediaUrl));
    _videoCtrl = ctrl;
    await ctrl.initialize();
    if (!mounted) return;
    ctrl.setLooping(true);
    ctrl.play();
    setState(() {});
  }

  void _dismiss() => Navigator.of(context).pop();

  void _onTap() {
    // Tap global → dismiss (comme pub YouTube)
    _dismiss();
  }

  Future<void> _onCta() async {
    final url = widget.ad.clickUrl;
    if (url == null) { _dismiss(); return; }

    // Tracker le clic
    try {
      await widget.ref.read(apiClientProvider).post('/ads/${widget.ad.id}/click');
    } catch (_) {}

    // Naviguer
    if (url.startsWith('/')) {
      // Route interne Flutter — fermer l'overlay puis naviguer
      _dismiss();
      if (mounted) {
        Navigator.of(context).pushNamed(url);
      }
    } else {
      final uri = Uri.tryParse(url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      _dismiss();
    }
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    _countdownTimer?.cancel();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _onTap,
        child: Stack(
          children: [
            // ── Média plein-écran ─────────────────────────────────────────
            SizedBox.expand(
              child: widget.ad.isVideo ? _buildVideo(size) : _buildImage(size),
            ),

            // ── Dégradé bas (pour lisibilité des boutons) ─────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 160,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),

            // ── Label "Publicité" en haut à droite ─────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Publicité',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ),

            // ── Bouton Passer (après N secondes) ──────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              child: AnimatedOpacity(
                opacity: _skipVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 400),
                child: GestureDetector(
                  onTap: _skipVisible ? _dismiss : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Passer',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.skip_next, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Countdown (avant bouton Passer) ────────────────────────────
            if (!_skipVisible && _countdown > 0)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white30),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$_countdown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // ── CTA bas (optionnel) ────────────────────────────────────────
            if (widget.ad.ctaLabel != null || widget.ad.clickUrl != null)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 32,
                left: 32,
                right: 32,
                child: GestureDetector(
                  onTap: _onCta,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(100),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.ad.ctaLabel ?? 'En savoir plus',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(Size size) => CachedNetworkImage(
    imageUrl: widget.ad.mediaUrl,
    width: size.width,
    height: size.height,
    fit: BoxFit.cover,
    placeholder: (ctx, _) => Container(color: Colors.black),
    errorWidget: (ctx, _, __) => Container(color: Colors.black),
  );

  Widget _buildVideo(Size size) {
    final ctrl = _videoCtrl;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return Container(color: Colors.black);
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ctrl.value.size.width,
          height: ctrl.value.size.height,
          child: VideoPlayer(ctrl),
        ),
      ),
    );
  }
}
