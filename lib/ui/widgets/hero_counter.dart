import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/kardashev_format.dart';
import '../../providers/game_provider.dart';
import '../theme/kardashev_tokens.dart';

/// The hero energy readout. Owns a [Ticker] that lerps a displayed value toward
/// the live energy total and only rebuilds when the formatted string actually
/// changes (≈1/sec for large numbers), so it never thrashes the rest of the UI.
/// Renders scientific notation (`m.mm × 10ⁿ`) above 1000, grouped int below.
class HeroCounter extends ConsumerStatefulWidget {
  const HeroCounter({super.key});

  @override
  ConsumerState<HeroCounter> createState() => _HeroCounterState();
}

class _HeroCounterState extends ConsumerState<HeroCounter> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _display = 0;
  String _lastStr = '';
  Duration _last = Duration.zero;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _display = ref.read(gameProvider).resources.gold;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration now) {
    final dt = _last == Duration.zero ? 0.016 : (now - _last).inMicroseconds / 1e6;
    _last = now;
    final target = ref.read(gameProvider).resources.gold;
    final k = _reduce ? 1.0 : (dt * 8).clamp(0.0, 1.0);
    _display += (target - _display) * k;
    final h = KFmt.hero(_display);
    final str = h.isPlain ? h.plain! : '${h.sci!.mantissa}e${h.sci!.exponent}';
    if (str != _lastStr) {
      _lastStr = str;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    _reduce = MediaQuery.of(context).disableAnimations;
    return _HeroText(KFmt.hero(_display));
  }
}

class _HeroText extends StatelessWidget {
  final HeroValue value;
  const _HeroText(this.value);

  @override
  Widget build(BuildContext context) {
    const heroSize = 44.0;
    const glow = [Shadow(color: KColors.accentGlow, blurRadius: 26)];

    final mantissa = KType.mono(
      size: heroSize,
      weight: FontWeight.w700,
      color: KColors.textHi,
      letterSpacing: heroSize * -0.02,
      height: 1.0,
      shadows: glow,
    );
    final unit = KType.mono(size: heroSize * 0.42, weight: FontWeight.w500, color: KColors.textMid);

    if (value.isPlain) {
      return RichText(
        textAlign: TextAlign.center,
        text: TextSpan(children: [
          TextSpan(text: value.plain, style: mantissa),
          TextSpan(text: '  J', style: unit),
        ]),
      );
    }

    final sci = value.sci!;
    final x10 = KType.mono(size: heroSize * 0.46, weight: FontWeight.w500, color: KColors.textMid);
    final exp = KType.mono(size: heroSize * 0.42, weight: FontWeight.w600, color: KColors.textHi);

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: [
        TextSpan(text: sci.mantissa, style: mantissa),
        TextSpan(text: ' ×10', style: x10),
        WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Transform.translate(
            offset: const Offset(1, -2),
            child: Text('${sci.exponent}', style: exp),
          ),
        ),
        TextSpan(text: ' J', style: unit),
      ]),
    );
  }
}
