import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

class Glass extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final double blur;
  final Color color;
  final EdgeInsets padding;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;

  const Glass({
    super.key,
    required this.child,
    this.borderRadius,
    this.blur = 24,
    this.color = const Color(0xCCFFFFFF),
    this.padding = EdgeInsets.zero,
    this.border,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? BorderRadius.circular(28);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow:
            shadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 1,
                spreadRadius: 1,
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              border:
                  border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1,
                  ),
              borderRadius: r,
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassDark extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsets padding;
  const GlassDark({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
  });
  @override
  Widget build(BuildContext context) {
    final r = borderRadius ?? BorderRadius.circular(28);
    return Glass(
      borderRadius: r,
      color: AppColors.ink.withValues(alpha: 0.72),
      blur: 24,
      padding: padding,
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: IconTheme(
          data: const IconThemeData(color: Colors.white),
          child: child,
        ),
      ),
    );
  }
}

class Pulse extends StatefulWidget {
  final Widget child;
  final Duration duration;
  const Pulse({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1800),
  });
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(
      begin: 0.55,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

class Hoverable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  const Hoverable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });
  @override
  State<Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<Hoverable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _down ? 0.97 : 1.0,
        child: widget.child,
      ),
    );
  }
}
