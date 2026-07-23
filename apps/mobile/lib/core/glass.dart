import 'dart:ui';
import 'package:flutter/material.dart';

/// iOS 26 "Liquid Glass"-style surface. Flutter's Cupertino package has not
/// shipped native Liquid Glass yet (roadmapped late 2026), so we assemble it
/// from its three ingredients: a heavy backdrop blur, a subtle saturation/tint
/// overlay, and a bright refraction highlight along the top edge.
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double blur;
  final BorderRadius borderRadius;
  final EdgeInsets padding;
  const LiquidGlass({
    super.key,
    required this.child,
    this.blur = 24,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            // tinted, translucent glass
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.62),
                Colors.white.withValues(alpha: 0.42),
              ],
            ),
            // refraction highlight
            border: Border.all(color: Colors.white.withValues(alpha: 0.65), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
