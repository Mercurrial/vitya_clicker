import 'package:flutter/widgets.dart';

import '../pixel/pixel_portrait.dart';
import '../theme/garage.dart';

/// Эпоха Вити — портрет растёт вместе с производством.
///
/// Смысл в почтении: чем больше империя, тем торжественнее обрамление. Юмор
/// берётся из контраста «эпическая рама ↔ обычный человек», а не из издёвки.
enum VityaEra { start, work, boss }

/// Эпоха Вити по суммарно нагнанному.
///
/// Пороги низкие намеренно: ранг — бесплатный источник ощущения роста, и если
/// он не меняется за первые полчаса, он не работает вовсе.
VityaEra vityaEraFor(double lifetime) {
  if (lifetime < 1e4) return VityaEra.start; // до 10 литров
  if (lifetime < 1e7) return VityaEra.work; // до 10 тысяч литров
  return VityaEra.boss;
}

extension VityaEraLook on VityaEra {
  String get asset => switch (this) {
        VityaEra.start => 'assets/images/vitya/vitya_doc.jpg',
        VityaEra.work => 'assets/images/vitya/vitya_frown.jpg',
        VityaEra.boss => 'assets/images/vitya/vitya_boss.jpg',
      };

  /// Подпись под портретом — сухая, как табличка в музее.
  String get caption => switch (this) {
        VityaEra.start => 'В. — начинающий',
        VityaEra.work => 'В. — за работой',
        VityaEra.boss => 'В. — директор производства',
      };
}

/// Настроение Вити — реакция на то, что происходит прямо сейчас.
///
/// Эпоха меняется раз в несколько часов и говорит, кем Витя стал. Настроение
/// меняется ежесекундно и говорит, как у него дела. Без него портрет был
/// единственной частью экрана, которая не откликалась ни на что: жар горит,
/// бак переполнен, участковый во дворе — а на стене всё то же лицо.
///
/// Показывается рамой и подписью, а не подменой фотографии: фотографий три,
/// и рисовать под каждое настроение ещё по одной некому. Рама — это оправа
/// вокруг лица, и её достаточно, чтобы состояние читалось боковым зрением.
enum VityaMood {
  /// Всё идёт как идёт.
  calm,

  /// Жар в окне — работа спорится.
  inWork,

  /// Перегрел.
  burnt,

  /// Бак полон, аппараты стоят.
  stuck,

  /// Участковый во дворе.
  hiding,
}

extension VityaMoodLook on VityaMood {
  /// Цвет рамы. Молчание — тоже ответ, поэтому у спокойного цвета нет.
  Color? get tint => switch (this) {
        VityaMood.calm => null,
        VityaMood.inWork => GColors.green,
        VityaMood.burnt => GColors.hot,
        VityaMood.stuck => GColors.amber,
        VityaMood.hiding => GColors.hot,
      };

  /// Что написать на табличке вместо эпохи. `null` — оставить эпоху.
  String? get caption => switch (this) {
        VityaMood.calm => null,
        VityaMood.inWork => 'В. — пошёл ровный',
        VityaMood.burnt => 'В. — перегнал',
        VityaMood.stuck => 'В. — некуда лить',
        VityaMood.hiding => 'В. — не дышит',
      };

  /// Стоит ли тревожно пульсировать. Только для того, что требует действия.
  bool get urgent => this == VityaMood.hiding;
}

/// Портрет Вити.
///
/// Жестов не ловит: зона касания одна и она снаружи, на всей сцене. Отсюда
/// только отдача — сжатие в момент зажима, чтобы касание ощущалось.
class VityaPortrait extends StatefulWidget {
  final VityaEra era;

  /// Что с Витей происходит прямо сейчас.
  final VityaMood mood;

  /// Держат ли сейчас палец. Портрет САМ жесты не ловит.
  ///
  /// Ловил — и это был баг: вложенный GestureDetector выигрывал арену у
  /// внешнего, тот получал onTapCancel и тут же отменял поддув, начатый
  /// внутренним. Зажим не работал вовсе. Зона касания должна быть одна, и она
  /// снаружи — на всей сцене.
  final bool pressed;

  final double size;

  /// Как переводить фотографию: спрайт или плакат.
  final PixelPortraitStyle style;

  /// Радиус рамы: пиксельный стиль требует рубленых углов.
  final double radius;

  const VityaPortrait({
    super.key,
    required this.era,
    required this.pressed,
    this.mood = VityaMood.calm,
    this.size = 220,
    this.style = PixelPortraitStyle.pixel,
    this.radius = GR.card,
  });

  @override
  State<VityaPortrait> createState() => _VityaPortraitState();
}

class _VityaPortraitState extends State<VityaPortrait>
    with TickerProviderStateMixin {
  late final AnimationController _press;

  /// Тревожная пульсация. Крутится только когда нужна: вечно вращающийся
  /// контроллер будит кадры даже в пустом гараже.
  late final AnimationController _alarm;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _alarm = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _syncAlarm();
  }

  void _syncAlarm() {
    if (widget.mood.urgent) {
      if (!_alarm.isAnimating) _alarm.repeat(reverse: true);
    } else if (_alarm.isAnimating) {
      _alarm.stop();
      _alarm.value = 0;
    }
  }

  @override
  void dispose() {
    _alarm.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VityaPortrait old) {
    super.didUpdateWidget(old);
    if (widget.mood != old.mood) _syncAlarm();
    if (widget.pressed == old.pressed) return;
    // Вибрация зажима живёт в registerTouch вместе со звуком: портрет — это
    // картинка, и знать про настройки отдачи ему незачем.
    widget.pressed ? _press.forward() : _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // Размер — по содержимому, без обёртки с заданной шириной.
    //
    // Раньше тут стоял SizedBox(width: size), и он же ограничивал подпись:
    // «В. — директор производства» в ширину рамы не влезает и рвётся ровно
    // по тире. Ширину задаёт сама рама внутри, а табличке позволено выступать
    // за её края — так её и вешают.
    //
    // Высота тоже по содержимому: до этого стоял множитель 1.28, подобранный
    // на глаз, и стоило подписи стать на строку выше, портрет вылезал за свой
    // бокс жёлтой полосой.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _press,
          builder: (context, child) {
            final t = _press.value;
            // Squash & stretch: чуть сжимается по вертикали и расплывается
            // по горизонтали — приём из классической анимации, из-за него
            // нажатие ощущается «мясистым».
            return Transform.scale(
              scaleX: 1 + 0.035 * t,
              scaleY: 1 - 0.055 * t,
              child: child,
            );
          },
          child: AnimatedBuilder(
            animation: _alarm,
            builder: (context, child) => _Frame(
              era: widget.era,
              mood: widget.mood,
              // Пульс идёт только при тревоге; в остальное время это ноль,
              // и рама не перерисовывается.
              alarm: _alarm.value,
              size: widget.size,
              style: widget.style,
              radius: widget.radius,
            ),
          ),
        ),
      ],
    );
  }
}

/// Рама портрета: медный кант, тёплый свет сверху, табличка снизу.
class _Frame extends StatelessWidget {
  final VityaEra era;
  final VityaMood mood;

  /// 0..1 — тревожный пульс. Нулевой для всех настроений, кроме шухера.
  final double alarm;

  final double size;
  final PixelPortraitStyle style;
  final double radius;

  const _Frame({
    required this.era,
    required this.mood,
    required this.alarm,
    required this.size,
    required this.style,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final grand = era == VityaEra.boss;
    final tint = mood.tint;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size * 1.1,
          padding: EdgeInsets.all(grand ? 8 : 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              // Настроение перекрашивает раму. Смешивается с медью, а не
              // заменяет её: гараж должен остаться гаражом.
              colors: tint == null
                  ? (grand
                      ? const [GColors.amber, GColors.copperDim]
                      : const [GColors.copper, GColors.copperDim])
                  : [
                      Color.lerp(GColors.copper, tint, 0.75)!,
                      Color.lerp(GColors.copperDim, tint, 0.35)!,
                    ],
            ),
            boxShadow: [
              const BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 22,
                  offset: Offset(0, 10)),
              if (grand)
                const BoxShadow(
                    color: GColors.amberGlow, blurRadius: 34, spreadRadius: 2),
              if (tint != null)
                BoxShadow(
                  // withOpacity, а не withValues: последний появился только во
                  // Flutter 3.27, а собираемся мы 3.24.
                  color: tint.withOpacity(0.30 + 0.40 * alarm),
                  blurRadius: 20 + 20 * alarm,
                  spreadRadius: alarm * 3,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius > 0 ? radius - 6 : 0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PixelPortrait(asset: era.asset, style: style),
                // Свет лампы сверху — сажает фото в гараж.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33FFD089),
                        Color(0x00000000),
                        Color(0x4D14100C)
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        // Табличка как в музее — сухо и серьёзно, в этом и шутка.
        //
        // Шире рамы намеренно: «В. — директор производства» в ширину портрета
        // не влезает и рвётся ровно по тире, отчего подпись читается как
        // обрывок. Табличке позволено выступать за раму — так её и вешают.
        //
        // Ширину задаёт сама рама (Container выше), а не обёртка вокруг всего
        // портрета — поэтому подписи никто не мешает быть шире, и колонка
        // просто становится по ней.
        //
        // OverflowBox тут не годится: в колонке он получает неограниченную
        // высоту, растягивается на бесконечность и утаскивает за экран всю
        // сцену. Проверено — пропал и портрет, и полки с аппаратами.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            // Латунь, как у настоящих табличек под портретами в коридорах.
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFD9B26A), Color(0xFF9A7338)],
            ),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: const Color(0xFF5E4420)),
            boxShadow: const [
              BoxShadow(color: Color(0x80000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            // Настроение важнее эпохи: «В. — директор производства» игрок
            // прочитал один раз, а «не дышит» надо прочитать сейчас.
            mood.caption ?? era.caption,
            textAlign: TextAlign.center,
            maxLines: 1,
            softWrap: false,
            // Буквы всегда тёмные, как гравировка. Настроение уже видно по
            // раме и её свечению, а подпись должна читаться: крашенная в тон
            // настроения, она сливалась с латунью — «некуда лить» янтарём по
            // латуни давало контраст меньше двух к одному.
            style: GType.ui(
              size: 9,
              weight: FontWeight.w700,
              color: const Color(0xFF2B1A06),
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}
