import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'shop_scroll_coordinator.dart';
import 'shop_scroll_position.dart';

/// 滑动控制器。为可滚动小部件创建一个控制器。
///
/// [initialScrollOffset] 和 [keepScrollOffset] 的值不能为 null。
class ShopScrollController extends ScrollController {
  ShopScrollController(
    this.coordinator, {
    double initialScrollOffset = 0.0,

    /// 每次滚动完成时，请使用 [PageStorage] 保存当前滚动 [offset] ，如果重新创建了此
    /// 控制器的可滚动内容，则将其还原。
    ///
    /// 如果将此属性设置为false，则永远不会保存滚动偏移量，
    /// 并且始终使用 [initialScrollOffset] 来初始化滚动偏移量。如果为 true（默认值），
    /// 则第一次创建控制器的可滚动对象时将使用初始滚动偏移量，因为尚无要还原的滚动偏移量。
    /// 随后，将恢复保存的偏移，并且忽略[initialScrollOffset]。
    ///
    /// 也可以看看：
    ///  * [PageStorageKey]，当同一路径中出现多个滚动条时，应使用 [PageStorageKey]
    ///    来区分用于保存滚动偏移量的 [PageStorage] 位置。
    bool keepScrollOffset = true,

    /// [toString] 输出中使用的标签。帮助在调试输出中标识滚动控制器实例。
    String debugLabel,
  })  : assert(initialScrollOffset != null),
        assert(keepScrollOffset != null),
        _initialScrollOffset = initialScrollOffset,
        super(keepScrollOffset: keepScrollOffset, debugLabel: debugLabel);

  final ShopScrollCoordinator coordinator;

  /// 用于 [offset] 的初始值。
  /// 如果 [keepScrollOffset] 为 false 或尚未保存滚动偏移量，
  /// 则创建并附加到此控制器的新 [ShopScrollPosition] 对象的偏移量将初始化为该值。
  /// 默认为 0.0。
  @override
  double get initialScrollOffset => _initialScrollOffset;
  final double _initialScrollOffset;

  /// 当前附加的 [positions]。
  ///
  /// 不应直接突变。
  /// 可以使用 [attach] 和 [detach] 添加和删除 [ShopScrollPosition] 对象。
  @protected
  @override
  Iterable<ShopScrollPosition> get positions => _positions;
  final List<ShopScrollPosition> _positions = <ShopScrollPosition>[];

  /// 是否有任何 [ShopScrollPosition] 对象已使用 [attach] 方法
  /// 将自身附加到 [ScrollController]。
  ///
  /// 如果为 false，则不得调用与 [ShopScrollPosition] 交互的成员，
  /// 例如 [position]，[offset]，[animateTo] 和 [jumpTo]。
  @override
  bool get hasClients => _positions.isNotEmpty;

  /// 返回附加的[ScrollPosition]，可以从中获取[ScrollView]的实际滚动偏移量。
  ///
  /// 仅在仅连接一个 [position] 时调用此选项才有效。
  @override
  ShopScrollPosition get position {
    assert(_positions.isNotEmpty,
        'ScrollController not attached to any scroll views.');
    assert(_positions.length == 1,
        'ScrollController attached to multiple scroll views.');
    return _positions.single;
  }

  /// 可滚动小部件的当前滚动偏移量。要求控制器仅控制一个可滚动小部件。
  @override
  double get offset => position.pixels;

  /// 从当前位置到给定值的位置动画。
  /// 任何活动的动画都将被取消。 如果用户当前正在滚动，则该操作将被取消。
  /// 返回的 [Future] 将在动画结束时完成，无论它是否成功完成或是否被过早中断。
  ///
  /// 每当用户尝试手动滚动或启动其他活动，或者动画到达视口边缘并尝试过度滚动时，
  /// 动画都会中断。如果 [ShopScrollPosition] 不会过度滚动，而是允许滚动超出范围，
  /// 那么超出范围不会中断动画。
  ///
  /// 动画对视口或内容尺寸的更改无动于衷。
  ///
  /// 一旦动画完成，如果滚动位置的值不稳定，则滚动位置将尝试开始弹道活动。
  /// （例如，如果滚动超出范围，并且在这种情况下滚动位置通常会弹回）
  ///
  /// 持续时间不能为零。要在没有动画的情况下跳至特定值，请使用 [jumpTo]。
  @override
  Future<void> animateTo(
    double offset, {
    @required Duration duration,
    @required Curve curve,
  }) {
    assert(
      _positions.isNotEmpty,
      'ScrollController not attached to any scroll views.',
    );
    final List<Future<void>> animations = List<Future<void>>(_positions.length);
    for (int i = 0; i < _positions.length; i += 1)
      animations[i] = _positions[i].animateTo(
        offset,
        duration: duration,
        curve: curve,
      );
    return Future.wait<void>(animations).then<void>((List<void> _) => null);
  }

  /// 将滚动位置从其当前值跳转到给定值，而不进行动画处理，也无需检查新值是否在范围内。
  /// 任何活动的动画都将被取消。 如果用户当前正在滚动，则该操作将被取消。
  ///
  /// 如果此方法更改了滚动位置，则将分派开始/更新/结束滚动通知的序列。
  /// 此方法不能生成过滚动通知。跳跃之后，如果数值超出范围，则立即开始弹道活动。
  @override
  void jumpTo(double value) {
    assert(
      _positions.isNotEmpty,
      'ScrollController not attached to any scroll views.',
    );
    for (final ScrollPosition position in List<ScrollPosition>.from(_positions))
      position.jumpTo(value);
  }

  /// 在此控制器上注册给定位置。
  /// 此函数返回后，此控制器上的 [animateTo] 和 [jumpTo] 方法将操纵给定位置。
  @override
  void attach(covariant ShopScrollPosition position) {
    assert(!_positions.contains(position));
    _positions.add(position);
    position.addListener(notifyListeners);
  }

  /// 用此控制器注销给定位置。
  /// 此函数返回后，此控制器上的 [animateTo] 和 [jumpTo] 方法将不会操纵给定位置。
  @override
  void detach(ScrollPosition position) {
    assert(_positions.contains(position));
    position.removeListener(notifyListeners);
    _positions.remove(position);
  }

  @override
  void dispose() {
    for (final ScrollPosition position in _positions)
      position.removeListener(notifyListeners);
    super.dispose();
  }

  /// 创建一个 [ShopScrollPosition] 供 [Scrollable] 小部件使用。
  ///
  /// 子类可以重写此功能，以自定义其控制的可滚动小部件使用的 [ShopScrollPosition]。
  /// 例如，[PageController] 重写此函数以返回面向页面的滚动位置子类，
  /// 该子类在可滚动窗口小部件调整大小时保持同一页面可见。
  ///
  /// 默认情况下，返回 [ScrollPositionWithSingleContext]。
  /// 参数通常传递给正在创建的 [ScrollPosition]：
  ///
  ///  * [physics]：[ScrollPhysics] 的一个实例，它确定 [ScrollPosition] 对用户交互的
  ///    反应方式，释放或甩动时如何模拟滚动等。该值不会为null。它通常来自 [ScrollView]
  ///    或其他创建 [Scrollable]的小部件，
  ///    或者（如果未提供）来自环境的 [ScrollConfiguration]。
  ///  * [context]：一个 [ScrollContext]，用于与拥有 [ScrollPosition] 的对象进行通信
  ///   （通常是 [Scrollable] 本身）。
  ///  * [oldPosition]：如果这不是第一次为此 [Scrollable] 创建 [ScrollPosition]，则
  ///    它将是前一个实例。当环境已更改并且 [Scrollable] 需要重新创建 [ScrollPosition]
  ///    对象时，将使用此方法。 第一次创建 [ScrollPosition] 时为 null。
  @override
  ShopScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition oldPosition,
  ) {
    return ShopScrollPosition(
      coordinator: coordinator,
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }

  @override
  String toString() {
    final List<String> description = <String>[];
    debugFillDescription(description);
    return '${describeIdentity(this)}(${description.join(", ")})';
  }

  /// 在给定的描述中添加其他信息，以供 [toString] 使用。
  /// 此方法使子类更易于协调以提供高质量的 [toString] 实现。[ScrollController] 基类上
  /// 的 [toString] 实现调用 [debugFillDescription] 来从子类中收集有用的信息，以合并
  /// 到其返回值中。如果您重写了此方法，请确保通过调用
  /// `super.debugFillDescription)description)` 来启动方法。
  @override
  @mustCallSuper
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (debugLabel != null) {
      description.add(debugLabel);
    }
    if (initialScrollOffset != 0.0)
      description.add(
          'initialScrollOffset: ${initialScrollOffset.toStringAsFixed(1)}, ');
    if (_positions.isEmpty) {
      description.add('no clients');
    } else if (_positions.length == 1) {
      // 实际上不列出客户端本身，因为它的 toString 可能引用了我们。
      description.add('one client, offset ${offset?.toStringAsFixed(1)}');
    } else {
      description.add('${_positions.length} clients');
    }
  }
}
