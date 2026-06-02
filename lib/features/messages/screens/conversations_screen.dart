import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';

final conversationsProvider = FutureProvider.autoDispose<List>((ref) async {
  final api = ref.read(apiClientProvider);
  final res = await api.get('/messages/conversations');
  return List.from(res.data);
});

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages'), actions: [
        IconButton(icon: const Icon(Icons.search), onPressed: () {}),
      ]),
      body: convsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (conversations) => conversations.isEmpty
            ? const Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textLight),
                  SizedBox(height: 16),
                  Text('Aucune conversation', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                ]),
              )
            : ListView.separated(
                itemCount: conversations.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, i) {
                  final c = conversations[i];
                  final isUnread = c['is_read'] == false;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        (c['contact_name'] ?? '?').toString().substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(
                      c['contact_name'] ?? 'Inconnu',
                      style: TextStyle(fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500),
                    ),
                    subtitle: Text(
                      c['content'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isUnread ? AppColors.textPrimary : AppColors.textSecondary,
                        fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          c['created_at']?.toString().substring(11, 16) ?? '',
                          style: TextStyle(fontSize: 11, color: isUnread ? AppColors.primary : AppColors.textLight),
                        ),
                        if (isUnread) ...[
                          const SizedBox(height: 4),
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                    onTap: () => context.go('/messages/chat/${c['contact_id']}'),
                  );
                },
              ),
      ),
    );
  }
}
