import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_translations.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value?.user;

    final t = AppTranslations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.t('my_profile'))),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header avec avatar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              ),
              child: Column(children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    (user?['name'] ?? user?['fullName'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                Text(user?['name'] ?? user?['fullName'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                Text(user?['phone'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _ChipBadge(label: user?['role'] ?? 'client', color: AppColors.secondary),
                  const SizedBox(width: 8),
                  _ChipBadge(
                    label: (user?['kycStatus'] ?? 'pending') == 'verified' ? t.t('kyc_verified') : t.t('kyc_pending'),
                    color: (user?['kycStatus'] ?? 'pending') == 'verified' ? AppColors.success : AppColors.warning,
                  ),
                ]),
              ]),
            ),

            // Score
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Expanded(child: _StatCard(value: user?['trustScore']?.toString() ?? '0', label: t.t('trust_score_label'), icon: Icons.star, color: AppColors.secondary)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(value: user?['totalRatings']?.toString() ?? '0', label: t.t('ratings_label'), icon: Icons.rate_review, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(value: user?['city'] ?? '-', label: t.t('city'), icon: Icons.location_on, color: AppColors.info)),
              ]),
            ),

            const Divider(),

            // Menu
            _MenuItem(icon: Icons.person_outline, title: t.t('edit_profile'), onTap: () {}),
            _MenuItem(icon: Icons.badge_outlined, title: t.t('kyc_docs'), onTap: () {}),
            _MenuItem(icon: Icons.payment, title: t.t('payment_methods'), onTap: () {}),
            _MenuItem(icon: Icons.notifications_outlined, title: t.t('notifications'), onTap: () {}),
            _MenuItem(icon: Icons.security, title: t.t('security'), onTap: () {}),
            _MenuItem(icon: Icons.help_outline, title: t.t('help'), onTap: () {}),
            _MenuItem(icon: Icons.star_outline, title: t.t('ratings'), onTap: () {}),

            const Divider(),

            _MenuItem(
              icon: Icons.logout,
              title: t.t('logout'),
              color: AppColors.error,
              onTap: () async {
                await ref.read(authStateProvider.notifier).logout();
                if (context.mounted) context.push('/auth/welcome');
              },
            ),
            const SizedBox(height: 32),

            const Text('W2D v1.0.0 — Made in Cameroun 🇨🇲', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ChipBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _ChipBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.title, this.subtitle, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textPrimary),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: color ?? AppColors.textPrimary)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(fontSize: 12)) : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
      onTap: onTap,
    );
  }
}
