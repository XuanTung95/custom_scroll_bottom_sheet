
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:flutter/physics.dart';

class CustomScrollBottomSheet extends StatefulWidget {
  const CustomScrollBottomSheet({super.key, required this.bodyBuilder, this.closeThreshold = 0.5, this.maxHeight = 0.8, this.header});

  final Widget Function(BuildContext context, ScrollController controller) bodyBuilder;

  final double closeThreshold;
  final double maxHeight;
  final Widget? header;

  @override
  State<CustomScrollBottomSheet> createState() => _CustomScrollBottomSheetState();

  static Future show(BuildContext context, Widget child) async {
    return Navigator.push(context, TransparentMaterialPageRoute(
        fullscreenDialog: true,
        builder: (BuildContext context) {
      return child;
    }));
  }
}

class _CustomScrollBottomSheetState extends State<CustomScrollBottomSheet> with SingleTickerProviderStateMixin {
  late CustomScrollBottomSheetDataController dataController;
  late CustomScrollBottomSheetScrollController myScrollController;
  late AnimationController topPosController;
  StateSetter? stateSetter;
  bool isClosing = false;
  double sheetHeight = 0;

  @override
  void initState() {
    super.initState();
    dataController = CustomScrollBottomSheetDataController(
      onStateChanged: () {
        stateSetter?.call(() {
        });
        if (sheetHeight != 0 && !isClosing) {
          if (dataController.pullDownOffset > sheetHeight * widget.closeThreshold) {
            close();
          }
        }
      },
      onTouchEnd: onTouchEnd,
      onTouchStart: onTouchStart,
    );
    myScrollController = CustomScrollBottomSheetScrollController(dataController: dataController);
    topPosController = AnimationController.unbounded(vsync: this);
    topPosController.addListener(() {
      dataController.setOffset(topPosController.value);
      if (topPosController.isAnimating && topPosController.value < 2) {
        topPosController.stop();
        dataController.setOffset(0);
      }
    });
  }

  @override
  void dispose() {
    topPosController.dispose();
    super.dispose();
  }

  void close() {
    if (isClosing) {
      return;
    }
    isClosing = true;
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  void onTouchStart() {
    if (isClosing) {
      return;
    }
    if (topPosController.isAnimating) {
      topPosController.stop();
    }
  }

  void onTouchEnd() {
    if (isClosing) {
      return;
    }
    if (dataController.isMoveUp) {
      if (dataController.pullDownOffset > 150) {
        animateToPosition(150);
      } else {
        animateToPosition(0);
      }
    } else {
      if (dataController.pullDownOffset < 150) {
        animateToPosition(150);
      } else {
        if (dataController.pullDownOffset > 150) {
          animateToPosition(150);
        } else {
          animateToPosition(0);
        }
      }
    }
  }

  TickerFuture animateToPosition(double target) {
    var simulation = buildSimulation(target);
    if (topPosController.isAnimating) {
      topPosController.stop();
    }
    return topPosController.animateWith(simulation);
  }

  Simulation buildSimulation(double target) {
    return StopBouncingScrollSimulation(
      spring: SpringDescription.withDampingRatio(
        mass: 0.5,
        stiffness: 400.0,
        ratio: 1.1,
      ),
      position: dataController.pullDownOffset,
      velocity: 0,
      // velocity: info.velocity.getVelocity().pixelsPerSecond.dy,
      leadingExtent: target,
      trailingExtent: target,
      tolerance: Tolerance.defaultTolerance,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, size) {
          final height = size.maxHeight * widget.maxHeight;
          sheetHeight = height;
          final child = Column(
            children: [
              Expanded(child: GestureDetector(
                onTap: () {
                  close();
                },
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),),
              SizedBox(
                height: height,
                width: double.infinity,
                child: Column(
                  children: [
                    if (widget.header != null) GestureDetector(
                      dragStartBehavior: DragStartBehavior.down,
                      onPanDown: (detail) {
                        dataController.onTouchStart();
                      },
                      onPanUpdate: (detail) {
                        if (topPosController.isAnimating) {
                          topPosController.stop();
                        }
                        dataController.handleUserOffsetDelta(detail.delta.dy);
                        if (dataController.pullDownOffset > sheetHeight * widget.closeThreshold) {
                          close();
                        }
                      },
                      onPanEnd: (detail) {
                        dataController.onTouchEnd();
                      },
                      onPanCancel: () {
                        dataController.onTouchEnd();
                      },
                      child: widget.header,
                    ),
                    Expanded(
                      child: widget.bodyBuilder(context, this.myScrollController),
                    )
                  ],
                ),
              ),
            ],
          );
          return Stack(
            children: [
              StatefulBuilder(builder: (BuildContext context, void Function(void Function()) setStateCb) {
                stateSetter = setStateCb;
                return Transform.translate(
                  offset: Offset(0, dataController.pullDownOffset),
                  child: child,
                );
              },)
            ],
          );
        }
    );
  }
}

class CustomScrollBottomSheetDataController {
  double pullDownOffset = 0;

  final VoidCallback onStateChanged;
  final VoidCallback onTouchEnd;
  final VoidCallback onTouchStart;
  bool isMoveUp = true;

  CustomScrollBottomSheetDataController({required this.onStateChanged, required this.onTouchEnd, required this.onTouchStart});

  void setOffset(double value) {
    pullDownOffset = value;
    onStateChanged.call();
  }

  bool handleUserOffsetDelta(double delta) {
    double newValue = pullDownOffset + delta;
    if (newValue < 0) {
      newValue = 0;
    }
    isMoveUp = delta < 0;
    if (newValue != pullDownOffset) {
      pullDownOffset = newValue;
      onStateChanged.call();
      return true;
    }
    return false;
  }

  void goBallistic(double velocity) {
    if (pullDownOffset > 0) {
      onTouchEnd.call();
    }
  }
}

class CustomScrollBottomSheetScrollController extends ScrollController {
  final CustomScrollBottomSheetDataController dataController;

  CustomScrollBottomSheetScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
    super.onAttach,
    super.onDetach,
    required this.dataController,
  });

  @override
  CustomScrollBottomSheetScrollPosition createScrollPosition(
      ScrollPhysics physics,
      ScrollContext context,
      ScrollPosition? oldPosition,
      ) {
    return CustomScrollBottomSheetScrollPosition(
      dataController: dataController,
      physics: physics.applyTo(const AlwaysScrollableScrollPhysics()),
      context: context,
      oldPosition: oldPosition,
    );
  }

  @override
  CustomScrollBottomSheetScrollPosition get position => super.position as CustomScrollBottomSheetScrollPosition;
}

class CustomScrollBottomSheetScrollPosition extends ScrollPositionWithSingleContext {
  CustomScrollBottomSheetScrollPosition({
    required this.dataController,
    required super.physics,
    required super.context,
    super.initialPixels = 0.0,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  bool get listShouldScroll => pixels > 0.0;
  final CustomScrollBottomSheetDataController dataController;

  @override
  void absorb(ScrollPosition other) {
    super.absorb(other);
  }

  @override
  void beginActivity(ScrollActivity? newActivity) {
    if (newActivity is HoldScrollActivity) {
      dataController.onTouchStart.call();
    }
    super.beginActivity(newActivity);
  }

  @override
  void applyUserOffset(double delta) {
    /// user scroll delta and finger touch the screen
    if (!listShouldScroll) {
      if (!dataController.handleUserOffsetDelta(delta)) {
        super.applyUserOffset(delta);
      }
    } else {
      super.applyUserOffset(delta);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void goBallistic(double velocity) {
    dataController.goBallistic(velocity);
    super.goBallistic(velocity);
  }

  @override
  Drag drag(DragStartDetails details, VoidCallback dragCancelCallback) {
    return super.drag(details, dragCancelCallback);
  }
}


class StopBouncingScrollSimulation extends Simulation {
  /// Creates a simulation group for scrolling on iOS, with the given
  /// parameters.
  ///
  /// The position and velocity arguments must use the same units as will be
  /// expected from the [x] and [dx] methods respectively (typically logical
  /// pixels and logical pixels per second respectively).
  ///
  /// The leading and trailing extents must use the unit of length, the same
  /// unit as used for the position argument and as expected from the [x]
  /// method (typically logical pixels).
  ///
  /// The units used with the provided [SpringDescription] must similarly be
  /// consistent with the other arguments. A default set of constants is used
  /// for the `spring` description if it is omitted; these defaults assume
  /// that the unit of length is the logical pixel.
  StopBouncingScrollSimulation({
    required double position,
    required double velocity,
    required this.leadingExtent,
    required this.trailingExtent,
    required this.spring,
    required super.tolerance,
  }) : assert(leadingExtent <= trailingExtent) {
    if (position < leadingExtent) {
      _springSimulation = _underscrollSimulation(position, velocity);
      _springTime = double.negativeInfinity;
    } else if (position > trailingExtent) {
      _springSimulation = _overscrollSimulation(position, velocity);
      _springTime = double.negativeInfinity;
    } else {
      // Taken from UIScrollView.decelerationRate (.normal = 0.998)
      // 0.998^1000 = ~0.135
      _frictionSimulation = FrictionSimulation(0.135, position, velocity);
      final double finalX = _frictionSimulation.finalX;
      if (velocity > 0.0 && finalX > trailingExtent) {
        _springTime = _frictionSimulation.timeAtX(trailingExtent);
        _springSimulation = StopSimulation(
          trailingExtent,
        );
        assert(_springTime.isFinite);
      } else if (velocity < 0.0 && finalX < leadingExtent) {
        _springTime = _frictionSimulation.timeAtX(leadingExtent);
        _springSimulation = StopSimulation(
          leadingExtent,
        );
        assert(_springTime.isFinite);
      } else {
        _springTime = double.infinity;
      }
    }
  }

  /// The maximum velocity that can be transferred from the inertia of a ballistic
  /// scroll into overscroll.
  static const double maxSpringTransferVelocity = 5000.0;

  /// When [x] falls below this value the simulation switches from an internal friction
  /// model to a spring model which causes [x] to "spring" back to [leadingExtent].
  final double leadingExtent;

  /// When [x] exceeds this value the simulation switches from an internal friction
  /// model to a spring model which causes [x] to "spring" back to [trailingExtent].
  final double trailingExtent;

  /// The spring used to return [x] to either [leadingExtent] or [trailingExtent].
  final SpringDescription spring;

  late FrictionSimulation _frictionSimulation;
  late Simulation _springSimulation;
  late double _springTime;
  double _timeOffset = 0.0;

  Simulation _underscrollSimulation(double x, double dx) {
    return ScrollSpringSimulation(spring, x, leadingExtent, dx);
  }

  Simulation _overscrollSimulation(double x, double dx) {
    return ScrollSpringSimulation(spring, x, trailingExtent, dx);
  }

  Simulation _simulation(double time) {
    final Simulation simulation;
    if (time > _springTime) {
      _timeOffset = _springTime.isFinite ? _springTime : 0.0;
      simulation = _springSimulation;
    } else {
      _timeOffset = 0.0;
      simulation = _frictionSimulation;
    }
    return simulation..tolerance = tolerance;
  }

  @override
  double x(double time) => _simulation(time).x(time - _timeOffset);

  @override
  double dx(double time) => _simulation(time).dx(time - _timeOffset);

  @override
  bool isDone(double time) => _simulation(time).isDone(time - _timeOffset);

  @override
  String toString() {
    return '${objectRuntimeType(this, 'BouncingScrollSimulation')}(leadingExtent: $leadingExtent, trailingExtent: $trailingExtent)';
  }
}

class StopSimulation extends Simulation {
  final double stop;

  StopSimulation(this.stop);

  @override
  double dx(double time) {
    return 0;
  }

  @override
  bool isDone(double time) {
    return true;
  }

  @override
  double x(double time) {
    return stop;
  }
}

class TransparentMaterialPageRoute<T> extends PageRoute<T> with MaterialRouteTransitionMixin<T> {
  /// Construct a MaterialPageRoute whose contents are defined by [builder].
  TransparentMaterialPageRoute({
    required this.builder,
    super.settings,
    this.maintainState = true,
    super.fullscreenDialog,
    super.allowSnapshotting = true,
    super.barrierDismissible = false,
  });

  /// Builds the primary contents of the route.
  final WidgetBuilder builder;

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  final bool maintainState;

  @override
  bool get opaque => false;

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';

  @override
  Color? get barrierColor => Colors.black.withOpacity(0.5);
}