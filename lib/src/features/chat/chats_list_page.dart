import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_shell.dart';
import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/booking/booking_providers.dart';
import '../../application/chat/chat_providers.dart';
import '../../application/user/user_providers.dart';
import '../../domain/enums/booking_status.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/chat_message.dart';
import '../shared/user_avatar.dart';

class ChatsListPage extends ConsumerStatefulWidget {
  const ChatsListPage({super.key});

  @override
  ConsumerState<ChatsListPage> createState() => _ChatsListPageState();
}

class _ChatsListPageState extends ConsumerState<ChatsListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final chatsAsync = ref.watch(chatsForModeProvider);

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: Text(l10n.messagesTitle),
        backgroundColor: oc.surface,
        surfaceTintColor: Colors.transparent,
        actions: const [BellIconButton()],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.chatTabActive),
            Tab(text: l10n.chatTabDone),
          ],
        ),
      ),
      body: chatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            l10n.chatLoadError,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: oc.secondaryText),
          ),
        ),
        data: (chats) {
          if (chats.isEmpty) return const _EmptyChats();
          return TabBarView(
            controller: _tabController,
            children: [
              _ChatListFiltered(
                chats: chats,
                activeOnly: true,
              ),
              _ChatListFiltered(
                chats: chats,
                activeOnly: false,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filtered chat list — splits by booking status
// ---------------------------------------------------------------------------

class _ChatListFiltered extends ConsumerWidget {
  const _ChatListFiltered({
    required this.chats,
    required this.activeOnly,
  });

  final List<Chat> chats;
  final bool activeOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Filter chats based on their linked booking status
    final filtered = chats.where((chat) {
      final bookingAsync = ref.watch(bookingDetailProvider(chat.bookingId));
      final booking = bookingAsync.valueOrNull;
      if (booking == null) return activeOnly; // loading → show in active tab
      final isActive = booking.status == BookingStatus.accepted ||
          booking.status == BookingStatus.inProgress ||
          booking.status == BookingStatus.requested;
      return activeOnly ? isActive : !isActive;
    }).toList();

    if (filtered.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Text(
          activeOnly ? l10n.chatActiveEmpty : l10n.chatDoneEmpty,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: context.oc.secondaryText),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 80,
        endIndent: 0,
      ),
      itemBuilder: (context, i) => _ChatTile(chat: filtered[i]),
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

    final messagesAsync = ref.watch(chatMessagesProvider(chat.id));
    final lastMsg = messagesAsync.valueOrNull?.lastOrNull;

    final hasUnread = lastMsg != null &&
        myUid != null &&
        lastMsg.senderId != myUid &&
        !lastMsg.readBy.contains(myUid);

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
            UserAvatar(
              displayName: otherUser?.displayName ?? '',
              photoPath: otherUser?.photoPath,
              radius: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherUser?.displayName ?? 'Conversation',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    if (message == null) {
      return Text(
        l10n.chatStartConversation,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: oc.secondaryText,
              fontStyle: FontStyle.italic,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final isMe = message!.senderId == myUid;
    final prefix = isMe ? l10n.chatYou : '';
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
    final l10n = AppLocalizations.of(context)!;
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
              l10n.chatEmpty,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.chatEmptySubtitle,
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
    'jan', 'f\u00e9v', 'mars', 'avr', 'mai', 'juin',
    'juil', 'ao\u00fbt', 'sep', 'oct', 'nov', 'd\u00e9c',
  ];
  return '${dt.day} ${months[dt.month - 1]}';
}
