import 'package:equatable/equatable.dart';

import '../content/wisdom_milestones.dart';
import 'prestige_state.dart';
import 'stats_state.dart';

/// Снимок портала: с чем Витя впервые дошёл до конца мира.
///
/// Второго слоя — нового мира — в игре ещё нет, а понадобится ему ровно это:
/// кто дошёл до портала, когда и в каком состоянии. Задним числом этого не
/// узнать: после следующего похмелья коллайдера в гараже уже нет, и сейв
/// игрока, взявшего портал неделю назад, ничем не отличался бы от сейва
/// того, кто до него не дошёл.
///
/// Внутри только факты — те же, что лежат в сейве и без портала, но на
/// момент его открытия. Мудрость, множители и вехи сюда не кладутся: второй
/// слой посчитает их сам по формулам своего времени (см. [PrestigeState],
/// «Почему мудрость НЕ хранится»).
class PortalSnapshot extends Equatable {
  /// Когда открыт портал — момент покупки, UTC с точностью до миллисекунды.
  final DateTime at;

  /// Сколько нагнано за всё время, включая прошлые заходы, мл.
  final double lifetime;

  /// Сколько было нагнано на момент последнего похмелья, мл.
  final double claimedMl;

  /// Мудрость, выданная компенсацией за правку баланса.
  final int bonusWisdom;

  /// Сколько похмелий было до портала.
  final int hangovers;

  /// Сколько секунд игра была на экране до портала.
  final double playSeconds;

  PortalSnapshot({
    required DateTime at,
    required this.lifetime,
    required this.claimedMl,
    required this.bonusWisdom,
    required this.hangovers,
    required this.playSeconds,
  }) : at = _toMillis(at);

  /// Снять снимок с состояния в момент [at].
  factory PortalSnapshot.take({
    required DateTime at,
    required PrestigeState prestige,
    required StatsState stats,
  }) =>
      PortalSnapshot(
        at: at,
        lifetime: prestige.totalEverEarned,
        claimedMl: prestige.claimedMl,
        bonusWisdom: prestige.bonusWisdom,
        hangovers: prestige.hangovers,
        playSeconds: stats.playSeconds,
      );

  /// Момент — ровно таким, каким он ляжет в сейв: UTC и целые миллисекунды.
  /// Иначе снимок, прочитанный из сейва, не совпал бы с записанным: часы
  /// телефона дают микросекунды и местный пояс, а сейв их не хранит.
  static DateTime _toMillis(DateTime t) =>
      DateTime.fromMillisecondsSinceEpoch(t.millisecondsSinceEpoch, isUtc: true);

  @override
  List<Object?> get props =>
      [at, lifetime, claimedMl, bonusWisdom, hangovers, playSeconds];

  @override
  bool get stringify => true;
}

/// Открытые порталы — по миру, ИЗ которого портал открыт.
///
/// По миру, а не один снимок, потому что портал будет в конце каждого мира:
/// у гаража — коллайдер, у следующего — своя последняя ступень. Снимок
/// следующего ляжет рядом с гаражным, и ни переносить, ни переименовывать
/// гаражный не придётся. Поэтому и сам блок — общий, а не гаражный: переход
/// в новый мир сбрасывает гараж, но не его портал.
class PortalState extends Equatable {
  final Map<World, PortalSnapshot> opened;

  const PortalState([this.opened = const {}]);

  bool get isEmpty => opened.isEmpty;

  bool isOpen(World world) => opened.containsKey(world);

  PortalSnapshot? operator [](World world) => opened[world];

  /// Записать снимок, если портал из [world] ещё не открыт.
  ///
  /// Портал открывается один раз: повторная покупка коллайдера после
  /// похмелья — уже не открытие, и перезапиши она снимок, второй слой узнал
  /// бы, с чем игрок пришёл ко второму коллайдеру, а не к порталу.
  PortalState open(World world, PortalSnapshot snapshot) =>
      isOpen(world) ? this : PortalState(Map.unmodifiable({...opened, world: snapshot}));

  @override
  List<Object?> get props => [opened];
}
