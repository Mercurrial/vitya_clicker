/// «Что изменилось» — экран после обновления баланса.
///
/// Существует ради одного случая: игрок открыл новую версию, и его цифры
/// поехали. Без объяснения это читается как поломка или как обман, и игра
/// теряет доверие в тот единственный момент, когда его труднее всего вернуть.
///
/// Поэтому правила простые:
///
/// * Объясняем **что и почему**, а не «баланс улучшен».
/// * Если стало хуже — говорим это первым словом, а не прячем в конце списка.
/// * Извиняемся делом: компенсация начисляется до показа экрана, а не
///   обещается на нём.
library;

import 'package:flutter/material.dart';

import '../../content/balance.dart';
import '../theme/garage.dart';

Future<void> showBalanceNews(
  BuildContext context,
  List<BalanceRelease> releases,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xCC0B0806),
    builder: (context) => _BalanceNewsDialog(releases: releases),
  );
}

class _BalanceNewsDialog extends StatelessWidget {
  final List<BalanceRelease> releases;

  const _BalanceNewsDialog({required this.releases});

  @override
  Widget build(BuildContext context) {
    final nerfed = releases.any((r) => r.isNerf);
    final compensation =
        releases.fold(0, (sum, r) => sum + r.compensationWisdom);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(GS.s4),
      child: Container(
        decoration: BoxDecoration(
          color: GColors.surface1,
          borderRadius: BorderRadius.circular(GR.card),
          border: Border.all(color: GColors.border),
          boxShadow: const [
            BoxShadow(color: Color(0xAA000000), blurRadius: 40, offset: Offset(0, 16)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(nerfed: nerfed),
            Flexible(
              // Затухание у нижнего края: длинный список иначе обрывается
              // ровной строкой, и непонятно, что он прокручивается.
              child: ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
                  stops: [0.0, 0.88, 1.0],
                ).createShader(rect),
                blendMode: BlendMode.dstIn,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(GS.s4, 0, GS.s4, GS.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final release in releases) _Release(release: release),
                    ],
                  ),
                ),
              ),
            ),
            if (compensation > 0) _Compensation(wisdom: compensation),
            Padding(
              padding: const EdgeInsets.fromLTRB(GS.s4, GS.s2, GS.s4, GS.s4),
              child: _Button(onTap: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool nerfed;
  const _Header({required this.nerfed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GS.s4, GS.s4, GS.s4, GS.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('В ГАРАЖЕ ПЕРЕСТАНОВКА', style: GType.label()),
          const SizedBox(height: GS.s1),
          Text(
            // Плохую новость говорим первой строкой. Спрятать её в конце
            // списка — это то же самое, что промолчать.
            nerfed ? 'Кое-что стало строже' : 'Кое-что поправили',
            style: GType.ui(size: 22, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Release extends StatelessWidget {
  final BalanceRelease release;
  const _Release({required this.release});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(release.title, style: GType.ui(size: 15, weight: FontWeight.w600)),
        const SizedBox(height: GS.s2),
        for (final change in release.changes)
          Padding(
            padding: const EdgeInsets.only(bottom: GS.s2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: GS.s2),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: GColors.copper,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(child: Text(change, style: GType.body())),
              ],
            ),
          ),
        const SizedBox(height: GS.s2),
      ],
    );
  }
}

class _Compensation extends StatelessWidget {
  final int wisdom;
  const _Compensation({required this.wisdom});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: GS.s4),
      padding: const EdgeInsets.all(GS.s3),
      decoration: BoxDecoration(
        color: GColors.wellBg,
        borderRadius: BorderRadius.circular(GR.card),
        border: Border.all(color: GColors.amber.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Text(
            '+$wisdom',
            style: GType.num(size: 26, weight: FontWeight.w700, color: GColors.amber),
          ),
          const SizedBox(width: GS.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('МУДРОСТИ СВЕРХУ', style: GType.label()),
                const SizedBox(height: 2),
                // Компенсация уже начислена — обещать нельзя, можно только
                // сообщить о сделанном.
                Text('Уже начислено', style: GType.body()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  final VoidCallback onTap;
  const _Button({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: GColors.amber,
          borderRadius: BorderRadius.circular(GR.pill),
        ),
        child: Text(
          'НУ ЛАДНО',
          style: GType.ui(
            size: 14,
            weight: FontWeight.w700,
            color: GColors.onAmber,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
