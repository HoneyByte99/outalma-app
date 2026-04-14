import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/network_image.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../l10n/app_localizations.dart';

import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/auth/auth_providers.dart';
import '../../application/auth/auth_state.dart';
import '../../application/chat/chat_providers.dart';
import '../../application/user/user_providers.dart';
import '../../data/services/chat_media_service.dart';
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

  @override
  void initState() {
    super.initState();
    // Mark messages read on initial load.
    Future.microtask(_markRead);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthAuthenticated) return;
    await ref.read(chatRepositoryProvider).markMessagesRead(
          chatId: widget.chatId,
          uid: authState.user.id,
        );
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

    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthAuthenticated) return;

    final l10n = AppLocalizations.of(context)!;
    final errorMsg = l10n.chatErrorSend;

    setState(() => _sending = true);

    try {
      await ref.read(chatRepositoryProvider).sendMessage(
            ChatMessage(
              id: '',
              chatId: widget.chatId,
              senderId: authState.user.id,
              type: MessageType.text,
              createdAt: DateTime.now().toUtc(),
              text: text,
            ),
          );
      if (mounted) {
        _controller.clear();
        SchedulerBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Pending image preview — WhatsApp-style: preview + caption before send
  String? _pendingImageUrl;

  Future<void> _sendMedia(MessageType type, String url, {String? caption}) async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState is! AuthAuthenticated) return;

    final l10n = AppLocalizations.of(context)!;
    final errorMsg = l10n.chatFileError;

    setState(() => _sending = true);
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
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
        SchedulerBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImage() async {
    final media = ref.read(chatMediaServiceProvider);
    final url = await media.pickImageFromGallery(widget.chatId);
    if (url != null && mounted) {
      setState(() => _pendingImageUrl = url);
    }
  }

  Future<void> _takePhoto() async {
    final media = ref.read(chatMediaServiceProvider);
    final url = await media.takePhoto(widget.chatId);
    if (url != null && mounted) {
      setState(() => _pendingImageUrl = url);
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

  Future<void> _startRecording() async {
    final l10n = AppLocalizations.of(context)!;
    final errorMsg = l10n.chatMicError;

    try {
      if (kIsWeb) {
        // On web, skip hasPermission (causes MissingPluginException with
        // path_provider). Browser will prompt for mic access automatically.
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.opus),
          path: '',
        );
      } else {
        if (!await _recorder.hasPermission()) return;
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
      }
      setState(() => _recording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: context.oc.error,
          ),
        );
      }
    }
  }

  Future<void> _stopAndSendRecording() async {
    final l10n = AppLocalizations.of(context)!;
    final errorMsg = l10n.chatVoiceError;

    final path = await _recorder.stop();
    setState(() => _recording = false);
    if (path == null || !mounted) return;

    setState(() => _sending = true);
    try {
      final media = ref.read(chatMediaServiceProvider);
      String url;
      // path is a blob URL on web or file path on native — fetch bytes via HTTP
      final response = await http.get(Uri.parse(path));
      url = await media.uploadVoiceBytes(
        widget.chatId,
        response.bodyBytes,
      );
      await _sendMedia(MessageType.voice, url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _cancelRecording() async {
    await _recorder.stop();
    setState(() => _recording = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final authState = ref.watch(authNotifierProvider).valueOrNull;
    final myUid =
        authState is AuthAuthenticated ? authState.user.id : null;

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: Text(l10n.chatConversation),
        backgroundColor: oc.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined, size: 20),
            tooltip: l10n.bookingReport,
            onPressed: () => context.push(
              AppRoutes.report(type: 'message', id: widget.chatId),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- Messages ----
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Text(
                  l10n.chatLoadError,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: oc.secondaryText),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return _EmptyChat();
                }
                // Auto-scroll when new messages arrive and mark them read.
                SchedulerBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                  _markRead();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == myUid;
                    return _MessageBubble(
                      message: msg,
                      isMe: isMe,
                      myUid: myUid,
                    );
                  },
                );

              },
            ),
          ),

          // ---- Input bar ----
          // Image preview overlay (WhatsApp-style)
          if (_pendingImageUrl != null)
            _ImagePreviewBar(
              imageUrl: _pendingImageUrl!,
              captionController: _controller,
              sending: _sending,
              onSend: _sendPendingImage,
              onCancel: _cancelPendingImage,
            )
          else
            _InputBar(
              controller: _controller,
              sending: _sending,
              recording: _recording,
              onSend: _send,
              onPickGallery: _pickImage,
              onTakePhoto: _takePhoto,
              onStartRecording: _startRecording,
              onStopRecording: _stopAndSendRecording,
              onCancelRecording: _cancelRecording,
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
  });

  final ChatMessage message;
  final bool isMe;
  final String? myUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oc = context.oc;
    final bg = isMe ? oc.primary : oc.surface;
    final fg = isMe ? oc.surface : oc.primaryText;
    final align =
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
      bottomRight:
          isMe ? const Radius.circular(4) : const Radius.circular(16),
    );

    // System messages — centered
    if (message.type == MessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: oc.border,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.text ?? '',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: oc.secondaryText,
                  ),
            ),
          ),
        ),
      );
    }

    // Determine read receipt for own messages.
    final bool isRead =
        isMe && message.readBy.any((uid) => uid != myUid);

    // For received messages, resolve sender profile for the avatar.
    final senderAsync = !isMe
        ? ref.watch(userByIdProvider(message.senderId))
        : null;
    final sender = senderAsync?.valueOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
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
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: radius,
                  border: isMe ? null : Border.all(color: oc.border),
                ),
                child: _buildBubbleContent(context, oc, fg),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: oc.icons,
                        ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isRead ? Icons.done_all : Icons.done,
                      size: 14,
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

  Widget _buildBubbleContent(BuildContext context, dynamic oc, Color fg) {
    switch (message.type) {
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.mediaUrl != null)
              GestureDetector(
                onTap: () => _showFullImage(context, message.mediaUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
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
                          color: fg,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => SizedBox(
                      width: 220,
                      height: 80,
                      child: Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: fg, size: 32),
                      ),
                    ),
                  ),
                ),
              ),
            if (message.text != null && message.text!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Text(
                  message.text!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: fg, height: 1.4),
                ),
              ),
          ],
        );

      case MessageType.voice:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: _VoicePlayer(url: message.mediaUrl ?? '', fg: fg),
        );

      case MessageType.text:
      case MessageType.system:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            message.text ?? '',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: fg, height: 1.4),
          ),
        );
    }
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
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
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final dur = await _player.setUrl(widget.url);
      if (dur != null && mounted) setState(() => _duration = dur);
    } catch (_) {}

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

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _playing ? _player.pause() : _player.play(),
          child: Icon(
            _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
            size: 36,
            color: widget.fg,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 4,
                child: LinearProgressIndicator(
                  value: _duration.inMilliseconds > 0
                      ? _position.inMilliseconds / _duration.inMilliseconds
                      : 0,
                  backgroundColor: widget.fg.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(widget.fg),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_fmt(_position)} / ${_fmt(_duration)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: widget.fg.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      ],
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
                        horizontal: 14, vertical: 10),
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
                children: [
                  GestureDetector(
                    onTap: onCancel,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: oc.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 18, color: oc.error),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: sending ? null : onSend,
                    child: Container(
                      width: 36,
                      height: 36,
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
                          : Icon(Icons.send_rounded,
                              size: 16, color: oc.surface),
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
    required this.onSend,
    required this.onPickGallery,
    required this.onTakePhoto,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
  });

  final TextEditingController controller;
  final bool sending;
  final bool recording;
  final VoidCallback onSend;
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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Recording mode
    if (widget.recording) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPadding),
        decoration: BoxDecoration(
          color: oc.error.withValues(alpha: 0.06),
          border: Border(
              top: BorderSide(color: oc.error.withValues(alpha: 0.3))),
        ),
        child: Row(
          children: [
            Icon(Icons.mic, color: oc.error, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.chatRecording,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: oc.error),
              ),
            ),
            IconButton(
              onPressed: widget.onCancelRecording,
              icon: Icon(Icons.delete_outline, color: oc.error),
              tooltip: l10n.cancel,
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: widget.onStopRecording,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: oc.error,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.stop_rounded, color: oc.surface, size: 24),
              ),
            ),
          ],
        ),
      );
    }

    // Normal mode — WhatsApp layout:
    // [gallery] [______message______] [camera] [mic/send]
    return Container(
      padding: EdgeInsets.fromLTRB(6, 8, 6, 8 + bottomPadding),
      decoration: BoxDecoration(
        color: oc.cardSurface,
        border: Border(top: BorderSide(color: oc.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Gallery button (left)
          IconButton(
            onPressed: widget.sending ? null : widget.onPickGallery,
            icon: Icon(Icons.photo_outlined, color: oc.icons, size: 24),
            tooltip: l10n.chatGallery,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: EdgeInsets.zero,
          ),

          // Text input with camera inside
          Expanded(
            child: TextField(
              controller: widget.controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: l10n.chatTyping,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: oc.inputFill,
                suffixIcon: IconButton(
                  onPressed: widget.sending ? null : widget.onTakePhoto,
                  icon: Icon(Icons.camera_alt_outlined,
                      color: oc.icons, size: 22),
                  tooltip: 'Photo',
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
          const SizedBox(width: 4),

          // Mic or Send button (right)
          if (widget.sending)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: oc.border,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: oc.primary,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.send_rounded, color: oc.surface, size: 20),
              ),
            )
          else
            GestureDetector(
              onTap: widget.onStartRecording,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: oc.primary,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.mic_rounded, color: oc.surface, size: 22),
              ),
            ),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 56,
              color: oc.icons,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.chatStartConversation,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.chatSubtitle,
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
// Helpers
// ---------------------------------------------------------------------------

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
