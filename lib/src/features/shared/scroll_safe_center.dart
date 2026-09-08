import 'package:flutter/material.dart';

/// A [Center] that scrolls instead of overflowing when its box is squeezed.
///
/// Empty and error states are centered columns that assume the room they
/// were designed for. When the on-screen keyboard shrinks the body (the home
/// grid drops to ~130 px on a small phone), a plain `Center > Column`
/// overflows and its recovery button is painted off-screen. This widget lays
/// the child out exactly like `Center` while it fits (the minimum height
/// fills the viewport, so the centering is identical) and becomes a scroll
/// view the moment it does not.
///
/// Needs a bounded height, like any scroll view: it is meant for an
/// `Expanded` slot or a sized box, not for an unbounded column.
class ScrollSafeCenter extends StatelessWidget {
  const ScrollSafeCenter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        assert(
          constraints.hasBoundedHeight,
          'ScrollSafeCenter needs a bounded height (Expanded or SizedBox)',
        );
        return SingleChildScrollView(
          // Same convention as every scrollable in the app: dragging closes
          // the keyboard, which is precisely when this state gets squeezed.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
