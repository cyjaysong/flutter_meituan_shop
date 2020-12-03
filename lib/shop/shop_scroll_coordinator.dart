import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'shop_scroll_controller.dart';
import 'shop_scroll_position.dart';

enum PageExpandState { NotExpand, Expanding, Expanded }

/// 协调器
///
/// 页面 Primary [CustomScrollView] 控制
class ShopScrollCoordinator {
  final String pageLabel = 'page';

  ShopScrollController _pageScrollController;
  double Function() pinnedHeaderSliverHeightBuilder;

  ShopScrollPosition get _pageScrollPosition => _pageScrollController.position;

  ScrollDragController scrollDragController;

  /// 主页面滑动部件默认位置
  double _pageInitialOffset;

  /// 获取主页面滑动控制器
  ShopScrollController pageScrollController([double initialOffset = 0.0]) {
    assert(initialOffset != null, initialOffset >= 0.0);
    _pageInitialOffset = initialOffset;
    _pageScrollController = ShopScrollController(
      this,
      debugLabel: pageLabel,
      initialScrollOffset: initialOffset,
    );
    return _pageScrollController;
  }

  /// 创建并获取一个子滑动控制器
  ShopScrollController newChildScrollController([String debugLabel]) =>
      ShopScrollController(this, debugLabel: debugLabel);

  /// 子部件滑动数据协调
  ///
  /// [userScrollDirection] 用户滑动方向
  /// [position] 被滑动的子部件的位置信息
  void applyUserOffset(
    double delta, [
    ScrollDirection userScrollDirection,
    ShopScrollPosition position,
  ]) {
    if (userScrollDirection == ScrollDirection.reverse) {
      updateUserScrollDirection(_pageScrollPosition, userScrollDirection);
      final double innerDelta =
          _pageScrollPosition.applyClampedDragUpdate(delta);
      if (innerDelta != 0.0) {
        updateUserScrollDirection(position, userScrollDirection);
        position.applyFullDragUpdate(innerDelta);
      }
    } else {
      updateUserScrollDirection(position, userScrollDirection);
      final double outerDelta = position.applyClampedDragUpdate(delta);
      if (outerDelta != 0.0) {
        updateUserScrollDirection(_pageScrollPosition, userScrollDirection);
        _pageScrollPosition.applyFullDragUpdate(outerDelta);
      }
    }
  }

  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent,
      ShopScrollPosition position) {
    if (pinnedHeaderSliverHeightBuilder != null) {
      maxScrollExtent = maxScrollExtent - pinnedHeaderSliverHeightBuilder();
      maxScrollExtent = math.max(0.0, maxScrollExtent);
    }
    return position.applyContentDimensions(
        minScrollExtent, maxScrollExtent, true);
  }

  /// 当默认位置不为0时，主部件已下拉距离超过默认位置，但超过的距离不大于该值时，
  /// 若手指离开屏幕，主部件头部会回弹至默认位置
  final double _scrollRedundancy = 80;

  /// 当前页面Header最大程度展开状态
  PageExpandState pageExpand = PageExpandState.NotExpand;

  /// 当手指离开屏幕
  void onPointerUp(PointerUpEvent event) {
    final double _pagePixels = _pageScrollPosition.pixels;
    if (0.0 < _pagePixels && _pagePixels < _pageInitialOffset) {
      if (pageExpand == PageExpandState.NotExpand &&
          _pageInitialOffset - _pagePixels > _scrollRedundancy) {
        _pageScrollPosition
            .animateTo(
              0.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.ease,
            )
            .then((_) => pageExpand = PageExpandState.Expanded);
      } else {
        pageExpand = PageExpandState.Expanding;
        _pageScrollPosition
            .animateTo(
              _pageInitialOffset,
              duration: const Duration(milliseconds: 400),
              curve: Curves.ease,
            )
            .then((_) => pageExpand = PageExpandState.NotExpand);
      }
    }
  }

  /// 更新用户滑动方向
  void updateUserScrollDirection(
      ShopScrollPosition position, ScrollDirection value) {
    assert(position != null && value != null);
    position.didUpdateScrollDirection(value);
  }

  /// 以特定的速度开始一个物理驱动的模拟，该模拟确定 [pixels] 位置。
  ///
  /// 此方法遵从 [ScrollPhysics.createBallisticSimulation]，通常在当前位置超出范围时
  /// 提供滑动模拟，而在当前位置超出范围但具有非零速度时提供摩擦模拟。
  ///
  /// 速度应以 逻辑像素/秒 为单位。
  void goBallistic(double velocity) =>
      _pageScrollPosition.goBallistic(velocity);
}
