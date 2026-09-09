import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The single entry point for modal bottom sheets in this app.
///
/// `showModalBottomSheet` knows nothing about the on-screen keyboard: the
/// sheet stays glued to the bottom of the screen and the keyboard covers it
/// (`Dialog` lifts itself, a sheet does not). [showAppSheet] wraps every
/// sheet in a [KeyboardAwareSheet] that lifts it above the keyboard and caps
/// its height to the space that remains visible.
///
/// Writing a sheet that contains a text field: put the drag handle and the
/// header outside the scrollable, then `Flexible(SingleChildScrollView(...))`
/// for the rest, so the field has a scrollable ancestor and the header keeps
/// the drag-to-close gesture.
///
/// An architecture test (`test/architecture/sheets_go_through_app_sheet_test`)
/// fails the suite when `showModalBottomSheet` or `viewInsets` is used
/// anywhere else under `lib/`. A legitimate exception is added to that test's
/// allowlist with a one-line justification, never by bypassing the helper.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool? showDragHandle,
  bool useSafeArea = true,
  double maxHeightFraction = 1.0,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor,
    shape: shape,
    showDragHandle: showDragHandle,
    // With useSafeArea the route keeps the sheet below the status bar by
    // itself, which is why [sheetMaxHeight] does not need the top safe area.
    useSafeArea: useSafeArea,
    builder: (_) => KeyboardAwareSheet(
      maxHeightFraction: maxHeightFraction,
      child: Builder(builder: builder),
    ),
  );
}

/// [maxHeightFraction] of a sheet that must leave the page behind it clearly
/// visible, because that page is the context of the choice being made: the
/// country picker, opened from the phone field it is about.
const double sheetFractionCompact = 0.65;

/// [maxHeightFraction] of a sheet that owns nearly the whole screen and only
/// keeps a strip of the page visible, so it still reads as a sheet and not as
/// a route: the location picker, the booking request.
const double sheetFractionTall = 0.85;

/// Pure: the tallest a sheet may be so that it stays above a keyboard of
/// [keyboardInset] pixels while never exceeding [fraction] of the screen.
double sheetMaxHeight({
  required double screenHeight,
  required double keyboardInset,
  required double fraction,
}) => math.max(
  0.0,
  math.min(screenHeight * fraction, screenHeight - keyboardInset),
);

/// Lifts a sheet's content above the on-screen keyboard and caps its height.
///
/// Two nesting contexts exist in this app, and both work:
/// - a sheet opened from a root route reads the real keyboard inset: the
///   padding lifts the content and [sheetMaxHeight] bounds it;
/// - a sheet opened from a `StatefulShellRoute` branch lives inside the
///   shell `Scaffold`'s body, whose `MediaQuery` has the bottom inset
///   removed: the inset reads 0 and the padding is inert, but that body is
///   already shrunk by the keyboard and the incoming constraint bounds the
///   sheet instead. Either way the content is fully reachable, provided it
///   is scrollable.
///
/// The content sees no bottom inset at all (`removeViewInsets`), so a sheet
/// can never pad for the keyboard twice.
class KeyboardAwareSheet extends StatelessWidget {
  const KeyboardAwareSheet({
    super.key,
    required this.child,
    this.maxHeightFraction = 1.0,
  });

  final Widget child;
  final double maxHeightFraction;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The sheet's world is the height the modal route hands it, not the
        // MediaQuery size: they differ inside a shell branch (shrunk body)
        // and on a test surface resized with setSurfaceSize. The route
        // always bounds it (_ModalBottomSheetLayout).
        assert(
          constraints.hasBoundedHeight,
          'KeyboardAwareSheet is meant to be mounted by showAppSheet',
        );
        final available = constraints.maxHeight;
        return AnimatedPadding(
          // Same timing as Dialog: the keyboard slides in ~250 ms on iOS, a
          // short animation keeps the sheet attached to it without lagging.
          duration: const Duration(milliseconds: 100),
          curve: Curves.decelerate,
          padding: EdgeInsets.only(bottom: inset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: sheetMaxHeight(
                screenHeight: available,
                keyboardInset: inset,
                fraction: maxHeightFraction,
              ),
            ),
            child: MediaQuery.removeViewInsets(
              context: context,
              removeBottom: true,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
