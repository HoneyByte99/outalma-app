import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../application/chat/chat_providers.dart';
import '../../domain/models/app_user.dart';
import '../shared/user_avatar.dart';
import '../../../l10n/app_localizations.dart';

/// Lists the accounts the user has blocked, with a one-tap unblock. This is the
/// canonical place to undo a block - blocked chats are hidden from the chat
/// list, so the in-chat toggle alone would strand the user.
class BlockedUsersPage extends ConsumerWidget {
  const BlockedUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final blockedAsync = ref.watch(blockedUsersProvider);

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: Text(l10n.blockedUsersTitle),
        backgroundColor: oc.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: blockedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_outlined, size: 56, color: oc.icons),
                const SizedBox(height: 16),
                Text(
                  l10n.errorGeneral,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: oc.secondaryText),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.invalidate(blockedUsersProvider),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.retry),
                ),
              ],
            ),
          ),
        ),
        data: (users) {
          if (users.isEmpty) return _EmptyBlocked(l10n: l10n);
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, indent: 72, endIndent: 16, color: oc.border),
            itemBuilder: (context, i) =>
                _BlockedUserTile(user: users[i], l10n: l10n),
          );
        },
      ),
    );
  }
}

class _BlockedUserTile extends ConsumerWidget {
  const _BlockedUserTile({required this.user, required this.l10n});

  final AppUser user;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final name = user.displayName.isNotEmpty
        ? user.displayName
        : l10n.blockedUserUnknown;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          UserAvatar(displayName: name, photoPath: user.photoPath, radius: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _unblock(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: oc.primary,
              side: BorderSide(color: oc.border),
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(l10n.unblockUser),
          ),
        ],
      ),
    );
  }

  Future<void> _unblock(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(userBlockServiceProvider).unblock(user.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.userUnblocked)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneral)));
    }
  }
}

class _EmptyBlocked extends StatelessWidget {
  const _EmptyBlocked({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_outlined, size: 56, color: oc.icons),
            const SizedBox(height: 16),
            Text(
              l10n.blockedUsersEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.blockedUsersEmptyHint,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}
