import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../l10n/app_localizations.dart';
import 'app_spacing.dart';
import 'app_theme.dart';

/// Wraps [child] and shows a floating bar with a button to dismiss the
/// on-screen keyboard whenever the focused text field cannot close its own
/// keyboard.
///
/// Most text fields already have a usable native return key (declaring a
/// [TextInputAction] makes it appear), so for those the bar would be a
/// redundant, "moche" button competing with the system. It only earns its
/// place for the two families that genuinely have no way out: a numeric/
/// phone keyboard, which has no return key at all on iOS, and a multiline
/// field, whose return key inserts a line break instead of submitting.
/// Rather than adding a dismiss button to each of the app's input fields one
/// by one (guaranteed to miss the next one added), this listens to
/// [FocusManager] globally and reacts whenever the focused node belongs to
/// an [EditableText], which is the one trait every text field shares
/// regardless of which screen it lives on.
class KeyboardDismissBar extends StatefulWidget {
  const KeyboardDismissBar({super.key, required this.child});

  final Widget child;

  /// The [EditableText] attached to [node], found by walking up from the
  /// focused node's context, or null if [node] isn't a text field (exposed
  /// for tests).
  @visibleForTesting
  static EditableText? editableTextFor(FocusNode? node) {
    final focusContext = node?.context;
    if (focusContext == null) return null;
    EditableText? found;
    focusContext.visitAncestorElements((element) {
      final elementWidget = element.widget;
      if (elementWidget is EditableText) {
        found = elementWidget;
        return false;
      }
      return true;
    });
    return found;
  }

  /// True when [node] is attached to an [EditableText] ancestor, the shared
  /// trait of every TextField/TextFormField in the app (exposed for tests).
  @visibleForTesting
  static bool isTextInputFocus(FocusNode? node) =>
      editableTextFor(node) != null;

  /// True when the text field attached to [node] cannot close its own
  /// keyboard, so the dismiss bar is the only way out (exposed for tests).
  ///
  /// A numeric/phone keyboard has no return key on iOS regardless of what
  /// [TextInputAction] is declared, so [EditableText.keyboardType] alone
  /// settles it. Otherwise the deciding factor is whether the field's
  /// *resolved* [TextInputAction] is [TextInputAction.newline] (return
  /// inserts a line break) rather than a submitting/navigating action --
  /// resolved the same way [EditableText] itself does: an explicit
  /// [EditableText.textInputAction] wins, and absent one, a
  /// [TextInputType.multiline] keyboard defaults to newline while every
  /// other keyboard defaults to done.
  @visibleForTesting
  static bool needsDismissBar(FocusNode? node) {
    final editableText = editableTextFor(node);
    if (editableText == null) return false;
    return !_canDismissNatively(editableText);
  }

  static bool _canDismissNatively(EditableText editableText) {
    final keyboardType = editableText.keyboardType;
    if (_hasNoReturnKey(keyboardType)) return false;
    final effectiveAction =
        editableText.textInputAction ??
        (keyboardType == TextInputType.multiline
            ? TextInputAction.newline
            : TextInputAction.done);
    return effectiveAction != TextInputAction.newline;
  }

  /// Numeric and phone keypads on iOS have no return key in their layout at
  /// all, so declaring a [TextInputAction] on them changes nothing.
  static bool _hasNoReturnKey(TextInputType keyboardType) {
    return keyboardType.index == TextInputType.number.index ||
        keyboardType == TextInputType.phone;
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
    final visible = KeyboardDismissBar.needsDismissBar(
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

/// iOS input-accessory-bar convention: a thin strip with a hairline
/// separator (never a shadow) and a plain text button, not a filled one.
/// Dismissing the keyboard is a utility action, not the screen's primary
/// action, so it must not compete visually with it.
class _DismissBar extends StatelessWidget {
  const _DismissBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final oc = context.oc;
    return Container(
      key: const Key('keyboardDismissBar'),
      decoration: BoxDecoration(
        color: oc.surface,
        border: Border(top: BorderSide(color: oc.border)),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: TextButton.icon(
              key: const Key('keyboardDismissButton'),
              onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppSpacing.minTouchTarget),
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
