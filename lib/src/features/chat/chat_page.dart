import 'dart:async';
import 'dart:io' show File;
import 'dart:math' as math;

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
import '../../core/utils/date_utils.dart' as date_utils;
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
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  int _lastMarkedReadCount = 0;
  int _lastScrolledCount = 0;
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
            ),
          );
      if (mounted) {
        _controller.clear();
        SchedulerBinding.instance.addPostFrameCallback(
          (_) => _scrollToBottom(),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: context.oc.error),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Pending image preview — WhatsApp-style: preview + caption before send
  String? _pendingImageUrl;

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
          SnackBar(content: Text(errorMsg), backgroundColor: context.oc.error),
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
        if (!await _recorder.hasPermission()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.chatMicError),
                backgroundColor: context.oc.error,
              ),
            );
          }
          return;
        }
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
      }
      if (mounted) {
        setState(() {
          _recording = true;
          _recordingSeconds = 0;
        });
        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordingSeconds++);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: context.oc.error),
        );
      }
    }
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

    // Mark messages read only when the message count actually grows — not on
    // every rebuild. Prevents a runaway Firestore write loop in the chat view.
    ref.listen<AsyncValue<List<ChatMessage>>>(
      chatMessagesProvider(widget.chatId),
      (_, next) {
        final msgs = next.valueOrNull;
        if (msgs == null) return;
        if (msgs.length != _lastMarkedReadCount) {
          _lastMarkedReadCount = msgs.length;
          _markRead();
        }
      },
    );

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: Text(chatTitle),
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
                  ],
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return _EmptyChat();
                }
                // Auto-scroll only when new messages arrive, not on every
                // rebuild (e.g. keystrokes), to avoid scroll fighting.
                if (messages.length > _lastScrolledCount) {
                  _lastScrolledCount = messages.length;
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });
                }

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
          else ...[
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
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    Icon(
                      isRead ? Icons.done_all_rounded : Icons.done_rounded,
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
            child: Container(
              width: 40,
              height: 40,
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
    if (has) widget.onTyping();
  }

  String _fmt(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Recording mode
    if (widget.recording) {
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
            // Pulsing mic dot
            _PulsingRecordDot(color: oc.error),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Text(
                    l10n.chatRecording,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: oc.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_fmt(widget.recordingSeconds ~/ 60)}:${_fmt(widget.recordingSeconds % 60)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: oc.error,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            // Cancel (trash)
            IconButton(
              onPressed: widget.onCancelRecording,
              icon: Icon(Icons.delete_outline_rounded, color: oc.error),
              tooltip: l10n.cancel,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
            const SizedBox(width: 6),
            // Send recording
            GestureDetector(
              onTap: widget.onStopRecording,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: oc.error,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.send_rounded, color: oc.surface, size: 22),
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
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
                child: Icon(Icons.send_rounded, color: oc.surface, size: 20),
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
                child: Icon(Icons.mic_rounded, color: oc.surface, size: 22),
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
