/// Traductions FR / EN pour W2D
/// Usage: AppTranslations.of(context).t('key')
/// Ou directement: tr(context, 'key')
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

  String t(String key) => _strings[_lang]?[key] ?? _strings['fr']![key] ?? key;

  // ─── Strings FR / EN ────────────────────────────────────────────────────────
  static const _strings = {
    'fr': {
      // Auth
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

      // Home
      'hello':              'Bonjour,',
      'our_services':       'Nos services',
      'recent_activity':    'Activité récente',
      'see_all':            'Voir tout',
      'trust_score':        'Score de confiance',
      'verified':           '✅ Vérifié',
      'pending_kyc':        '⏳ En cours',

      // Services
      'education':          'Éducation',
      'artisans':           'Artisans',
      'real_estate':        'Immobilier',
      'housekeeping':       'Ménagère',
      'moto':               'Moto',
      'marketplace':        'Marché',

      // Wallet
      'wallet':             'Mon Wallet',
      'available_balance':  'Solde disponible',
      'in_escrow':          'En escrow',
      'total_earned':       'Total gagné',
      'top_up':             'Recharger',
      'withdraw':           'Retirer',
      'history':            'Historique',
      'transactions':       'Transactions',
      'amount':             'Montant',
      'operator':           'Opérateur',
      'pay':                'Procéder au paiement',
      'min_amount':         'Montant minimum: 500 XAF',

      // Messages
      'messages':           'Messages',
      'no_conversations':   'Aucune conversation',
      'message_hint':       'Votre message...',

      // Profile
      'my_profile':         'Mon Profil',
      'edit_profile':       'Modifier le profil',
      'kyc_docs':           'Documents KYC',
      'payment_methods':    'Méthodes de paiement',
      'notifications':      'Notifications',
      'security':           'Sécurité & Confidentialité',
      'help':               'Aide & Support',
      'ratings':            'Évaluations reçues',
      'logout':             'Se déconnecter',
      'trust_score_label':  'Score confiance',
      'ratings_label':      'Évaluations',

      // Common
      'loading':            'Chargement...',
      'error':              'Erreur',
      'retry':              'Réessayer',
      'cancel':             'Annuler',
      'confirm':            'Confirmer',
      'save':               'Enregistrer',
      'close':              'Fermer',
      'yes':                'Oui',
      'no':                 'Non',
      'search':             'Rechercher',
      'filter':             'Filtrer',
      'refresh':            'Actualiser',
    },

    'en': {
      // Auth
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
      'client_subtitle':    'I\'m looking for services',
      'provider':           'Provider',
      'provider_subtitle':  'I offer services',
      'city':               'City',
      'language':           'Language',
      'create_my_account':  'Create my account',

      // Home
      'hello':              'Hello,',
      'our_services':       'Our services',
      'recent_activity':    'Recent activity',
      'see_all':            'See all',
      'trust_score':        'Trust score',
      'verified':           '✅ Verified',
      'pending_kyc':        '⏳ Pending',

      // Services
      'education':          'Education',
      'artisans':           'Craftsmen',
      'real_estate':        'Real Estate',
      'housekeeping':       'Housekeeper',
      'moto':               'Moto',
      'marketplace':        'Market',

      // Wallet
      'wallet':             'My Wallet',
      'available_balance':  'Available balance',
      'in_escrow':          'In escrow',
      'total_earned':       'Total earned',
      'top_up':             'Top up',
      'withdraw':           'Withdraw',
      'history':            'History',
      'transactions':       'Transactions',
      'amount':             'Amount',
      'operator':           'Operator',
      'pay':                'Proceed to payment',
      'min_amount':         'Minimum amount: 500 XAF',

      // Messages
      'messages':           'Messages',
      'no_conversations':   'No conversations',
      'message_hint':       'Your message...',

      // Profile
      'my_profile':         'My Profile',
      'edit_profile':       'Edit profile',
      'kyc_docs':           'KYC Documents',
      'payment_methods':    'Payment methods',
      'notifications':      'Notifications',
      'security':           'Security & Privacy',
      'help':               'Help & Support',
      'ratings':            'Received ratings',
      'logout':             'Sign out',
      'trust_score_label':  'Trust score',
      'ratings_label':      'Ratings',

      // Common
      'loading':            'Loading...',
      'error':              'Error',
      'retry':              'Retry',
      'cancel':             'Cancel',
      'confirm':            'Confirm',
      'save':               'Save',
      'close':              'Close',
      'yes':                'Yes',
      'no':                 'No',
      'search':             'Search',
      'filter':             'Filter',
      'refresh':            'Refresh',
    },
  };
}

/// Raccourci global: tr(ref, 'key')
String tr(WidgetRef ref, String key) {
  final locale = ref.watch(localeProvider).value ?? const Locale('fr');
  return AppTranslations(locale.languageCode).t(key);
}
