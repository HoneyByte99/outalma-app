import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_theme.dart';
import '../../app/router.dart';
import '../../application/booking/booking_providers.dart';

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
  int _step = 0; // 0-based: 0=message, 1=schedule, 2=address
  bool _loading = false;

  final _messageController = TextEditingController();
  final _scheduleController = TextEditingController();
  final _addressController = TextEditingController();

  final _messageFocus = FocusNode();
  final _scheduleFocus = FocusNode();
  final _addressFocus = FocusNode();

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
    _scheduleController.dispose();
    _addressController.dispose();
    _messageFocus.dispose();
    _scheduleFocus.dispose();
    _addressFocus.dispose();
    super.dispose();
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
        schedule: _scheduleController.text.trim(),
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
            controller: _scheduleController, focus: _scheduleFocus);
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
  const _StepSchedule({required this.controller, required this.focus});

  final TextEditingController controller;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Créneau souhaité',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Indiquez vos disponibilités (optionnel).',
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
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Ex: Lundi matin, semaine du 15 avril',
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 — Address
// ---------------------------------------------------------------------------

class _StepAddress extends StatelessWidget {
  const _StepAddress({required this.controller, required this.focus});

  final TextEditingController controller;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adresse d\'intervention',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Où souhaitez-vous que le prestataire intervienne ? (optionnel)',
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
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Ex: 12 rue de la Paix, Paris 75001',
          ),
        ),
      ],
    );
  }
}
