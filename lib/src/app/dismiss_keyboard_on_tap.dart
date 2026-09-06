import 'package:flutter/material.dart';

/// Wraps [child] and drops focus (closing the on-screen keyboard) when the
/// user taps anywhere that no more specific descendant already claims: empty
/// background, a label, the space between two fields.
///
/// This replaces the "Done" bar that used to float above the keyboard: taps
/// on a button, a chip or a field still reach that widget's own recognizer
/// first (Flutter resolves overlapping tap recognizers in favor of the
/// innermost one, hit-tested before this ancestor), so nothing here needs to
/// know about buttons to avoid swallowing them. [HitTestBehavior.translucent]
/// only makes sure genuinely empty areas (no descendant painted there at
/// all, e.g. the gaps between widgets in a Column) still count as a tap for
/// this purpose instead of falling through unnoticed.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
