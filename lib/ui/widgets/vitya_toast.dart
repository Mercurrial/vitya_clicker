import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/vitya_quotes.dart';
import '../pixel/goal_icons.dart';
import '../pixel/pixel_sprite.dart';
import '../pixel/still_sprites.dart';
import '../theme/garage.dart';

/// Что показать во всплывающей плашке.
class ToastMessage {
  /// Мелкая строка-ярлык: «СОРТ ПОДНЯЛСЯ», «ПРОДАНО».
  final String kind;

  /// Крупная строка: название сорта, имя покупателя.
  final String title;

  /// Сухая подпись с числами.
  final String note;

  /// Реплика Вити — здесь шутка уместна, потому что видят её редко.
  final String voice;

  /// Цель, значок которой показать вместо галочки. `null` — галочка.
  final String? goalId;

  const ToastMessage({
    required this.kind,
    required this.title,
    this.note = '',
    this.voice = '',
    this.goalId,
  });
}

/// Очередь плашек. Живёт в провайдере, чтобы её мог наполнять кто угодно —
/// движок через провайдер игры, интерфейс напрямую.
class ToastQueue extends Notifier<ToastMessage?> {
  Timer? _timer;
  final VityaVoice _voice = VityaVoice();

  @override
  ToastMessage? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  /// Показать плашку с репликой Вити под событие.
  void show({
    required String kind,
    required String title,
    String note = '',
    VityaEvent? event,
    String? goalId,
  }) {
    state = ToastMessage(
      kind: kind,
      title: title,
      note: note,
      voice: event == null ? '' : _voice.line(event),
      goalId: goalId,
    );
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 2800), () => state = null);
  }
}

final toastProvider = NotifierProvider<ToastQueue, ToastMessage?>(ToastQueue.new);

/// Сама плашка. Появляется сверху, уезжает сама.
class VityaToast extends ConsumerWidget {
  const VityaToast({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(toastProvider);
    final reduced = MediaQuery.of(context).disableAnimations;

    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduced ? 0 : 220),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.3), end: Offset.zero)
              .animate(animation),
          child: child,
        ),
      ),
      child: message == null
          ? const SizedBox.shrink()
          : _Card(key: ValueKey(message), message: message),
    );
  }
}

class _Card extends StatelessWidget {
  final ToastMessage message;
  const _Card({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: GS.s3),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
        decoration: BoxDecoration(
          color: GColors.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GColors.amber),
          boxShadow: const [
            BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 12)),
            BoxShadow(color: GColors.amberGlow, blurRadius: 22),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [GColors.copperDim, Color(0xFF5E3820)],
                ),
                border: Border.all(color: GColors.amber.withOpacity(0.6)),
              ),
              child: message.goalId != null
                  ? PixelImage(
                      sprite: goalIcon(message.goalId!),
                      size: 32,
                      palette: kStillPalette,
                    )
                  : Text(
                      '✓',
                      style: GType.num(
                        size: 15,
                        weight: FontWeight.w700,
                        color: GColors.lamp,
                      ),
                    ),
            ),
            const SizedBox(width: GS.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.kind,
                    style: GType.label().copyWith(color: GColors.amber, fontSize: 9),
                  ),
                  Text(
                    message.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GType.ui(size: 14, weight: FontWeight.w600),
                  ),
                  if (message.note.isNotEmpty)
                    Text(
                      message.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GType.num(size: 11, color: GColors.textMid),
                    ),
                  if (message.voice.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      message.voice,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GType.quote().copyWith(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
