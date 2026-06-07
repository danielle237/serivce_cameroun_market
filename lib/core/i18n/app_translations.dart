/// Traductions FR / EN / AR pour W2D
/// Usage depuis un Widget: AppTranslations.of(context).t('key')
/// Usage depuis un ConsumerWidget: tr(ref, 'key')
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/locale_provider.dart';

class AppTranslations {
  final String _lang;
  const AppTranslations(this._lang);

  static AppTranslations of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return AppTranslations(locale.languageCode);
  }

  String t(String key) =>
      _strings[_lang]?[key] ?? _strings['fr']![key] ?? key;

  // ─── Strings ─────────────────────────────────────────────────────────────
  static const _strings = <String, Map<String, String>>{

    // ════════════════════════════════════════════════════════════════════════
    'fr': {
      // ── Auth ──────────────────────────────────────────────────────────────
      'welcome_title':      'La confiance,\nau Cameroun',
      'welcome_subtitle':   'Connectez-vous en toute sécurité avec des enseignants, artisans, ménagères et bien plus.',
      'sign_in':            'Se connecter',
      'create_account':     'Créer un compte',
      'your_number':        'Votre numéro',
      'sms_hint':           'Un code de 6 chiffres sera envoyé par SMS',
      'receive_sms':        'Recevoir le code SMS',
      'verify_code':        'Code de vérification',
      'code_sent_to':       'Code envoyé au',
      'verify':             'Vérifier',
      'resend_code':        'Renvoyer le code',
      'resend_in':          'Renvoyer dans',
      'seconds':            's',
      'your_profile':       'Votre profil',
      'full_name':          'Nom complet',
      'you_are':            'Vous êtes :',
      'client':             'Client',
      'client_subtitle':    'Je cherche des services',
      'provider':           'Prestataire',
      'provider_subtitle':  'Je propose mes services',
      'city':               'Ville',
      'language':           'Langue',
      'create_my_account':  'Créer mon compte',

      // ── Home ──────────────────────────────────────────────────────────────
      'hello':                  'Bonjour,',
      'our_services':           'Nos services',
      'workspaces':             'Mes espaces de travail',
      'recent_activity':        'Activité récente',
      'see_all':                'Voir tout',
      'no_recent_activity':     'Aucune activité récente',
      'trust_score':            'Score de confiance',
      'verified':               '✅ Vérifié',
      'pending_kyc':            '⏳ En cours',
      'kyc_verified':           '✅ Vérifié',
      'kyc_pending':            '⏳ KYC en cours',

      // Mode badges
      'mode_provider':          '🔧 MODE PRESTATAIRE',
      'mode_client':            '👤 MODE CLIENT',
      'provider_mode_desc':     'Vous êtes en mode prestataire — gérez vos missions',
      'client_mode_desc':       'Vous êtes en mode client — accédez à tous les services',

      // ── Services (bannière horizontale + grilles) ─────────────────────────
      'education':              'Éducation',
      'artisans':               'Artisans',
      'real_estate':            'Immobilier',
      'housekeeping':           'Ménagère',
      'moto':                   'Moto',
      'marketplace':            'Marché',
      'rental':                 'Location',

      // ── Grille prestataire ────────────────────────────────────────────────
      'my_quotes':              'Mes devis',
      'my_classes':             'Mes cours',
      'my_missions':            'Mes missions',
      'my_deliveries':          'Mes livraisons',
      'my_properties':          'Mes biens',
      'my_portfolio':           'Mon portfolio',

      // ── Wallet ────────────────────────────────────────────────────────────
      'wallet':                 'Mon Wallet',
      'available_balance':      'Solde disponible',
      'in_escrow':              'En escrow',
      'total_earned':           'Total gagné',
      'top_up':                 'Recharger',
      'withdraw':               'Retirer',
      'history':                'Historique',
      'transactions':           'Transactions',
      'amount':                 'Montant',
      'operator':               'Opérateur',
      'pay':                    'Procéder au paiement',
      'min_amount':             'Montant minimum: 500 XAF',

      // ── Messages ──────────────────────────────────────────────────────────
      'messages':               'Messages',
      'no_conversations':       'Aucune conversation',
      'message_hint':           'Votre message...',

      // ── Profile ───────────────────────────────────────────────────────────
      'my_profile':             'Mon Profil',
      'edit_profile':           'Modifier le profil',
      'kyc_docs':               'Documents KYC',
      'payment_methods':        'Méthodes de paiement',
      'notifications':          'Notifications',
      'security':               'Sécurité & Confidentialité',
      'help':                   'Aide & Support',
      'ratings':                'Évaluations reçues',
      'logout':                 'Se déconnecter',
      'trust_score_label':      'Score confiance',
      'ratings_label':          'Évaluations',

      // ── Common ────────────────────────────────────────────────────────────
      'loading':                'Chargement...',
      'error':                  'Erreur',
      'retry':                  'Réessayer',
      'cancel':                 'Annuler',
      'confirm':                'Confirmer',
      'save':                   'Enregistrer',
      'close':                  'Fermer',
      'yes':                    'Oui',
      'no':                     'Non',
      'search':                 'Rechercher',
      'filter':                 'Filtrer',
      'refresh':                'Actualiser',
      'choose_language':        'Choisir la langue',

      // ── Annonces prestataire ──────────────────────────────────────────────
      'available_ads':          'Annonces disponibles',
      'private_lessons':        'Cours particuliers',
      'works_services':         'Travaux & services',
      'complete_profile_ads':   'Complétez votre profil pour voir les annonces correspondantes',

      // ── Éducation ─────────────────────────────────────────────────────────
      'education_module':       'Module Éducation',
      'weekly_schedule':        'Planning semainier',
      'schedule_session':       'Planifier une séance',
      'class_schedule':         'Planning des cours',
      'monthly_summary':        'Récapitulatif mensuel',
      'follow_up_books':        'Cahiers de suivi',
      'no_books_available':     'Aucun cahier disponible pour l\'instant',

      // ── Artisans ──────────────────────────────────────────────────────────
      'find_artisan':           'Trouver un artisan',
      'available_now':          'Disponible maintenant',
      'new_request':            'Nouvelle demande',
      'no_requests':            'Aucune demande',
      'publish_request':        'Publier une demande',
      'post_to_find_artisan':   'Publiez une demande pour trouver un artisan',

      // ── Immobilier ────────────────────────────────────────────────────────
      'what_looking_for':       'Que recherchez-vous ?',
      'featured':               '⭐ En vedette',
      'publish_property':       'Publier un bien',

      // ── Ménagère ──────────────────────────────────────────────────────────
      'menagere':               'Ménagère',
      'become_housekeeper':     'Devenir ménagère',
      'find_tab':               'Trouver',
      'my_contracts':           'Mes contrats',
      'nettoyage':              'Nettoyage',
      'cuisine':                'Cuisine',
      'garde_enfants':          'Garde enfants',
      'repassage':              'Repassage',
      'lessive':                'Lessive',
      'courses_svc':            'Courses',
      'ponctuel':               'Ponctuel',
      'regulier':               'Régulier',
      'residentiel':            'Résidentiel',

      // ── Moto ──────────────────────────────────────────────────────────────
      'moto_delivery':          'Moto & Livraison',
      'service_type':           'Type de service',
      'transport_chip':         '🛵 Transport',
      'parcel_chip':            '📦 Colis',
      'shopping_chip':          '🛒 Courses',
      'food_chip':              '🍔 Repas',
      'pickup_point':           'Point de départ',
      'destination':            'Destination',
      'estimated_distance':     'Distance estimée',
      'estimated_price':        'Prix estimé',
      'find_driver':            'Trouver un conducteur',
      'request_sent_driver':    'Demande envoyée! Recherche de conducteur...',

      // ── Location ──────────────────────────────────────────────────────────
      'cars':                   'Voitures',
      'with_without_driver':    'Avec ou sans chauffeur',
      'equipment':              'Matériel',
      'chairs_tents_sound':     'Chaises · Tentes · Sono',

      // ── Filtres ───────────────────────────────────────────────────────────
      'all_services':           'Tous',
      'all_modes':              'Tout mode',

      // ── Don ───────────────────────────────────────────────────────────────
      'donation_title':         'Faire un don',
      'choose_cause':           'Choisissez une cause',
      'min_donation':           'Montant minimum : 500 FCFA',

      // ── Marketplace ───────────────────────────────────────────────────────
      'my_listings':            'Mes annonces',
      'add_product':            'Ajouter un produit',
      'no_products':            'Aucun produit',
    }, // end 'fr'

    // ════════════════════════════════════════════════════════════════════════
    'en': {
      // ── Auth ──────────────────────────────────────────────────────────────
      'welcome_title':      'Trust,\nin Cameroon',
      'welcome_subtitle':   'Connect securely with teachers, craftsmen, housekeepers and more.',
      'sign_in':            'Sign in',
      'create_account':     'Create account',
      'your_number':        'Your number',
      'sms_hint':           'A 6-digit code will be sent by SMS',
      'receive_sms':        'Receive SMS code',
      'verify_code':        'Verification code',
      'code_sent_to':       'Code sent to',
      'verify':             'Verify',
      'resend_code':        'Resend code',
      'resend_in':          'Resend in',
      'seconds':            's',
      'your_profile':       'Your profile',
      'full_name':          'Full name',
      'you_are':            'You are:',
      'client':             'Client',
      'client_subtitle':    'I am looking for services',
      'provider':           'Provider',
      'provider_subtitle':  'I offer services',
      'city':               'City',
      'language':           'Language',
      'create_my_account':  'Create my account',

      // ── Home ──────────────────────────────────────────────────────────────
      'hello':                  'Hello,',
      'our_services':           'Our services',
      'workspaces':             'My workspaces',
      'recent_activity':        'Recent activity',
      'see_all':                'See all',
      'no_recent_activity':     'No recent activity',
      'trust_score':            'Trust score',
      'verified':               '✅ Verified',
      'pending_kyc':            '⏳ Pending',
      'kyc_verified':           '✅ Verified',
      'kyc_pending':            '⏳ KYC pending',

      'mode_provider':          '🔧 PROVIDER MODE',
      'mode_client':            '👤 CLIENT MODE',
      'provider_mode_desc':     'You are in provider mode — manage your missions',
      'client_mode_desc':       'You are in client mode — access all services',

      // ── Services ──────────────────────────────────────────────────────────
      'education':              'Education',
      'artisans':               'Craftsmen',
      'real_estate':            'Real Estate',
      'housekeeping':           'Housekeeper',
      'moto':                   'Moto',
      'marketplace':            'Market',
      'rental':                 'Rental',

      'my_quotes':              'My quotes',
      'my_classes':             'My classes',
      'my_missions':            'My missions',
      'my_deliveries':          'Deliveries',
      'my_properties':          'My properties',
      'my_portfolio':           'Portfolio',

      // ── Wallet ────────────────────────────────────────────────────────────
      'wallet':                 'My Wallet',
      'available_balance':      'Available balance',
      'in_escrow':              'In escrow',
      'total_earned':           'Total earned',
      'top_up':                 'Top up',
      'withdraw':               'Withdraw',
      'history':                'History',
      'transactions':           'Transactions',
      'amount':                 'Amount',
      'operator':               'Operator',
      'pay':                    'Proceed to payment',
      'min_amount':             'Minimum amount: 500 XAF',

      // ── Messages ──────────────────────────────────────────────────────────
      'messages':               'Messages',
      'no_conversations':       'No conversations',
      'message_hint':           'Your message...',

      // ── Profile ───────────────────────────────────────────────────────────
      'my_profile':             'My Profile',
      'edit_profile':           'Edit profile',
      'kyc_docs':               'KYC Documents',
      'payment_methods':        'Payment methods',
      'notifications':          'Notifications',
      'security':               'Security & Privacy',
      'help':                   'Help & Support',
      'ratings':                'Received ratings',
      'logout':                 'Sign out',
      'trust_score_label':      'Trust score',
      'ratings_label':          'Ratings',

      // ── Common ────────────────────────────────────────────────────────────
      'loading':                'Loading...',
      'error':                  'Error',
      'retry':                  'Retry',
      'cancel':                 'Cancel',
      'confirm':                'Confirm',
      'save':                   'Save',
      'close':                  'Close',
      'yes':                    'Yes',
      'no':                     'No',
      'search':                 'Search',
      'filter':                 'Filter',
      'refresh':                'Refresh',
      'choose_language':        'Choose language',

      'available_ads':          'Available listings',
      'private_lessons':        'Private lessons',
      'works_services':         'Works & services',
      'complete_profile_ads':   'Complete your profile to see matching listings',

      // ── Education ─────────────────────────────────────────────────────────
      'education_module':       'Education Module',
      'weekly_schedule':        'Weekly schedule',
      'schedule_session':       'Schedule a session',
      'class_schedule':         'Class schedule',
      'monthly_summary':        'Monthly summary',
      'follow_up_books':        'Follow-up books',
      'no_books_available':     'No books available yet',

      // ── Artisans ──────────────────────────────────────────────────────────
      'find_artisan':           'Find a craftsman',
      'available_now':          'Available now',
      'new_request':            'New request',
      'no_requests':            'No requests',
      'publish_request':        'Post a request',
      'post_to_find_artisan':   'Post a request to find a craftsman',

      // ── Real estate ───────────────────────────────────────────────────────
      'what_looking_for':       'What are you looking for?',
      'featured':               '⭐ Featured',
      'publish_property':       'Post property',

      // ── Housekeeping ──────────────────────────────────────────────────────
      'menagere':               'Housekeeper',
      'become_housekeeper':     'Become a housekeeper',
      'find_tab':               'Find',
      'my_contracts':           'My contracts',
      'nettoyage':              'Cleaning',
      'cuisine':                'Cooking',
      'garde_enfants':          'Childcare',
      'repassage':              'Ironing',
      'lessive':                'Laundry',
      'courses_svc':            'Errands',
      'ponctuel':               'One-off',
      'regulier':               'Regular',
      'residentiel':            'Residential',

      // ── Moto ──────────────────────────────────────────────────────────────
      'moto_delivery':          'Moto & Delivery',
      'service_type':           'Service type',
      'transport_chip':         '🛵 Transport',
      'parcel_chip':            '📦 Parcel',
      'shopping_chip':          '🛒 Errands',
      'food_chip':              '🍔 Food',
      'pickup_point':           'Pick-up point',
      'destination':            'Destination',
      'estimated_distance':     'Estimated distance',
      'estimated_price':        'Estimated price',
      'find_driver':            'Find a driver',
      'request_sent_driver':    'Request sent! Looking for a driver...',

      // ── Rental ────────────────────────────────────────────────────────────
      'cars':                   'Cars',
      'with_without_driver':    'With or without driver',
      'equipment':              'Equipment',
      'chairs_tents_sound':     'Chairs · Tents · Sound',

      // ── Filtres ───────────────────────────────────────────────────────────
      'all_services':           'All',
      'all_modes':              'All modes',

      // ── Donation ──────────────────────────────────────────────────────────
      'donation_title':         'Make a donation',
      'choose_cause':           'Choose a cause',
      'min_donation':           'Minimum amount: 500 FCFA',

      // ── Marketplace ───────────────────────────────────────────────────────
      'my_listings':            'My listings',
      'add_product':            'Add product',
      'no_products':            'No products',
    },

    // ════════════════════════════════════════════════════════════════════════
    'ar': {
      // ── Auth ──────────────────────────────────────────────────────────────
      'welcome_title':      'الثقة،\nفي الكاميرون',
      'welcome_subtitle':   'تواصل بأمان مع المعلمين والحرفيين وعمال المنازل وأكثر.',
      'sign_in':            'تسجيل الدخول',
      'create_account':     'إنشاء حساب',
      'your_number':        'رقمك',
      'sms_hint':           'سيتم إرسال رمز مكوّن من 6 أرقام عبر رسالة SMS',
      'receive_sms':        'استلام رمز SMS',
      'verify_code':        'رمز التحقق',
      'code_sent_to':       'الرمز أُرسل إلى',
      'verify':             'تحقق',
      'resend_code':        'إعادة إرسال الرمز',
      'resend_in':          'إعادة الإرسال بعد',
      'seconds':            'ث',
      'your_profile':       'ملفك الشخصي',
      'full_name':          'الاسم الكامل',
      'you_are':            'أنت:',
      'client':             'عميل',
      'client_subtitle':    'أبحث عن خدمات',
      'provider':           'مزوّد خدمة',
      'provider_subtitle':  'أقدّم خدماتي',
      'city':               'المدينة',
      'language':           'اللغة',
      'create_my_account':  'إنشاء حسابي',

      // ── Home ──────────────────────────────────────────────────────────────
      'hello':                  'مرحباً،',
      'our_services':           'خدماتنا',
      'workspaces':             'مساحات عملي',
      'recent_activity':        'النشاط الأخير',
      'see_all':                'عرض الكل',
      'no_recent_activity':     'لا يوجد نشاط حديث',
      'trust_score':            'درجة الثقة',
      'verified':               '✅ موثّق',
      'pending_kyc':            '⏳ قيد المراجعة',
      'kyc_verified':           '✅ موثّق',
      'kyc_pending':            '⏳ KYC قيد المراجعة',

      'mode_provider':          '🔧 وضع مزوّد الخدمة',
      'mode_client':            '👤 وضع العميل',
      'provider_mode_desc':     'أنت في وضع مزوّد الخدمة — أدر مهماتك',
      'client_mode_desc':       'أنت في وضع العميل — استفد من جميع الخدمات',

      // ── Services ──────────────────────────────────────────────────────────
      'education':              'التعليم',
      'artisans':               'الحرفيون',
      'real_estate':            'العقارات',
      'housekeeping':           'عمال المنزل',
      'moto':                   'موتو',
      'marketplace':            'السوق',
      'rental':                 'الإيجار',

      'my_quotes':              'عروضي',
      'my_classes':             'دروسي',
      'my_missions':            'مهماتي',
      'my_deliveries':          'التوصيلات',
      'my_properties':          'عقاراتي',
      'my_portfolio':           'ملف أعمالي',

      // ── Wallet ────────────────────────────────────────────────────────────
      'wallet':                 'محفظتي',
      'available_balance':      'الرصيد المتاح',
      'in_escrow':              'في الضمان',
      'total_earned':           'إجمالي الأرباح',
      'top_up':                 'شحن الرصيد',
      'withdraw':               'سحب',
      'history':                'السجل',
      'transactions':           'المعاملات',
      'amount':                 'المبلغ',
      'operator':               'المشغّل',
      'pay':                    'المتابعة للدفع',
      'min_amount':             'الحد الأدنى للمبلغ: 500 XAF',

      // ── Messages ──────────────────────────────────────────────────────────
      'messages':               'الرسائل',
      'no_conversations':       'لا توجد محادثات',
      'message_hint':           'رسالتك...',

      // ── Profile ───────────────────────────────────────────────────────────
      'my_profile':             'ملفي الشخصي',
      'edit_profile':           'تعديل الملف الشخصي',
      'kyc_docs':               'وثائق KYC',
      'payment_methods':        'طرق الدفع',
      'notifications':          'الإشعارات',
      'security':               'الأمان والخصوصية',
      'help':                   'المساعدة والدعم',
      'ratings':                'التقييمات المستلمة',
      'logout':                 'تسجيل الخروج',
      'trust_score_label':      'درجة الثقة',
      'ratings_label':          'التقييمات',

      // ── Common ────────────────────────────────────────────────────────────
      'loading':                'جارٍ التحميل...',
      'error':                  'خطأ',
      'retry':                  'إعادة المحاولة',
      'cancel':                 'إلغاء',
      'confirm':                'تأكيد',
      'save':                   'حفظ',
      'close':                  'إغلاق',
      'yes':                    'نعم',
      'no':                     'لا',
      'search':                 'بحث',
      'filter':                 'تصفية',
      'refresh':                'تحديث',
      'choose_language':        'اختر اللغة',

      'available_ads':          'الإعلانات المتاحة',
      'private_lessons':        'دروس خصوصية',
      'works_services':         'أعمال وخدمات',
      'complete_profile_ads':   'أكمل ملفك الشخصي لرؤية الإعلانات المناسبة',

      // ── التعليم ───────────────────────────────────────────────────────────
      'education_module':       'وحدة التعليم',
      'weekly_schedule':        'الجدول الأسبوعي',
      'schedule_session':       'جدولة جلسة',
      'class_schedule':         'جدول الدروس',
      'monthly_summary':        'ملخص شهري',
      'follow_up_books':        'كتب المتابعة',
      'no_books_available':     'لا تتوفر كتب حاليًا',

      // ── الحرفيون ──────────────────────────────────────────────────────────
      'find_artisan':           'البحث عن حرفي',
      'available_now':          'متاح الآن',
      'new_request':            'طلب جديد',
      'no_requests':            'لا توجد طلبات',
      'publish_request':        'نشر طلب',
      'post_to_find_artisan':   'انشر طلباً للعثور على حرفي',

      // ── العقارات ──────────────────────────────────────────────────────────
      'what_looking_for':       'ماذا تبحث عن؟',
      'featured':               '⭐ المميزة',
      'publish_property':       'نشر عقار',

      // ── عمال المنزل ───────────────────────────────────────────────────────
      'menagere':               'عاملة منزل',
      'become_housekeeper':     'أصبح عاملة منزل',
      'find_tab':               'بحث',
      'my_contracts':           'عقودي',
      'nettoyage':              'تنظيف',
      'cuisine':                'طبخ',
      'garde_enfants':          'رعاية أطفال',
      'repassage':              'كي',
      'lessive':                'غسيل',
      'courses_svc':            'تسوق',
      'ponctuel':               'مرة واحدة',
      'regulier':               'منتظم',
      'residentiel':            'سكني',

      // ── موتو ──────────────────────────────────────────────────────────────
      'moto_delivery':          'موتو والتوصيل',
      'service_type':           'نوع الخدمة',
      'transport_chip':         '🛵 نقل',
      'parcel_chip':            '📦 طرود',
      'shopping_chip':          '🛒 تسوق',
      'food_chip':              '🍔 طعام',
      'pickup_point':           'نقطة الانطلاق',
      'destination':            'الوجهة',
      'estimated_distance':     'المسافة المقدرة',
      'estimated_price':        'السعر المقدر',
      'find_driver':            'البحث عن سائق',
      'request_sent_driver':    'تم إرسال الطلب! جاري البحث عن سائق...',

      // ── الإيجار ───────────────────────────────────────────────────────────
      'cars':                   'سيارات',
      'with_without_driver':    'مع أو بدون سائق',
      'equipment':              'معدات',
      'chairs_tents_sound':     'كراسي · خيام · صوتيات',

      // ── الفلاتر ───────────────────────────────────────────────────────────
      'all_services':           'الكل',
      'all_modes':              'كل الأوضاع',

      // ── التبرع ────────────────────────────────────────────────────────────
      'donation_title':         'التبرع',
      'choose_cause':           'اختر قضية',
      'min_donation':           'الحد الأدنى: 500 فرنك',

      // ── السوق ─────────────────────────────────────────────────────────────
      'my_listings':            'إعلاناتي',
      'add_product':            'إضافة منتج',
      'no_products':            'لا توجد منتجات',
    },
  };
}

/// Raccourci global pour ConsumerWidget: tr(ref, 'key')
String tr(WidgetRef ref, String key) {
  final locale = ref.watch(localeProvider).value ?? const Locale('fr');
  return AppTranslations(locale.languageCode).t(key);
}
