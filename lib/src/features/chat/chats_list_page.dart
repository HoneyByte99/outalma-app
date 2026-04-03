import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_shell.dart';
import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/booking/booking_providers.dart';
import '../../application/chat/chat_providers.dart';
import '../../application/user/user_providers.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/chat_message.dart';
import '../shared/user_avatar.dart';

class ChatsListPage extends ConsumerWidget {
  const ChatsListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final chatsAsync = ref.watch(userChatsProvider);

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: oc.surface,
        surfaceTintColor: Colors.transparent,
        actions: const [BellIconButton()],
      ),
      body: chatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            'Impossible de charger les chats.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: oc.secondaryText),
          ),
        ),
        data: (chats) {
          if (chats.isEmpty) return const _EmptyChats();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: 80,
              endIndent: 0,
            ),
            itemBuilder: (context, i) => _ChatTile(chat: chats[i]),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat tile
// ---------------------------------------------------------------------------

class _ChatTile extends ConsumerWidget {
  const _ChatTile({required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final myUid =
        authState is AuthAuthenticated ? authState.user.id : null;

    // Fetch last message for preview
    final messagesAsync = ref.watch(chatMessagesProvider(chat.id));
    final lastMsg = messagesAsync.valueOrNull?.lastOrNull;

    final hasUnread = lastMsg != null &&
        myUid != null &&
        lastMsg.senderId != myUid &&
        !lastMsg.readBy.contains(myUid);

    // Resolve the other participant's profile.
    final otherUid = chat.participantIds
        .firstWhere((id) => id != myUid, orElse: () => '');
    final otherUserAsync =
        otherUid.isNotEmpty ? ref.watch(userByIdProvider(otherUid)) : null;
    final otherUser = otherUserAsync?.valueOrNull;

    return InkWell(
      onTap: () => context.push(AppRoutes.chat(chat.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            UserAvatar(
              displayName: otherUser?.displayName ?? '',
              photoPath: otherUser?.photoPath,
              radius: 26,
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ServiceTitle(bookingId: chat.bookingId),
                      ),
                      if (chat.lastMessageAt != null)
                        Text(
                          _formatTime(chat.lastMessageAt!),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: hasUnread
                                        ? oc.primary
                                        : oc.icons,
                                    fontWeight: hasUnread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    fontSize: 12,
                                  ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _LastMessagePreview(
                          message: lastMsg,
                          myUid: myUid,
                          hasUnread: hasUnread,
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: oc.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Service title loaded from booking
// ---------------------------------------------------------------------------

class _ServiceTitle extends ConsumerWidget {
  const _ServiceTitle({required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingDetailProvider(bookingId));
    final serviceId = bookingAsync.valueOrNull?.serviceId;

    // Use service title if available, otherwise show booking id placeholder
    final label = serviceId != null ? _ServiceName(serviceId: serviceId) : null;

    return label ??
        Text(
          'Réservation',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
  }
}

class _ServiceName extends ConsumerWidget {
  const _ServiceName({required this.serviceId});

  final String serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text(
      'Réservation', // sufficient for MVP — service title shown in chat AppBar
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ---------------------------------------------------------------------------
// Last message preview
// ---------------------------------------------------------------------------

class _LastMessagePreview extends StatelessWidget {
  const _LastMessagePreview({
    required this.message,
    required this.myUid,
    required this.hasUnread,
  });

  final ChatMessage? message;
  final String? myUid;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    if (message == null) {
      return Text(
        'Démarrez la conversation',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: oc.secondaryText,
              fontStyle: FontStyle.italic,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final isMe = message!.senderId == myUid;
    final prefix = isMe ? 'Vous : ' : '';
    final text = message!.text ?? '';

    return Text(
      '$prefix$text',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: hasUnread ? oc.primaryText : oc.secondaryText,
            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
          ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: oc.icons,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun chat actif',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Les conversations démarrent après\nl\'acceptation d\'une réservation.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: oc.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time formatting
// ---------------------------------------------------------------------------

String _formatTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inMinutes < 1) return 'maintenant';
  if (diff.inHours < 1) return 'il y a ${diff.inMinutes} min';
  if (diff.inDays < 1) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  if (diff.inDays < 7) {
    const days = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];
    return days[dt.weekday - 1];
  }
  const months = [
    'jan', 'fév', 'mars', 'avr', 'mai', 'juin',
    'juil', 'août', 'sep', 'oct', 'nov', 'déc',
  ];
  return '${dt.day} ${months[dt.month - 1]}';
}
