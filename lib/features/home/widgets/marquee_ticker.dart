import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_provider.dart';

// ── Provider — passe module, userId et activeMode ────────────────────────────
final marqueeProvider = FutureProvider.autoDispose.family<
    List<Map<String, dynamic>>, String>((ref, module) async {
  try {
    final auth       = ref.read(authStateProvider).value;
    final userId     = auth?.user?['id']         as String?;
    final activeMode = auth?.user?['activeMode'] as String? ?? 'client';

    final params = <String, dynamic>{'module': module};
    if (userId != null) {
      params['userId']     = userId;
      params['activeMode'] = activeMode;
    }

    final res = await ref.read(apiClientProvider).get(
      '/marquee/active',
      params: params,
      forceRefresh: true,           // toujours demander au serveur
      cacheTtl: const Duration(minutes: 2), // garde en cache max 2 min
    );

    // Si réponse provient d'un cache périmé (offline) → rien afficher
    if (res.extra['stale'] == true) return [];

    final data = res.data;
    if (data is List) {
      final now = DateTime.now();
      return data
          .map((m) => Map<String, dynamic>.from(m))
          .where((m) {
            if (m['active'] == false) return false;
            final endAt = DateTime.tryParse(m['endAt'] ?? '');
            if (endAt != null && endAt.isBefore(now)) return false;
            return true;
          })
          .toList();
    }
    return [];
  } catch (_) { return []; } // offline sans cache → rien
});

// ── Vitesse en pixels/seconde selon le champ speed ───────────────────────────
double _speedPx(String? speed) {
  switch (speed) {
    case 'slow':  return 40.0;
    case 'fast':  return 120.0;
    default:      return 75.0; // normal
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Widget principal — charge les messages et les affiche un par un
// ═════════════════════════════════════════════════════════════════════════════
class MarqueeTicker extends ConsumerStatefulWidget {
  final String module;
  const MarqueeTicker({super.key, this.module = 'home'});

  @override
  ConsumerState<MarqueeTicker> createState() => _MarqueeTickerState();
}

class _MarqueeTickerState extends ConsumerState<MarqueeTicker> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Rafraîchit toutes les 60 secondes
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) ref.invalidate(marqueeProvider(widget.module));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(marqueeProvider(widget.module));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (messages) {
        if (messages.isEmpty) return const SizedBox.shrink();
        return _TickerRotator(messages: messages);
      },
    );
  }
}

// ─── Rotateur : change de message toutes les N secondes ─────────────────────
class _TickerRotator extends StatefulWidget {
  final List<Map<String, dynamic>> messages;
  const _TickerRotator({required this.messages});

  @override
  State<_TickerRotator> createState() => _TickerRotatorState();
}

class _TickerRotatorState extends State<_TickerRotator> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.messages.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 12), (_) {
        if (mounted) setState(() => _index = (_index + 1) % widget.messages.length);
      });
    }
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final msg = widget.messages[_index];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _SingleTicker(key: ValueKey(_index), message: msg),
    );
  }
}

// ─── Un seul ticker défilant ─────────────────────────────────────────────────
class _SingleTicker extends StatefulWidget {
  final Map<String, dynamic> message;
  const _SingleTicker({required this.message, super.key});

  @override
  State<_SingleTicker> createState() => _SingleTickerState();
}

class _SingleTickerState extends State<_SingleTicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  double _textWidth  = 0;
  double _screenWidth = 0;
  bool   _measured   = false;

  @override
  void initState() {
    super.initState();
    // Durée provisoire — sera écrasée après mesure du texte dans _startScroll()
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 10));
    // Pas de addListener + setState — on utilise AnimatedBuilder dans build()
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenWidth = MediaQuery.of(context).size.width;
    if (!_measured) _startScroll();
  }

  void _startScroll() {
    // Mesure le texte puis lance l'animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final text  = _fullText;
      final style = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: _textColor);
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      _textWidth = tp.width + 40; // padding

      final speed    = _speedPx(widget.message['speed'] as String?);
      final distance = _screenWidth + _textWidth;
      final seconds  = distance / speed;

      _ctrl.duration = Duration(milliseconds: (seconds * 1000).toInt());
      _anim = Tween<double>(begin: _screenWidth, end: -_textWidth).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.linear));
      _ctrl.repeat();
      _measured = true;
    });
  }

  String get _fullText {
    final icon = widget.message['icon'] as String?;
    final msg  = widget.message['message'] as String? ?? '';
    return icon != null ? '$icon  $msg' : msg;
  }

  Color get _textColor {
    final hex = widget.message['textColor'] as String? ?? '#FFFFFF';
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return Colors.white; }
  }

  Color get _bgColor {
    final hex = widget.message['bgColor'] as String? ?? '#1A237E';
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return const Color(0xFF1A237E); }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // Les dégradés sont statiques — on les passe en `child` d'AnimatedBuilder
    // pour qu'ils ne soient pas reconstruits à chaque frame (60fps)
    final gradients = Stack(children: [
      Positioned(
        left: 0, top: 0, bottom: 0, width: 24,
        child: DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgColor, _bgColor.withOpacity(0)]),
        )),
      ),
      Positioned(
        right: 0, top: 0, bottom: 0, width: 24,
        child: DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft, end: Alignment.centerRight,
            colors: [_bgColor.withOpacity(0), _bgColor]),
        )),
      ),
    ]);

    return Container(
      height: 34,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      // AnimatedBuilder reconstruit UNIQUEMENT le Positioned du texte,
      // pas le Container ni les dégradés → ~0 overhead au lieu de 60 setState/sec
      child: AnimatedBuilder(
        animation: _ctrl,
        child: gradients,
        builder: (context, staticChild) {
          final offset = _measured ? _anim.value : _screenWidth.toDouble();
          return Stack(children: [
            Positioned(
              left: offset,
              top: 0, bottom: 0,
              child: Center(
                child: Text(
                  _fullText,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: _textColor,
                    letterSpacing: 0.2),
                  maxLines: 1,
                ),
              ),
            ),
            staticChild!, // dégradés pré-construits, jamais re-rendus
          ]);
        },
      ),
    );
  }
}
