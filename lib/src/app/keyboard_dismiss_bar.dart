import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../l10n/app_localizations.dart';
import 'app_spacing.dart';
import 'app_theme.dart';

/// Wraps [child] and shows a floating bar with a button to dismiss the
/// on-screen keyboard whenever any text field in the app has focus.
///
/// This is the one shared mechanism for a problem that touches every screen
/// with a text field: a keyboard without a usable return key (numeric,
/// phone, multiline) leaves the user with no way to close it, sitting on top
/// of whatever they were trying to reach. Rather than adding a dismiss
/// button to each of the app's input fields one by one (guaranteed to miss
/// the next one added), this listens to [FocusManager] globally and reacts
/// whenever the focused node belongs to an [EditableText], which is the one
/// trait every text field shares regardless of which screen it lives on.
class KeyboardDismissBar extends StatefulWidget {
  const KeyboardDismissBar({super.key, required this.child});

  final Widget child;

  /// True when [node] is attached to an [EditableText] ancestor, the shared
  /// trait of every TextField/TextFormField in the app (exposed for tests).
  @visibleForTesting
  static bool isTextInputFocus(FocusNode? node) {
    final focusContext = node?.context;
    if (focusContext == null) return false;
    var found = false;
    focusContext.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        found = true;
        return false;
      }
      return true;
    });
    return found;
  }

  @override
  State<KeyboardDismissBar> createState() => _KeyboardDismissBarState();
}

class _KeyboardDismissBarState extends State<KeyboardDismissBar> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    final visible = KeyboardDismissBar.isTextInputFocus(
      FocusManager.instance.primaryFocus,
    );
    if (visible == _visible) return;
    // FocusManager notifies listeners mid-frame (while the framework may
    // still be building/laying out), so rebuilding synchronously here can
    // hit a "setState called during build" assertion. Defer to next frame.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = visible);
    });
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Stack(
      key: const Key('keyboardDismissStack'),
      children: [
        widget.child,
        if (_visible)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: const _DismissBar(),
          ),
      ],
    );
  }
}

class _DismissBar extends StatelessWidget {
  const _DismissBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Material(
      key: const Key('keyboardDismissBar'),
      color: oc.surface,
      elevation: 4,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: ElevatedButton.icon(
              key: const Key('keyboardDismissButton'),
              onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
              style: ElevatedButton.styleFrom(
                backgroundColor: oc.primary,
                foregroundColor: oc.surface,
                minimumSize: const Size(0, AppSpacing.minTouchTarget),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              icon: const Icon(Icons.keyboard_hide_rounded, size: 20),
              label: Text(l10n.keyboardDismiss),
            ),
          ),
        ),
      ),
    );
  }
}
