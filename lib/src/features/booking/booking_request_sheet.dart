import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/booking/booking_providers.dart';
import '../../application/provider/provider_providers.dart';
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

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _scheduleConflict; // warning message if slot is busy

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
  }

  void _onMessageChanged() => setState(() {});

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _addressController.dispose();
    _messageFocus.dispose();
    _addressFocus.dispose();
    super.dispose();
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
    setState(() => _loading = true);
    try {
      final useCase = ref.read(createBookingUseCaseProvider);
      await useCase(
        providerId: widget.providerId,
        serviceId: widget.serviceId,
        requestMessage: _messageController.text.trim(),
        scheduledAt: _scheduledAt,
        address: _addressController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande envoyée avec succès ✓')),
        );
        context.go(AppRoutes.bookings);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message ?? 'Une erreur est survenue. Réessayez.',
            ),
            backgroundColor: context.oc.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Une erreur est survenue. Réessayez.'),
            backgroundColor: context.oc.error,
          ),
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
      locale: const Locale('fr'),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _checkConflict();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
      _checkConflict();
    }
  }

  void _checkConflict() {
    final dt = _scheduledAt;
    if (dt == null) {
      setState(() => _scheduleConflict = null);
      return;
    }

    // Invalidate to force fresh data, then read
    final dateKey = (providerId: widget.providerId, date: dt);
    ref.invalidate(providerBookingsForDateProvider(dateKey));

    final bookingsAsync = ref.read(
      providerBookingsForDateProvider(dateKey),
    );

    final blockedAsync = ref.read(
      blockedSlotsForProviderProvider(widget.providerId),
    );

    String? conflict;

    // Check bookings
    final bookings = bookingsAsync.valueOrNull ?? [];
    for (final b in bookings) {
      if (b.scheduledAt != null) {
        final diff = (b.scheduledAt!.difference(dt).inMinutes).abs();
        if (diff < 120) {
          conflict = 'Le prestataire a d\u00e9j\u00e0 un RDV pr\u00e9vu \u00e0 cette heure.';
          break;
        }
      }
    }

    // Check blocked slots
    if (conflict == null) {
      final slots = blockedAsync.valueOrNull ?? [];
      for (final slot in slots) {
        if (slot.isFullDay &&
            slot.date.year == dt.year &&
            slot.date.month == dt.month &&
            slot.date.day == dt.day) {
          conflict = 'Le prestataire est indisponible ce jour.';
          break;
        }
        if (slot.endDate != null &&
            dt.isAfter(slot.date) &&
            dt.isBefore(slot.endDate!)) {
          conflict = 'Le prestataire est indisponible sur ce cr\u00e9neau.';
          break;
        }
      }
    }

    setState(() => _scheduleConflict = conflict);
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: oc.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                      'Demander ce service',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _StepIndicator(current: _step, total: 3),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.serviceTitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: oc.secondaryText,
                    ),
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
                        onPressed:
                            _loading ? null : () => setState(() => _step--),
                        child: const Text('Retour'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: _step > 0 ? 1 : 1,
                    child: _step < 2
                        ? ElevatedButton(
                            onPressed: _canAdvance
                                ? () => setState(() => _step++)
                                : null,
                            child: const Text('Continuer'),
                          )
                        : ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: oc.surface,
                                    ),
                                  )
                                : const Text('Envoyer la demande'),
                          ),
                  ),
                ],
              ),
              SizedBox(height: bottomPadding > 0 ? 0 : 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _StepMessage(controller: _messageController, focus: _messageFocus);
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
            controller: _addressController, focus: _addressFocus);
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
// Step 1 — Message
// ---------------------------------------------------------------------------

class _StepMessage extends StatelessWidget {
  const _StepMessage({required this.controller, required this.focus});

  final TextEditingController controller;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Décrivez votre besoin',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Donnez des détails pour aider le prestataire à comprendre votre demande.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: context.oc.secondaryText),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          focusNode: focus,
          autofocus: true,
          maxLines: 5,
          maxLength: 500,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText: 'Ex: J\'ai besoin d\'un nettoyage complet de mon appartement...',
          ),
        ),
      ],
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
    final oc = context.oc;
    final dateFmt = DateFormat('EEE d MMMM yyyy', 'fr_FR');
    final dateLabel = selectedDate != null
        ? dateFmt.format(selectedDate!)
        : 'Choisir une date';
    final timeLabel = selectedTime != null
        ? '${selectedTime!.hour.toString().padLeft(2, '0')}h${selectedTime!.minute.toString().padLeft(2, '0')}'
        : 'Choisir une heure';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date et heure souhaitées',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Sélectionnez un créneau (optionnel).',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: oc.secondaryText),
        ),
        const SizedBox(height: 16),

        // Date picker button
        _PickerButton(
          icon: Icons.calendar_today_outlined,
          label: dateLabel,
          filled: selectedDate != null,
          onTap: onPickDate,
        ),
        const SizedBox(height: 10),

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: filled ? oc.primary.withValues(alpha: 0.06) : oc.inputFill,
          borderRadius: BorderRadius.circular(12),
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
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 — Address
// ---------------------------------------------------------------------------

class _StepAddress extends ConsumerStatefulWidget {
  const _StepAddress({required this.controller, required this.focus});

  final TextEditingController controller;
  final FocusNode focus;

  @override
  ConsumerState<_StepAddress> createState() => _StepAddressState();
}

class _StepAddressState extends ConsumerState<_StepAddress> {
  List<PlaceSuggestion> _suggestions = [];

  Future<void> _onChanged(String input) async {
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
    setState(() => _suggestions = []);
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adresse d\'intervention',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'O\u00f9 souhaitez-vous que le prestataire intervienne ? (optionnel)',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: oc.secondaryText),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focus,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'Ex: 12 rue de la Paix, Paris 75001',
            prefixIcon: Icon(Icons.location_on_outlined,
                size: 20, color: oc.icons),
          ),
          onChanged: _onChanged,
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              color: oc.surface,
              borderRadius: BorderRadius.circular(12),
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
                return InkWell(
                  onTap: () => _selectSuggestion(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: oc.secondaryText),
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
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
