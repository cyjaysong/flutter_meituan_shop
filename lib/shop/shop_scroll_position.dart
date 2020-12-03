import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'shop_scroll_coordinator.dart';

/// 滑动位置信息
class ShopScrollPosition extends ScrollPosition
    implements ScrollActivityDelegate {
  ShopScrollPosition({
    @required ScrollPhysics physics,
    @required ScrollContext context,
    double initialPixels = 0.0,
    bool keepScrollOffset = true,
    ScrollPosition oldPosition,
    String debugLabel,
    @required this.coordinator,
  }) : super(
          physics: physics,
          context: context,
          keepScrollOffset: keepScrollOffset,
          oldPosition: oldPosition,
          debugLabel: debugLabel,
        ) {
    // 如果oldPosition不为null，则父级将首先调用Absorb()，它可以设置_pixels和_activity.
    if (pixels == null && initialPixels != null) {
      correctPixels(initialPixels);
    }
    if (activity == null) {
      goIdle();
    }
    assert(activity != null);
  }

  final ShopScrollCoordinator coordinator; // 协调器
  ScrollDragController _currentDrag;
  double _heldPreviousVelocity = 0.0;

  @override
  AxisDirection get axisDirection => context.axisDirection;

  @override
  double setPixels(double newPixels) {
    assert(activity.isScrolling);
    return super.setPixels(newPixels);
  }

  @override
  void absorb(ScrollPosition other) {
    super.absorb(other);
    if (other is! ShopScrollPosition) {
      goIdle();
      return;
    }
    activity.updateDelegate(this);
    final ShopScrollPosition typedOther = other as ShopScrollPosition;
    _userScrollDirection = typedOther._userScrollDirection;
    assert(_currentDrag == null);
    if (typedOther._currentDrag != null) {
      _currentDrag = typedOther._currentDrag;
      _currentDrag.updateDelegate(this);
      typedOther._currentDrag = null;
    }
  }

  @override
  void applyNewDimensions() {
    super.applyNewDimensions();
    context.setCanDrag(physics.shouldAcceptUserOffset(this));
  }

  /// 返回未使用的增量。
  ///
  /// 正增量表示下降（在上方显示内容），负增量向上（在下方显示内容）。
  double applyClampedDragUpdate(double delta) {
    assert(delta != 0.0);
    // 如果我们要朝向 maxScrollExtent（负滚动偏移），那么我们在 minScrollExtent 方向上
    // 可以达到的最大距离是负无穷大。例如，如果我们已经过度滚动，则滚动以减少过度滚动不应
    // 禁止过度滚动。如果我们要朝 minScrollExtent（正滚动偏移量）方向移动，那么我们在
    // minScrollExtent 方向上可以达到的最大距离是我们现在所处的位置。
    // 换句话说，我们不能通过 applyClampedDragUpdate 进入过滚动状态。
    // 尽管如此，可能通过多种方式进入了过度滚动的情况。一种是物理是否允许通过
    // applyFullDragUpdate（请参见下文）。
    // 可能会发生过度滚动的情况，例如，使用滚动控制器人工设置了滚动位置。
    final double min =
        delta < 0.0 ? -double.infinity : math.min(minScrollExtent, pixels);
    // max 的逻辑是等效的，但反向。
    final double max =
        delta > 0.0 ? double.infinity : math.max(maxScrollExtent, pixels);
    final double oldPixels = pixels;
    final double newPixels = (pixels - delta).clamp(min, max) as double;
    final double clampedDelta = newPixels - pixels;
    if (clampedDelta == 0.0) {
      return delta;
    }
    final double overScroll = physics.applyBoundaryConditions(this, newPixels);
    final double actualNewPixels = newPixels - overScroll;
    final double offset = actualNewPixels - oldPixels;
    if (offset != 0.0) {
      forcePixels(actualNewPixels);
      didUpdateScrollPositionBy(offset);
    }
    return delta + offset;
  }

  // 返回过度滚动。
  double applyFullDragUpdate(double delta) {
    assert(delta != 0.0);
    final double oldPixels = pixels;
    // Apply friction: 施加摩擦：
    final double newPixels =
        pixels - physics.applyPhysicsToUserOffset(this, delta);
    if (oldPixels == newPixels) {
      // 增量一定很小，我们在添加浮点数时将其删除了
      return 0.0;
    }
    // Check for overScroll: 检查过度滚动：
    final double overScroll = physics.applyBoundaryConditions(this, newPixels);
    final double actualNewPixels = newPixels - overScroll;
    if (actualNewPixels != oldPixels) {
      forcePixels(actualNewPixels);
      didUpdateScrollPositionBy(actualNewPixels - oldPixels);
    }
    return overScroll;
  }

  /// 当手指滑动时，该方法会获取到滑动距离。
  ///
  /// [delta] 滑动距离，正增量表示下滑，负增量向上滑。
  ///
  /// 我们需要把子部件的滑动数据交给协调器处理，主部件无干扰。
  @override
  void applyUserOffset(double delta) {
    final ScrollDirection userScrollDirection =
        delta > 0.0 ? ScrollDirection.forward : ScrollDirection.reverse;
    if (debugLabel != coordinator.pageLabel) {
      return coordinator.applyUserOffset(delta, userScrollDirection, this);
    }
    updateUserScrollDirection(userScrollDirection);
    setPixels(pixels - physics.applyPhysicsToUserOffset(this, delta));
  }

  @override
  void beginActivity(ScrollActivity newActivity) {
    _heldPreviousVelocity = 0.0;
    if (newActivity == null) {
      return;
    }
    assert(newActivity.delegate == this);
    super.beginActivity(newActivity);
    _currentDrag?.dispose();
    _currentDrag = null;
    if (!activity.isScrolling) {
      updateUserScrollDirection(ScrollDirection.idle);
    }
  }

  /// 将用户滚动方向设置为给定值。
  /// 如果更改了该值，则将分派 [User ScrollNotification]。
  @protected
  @visibleForTesting
  void updateUserScrollDirection(ScrollDirection value) {
    assert(value != null);
    if (userScrollDirection == value) {
      return;
    }
    _userScrollDirection = value;
    didUpdateScrollDirection(value);
  }

  @override
  ScrollHoldController hold(VoidCallback holdCancelCallback) {
    final double previousVelocity = activity.velocity;
    final HoldScrollActivity holdActivity = HoldScrollActivity(
      delegate: this,
      onHoldCanceled: holdCancelCallback,
    );
    beginActivity(holdActivity);
    _heldPreviousVelocity = previousVelocity;
    return holdActivity;
  }

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    final ScrollDragController drag = ScrollDragController(
      delegate: this,
      details: details,
      onDragCanceled: dragCancelCallback,
      carriedVelocity: physics.carriedMomentum(_heldPreviousVelocity),
      motionStartDistanceThreshold: physics.dragStartDistanceMotionThreshold,
    );
    beginActivity(DragScrollActivity(this, drag));
    assert(_currentDrag == null);
    _currentDrag = drag;
    return drag;
  }

  @override
  void goIdle() {
    beginActivity(IdleScrollActivity(this));
  }

  /// 以特定的速度开始一个物理驱动的模拟，该模拟确定 [pixels] 位置。
  /// 此方法遵从 [ScrollPhysics.createBallisticSimulation]，该方法通常在当前位置超出
  /// 范围时提供滑动模拟，而在当前位置超出范围但具有非零速度时提供摩擦模拟。
  /// 速度应以逻辑像素/秒为单位。
  @override
  void goBallistic(double velocity, [bool fromCoordinator = false]) {
    if (debugLabel != coordinator.pageLabel) {
      if (velocity > 0.0) {
        coordinator.goBallistic(velocity);
      }
    } else {
      if (fromCoordinator && velocity <= 0.0) {
        return;
      }
      if (coordinator.pageExpand == PageExpandState.Expanding) {
        return;
      }
    }
    assert(pixels != null);
    final Simulation simulation =
        physics.createBallisticSimulation(this, velocity);
    if (simulation != null) {
      beginActivity(BallisticScrollActivity(this, simulation, context.vsync));
    } else {
      goIdle();
    }
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent,
      [bool fromCoordinator = false]) {
    if (debugLabel == coordinator.pageLabel && !fromCoordinator)
      return coordinator.applyContentDimensions(
          minScrollExtent, maxScrollExtent, this);
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }

  @override
  ScrollDirection get userScrollDirection => _userScrollDirection;
  ScrollDirection _userScrollDirection = ScrollDirection.idle;

  @override
  Future<void> animateTo(
    double to, {
    @required Duration duration,
    @required Curve curve,
  }) {
    if (nearEqual(to, pixels, physics.tolerance.distance)) {
      // 跳过动画，直接移到我们已经靠近的位置。
      jumpTo(to);
      return Future<void>.value();
    }

    final DrivenScrollActivity activity = DrivenScrollActivity(
      this,
      from: pixels,
      to: to,
      duration: duration,
      curve: curve,
      vsync: context.vsync,
    );
    beginActivity(activity);
    return activity.done;
  }

  @override
  void jumpTo(double value) {
    goIdle();
    if (pixels != value) {
      final double oldPixels = pixels;
      forcePixels(value);
      notifyListeners();
      didStartScroll();
      didUpdateScrollPositionBy(pixels - oldPixels);
      didEndScroll();
    }
    goBallistic(0.0);
  }

  @Deprecated('This will lead to bugs.')
  @override
  void jumpToWithoutSettling(double value) {
    goIdle();
    if (pixels != value) {
      final double oldPixels = pixels;
      forcePixels(value);
      notifyListeners();
      didStartScroll();
      didUpdateScrollPositionBy(pixels - oldPixels);
      didEndScroll();
    }
  }

  @override
  void dispose() {
    _currentDrag?.dispose();
    _currentDrag = null;
    super.dispose();
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('${context.runtimeType}');
    description.add('$physics');
    description.add('$activity');
    description.add('$userScrollDirection');
  }
}
