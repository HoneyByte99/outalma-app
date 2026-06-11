import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../app/app_theme.dart';

/// Compact, self-contained voice-message player: a play/pause button, a
/// progress bar and a duration label. Used for the booking request's voice note
/// (booking_detail_page) so the provider can actually listen to it — without it
/// the recorded audio is uploaded but never playable.
class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({super.key, required this.url});

  final String url;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final _player = AudioPlayer();
  bool _playing = false;
  bool _hasError = false;
  bool _loading = true;
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
      if (mounted) {
        setState(() {
          _loading = false;
          if (dur != null) _duration = dur;
        });
      }
    } catch (e) {
      debugPrint('VoiceMessagePlayer setUrl error: $e — url: ${widget.url}');
      if (mounted) {
        setState(() {
          _hasError = true;
          _loading = false;
        });
      }
      return;
    }
    _positionSub = _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state.playing);
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
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
    final oc = context.oc;

    if (_hasError) {
      return Row(
        children: [
          // warning (not "cloud off") — readable as "something's wrong" without
          // any tech metaphor.
          Icon(Icons.warning_amber_rounded, color: oc.icons, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Lecture impossible',
              style: TextStyle(color: oc.secondaryText, fontSize: 13),
            ),
          ),
        ],
      );
    }

    // While the URL loads, the play button does nothing — show a spinner so a
    // tap-and-nothing-happens on a slow connection doesn't read as "broken".
    final timeLabel = _duration <= Duration.zero
        ? '—:—'
        : (_playing && _duration > _position)
        ? _fmt(_duration - _position)
        : _fmt(_duration);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: oc.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Material(
            color: oc.primary.withValues(alpha: 0.12),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkResponse(
              onTap: _loading
                  ? null
                  : () => _playing ? _player.pause() : _player.play(),
              radius: 28,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Semantics(
                  button: true,
                  label: _playing ? 'Pause' : 'Lecture',
                  child: _loading
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(oc.primary),
                          ),
                        )
                      : Icon(
                          _playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: oc.primary,
                          size: 24,
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Mic glyph makes the widget self-explanatory as "audio" even if the
          // section title isn't read.
          Icon(Icons.graphic_eq_rounded, color: oc.secondaryText, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: oc.primary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(oc.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            timeLabel,
            style: TextStyle(
              color: oc.secondaryText,
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
