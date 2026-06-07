import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/router/app_router.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/services/cache_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/offline_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capturer les erreurs Flutter silencieuses (debug web)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
  };

  // Firebase init (requis par firebase_core 3.x)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase non configuré: $e');
  }

  // Orientation portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Style barre système
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Cache local (Hive) — réduit la consommation data sur MTN/Orange
  await CacheService.init();

  // Pré-lire le token auth pour éviter le flash d'écran de chargement au démarrage
  await AuthNotifier.preloadAuth();

  runApp(const ProviderScope(child: W2DApp()));
}

class W2DApp extends ConsumerWidget {
  const W2DApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    final locale = ref.watch(localeProvider).value ?? const Locale('fr');

    return MaterialApp.router(
      title: 'W2D — Confiance & Service',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      locale: locale,
      supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        // Connectivité + scale fixe + RTL arabe
        ref.watch(connectivityProvider);
        final isRtl = locale.languageCode == 'ar';
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
            child: OfflineBanner(child: child!),
          ),
        );
      },
    );
  }
}
