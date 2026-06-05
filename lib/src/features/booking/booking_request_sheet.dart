import 'dart:async';
import 'dart:io' show File;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/app_spacing.dart';
import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/booking/booking_providers.dart';
import '../../application/provider/provider_providers.dart';
import '../../data/services/chat_media_service.dart';
import '../../data/services/geocoding_service.dart';

class BookingRequestSheet extends ConsumerStatefulWidget {
  const BookingRequestSheet({
    super.key,
    required this.serviceId,
    required this.providerId,
    required this.serviceTitle,
  });

  final String serviceId;
  final String providerId;
  final String serviceTitle;

  @override
  ConsumerState<BookingRequestSheet> createState() =>
      _BookingRequestSheetState();
}

class _BookingRequestSheetState extends ConsumerState<BookingRequestSheet> {
  int _step = 0; // 0=message, 1=schedule, 2=address
  bool _loading = false;

  final _messageController = TextEditingController();
  final _addressController = TextEditingController();
  final _messageFocus = FocusNode();
  final _addressFocus = FocusNode();

  // Voice message state
  bool _voiceMode = false;
  final _recorder = AudioRecorder();
  bool _recording = false;
  Uint8List? _recordedBytes;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  AudioPlayer? _player;
  bool _playing = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _scheduleConflict; // warning message if slot is busy

  // Place id of the selected suggestion, if any. Cleared as soon as the user
  // edits the address text by hand.
  String? _selectedPlaceId;

  bool _defaultMessageSet = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_defaultMessageSet) {
      _defaultMessageSet = true;
      final l10n = AppLocalizations.of(context)!;
      _messageController.text = l10n.bookingDefaultMessage(widget.serviceTitle);
    }
  }

  void _onMessageChanged() => setState(() {});

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _addressController.dispose();
    _messageFocus.dispose();
    _addressFocus.dispose();
    _recorder.dispose();
    _recordingTimer?.cancel();
    _player?.dispose();
    super.dispose();
  }

  // ---- Voice recording helpers ----

  Future<void> _startRecording() async {
    try {
      if (kIsWeb) {
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.opus),
          path: '',
        );
      } else {
        if (!await _recorder.hasPermission()) return;
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/booking_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
      }
      _recordingSeconds = 0;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingSeconds++);
      });
      if (mounted) setState(() => _recording = true);
    } catch (_) {
      if (mounted) {
        setState(() => _voiceMode = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.bookingVoicePermissionDenied,
            ),
            backgroundColor: context.oc.error,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    final path = await _recorder.stop();
    if (mounted) setState(() => _recording = false);
    if (path == null) return;
    try {
      final Uint8List bytes = kIsWeb
          ? (await http.get(Uri.parse(path))).bodyBytes
          : await File(path).readAsBytes();
      // Reject empty recordings (mic failure / immediate stop) so we never
      // upload a 0-byte clip that the provider cannot play. Mirrors the chat
      // guard in chat_page.dart.
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.bookingVoiceUploadFailed,
              ),
              backgroundColor: context.oc.error,
            ),
          );
        }
        return;
      }
      if (mounted) setState(() => _recordedBytes = bytes);
    } catch (_) {}
  }

  Future<void> _playPreview() async {
    final bytes = _recordedBytes;
    if (bytes == null) return;
    unawaited(_player?.dispose());
    final player = AudioPlayer();
    _player = player;
    player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _playing = false);
      }
    });
    setState(() => _playing = true);
    try {
      await player.setAudioSource(
        AudioSource.uri(Uri.dataFromBytes(bytes, mimeType: 'audio/mp4')),
      );
      await player.play();
    } catch (_) {
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _stopPreview() async {
    await _player?.stop();
    if (mounted) setState(() => _playing = false);
  }

  void _deleteRecording() {
    unawaited(_player?.dispose());
    _player = null;
    if (mounted) {
      setState(() {
        _recordedBytes = null;
        _recording = false;
        _playing = false;
        _recordingSeconds = 0;
      });
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  DateTime? get _scheduledAt {
    if (_selectedDate == null) return null;
    final time = _selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      time.hour,
      time.minute,
    );
  }

  bool get _canAdvance {
    switch (_step) {
      case 0:
        if (_voiceMode) return _recordedBytes != null;
        return _messageController.text.trim().isNotEmpty;
      case 1:
        return true; // schedule is optional
      case 2:
        return true; // address is optional
      default:
        return false;
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final successMsg = l10n.bookingSentSuccess;
    final errorMsg = l10n.errorGeneral;
    final errorColor = context.oc.error;

    setState(() => _loading = true);
    try {
      double? lat;
      double? lng;
      final placeId = _selectedPlaceId;
      if (placeId != null && placeId.isNotEmpty) {
        try {
          final geocoding = ref.read(geocodingServiceProvider);
          final coords = await geocoding.getPlaceLatLng(placeId);
          if (coords != null) {
            lat = coords.lat;
            lng = coords.lng;
          }
        } catch (_) {
          // Non-blocking: the booking can still be created without coords.
        }
      }

      String requestMessage;
      String? audioMessageUrl;
      if (_voiceMode && _recordedBytes != null) {
        final media = ref.read(chatMediaServiceProvider);
        try {
          audioMessageUrl = await media.uploadBookingVoice(_recordedBytes!);
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.bookingVoiceUploadFailed),
                backgroundColor: errorColor,
              ),
            );
            setState(() => _loading = false);
          }
          return;
        }
        requestMessage = l10n.bookingVoiceMessageLabel;
      } else {
        requestMessage = _messageController.text.trim();
      }

      final useCase = ref.read(createBookingUseCaseProvider);
      await useCase(
        providerId: widget.providerId,
        serviceId: widget.serviceId,
        requestMessage: requestMessage,
        scheduledAt: _scheduledAt,
        address: _addressController.text.trim(),
        addressLat: lat,
        addressLng: lng,
        audioMessageUrl: audioMessageUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMsg)));
        context.go(AppRoutes.bookings);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? errorMsg),
            backgroundColor: errorColor,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      locale: Localizations.localeOf(context),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      await _checkConflict();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
      await _checkConflict();
    }
  }

  Future<void> _checkConflict() async {
    final dt = _scheduledAt;
    if (dt == null) {
      setState(() => _scheduleConflict = null);
      return;
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final dateKey = (providerId: widget.providerId, date: dt);
    ref.invalidate(providerBookingsForDateProvider(dateKey));

    String? conflict;
    try {
      final bookings = await ref.read(
        providerBookingsForDateProvider(dateKey).future,
      );
      for (final b in bookings) {
        if (b.scheduledAt != null) {
          final diff = (b.scheduledAt!.difference(dt).inMinutes).abs();
          if (diff < 120) {
            conflict = l10n.bookingConflictBusy;
            break;
          }
        }
      }

      if (conflict == null) {
        final slots = await ref.read(
          blockedSlotsForProviderProvider(widget.providerId).future,
        );
        for (final slot in slots) {
          if (slot.isFullDay &&
              slot.date.year == dt.year &&
              slot.date.month == dt.month &&
              slot.date.day == dt.day) {
            conflict = l10n.bookingConflictUnavailableDay;
            break;
          }
          if (slot.endDate != null &&
              dt.isAfter(slot.date) &&
              dt.isBefore(slot.endDate!)) {
            conflict = l10n.bookingConflictUnavailableSlot;
            break;
          }
        }
      }
    } catch (_) {
      // Non-blocking — conflict detection failure should not block submission.
    }

    if (mounted) setState(() => _scheduleConflict = conflict);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomPadding = mediaQuery.padding.bottom;
    final maxHeight = mediaQuery.size.height * 0.85;

    return Container(
      decoration: BoxDecoration(
        color: oc.cardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: oc.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title + step indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.bookingRequestTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    _StepIndicator(current: _step, total: 3),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.serviceTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),

                // Step content
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _buildStepContent(),
                  ),
                ),
                const SizedBox(height: 20),

                // Navigation buttons
                Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _loading
                              ? null
                              : () => setState(() => _step--),
                          child: Text(l10n.bookingBack),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: _step < 2
                          ? ElevatedButton(
                              onPressed: _canAdvance
                                  ? () => setState(() => _step++)
                                  : null,
                              child: Text(l10n.bookingContinue),
                            )
                          : ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: oc.cardSurface,
                                      ),
                                    )
                                  : Text(l10n.bookingSend),
                            ),
                    ),
                  ],
                ),
                SizedBox(height: bottomPadding > 0 ? 0 : 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _StepMessage(
          controller: _messageController,
          focus: _messageFocus,
          voiceMode: _voiceMode,
          onToggleMode: (v) => setState(() {
            _voiceMode = v;
            // Reset voice state when switching modes
            if (!v) _deleteRecording();
          }),
          recording: _recording,
          recordedBytes: _recordedBytes,
          recordingSeconds: _recordingSeconds,
          playing: _playing,
          onStartRecording: _startRecording,
          onStopRecording: _stopRecording,
          onPlay: _playPreview,
          onStopPlay: _stopPreview,
          onDeleteRecording: _deleteRecording,
          formatDuration: _formatDuration,
        );
      case 1:
        return _StepSchedule(
          selectedDate: _selectedDate,
          selectedTime: _selectedTime,
          conflictMessage: _scheduleConflict,
          onPickDate: _pickDate,
          onPickTime: _pickTime,
        );
      case 2:
        return _StepAddress(
          controller: _addressController,
          focus: _addressFocus,
          onPlaceSelected: (placeId) =>
              setState(() => _selectedPlaceId = placeId),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Step indicator
// ---------------------------------------------------------------------------

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isActive = i <= current;
        return Container(
          width: i == current ? 20 : 8,
          height: 8,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: isActive ? oc.primary : oc.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1 — Message (text or voice)
// ---------------------------------------------------------------------------

class _StepMessage extends StatelessWidget {
  const _StepMessage({
    required this.controller,
    required this.focus,
    required this.voiceMode,
    required this.onToggleMode,
    required this.recording,
    required this.recordedBytes,
    required this.recordingSeconds,
    required this.playing,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onPlay,
    required this.onStopPlay,
    required this.onDeleteRecording,
    required this.formatDuration,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool voiceMode;
  final ValueChanged<bool> onToggleMode;
  final bool recording;
  final Uint8List? recordedBytes;
  final int recordingSeconds;
  final bool playing;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onPlay;
  final VoidCallback onStopPlay;
  final VoidCallback onDeleteRecording;
  final String Function(int) formatDuration;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.bookingStep1Title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.bookingStep1Subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
        ),
        const SizedBox(height: 12),

        // Toggle: Texte / Vocal
        Container(
          decoration: BoxDecoration(
            color: oc.inputFill,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              _ModeChip(
                label: 'Texte',
                icon: Icons.text_fields_rounded,
                selected: !voiceMode,
                onTap: () => onToggleMode(false),
              ),
              _ModeChip(
                label: 'Vocal',
                icon: Icons.mic_none_rounded,
                selected: voiceMode,
                onTap: () => onToggleMode(true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (!voiceMode)
          TextFormField(
            controller: controller,
            focusNode: focus,
            autofocus: true,
            maxLines: 5,
            maxLength: 500,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(hintText: l10n.bookingStep1Hint),
          )
        else
          _VoiceRecorder(
            recording: recording,
            recordedBytes: recordedBytes,
            recordingSeconds: recordingSeconds,
            playing: playing,
            onStartRecording: onStartRecording,
            onStopRecording: onStopRecording,
            onPlay: onPlay,
            onStopPlay: onStopPlay,
            onDelete: onDeleteRecording,
            formatDuration: formatDuration,
          ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(
              minHeight: AppSpacing.minTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
            decoration: BoxDecoration(
              color: selected ? oc.cardSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: oc.shadow,
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? oc.primary : oc.secondaryText,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected ? oc.primary : oc.secondaryText,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceRecorder extends StatelessWidget {
  const _VoiceRecorder({
    required this.recording,
    required this.recordedBytes,
    required this.recordingSeconds,
    required this.playing,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onPlay,
    required this.onStopPlay,
    required this.onDelete,
    required this.formatDuration,
  });

  final bool recording;
  final Uint8List? recordedBytes;
  final int recordingSeconds;
  final bool playing;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onPlay;
  final VoidCallback onStopPlay;
  final VoidCallback onDelete;
  final String Function(int) formatDuration;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;

    if (recordedBytes != null) {
      // Playback / delete UI
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: oc.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: oc.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            // Play / stop button
            GestureDetector(
              onTap: playing ? onStopPlay : onPlay,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: oc.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: oc.background,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.bookingVoiceMessageLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    formatDuration(recordingSeconds),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
                  ),
                ],
              ),
            ),
            // Delete button
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: oc.error),
              onPressed: onDelete,
              tooltip: AppLocalizations.of(context)!.bookingDeleteRecording,
            ),
          ],
        ),
      );
    }

    // Record UI
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 8),
          GestureDetector(
            onTap: recording ? onStopRecording : onStartRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: recording
                    ? oc.error.withValues(alpha: 0.12)
                    : oc.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: recording ? oc.error : oc.primary,
                  width: 2,
                ),
              ),
              child: Icon(
                recording ? Icons.stop_rounded : Icons.mic_rounded,
                size: 32,
                color: recording ? oc.error : oc.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            recording
                ? formatDuration(recordingSeconds)
                : AppLocalizations.of(context)!.bookingRecordPrompt,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: recording ? oc.error : oc.secondaryText,
              fontWeight: recording ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — Schedule
// ---------------------------------------------------------------------------

class _StepSchedule extends StatelessWidget {
  const _StepSchedule({
    required this.selectedDate,
    required this.selectedTime,
    required this.conflictMessage,
    required this.onPickDate,
    required this.onPickTime,
  });

  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final String? conflictMessage;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    final dateFmt = DateFormat('EEE d MMMM yyyy', 'fr_FR');
    final dateLabel = selectedDate != null
        ? dateFmt.format(selectedDate!)
        : l10n.bookingStep2PickDate;
    final timeLabel = selectedTime != null
        ? '${selectedTime!.hour.toString().padLeft(2, '0')}h${selectedTime!.minute.toString().padLeft(2, '0')}'
        : l10n.bookingStep2PickTime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.bookingStep2Title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.bookingStep2Subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
        ),
        const SizedBox(height: 16),

        // Date picker button
        _PickerButton(
          icon: Icons.calendar_today_outlined,
          label: dateLabel,
          filled: selectedDate != null,
          onTap: onPickDate,
        ),
        const SizedBox(height: AppSpacing.m),

        // Time picker button
        _PickerButton(
          icon: Icons.access_time_outlined,
          label: timeLabel,
          filled: selectedTime != null,
          onTap: onPickTime,
        ),

        // Conflict warning
        if (conflictMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: oc.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: oc.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: oc.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    conflictMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: oc.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final radius = BorderRadius.circular(12);
    return Material(
      color: filled ? oc.primary.withValues(alpha: 0.06) : oc.inputFill,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: filled ? oc.primary.withValues(alpha: 0.3) : oc.border,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: filled ? oc.primary : oc.icons),
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: filled ? oc.primary : oc.secondaryText,
                  fontWeight: filled ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 — Address
// ---------------------------------------------------------------------------

class _StepAddress extends ConsumerStatefulWidget {
  const _StepAddress({
    required this.controller,
    required this.focus,
    required this.onPlaceSelected,
  });

  final TextEditingController controller;
  final FocusNode focus;

  /// Called with the selected suggestion's placeId, or null when the user
  /// edits the address by hand (so the cached id is no longer valid).
  final ValueChanged<String?> onPlaceSelected;

  @override
  ConsumerState<_StepAddress> createState() => _StepAddressState();
}

class _StepAddressState extends ConsumerState<_StepAddress> {
  List<PlaceSuggestion> _suggestions = [];

  Future<void> _onChanged(String input) async {
    // Manual edits invalidate the previously selected place.
    widget.onPlaceSelected(null);
    if (input.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    try {
      final geocoding = ref.read(geocodingServiceProvider);
      final results = await geocoding.autocomplete(input);
      if (mounted) setState(() => _suggestions = results);
    } catch (_) {}
  }

  void _selectSuggestion(PlaceSuggestion s) {
    widget.controller.text = s.description;
    widget.onPlaceSelected(s.placeId);
    setState(() => _suggestions = []);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.bookingAddressLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.bookingStep3Subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focus,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: l10n.bookingStep3Hint,
            prefixIcon: Icon(
              Icons.location_on_outlined,
              size: 20,
              color: oc.icons,
            ),
          ),
          onChanged: _onChanged,
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              color: oc.cardSurface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(color: oc.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: oc.border.withValues(alpha: 0.5)),
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                return Semantics(
                  label: s.description,
                  button: true,
                  child: InkWell(
                    onTap: () => _selectSuggestion(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                        vertical: AppSpacing.l,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: oc.secondaryText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.description,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
