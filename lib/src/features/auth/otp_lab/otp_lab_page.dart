// 🔬 OTP Lab — internal test screen for benchmarking OTP providers.
//
// Not part of the production user flow. Accessible at /otp-lab from the
// sign-in screen via a small debug link.
//
// Metrics captured per attempt:
//   - Provider used
//   - Phone number (E.164)
//   - send_at timestamp
//   - received_at timestamp (manual — user taps "Marquer reçu" when SMS arrives)
//   - verify_at timestamp
//   - success / error
//
// After a successful verify the lab signs the user out so the screen stays
// usable for further tests.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../application/auth/auth_providers.dart';
import '../../../data/auth/phone_otp_service.dart';

// ---------------------------------------------------------------------------
// In-memory log
// ---------------------------------------------------------------------------

enum OtpProvider { firebase, twilio, vonage }

class OtpAttempt {
  OtpAttempt({
    required this.provider,
    required this.phone,
    required this.sentAt,
  });

  final OtpProvider provider;
  final String phone;
  final DateTime sentAt;
  DateTime? receivedAt;
  DateTime? verifiedAt;
  String? error;
  String? code;
  bool autoVerified = false;

  Duration? get smsLatency => receivedAt?.difference(sentAt);
  Duration? get totalLatency => verifiedAt?.difference(sentAt);
  bool get isSuccess => verifiedAt != null && error == null;
}

final _attemptsProvider = StateProvider<List<OtpAttempt>>((_) => []);

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class OtpLabPage extends ConsumerStatefulWidget {
  const OtpLabPage({super.key});

  @override
  ConsumerState<OtpLabPage> createState() => _OtpLabPageState();
}

class _OtpLabPageState extends ConsumerState<OtpLabPage> {
  final _phoneController = TextEditingController(text: '+33');
  final _codeController = TextEditingController();
  OtpProvider _provider = OtpProvider.firebase;
  String? _verificationId;
  OtpAttempt? _current;
  bool _busy = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = _phoneController.text.trim();
    if (!phone.startsWith('+')) {
      _toast('Numéro doit être en E.164 (commencer par +)');
      return;
    }

    final attempt = OtpAttempt(
      provider: _provider,
      phone: phone,
      sentAt: DateTime.now(),
    );

    setState(() {
      _busy = true;
      _current = attempt;
      _verificationId = null;
      _codeController.clear();
    });

    try {
      switch (_provider) {
        case OtpProvider.firebase:
          final auth = ref.read(firebaseAuthProvider);
          // On the iOS Simulator and in debug we can't get an APNs token,
          // so we disable app verification and rely on Firebase Console
          // "Phone numbers for testing" entries to drive the flow.
          if (kDebugMode) {
            await auth.setSettings(appVerificationDisabledForTesting: true);
          }
          final vId = await platformSendOtp(auth, phone);
          if (vId == null) {
            // Android auto-verification — already signed in.
            attempt.autoVerified = true;
            attempt.verifiedAt = DateTime.now();
            // Sign out immediately so the lab stays usable.
            await auth.signOut();
          } else {
            _verificationId = vId;
          }
        case OtpProvider.twilio:
          // Use the production endpoint. The legacy `sendOtpTwilio` callable
          // was retired (cf. security review H4).
          final functions = FirebaseFunctions.instance;
          await functions
              .httpsCallable('requestPhoneOtp')
              .call<Map<String, dynamic>>({'phone': phone, 'channel': 'sms'});
          // Twilio Verify side effect = SMS dispatched. Flag to enable verify.
          _verificationId = 'twilio';
        case OtpProvider.vonage:
          throw 'Vonage non câblé pour le moment (à brancher plus tard)';
      }
    } catch (e) {
      attempt.error = '$e';
    } finally {
      ref.read(_attemptsProvider.notifier).update((list) => [attempt, ...list]);
      if (mounted) setState(() => _busy = false);
    }
  }

  void _markReceived() {
    final c = _current;
    if (c == null) return;
    setState(() {
      c.receivedAt = DateTime.now();
    });
    _toast('Reçu enregistré');
  }

  Future<void> _verify() async {
    final c = _current;
    final code = _codeController.text.trim();
    final vId = _verificationId;
    if (c == null || vId == null || code.isEmpty) return;

    setState(() => _busy = true);
    try {
      final auth = ref.read(firebaseAuthProvider);
      switch (c.provider) {
        case OtpProvider.firebase:
          await platformVerifyOtp(auth, vId, code);
          c.verifiedAt = DateTime.now();
          c.code = code;
          await auth.signOut();
          _toast('✅ OTP Firebase vérifié + sign-out auto');
        case OtpProvider.twilio:
          final functions = FirebaseFunctions.instance;
          final result = await functions
              .httpsCallable('verifyPhoneOtpAndSignIn')
              .call<Map<String, dynamic>>({'phone': c.phone, 'code': code});
          c.verifiedAt = DateTime.now();
          c.code = code;
          final newUser = result.data['newUser'] == true;
          if (newUser) {
            _toast('✅ OTP Twilio vérifié — newUser (aucun compte Outalma lié)');
          } else {
            // Sign in with the Firebase custom token, then sign out so the
            // lab stays usable.
            final token = result.data['customToken'] as String?;
            if (token != null) {
              await auth.signInWithCustomToken(token);
              await auth.signOut();
            }
            _toast('✅ OTP Twilio vérifié + sign-out auto');
          }
        case OtpProvider.vonage:
          throw 'Vonage non câblé';
      }
    } on FirebaseAuthException catch (e) {
      c.error = '${e.code}: ${e.message ?? '-'}';
      _toast('❌ ${c.error}');
    } on FirebaseFunctionsException catch (e) {
      c.error = '${e.code}: ${e.message ?? '-'}';
      _toast('❌ ${c.error}');
    } catch (e) {
      c.error = '$e';
      _toast('❌ $e');
    } finally {
      // Trigger rebuild so list shows the verifiedAt update.
      ref.read(_attemptsProvider.notifier).update((list) => [...list]);
      if (mounted) setState(() => _busy = false);
    }
  }

  void _clearLog() {
    ref.read(_attemptsProvider.notifier).state = [];
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    final attempts = ref.watch(_attemptsProvider);

    return Scaffold(
      backgroundColor: oc.background,
      appBar: AppBar(
        title: const Text('🔬 OTP Lab'),
        actions: [
          if (attempts.isNotEmpty)
            IconButton(
              tooltip: 'Effacer le log',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _clearLog,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (kDebugMode)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: oc.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: oc.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: oc.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mode debug — sur le simulateur iOS, Firebase Phone Auth '
                      'exige un numéro de test configuré dans la Firebase '
                      'Console (Authentication → Sign-in method → Phone → '
                      'Phone numbers for testing). Sinon, tester sur appareil '
                      'physique.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          _Section(
            title: 'Provider',
            child: SegmentedButton<OtpProvider>(
              segments: const [
                ButtonSegment(
                  value: OtpProvider.firebase,
                  label: Text('Firebase'),
                ),
                ButtonSegment(value: OtpProvider.twilio, label: Text('Twilio')),
                ButtonSegment(value: OtpProvider.vonage, label: Text('Vonage')),
              ],
              selected: {_provider},
              onSelectionChanged: (s) => setState(() => _provider = s.first),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Numéro à tester (E.164)',
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+33612345678 ou +221701234567',
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _busy ? null : _send,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: const Text('Envoyer OTP'),
          ),
          if (_verificationId != null) ...[
            const SizedBox(height: 16),
            _Section(
              title: 'Réception',
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _current?.receivedAt == null
                          ? 'En attente du SMS…'
                          : 'Reçu à ${_fmt(_current!.receivedAt!)} '
                                '(latence : ${_current!.smsLatency!.inMilliseconds} ms)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _current?.receivedAt == null
                        ? _markReceived
                        : null,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Marquer reçu'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Code reçu',
              child: TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '123456'),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _busy ? null : _verify,
              icon: const Icon(Icons.verified_outlined),
              label: const Text('Vérifier'),
            ),
          ],
          const SizedBox(height: 24),
          if (attempts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aucun test pour le moment',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
                ),
              ),
            )
          else
            _Section(
              title: 'Historique (${attempts.length})',
              child: Column(children: attempts.map(_buildLogTile).toList()),
            ),
        ],
      ),
    );
  }

  Widget _buildLogTile(OtpAttempt a) {
    final oc = context.oc;
    Color statusColor;
    IconData statusIcon;
    String statusText;
    if (a.error != null) {
      statusColor = oc.error;
      statusIcon = Icons.error_outline;
      statusText = a.error!;
    } else if (a.isSuccess) {
      statusColor = oc.success;
      statusIcon = Icons.check_circle_outline;
      statusText = a.autoVerified ? 'Auto-verified' : 'Vérifié';
    } else if (a.receivedAt != null) {
      statusColor = oc.warning;
      statusIcon = Icons.timelapse;
      statusText = 'En cours (reçu, non vérifié)';
    } else {
      statusColor = oc.secondaryText;
      statusIcon = Icons.send_outlined;
      statusText = 'Envoyé, en attente';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: oc.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: oc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 6),
              Text(
                '${a.provider.name.toUpperCase()} · ${a.phone}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Spacer(),
              Text(
                _fmt(a.sentAt),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            statusText,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: statusColor),
          ),
          if (a.smsLatency != null)
            Text(
              'SMS reçu en ${a.smsLatency!.inSeconds}.${(a.smsLatency!.inMilliseconds % 1000).toString().padLeft(3, '0')} s',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
            ),
          if (a.totalLatency != null)
            Text(
              'Total → vérif : ${a.totalLatency!.inSeconds} s',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: oc.secondaryText),
            ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Section card
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final oc = context.oc;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: oc.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: oc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: oc.secondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
