import 'dart:async';
import 'dart:io' show Directory, File;
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/network_image.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../../l10n/app_localizations.dart';

import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/booking/booking_providers.dart';
import '../../application/chat/chat_providers.dart';
import '../../application/notification/notification_providers.dart';
import '../../application/user/user_providers.dart';
import '../../core/utils/date_utils.dart' as date_utils;
import '../../data/services/chat_media_service.dart';
import '../../domain/enums/booking_status.dart';
import '../../domain/enums/message_type.dart';
import '../../domain/models/chat_message.dart';
import '../shared/user_avatar.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = AudioRecorder();
  bool _sending = false;
  bool _recording = false;
  bool _uploadingVoice = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  // Id of the newest message we last auto-scrolled to. Tracking the id (not a
  // count) means prepending older messages via pagination never triggers a
  // jump to the bottom — only a genuinely new latest message does.
  String? _lastBottomMsgId;
  Timer? _typingCooldown;

  @override
  void initState() {
    super.initState();
    // Mark messages read on initial load.
    Future.microtask(_markRead);
  }

  @override
  void dispose() {
    _typingCooldown?.cancel();
    _recordingTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  /// Writes typing presence at most once every 2 seconds (leading debounce).
  void _notifyTyping() {
    if (_typingCooldown != null) return;
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthAuthenticated) return;
    ref
        .read(chatRepositoryProvider)
        .setTyping(chatId: widget.chatId, uid: authState.user.id);
    _typingCooldown = Timer(
      const Duration(seconds: 2),
      () => _typingCooldown = null,
    );
  }

  Future<void> _markRead() async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthAuthenticated) return;
    await ref
        .read(chatRepositoryProvider)
        .markMessagesRead(chatId: widget.chatId, uid: authState.user.id);
    // Also clear the in-app (bell) notifications tied to this chat, so the
    // badge decrements when the user opens the conversation.
    final notifs = ref.read(notificationsProvider).valueOrNull ?? const [];
    final db = ref.read(firestoreProvider);
    for (final n in notifs) {
      if (!n.read && n.chatId == widget.chatId) {
        // ignore: unawaited_futures — best-effort, fire and forget
        markNotificationRead(db: db, uid: authState.user.id, notifId: n.id);
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    // Editing an existing message instead of sending a new one.
    if (_editing != null) {
      await _submitEdit(text);
      return;
    }

    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthAuthenticated) return;

    final l10n = AppLocalizations.of(context)!;
    final errorMsg = l10n.chatErrorSend;

    setState(() => _sending = true);

    final replyTo = _replyingTo;
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            ChatMessage(
              id: '',
              chatId: widget.chatId,
              senderId: authState.user.id,
              type: MessageType.text,
              createdAt: DateTime.now().toUtc(),
              text: text,
              replyToId: replyTo?.id,
              replyToText: replyTo?.text,
              replyToSenderId: replyTo?.senderId,
            ),
          );
      if (mounted) {
        _controller.clear();
        setState(() => _replyingTo = null);
        SchedulerBinding.instance.addPostFrameCallback(
          (_) => _scrollToBottom(),
        );
      }
    } catch (_) {
      // Text + reply context are preserved (only cleared on success), so the
      // user can retry directly from the SnackBar action.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: context.oc.error,
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.retry,
              textColor: Colors.white,
              onPressed: _send,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleBlock(
    String otherUid,
    bool isBlocked,
    AppLocalizations l10n,
    OutalmaColors oc,
  ) async {
    final svc = ref.read(userBlockServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (isBlocked) {
      await svc.unblock(otherUid);
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.userUnblocked)));
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.blockUser),
        content: Text(l10n.blockUserConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.blockUser, style: TextStyle(color: oc.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await svc.block(otherUid);
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.userBlocked)));
      }
    }
  }

  // Pending image preview — WhatsApp-style: preview + caption before send
  String? _pendingImageUrl;

  // Message the composer is currently replying to (quote shown above input).
  ChatMessage? _replyingTo;

  // Message currently being edited (composer prefilled, banner shown).
  ChatMessage? _editing;

  /// WhatsApp-style edit window: a sent message can be edited for 15 minutes.
  static const _editWindow = Duration(minutes: 15);
  bool _canEdit(ChatMessage m) =>
      !m.deleted &&
      m.type == MessageType.text &&
      DateTime.now().toUtc().difference(m.createdAt) < _editWindow;

  void _startEditing(ChatMessage msg) {
    setState(() {
      _editing = msg;
      _replyingTo = null;
      _controller.text = msg.text ?? '';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    });
  }

  void _cancelEditing() {
    setState(() => _editing = null);
    _controller.clear();
  }

  Future<void> _submitEdit(String text) async {
    final msg = _editing!;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .editMessage(chatId: widget.chatId, messageId: msg.id, newText: text);
      if (mounted) {
        _controller.clear();
        setState(() => _editing = null);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.chatErrorSend),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static const _quickReactions = ['❤️', '😂', '👍', '😮', '😢', '🙏'];

  Future<void> _react(ChatMessage msg, String emoji) async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthAuthenticated) return;
    final uid = authState.user.id;
    // Tapping the same emoji again removes it (toggle).
    final next = msg.reactions[uid] == emoji ? null : emoji;
    try {
      await ref
          .read(chatRepositoryProvider)
          .setReaction(
            chatId: widget.chatId,
            messageId: msg.id,
            uid: uid,
            emoji: next,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorGeneral),
            backgroundColor: context.oc.error,
          ),
        );
      }
    }
  }

  /// Long-press action sheet on a message: react / reply / copy / delete / report.
  Future<void> _showMessageActions(ChatMessage msg, bool isMe) async {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final hasText = (msg.text ?? '').isNotEmpty;
    if (msg.deleted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: oc.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick emoji reaction row.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final emoji in _quickReactions)
                    IconButton(
                      tooltip: emoji,
                      onPressed: () {
                        Navigator.pop(ctx);
                        _react(msg, emoji);
                      },
                      icon: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: Text(l10n.chatReply),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingTo = msg);
              },
            ),
            if (hasText)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(l10n.chatCopy),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: msg.text!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.chatCopied),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            if (isMe && _canEdit(msg))
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.chatEdit),
                onTap: () {
                  Navigator.pop(ctx);
                  _startEditing(msg);
                },
              ),
            if (isMe)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: oc.error),
                title: Text(l10n.chatDelete, style: TextStyle(color: oc.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(msg);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.chatReportMessage),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.report(type: 'message', id: msg.id));
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(ChatMessage msg) async {
    try {
      await ref
          .read(chatRepositoryProvider)
          .softDeleteMessage(chatId: widget.chatId, messageId: msg.id);
      if (_replyingTo?.id == msg.id) setState(() => _replyingTo = null);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorGeneral),
            backgroundColor: context.oc.error,
          ),
        );
      }
    }
  }

  Future<void> _sendMedia(
    MessageType type,
    String url, {
    String? caption,
  }) async {
    if (_sending) return;
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthAuthenticated) return;

    final l10n = AppLocalizations.of(context)!;
    final errorMsg = l10n.chatFileError;

    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            ChatMessage(
              id: '',
              chatId: widget.chatId,
              senderId: authState.user.id,
              type: type,
              createdAt: DateTime.now().toUtc(),
              mediaUrl: url,
              text: caption != null && caption.isNotEmpty ? caption : null,
            ),
          );
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback(
          (_) => _scrollToBottom(),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: context.oc.error,
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.retry,
              textColor: Colors.white,
              onPressed: () => _sendMedia(type, url, caption: caption),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final media = ref.read(chatMediaServiceProvider);
      final url = await media.pickImageFromGallery(widget.chatId);
      if (url != null && mounted) {
        setState(() => _pendingImageUrl = url);
      }
    } catch (e, st) {
      debugPrint('Image pick error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.chatFileError),
            backgroundColor: context.oc.error,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final media = ref.read(chatMediaServiceProvider);
      final url = await media.takePhoto(widget.chatId);
      if (url != null && mounted) {
        setState(() => _pendingImageUrl = url);
      }
    } catch (e, st) {
      debugPrint('Camera error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.chatFileError),
            backgroundColor: context.oc.error,
          ),
        );
      }
    }
  }

  void _sendPendingImage() {
    if (_pendingImageUrl == null) return;
    final caption = _controller.text.trim();
    _controller.clear();
    final url = _pendingImageUrl!;
    setState(() => _pendingImageUrl = null);
    _sendMedia(MessageType.image, url, caption: caption);
  }

  void _cancelPendingImage() {
    setState(() => _pendingImageUrl = null);
  }

  /// Configures the iOS/Android audio session for recording. just_audio (used
  /// for voice playback) leaves the AVAudioSession in a playback-only category,
  /// which makes record's start() throw even when the mic permission is granted.
  /// Switching to playAndRecord before recording fixes the "impossible
  /// d'activer le micro" failure after a voice message has been played.
  Future<void> _configureRecordingSession() async {
    if (kIsWeb) return;
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      ),
    );
    await session.setActive(true);
  }

  Future<void> _startRecording() async {
    final l10n = AppLocalizations.of(context)!;
    final permissionMsg = l10n.chatMicPermission;
    final errorMsg = l10n.chatMicError;

    try {
      if (kIsWeb) {
        // On web, skip hasPermission (causes MissingPluginException with
        // path_provider). Browser will prompt for mic access automatically.
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.opus),
          path: '',
        );
        if (mounted) _beginRecordingTimer();
      } else {
        // hasPermission() also requests the permission on first use.
        if (!await _recorder.hasPermission()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(permissionMsg),
                backgroundColor: context.oc.error,
              ),
            );
          }
          return;
        }
        // Start the on-screen countdown immediately, before the native recorder
        // and audio session spin up. On device that startup can take a beat, and
        // if we waited for it the timer stayed frozen at 00:00 ("pas de
        // décompte"). If start fails below, we roll the timer back in catch.
        if (mounted) _beginRecordingTimer();
        // Critical: claim the audio session for recording (see helper doc).
        await _configureRecordingSession();
        // Use dart:io systemTemp instead of path_provider's getTemporaryDirectory:
        // path_provider_foundation fails to load objective_c.framework on the
        // x86_64 iOS simulator (FFI DOBJC_initializeApi), which broke voice
        // recording. systemTemp reads TMPDIR directly (works on sim and device).
        final dir = Directory.systemTemp;
        final path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
      }
    } catch (e, st) {
      // Was silently swallowed before — log the real cause for diagnosis.
      debugPrint('[Voice] recorder.start failed: $e\n$st');
      // Roll back the optimistic countdown if recording never actually started.
      _recordingTimer?.cancel();
      _recordingTimer = null;
      if (mounted) {
        setState(() => _recording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: context.oc.error),
        );
      }
    }
  }

  /// Shows the recording state and starts the 1-second elapsed-time counter.
  void _beginRecordingTimer() {
    setState(() {
      _recording = true;
      _recordingSeconds = 0;
    });
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
    });
  }

  Future<void> _stopAndSendRecording() async {
    final l10n = AppLocalizations.of(context)!;
    final errorMsg = l10n.chatVoiceError;
    final chatId = widget.chatId;

    String? path;
    try {
      path = await _recorder.stop();
    } catch (e, st) {
      debugPrint('Recorder stop error: $e\n$st');
    } finally {
      _recordingTimer?.cancel();
      _recordingTimer = null;
      if (mounted) setState(() => _recording = false);
    }
    if (path == null || path.isEmpty || !mounted) {
      if (path == null) {
        debugPrint('Voice send: recorder.stop() returned null path');
      }
      return;
    }

    setState(() => _uploadingVoice = true);
    try {
      final media = ref.read(chatMediaServiceProvider);
      // path is a blob URL on web (fetch via http) or a filesystem path on
      // native (read directly — http.get cannot resolve file paths).
      final Uint8List bytes = kIsWeb
          ? (await http.get(Uri.parse(path))).bodyBytes
          : await File(path).readAsBytes();
      debugPrint('Voice send: chatId=$chatId path=$path bytes=${bytes.length}');
      if (chatId.isEmpty) {
        throw StateError('Voice send aborted: empty chatId');
      }
      if (bytes.isEmpty) {
        throw StateError('Voice send aborted: empty recording bytes');
      }
      final url = await media.uploadVoiceBytes(chatId, bytes);
      await _sendMedia(MessageType.voice, url);
    } catch (e, st) {
      debugPrint('Voice send error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: context.oc.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingVoice = false);
    }
  }

  void _cancelRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    if (mounted) setState(() => _recording = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final myUid = authState is AuthAuthenticated ? authState.user.id : null;

    // Resolve the other participant's name for the AppBar title.
    final chat = ref.watch(chatDetailProvider(widget.chatId)).valueOrNull;
    final otherUid = (chat == null || myUid == null)
        ? null
        : chat.participantIds.firstWhere((id) => id != myUid, orElse: () => '');
    final otherUser = (otherUid != null && otherUid.isNotEmpty)
        ? ref.watch(userByIdProvider(otherUid)).valueOrNull
        : null;
    final chatTitle = (otherUser != null && otherUser.displayName.isNotEmpty)
        ? otherUser.displayName
        : l10n.chatConversation;

    final blocked = ref.watch(blockedUserIdsProvider).valueOrNull ?? const {};
    final isBlocked =
        otherUid != null && otherUid.isNotEmpty && blocked.contains(otherUid);

    // Lock the composer once the related booking is completed: the conversation
    // stays readable as history, but no new messages can be sent.
    final bookingId = chat?.bookingId;
    final booking = (bookingId != null && bookingId.isNotEmpty)
        ? ref.watch(bookingDetailProvider(bookingId)).valueOrNull
        : null;
    final isMissionDone = booking?.status == BookingStatus.done;

    // The other participant is the provider when their uid matches the chat's
    // providerId — only then is their public profile reachable on tap.
    final otherIsProvider =
        otherUid != null && otherUid.isNotEmpty && chat?.providerId == otherUid;

    // Mark messages read whenever the set of unread messages from the other
    // party changes — keyed on the newest unread message id rather than the
    // raw count, so edits/deletes and pagination don't miss (or spam) the
    // write. Idempotent: markMessagesRead only writes for genuinely unread docs.
    ref.listen<AsyncValue<List<ChatMessage>>>(
      chatMessagesProvider(widget.chatId),
      (_, next) {
        final msgs = next.valueOrNull;
        if (msgs == null || myUid == null) return;
        final hasUnread = msgs.any(
          (m) => m.senderId != myUid && !m.readBy.contains(myUid),
        );
        if (hasUnread) _markRead();
      },
    );

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: otherIsProvider
            ? InkWell(
                onTap: () => context.push(AppRoutes.providerProfile(otherUid)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    UserAvatar(
                      photoPath: otherUser?.photoPath,
                      displayName: chatTitle,
                      radius: 16,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(chatTitle, overflow: TextOverflow.ellipsis),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: oc.secondaryText,
                    ),
                  ],
                ),
              )
            : Text(chatTitle),
        backgroundColor: oc.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (otherUid != null && otherUid.isNotEmpty)
            IconButton(
              icon: Icon(
                isBlocked ? Icons.block : Icons.block_outlined,
                size: 20,
                color: isBlocked ? oc.error : null,
              ),
              tooltip: isBlocked ? l10n.unblockUser : l10n.blockUser,
              onPressed: () => _toggleBlock(otherUid, isBlocked, l10n, oc),
            ),
          if (otherUid != null && otherUid.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.flag_outlined, size: 20),
              tooltip: l10n.bookingReport,
              onPressed: () =>
                  context.push(AppRoutes.report(type: 'user', id: otherUid)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ---- Messages ----
          Expanded(
            child: messagesAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: oc.primary,
                ),
              ),
              error: (_, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 40, color: oc.icons),
                    const SizedBox(height: 12),
                    Text(
                      l10n.chatLoadError,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(chatMessagesProvider(widget.chatId)),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
              data: (allMessages) {
                // Hide messages from users the current user has blocked.
                final messages = blocked.isEmpty
                    ? allMessages
                    : allMessages
                          .where((m) => !blocked.contains(m.senderId))
                          .toList();
                if (messages.isEmpty) {
                  return _EmptyChat();
                }
                // Auto-scroll only when the newest message changes (a real new
                // message or first load) — never when older messages are
                // prepended via pagination, and not on plain rebuilds.
                final newestId = messages.last.id;
                if (newestId != _lastBottomMsgId) {
                  _lastBottomMsgId = newestId;
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });
                }

                // When the loaded window is full there are probably older
                // messages on the server: show a header to fetch one more page.
                final currentLimit = ref.watch(
                  chatMessageLimitProvider(widget.chatId),
                );
                final hasOlder = messages.length >= currentLimit;
                final headerCount = hasOlder ? 1 : 0;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: messages.length + headerCount,
                  itemBuilder: (context, rawIndex) {
                    if (hasOlder && rawIndex == 0) {
                      return _LoadOlderButton(
                        onPressed: () =>
                            ref
                                    .read(
                                      chatMessageLimitProvider(
                                        widget.chatId,
                                      ).notifier,
                                    )
                                    .state +=
                                chatMessagePageSize,
                      );
                    }
                    final i = rawIndex - headerCount;
                    final msg = messages[i];
                    final isMe = msg.senderId == myUid;
                    // Insert a day separator above the first message of each
                    // calendar day so multi-day threads stay readable.
                    final showDaySeparator =
                        i == 0 ||
                        date_utils.isDifferentDay(
                          messages[i - 1].createdAt,
                          msg.createdAt,
                        );
                    final bubble = _MessageBubble(
                      message: msg,
                      isMe: isMe,
                      myUid: myUid,
                      onLongPress: () => _showMessageActions(msg, isMe),
                      onReactionTap: (emoji) => _react(msg, emoji),
                    );
                    if (!showDaySeparator) return bubble;
                    return Column(
                      children: [
                        _DateSeparator(date: msg.createdAt),
                        bubble,
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ---- Input bar ----
          // Blocked: hide the composer, show a banner instead.
          if (isBlocked)
            _BlockedBanner(message: l10n.chatBlockedBanner)
          // Mission completed: conversation is read-only history.
          else if (isMissionDone)
            _BlockedBanner(
              message: l10n.chatMissionEndedBanner,
              icon: Icons.lock_outline_rounded,
            )
          // Voice message uploading — show progress instead of the composer.
          else if (_uploadingVoice)
            _SendingBar(message: l10n.chatVoiceSending)
          // Image preview overlay (WhatsApp-style)
          else if (_pendingImageUrl != null)
            _ImagePreviewBar(
              imageUrl: _pendingImageUrl!,
              captionController: _controller,
              sending: _sending,
              onSend: _sendPendingImage,
              onCancel: _cancelPendingImage,
            )
          else ...[
            if (_editing != null)
              _EditComposerBanner(onCancel: _cancelEditing)
            else if (_replyingTo != null)
              _ReplyComposerBanner(
                message: _replyingTo!,
                onCancel: () => setState(() => _replyingTo = null),
              ),
            _TypingIndicatorBar(chatId: widget.chatId),
            _InputBar(
              controller: _controller,
              sending: _sending,
              recording: _recording,
              recordingSeconds: _recordingSeconds,
              onSend: _send,
              onTyping: _notifyTyping,
              onPickGallery: _pickImage,
              onTakePhoto: _takePhoto,
              onStartRecording: _startRecording,
              onStopRecording: _stopAndSendRecording,
              onCancelRecording: _cancelRecording,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Blocked banner (shown instead of the composer when the other user is blocked)
// ---------------------------------------------------------------------------

/// Header control to fetch one more page of older messages.
/// Stateful so it can show a spinner and block double-taps while the next
/// page streams in.
class _LoadOlderButton extends StatefulWidget {
  const _LoadOlderButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_LoadOlderButton> createState() => _LoadOlderButtonState();
}

class _LoadOlderButtonState extends State<_LoadOlderButton> {
  bool _loading = false;

  void _handle() {
    if (_loading) return;
    setState(() => _loading = true);
    widget.onPressed();
    // The list rebuilds with the larger window once the stream emits, which
    // replaces this widget instance. This is a fallback in case the window is
    // already at the end (no new data, same instance kept).
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: _loading ? null : _handle,
          icon: _loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: oc.primary,
                  ),
                )
              : const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
          label: Text(l10n.chatLoadOlder),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }
}

/// Centered pill marking the start of a new calendar day in the thread.
class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final label = date_utils.formatChatDaySeparator(
      date,
      today: l10n.chatDateToday,
      yesterday: l10n.chatDateYesterday,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: oc.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: oc.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner({required this.message, this.icon = Icons.block});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottomPadding),
      decoration: BoxDecoration(
        color: oc.surfaceVariant,
        border: Border(top: BorderSide(color: oc.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: oc.secondaryText),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sending bar (shown instead of the composer while media is uploading)
// ---------------------------------------------------------------------------

class _SendingBar extends StatelessWidget {
  const _SendingBar({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottomPadding),
      decoration: BoxDecoration(
        color: oc.cardSurface,
        border: Border(top: BorderSide(color: oc.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: oc.primary),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: oc.secondaryText),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reaction chips (emoji + count) shown under a message bubble
// ---------------------------------------------------------------------------

class _ReactionChips extends StatelessWidget {
  const _ReactionChips({required this.reactions, this.onTapEmoji});

  final Map<String, String> reactions;

  /// Tapping a chip toggles the current user's reaction for that emoji.
  final void Function(String emoji)? onTapEmoji;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    // Aggregate emoji → count.
    final counts = <String, int>{};
    for (final emoji in reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: [
          for (final entry in counts.entries)
            GestureDetector(
              onTap: onTapEmoji == null ? null : () => onTapEmoji!(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: oc.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: oc.border),
                ),
                child: Text(
                  entry.value > 1 ? '${entry.key} ${entry.value}' : entry.key,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reply composer banner (shown above the input when replying to a message)
// ---------------------------------------------------------------------------

class _ReplyComposerBanner extends StatelessWidget {
  const _ReplyComposerBanner({required this.message, required this.onCancel});

  final ChatMessage message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final l10n = AppLocalizations.of(context)!;
    final preview = (message.text?.isNotEmpty ?? false)
        ? message.text!
        : l10n.bookingVoiceMessageLabel;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: oc.surfaceVariant,
        border: Border(left: BorderSide(color: oc.primary, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.chatReplyingTo,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: oc.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 20, color: oc.secondaryText),
            onPressed: onCancel,
            tooltip: l10n.cancel,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit composer banner (shown above the input while editing a message)
// ---------------------------------------------------------------------------

class _EditComposerBanner extends StatelessWidget {
  const _EditComposerBanner({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: oc.surfaceVariant,
        border: Border(left: BorderSide(color: oc.primary, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, size: 16, color: oc.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.chatEditing,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: oc.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 20, color: oc.secondaryText),
            onPressed: onCancel,
            tooltip: l10n.cancel,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble
// ---------------------------------------------------------------------------

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.myUid,
    this.onLongPress,
    this.onReactionTap,
  });

  final ChatMessage message;
  final bool isMe;
  final String? myUid;
  final VoidCallback? onLongPress;
  final void Function(String emoji)? onReactionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final bg = isMe ? oc.primary : oc.surface;
    final fg = isMe ? oc.surface : oc.primaryText;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
    );

    // System messages — centered
    if (message.type == MessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: oc.border,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.text ?? '',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
            ),
          ),
        ),
      );
    }

    // Determine read receipt for own messages.
    final bool isRead = isMe && message.readBy.any((uid) => uid != myUid);

    // For received messages, resolve sender profile for the avatar.
    final senderAsync = !isMe
        ? ref.watch(userByIdProvider(message.senderId))
        : null;
    final sender = senderAsync?.valueOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          // Sender avatar — only for received messages
          if (!isMe) ...[
            UserAvatar(
              displayName: sender?.displayName ?? '',
              photoPath: sender?.photoPath,
              radius: 14,
            ),
            const SizedBox(width: 8),
          ],

          // Bubble + timestamp
          Column(
            crossAxisAlignment: align,
            children: [
              GestureDetector(
                onLongPress: message.deleted ? null : onLongPress,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.65,
                  ),
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: radius,
                    border: isMe ? null : Border.all(color: oc.border),
                  ),
                  child: message.deleted
                      ? _deletedContent(context, fg)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.isReply) _replyQuote(context, fg),
                            _buildBubbleContent(context, oc, fg),
                          ],
                        ),
                ),
              ),
              if (message.reactions.isNotEmpty && !message.deleted)
                _ReactionChips(
                  reactions: message.reactions,
                  onTapEmoji: onReactionTap,
                ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.edited && !message.deleted) ...[
                    Text(
                      AppLocalizations.of(context)!.chatEdited,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: oc.icons,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    date_utils.formatTime(message.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.2,
                      color: oc.icons,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 3),
                    // Pending (not yet synced, e.g. offline) → clock; sent →
                    // single check; read → double check.
                    Icon(
                      message.isPending
                          ? Icons.schedule_rounded
                          : isRead
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 13,
                      color: isRead ? oc.primary : oc.icons,
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Spacer on the right for sent messages to keep timestamp aligned
          if (isMe) const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _deletedContent(BuildContext context, Color fg) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 14, color: fg.withValues(alpha: 0.5)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              l10n.chatDeletedMessage,
              style: TextStyle(
                color: fg.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _replyQuote(BuildContext context, Color fg) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: fg.withValues(alpha: 0.5), width: 3),
        ),
      ),
      child: Text(
        message.replyToText?.isNotEmpty == true
            ? message.replyToText!
            : AppLocalizations.of(context)!.bookingVoiceMessageLabel,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 12.5),
      ),
    );
  }

  Widget _buildBubbleContent(BuildContext context, dynamic oc, Color fg) {
    switch (message.type) {
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.mediaUrl != null)
              GestureDetector(
                onTap: () => _showFullImage(context, message.mediaUrl!),
                child: CachedNetworkImage(
                  imageUrl: message.mediaUrl!,
                  width: 220,
                  height: 180,
                  fit: BoxFit.cover,
                  // 2× for Retina — 440×360 keeps memory reasonable
                  memCacheWidth: 440,
                  memCacheHeight: 360,
                  httpHeaders: const {'Accept': '*/*'},
                  placeholder: (_, __) => SizedBox(
                    width: 220,
                    height: 180,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => SizedBox(
                    width: 220,
                    height: 80,
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: fg.withValues(alpha: 0.5),
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            if (message.text != null && message.text!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Text(
                  message.text!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: fg, height: 1.4),
                ),
              ),
          ],
        );

      case MessageType.voice:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: _VoicePlayer(url: message.mediaUrl ?? '', fg: fg),
        );

      case MessageType.text:
      case MessageType.system:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            message.text ?? '',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: fg, height: 1.4),
          ),
        );
    }
  }

  void _showFullImage(BuildContext context, String url) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, animation, __) {
          return FadeTransition(
            opacity: animation,
            child: _FullImageViewer(url: url),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-screen image viewer (B.6) — black background, pinch-to-zoom, close
// button, tap-to-dismiss.
// ---------------------------------------------------------------------------

class _FullImageViewer extends StatelessWidget {
  const _FullImageViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: AppNetworkImage(url: url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Voice player widget
// ---------------------------------------------------------------------------

class _VoicePlayer extends StatefulWidget {
  const _VoicePlayer({required this.url, required this.fg});
  final String url;
  final Color fg;

  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  final _player = AudioPlayer();
  bool _playing = false;
  bool _hasError = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  // Pseudo-random waveform bars seeded by URL hash — stable across rebuilds
  static const int _barCount = 22;
  late final List<double> _bars;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(widget.url.hashCode);
    _bars = List.generate(_barCount, (_) => 0.25 + rng.nextDouble() * 0.75);
    _init();
  }

  Future<void> _init() async {
    try {
      final dur = await _player.setUrl(widget.url);
      if (dur != null && mounted) setState(() => _duration = dur);
    } catch (e) {
      debugPrint('VoicePlayer setUrl error: $e — url: ${widget.url}');
      if (mounted) setState(() => _hasError = true);
      return;
    }

    _positionSub = _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _playerStateSub = _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _playing = state.playing);
        if (state.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
        }
      }
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _progress => _duration.inMilliseconds > 0
      ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  @override
  Widget build(BuildContext context) {
    final fg = widget.fg;

    if (_hasError) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: fg.withValues(alpha: 0.5),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            AppLocalizations.of(context)!.chatUnsupportedFormat,
            style: TextStyle(color: fg.withValues(alpha: 0.5), fontSize: 12),
          ),
        ],
      );
    }

    // Show remaining time while playing, total duration otherwise
    final timeLabel = (_playing && _duration > _position)
        ? _fmt(_duration - _position)
        : _fmt(_duration);

    return SizedBox(
      width: 188,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Play / pause button
          GestureDetector(
            onTap: () => _playing ? _player.pause() : _player.play(),
            child: Semantics(
              button: true,
              label: _playing ? 'Pause' : 'Lecture',
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 24,
                  color: fg,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Waveform bars + time label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tappable waveform — tap to seek
                LayoutBuilder(
                  builder: (context, constraints) {
                    final waveWidth = constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        if (_duration == Duration.zero || waveWidth <= 0) {
                          return;
                        }
                        final frac = (details.localPosition.dx / waveWidth)
                            .clamp(0.0, 1.0);
                        _player.seek(
                          Duration(
                            milliseconds: (frac * _duration.inMilliseconds)
                                .round(),
                          ),
                        );
                      },
                      child: SizedBox(
                        height: 28,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(_barCount, (i) {
                            final barProgress = i / _barCount;
                            final isPlayed = barProgress < _progress;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 80),
                                  height: 28 * _bars[i],
                                  decoration: BoxDecoration(
                                    color: isPlayed
                                        ? fg
                                        : fg.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  timeLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: fg.withValues(alpha: 0.6),
                    fontSize: 10,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Image preview bar — WhatsApp-style caption before sending
// ---------------------------------------------------------------------------

class _ImagePreviewBar extends StatelessWidget {
  const _ImagePreviewBar({
    required this.imageUrl,
    required this.captionController,
    required this.sending,
    required this.onSend,
    required this.onCancel,
  });

  final String imageUrl;
  final TextEditingController captionController;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPadding),
      decoration: BoxDecoration(
        color: oc.cardSurface,
        border: Border(top: BorderSide(color: oc.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Preview + cancel
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  memCacheWidth: 128,
                  memCacheHeight: 128,
                  httpHeaders: const {'Accept': '*/*'},
                  errorWidget: (_, __, ___) => Container(
                    width: 64,
                    height: 64,
                    color: oc.border,
                    child: Icon(Icons.image, color: oc.icons),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: captionController,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: l10n.chatAddCaption,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: oc.inputFill,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: oc.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: oc.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: oc.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, size: 18, color: oc.error),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: sending ? null : onSend,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: sending ? oc.border : oc.primary,
                          shape: BoxShape.circle,
                        ),
                        child: sending
                            ? Padding(
                                padding: const EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: oc.surface,
                                ),
                              )
                            : Icon(
                                Icons.send_rounded,
                                size: 16,
                                color: oc.surface,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar — WhatsApp-style layout
// ---------------------------------------------------------------------------

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.recording,
    required this.recordingSeconds,
    required this.onSend,
    required this.onTyping,
    required this.onPickGallery,
    required this.onTakePhoto,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
  });

  final TextEditingController controller;
  final bool sending;
  final bool recording;
  final int recordingSeconds;
  final VoidCallback onSend;
  final VoidCallback onTyping;
  final VoidCallback onPickGallery;
  final VoidCallback onTakePhoto;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  // WhatsApp-style press-and-hold voice recording state.
  bool _held = false; // finger down, recording (not yet locked)
  bool _locked = false; // slid up to lock — hands-free recording
  bool _willCancel = false; // slid left far enough to cancel on release
  double _dragDx = 0;
  double _dragDy = 0;
  Offset _downPos = Offset.zero;
  // Delays the actual start so a quick tap / accidental brush never records.
  Timer? _holdStartTimer;

  static const double _lockThreshold = -80; // px up to lock hands-free
  static const Duration _holdDelay = Duration(milliseconds: 150);

  // Cancel threshold scales with screen width (≈22%) so it feels consistent
  // across small and large phones.
  double get _cancelThreshold =>
      -(MediaQuery.of(context).size.width * 0.22).clamp(70.0, 160.0);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _holdStartTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
    if (has) widget.onTyping();
  }

  String _fmt(int v) => v.toString().padLeft(2, '0');

  void _resetDrag() {
    _dragDx = 0;
    _dragDy = 0;
    _willCancel = false;
  }

  void _onPointerDown(PointerDownEvent e) {
    if (widget.sending || _locked) return;
    _downPos = e.position;
    // Start only after a short hold so a quick tap / accidental brush never
    // begins a recording.
    _holdStartTimer = Timer(_holdDelay, () {
      if (!mounted) return;
      setState(() {
        _held = true;
        _resetDrag();
      });
      HapticFeedback.mediumImpact();
      widget.onStartRecording();
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_held) return;
    final wasCancel = _willCancel;
    setState(() {
      _dragDx = e.position.dx - _downPos.dx;
      _dragDy = e.position.dy - _downPos.dy;
      _willCancel = _dragDx < _cancelThreshold;
    });
    if (_willCancel && !wasCancel) HapticFeedback.lightImpact();
    // Slide up far enough → lock hands-free recording.
    if (_dragDy < _lockThreshold && !_willCancel) {
      HapticFeedback.mediumImpact();
      setState(() {
        _locked = true;
        _held = false;
        _resetDrag();
      });
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    // Released before the hold delay elapsed → it was a tap, not a recording.
    final pending = _holdStartTimer?.isActive ?? false;
    _holdStartTimer?.cancel();
    _holdStartTimer = null;
    if (pending) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.chatHoldToRecord),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (!_held) return; // already locked or not recording
    final cancel = _willCancel;
    setState(() {
      _held = false;
      _resetDrag();
    });
    HapticFeedback.lightImpact();
    if (cancel) {
      widget.onCancelRecording();
    } else {
      widget.onStopRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Locked (hands-free) recording — explicit cancel / send controls.
    if (_locked) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPadding),
        decoration: BoxDecoration(
          color: oc.error.withValues(alpha: 0.05),
          border: Border(
            top: BorderSide(color: oc.error.withValues(alpha: 0.25)),
          ),
        ),
        child: Row(
          children: [
            _PulsingRecordDot(color: oc.error),
            const SizedBox(width: 10),
            Expanded(child: _timerLabel(context, oc)),
            IconButton(
              onPressed: () {
                setState(() => _locked = false);
                widget.onCancelRecording();
              },
              icon: Icon(Icons.delete_outline_rounded, color: oc.error),
              tooltip: l10n.cancel,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () {
                setState(() => _locked = false);
                HapticFeedback.lightImpact();
                widget.onStopRecording();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: oc.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.send_rounded, color: oc.surface, size: 22),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(6, 8, 6, 8 + bottomPadding),
      decoration: BoxDecoration(
        color: _held ? oc.error.withValues(alpha: 0.05) : oc.cardSurface,
        border: Border(
          top: BorderSide(
            color: _held ? oc.error.withValues(alpha: 0.25) : oc.border,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Left side: gallery (idle) or recording status strip (while held).
          if (_held)
            Expanded(child: _recordingStrip(context, oc, l10n))
          else ...[
            IconButton(
              onPressed: widget.sending ? null : widget.onPickGallery,
              icon: Icon(Icons.photo_outlined, color: oc.icons, size: 24),
              tooltip: l10n.chatGallery,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: EdgeInsets.zero,
            ),
            Expanded(
              child: TextField(
                controller: widget.controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: l10n.chatTyping,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: oc.inputFill,
                  suffixIcon: IconButton(
                    onPressed: widget.sending ? null : widget.onTakePhoto,
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: oc.icons,
                      size: 22,
                    ),
                    tooltip: l10n.chatTakePhoto,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: oc.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: oc.primary, width: 1.5),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),

          // Right button: spinner / send (text) / hold-to-record mic.
          if (widget.sending)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: oc.border,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: oc.cardSurface,
                ),
              ),
            )
          else if (_hasText)
            GestureDetector(
              onTap: widget.onSend,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: oc.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.send_rounded, color: oc.surface, size: 20),
              ),
            )
          else
            // Hold-to-record mic. Listener gives immediate press response and
            // full control over slide-to-cancel / slide-up-to-lock.
            Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: (_) {
                _holdStartTimer?.cancel();
                _holdStartTimer = null;
                if (_held) {
                  setState(() {
                    _held = false;
                    _resetDrag();
                  });
                  widget.onCancelRecording();
                }
              },
              // Fixed 56px slot so the button growing while held never shifts
              // the rest of the bar.
              child: SizedBox(
                width: 56,
                height: 56,
                child: Center(
                  child: Transform.translate(
                    offset: Offset(
                      _held ? _dragDx.clamp(-140.0, 0.0) : 0,
                      _held
                          ? (_dragDy < 0
                                ? (_dragDy * 0.3).clamp(-56.0, 0.0)
                                : 0)
                          : 0,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Lock affordance shown above the mic while recording.
                        if (_held && !_willCancel)
                          Positioned(
                            top: -34,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 16,
                                  color: oc.secondaryText,
                                ),
                                Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 16,
                                  color: oc.secondaryText,
                                ),
                              ],
                            ),
                          ),
                        Semantics(
                          button: true,
                          label: l10n.chatHoldToRecord,
                          child: Container(
                            width: _held ? 54 : 48,
                            height: _held ? 54 : 48,
                            decoration: BoxDecoration(
                              color: _willCancel ? oc.error : oc.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _willCancel
                                  ? Icons.delete_outline_rounded
                                  : Icons.mic_rounded,
                              color: oc.surface,
                              size: _held ? 26 : 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _timerLabel(BuildContext context, OutalmaColors oc) {
    return Row(
      children: [
        Text(
          '${_fmt(widget.recordingSeconds ~/ 60)}:${_fmt(widget.recordingSeconds % 60)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: oc.error,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _recordingStrip(
    BuildContext context,
    OutalmaColors oc,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        children: [
          _PulsingRecordDot(color: oc.error),
          const SizedBox(width: 8),
          Text(
            '${_fmt(widget.recordingSeconds ~/ 60)}:${_fmt(widget.recordingSeconds % 60)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: oc.error,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          // Slide-to-cancel hint, intensifies as the finger nears the threshold.
          Flexible(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _willCancel ? 1 : 0.6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: _willCancel ? oc.error : oc.secondaryText,
                  ),
                  Flexible(
                    child: Text(
                      _willCancel
                          ? l10n.chatReleaseToCancel
                          : l10n.chatSlideToCancel,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _willCancel ? oc.error : oc.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon wrapped in a soft circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: oc.primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 36,
                color: oc.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.chatStartConversation,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: oc.primaryText,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.chatSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: oc.secondaryText,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing indicator
// ---------------------------------------------------------------------------

class _TypingIndicatorBar extends ConsumerStatefulWidget {
  const _TypingIndicatorBar({required this.chatId});
  final String chatId;

  @override
  ConsumerState<_TypingIndicatorBar> createState() =>
      _TypingIndicatorBarState();
}

class _TypingIndicatorBarState extends ConsumerState<_TypingIndicatorBar>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  late final AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = ref.watch(otherTypingProvider(widget.chatId)).valueOrNull;
    if (timestamp == null) return const SizedBox.shrink();
    if (DateTime.now().toUtc().difference(timestamp) >
        const Duration(seconds: 5)) {
      return const SizedBox.shrink();
    }

    final oc = context.oc;
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: oc.cardSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedBuilder(
              animation: _dotController,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final offset = (i / 3);
                    final phase = (_dotController.value - offset).abs() % 1.0;
                    final scale =
                        1.0 + 0.4 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: oc.secondaryText,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pulsing record indicator dot
// ---------------------------------------------------------------------------

class _PulsingRecordDot extends StatefulWidget {
  const _PulsingRecordDot({required this.color});
  final Color color;

  @override
  State<_PulsingRecordDot> createState() => _PulsingRecordDotState();
}

class _PulsingRecordDotState extends State<_PulsingRecordDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.75,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
