import 'package:flutter/material.dart';

/// `FittedBox` that also fills the space given to it inside a flex slot.
///
/// A bare `FittedBox` shrink-wraps to its child's size, so placed in a
/// `Flexible` it abandons its alignment. Wrapping it in an `Align` keeps the
/// child anchored (e.g. right-aligned) while still scaling down on overflow.
class ScaleFit extends StatelessWidget {
  final Widget child;
  final Alignment alignment;

  const ScaleFit({
    super.key,
    required this.child,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );
  }
}
