import 'package:flutter/widgets.dart';

import '../theme/kardashev_tokens.dart';

/// The star core — a PASSIVE visual (no clicking in KARDASHEV). Radial
/// plasma-cyan gradient, dark inner ring, soft cyan glow, gentle idle pulse
/// (scale 1.0↔1.03). Energy is radiated continuously; you build around it.
class CoreButton extends StatefulWidget {
  final double size;
  final bool reduceMotion;
  const CoreButton({super.key, this.size = 210, this.reduceMotion = false});

  @override
  State<CoreButton> createState() => _CoreButtonState();
}

class _CoreButtonState extends State<CoreButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // 1.2s each way ⇒ 2.4s full pulse cycle.
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    if (!widget.reduceMotion) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final scale = widget.reduceMotion ? 1.0 : 1.0 + 0.03 * _pulse.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(0, -0.12),
                radius: 0.72,
                colors: [
                  Color(0xFFBFFCF6),
                  KColors.accent,
                  Color(0xFF16847C),
                  Color(0xFF0C2C2E),
                  KColors.voidBg,
                ],
                stops: [0.0, 0.26, 0.58, 0.82, 1.0],
              ),
              boxShadow: KShadow.coreIdle,
            ),
            child: Padding(
              padding: EdgeInsets.all(widget.size * 0.12),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(BorderSide(color: KColors.coreRing, width: 2)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Centers the core in the main screen's core zone.
class CoreZone extends StatelessWidget {
  final bool reduceMotion;
  const CoreZone({super.key, this.reduceMotion = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 380,
      child: Center(child: CoreButton(size: 210, reduceMotion: reduceMotion)),
    );
  }
}
