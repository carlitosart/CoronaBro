import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Represents a generic game.
///
/// Subclass this to implement the [update] and [render] methods.
/// Flame will deal with calling these methods properly when the game's [widget] is rendered.
abstract class Game {
  /// Implement this method to update the game state, given that a time [t] has passed.
  ///
  /// Keep the updates as short as possible. [t] is in seconds, with microsseconds precision.
  void update(double t);

  /// Implement this method to render the current game state in the [canvas].
  void render(Canvas canvas);

  void destroy();
  void init();

  /// This is the resize hook; every time the game widget is resized, this hook is called.
  ///
  /// The default implementation does nothing; override to use the hook.
  void resize(Size size) {}

  /// This is the lifecycle state change hook; every time the game is resumed, paused or suspended, this is called.
  ///
  /// The default implementation does nothing; override to use the hook.
  /// Check [AppLifecycleState] for details about the events received.
  void lifecycleStateChange(AppLifecycleState state) {}

  void _recordDt(double dt) {}

  Widget _widget;

  /// Returns the game widget. Put this in your structure to start rendering and updating the game.
  ///
  /// You can add it directly to the runApp method or inside your widget structure (if you use vanilla screens and widgets).
  Widget get widget {
    if (_widget == null) {
      _widget = _LifeCyclerWatch(this);
    }
    return _widget;
  }
}

class _LifeCyclerWatch extends StatefulWidget {
  final game;

  _LifeCyclerWatch(this.game);

  @override
  State<StatefulWidget> createState() {
    return _LifeCyclerWatchState(game);
  }
}

class _LifeCyclerWatchState extends State<_LifeCyclerWatch> {
  final game;
  _LifeCyclerWatchState(this.game);

  @override
  Widget build(BuildContext context) {
    return Center(
        child: new Directionality(
            textDirection: TextDirection.ltr,
            child: _GameRenderObjectWidget(game)));
  }

  @override
  void initState() {
    super.initState();
    print('====initState=====');
    game?.init();
  }

  @override
  void dispose() {
    print('====dispose=====');
    game?.destroy();
    super.dispose();
  }
}

class _GameRenderObjectWidget extends SingleChildRenderObjectWidget {
  final Game game;

  _GameRenderObjectWidget(this.game);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      new _GameRenderBox(context, this.game);
}

class _GameRenderBox extends RenderBox with WidgetsBindingObserver {
  BuildContext context;

  Game game;

  int _frameCallbackId;

  Duration previous = Duration.zero;

  _GameRenderBox(this.context, this.game);

  @override
  bool get sizedByParent => true;

  @override
  void performResize() {
    super.performResize();
    game.resize(constraints.biggest);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _scheduleTick();
    _bindLifecycleListener();
  }

  @override
  void detach() {
    super.detach();
    _unscheduleTick();
    _unbindLifecycleListener();
  }

  void _scheduleTick() {
    _frameCallbackId = SchedulerBinding.instance.scheduleFrameCallback(_tick);
  }

  void _unscheduleTick() {
    SchedulerBinding.instance.cancelFrameCallbackWithId(_frameCallbackId);
  }

  void _tick(Duration timestamp) {
    if (!attached) return;
    _scheduleTick();
    _update(timestamp);
    markNeedsPaint();
  }

  void _update(Duration now) {
    double dt = _computeDeltaT(now);
    game._recordDt(dt);
    game.update(dt);
  }

  double _computeDeltaT(Duration now) {
    Duration delta = now - previous;
    if (previous == Duration.zero) {
      delta = Duration.zero;
    }
    previous = now;
    return delta.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    game.render(context.canvas);
  }

  void _bindLifecycleListener() {
    WidgetsBinding.instance.addObserver(this);
  }

  void _unbindLifecycleListener() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    game.lifecycleStateChange(state);
  }
}

/// This is a more complete and opinated implementation of Game.
///
/// It still needs to be subclases to add your game log, but the [update], [render] and [resize] methods have default implementations.
/// This is the recommended strucutre to use for most games.
/// It is based on the Component system.
abstract class BaseGame extends Game {
  /// The list of components to be updated and rendered by the base game.

  /// Components added by the [addLater] method

  /// Current screen size, updated every resize via the [resize] method hook
  Size size;

  /// List of deltas used in debug mode to calculate FPS
  List<double> _dts = [];

  /// This implementation of render basically calls [renderComponent] for every component, making sure the canvas is reset for each one.
  ///
  /// You can override it futher to add more custom behaviour.
  @override
  void render(Canvas canvas);

  /// This implementation of update updates every component in the list.
  ///
  /// It also actually adds the components that were added by the [addLater] method, and remove those that are marked for destruction via the [Component.destroy] method.
  /// You can override it futher to add more custom behaviour.
  @override
  void update(double t);

  /// This implementation of resize repasses the resize call to every component in the list, enabling each one to make their decisions as how to handle the resize.
  ///
  /// You can override it futher to add more custom behaviour.
  @override
  void resize(Size size) {
    this.size = size;
  }

  /// Returns wether thdis [Game] is in debug mode or not.
  ///
  /// Returns `false` by default. Override to use the debug mode.
  /// In debug mode, the [_recordDt] method actually records every `dt` for statistics.
  /// Then, you can use the [fps] method to check the game FPS.
  /// You can also use this value to enable other debug behaviors for your game.
  bool debugMode() => true;

  ///Este es un enlace que proviene de RenderBox para permitir el registro de tiempos de procesamiento y estadísticas.
  @override
  void _recordDt(double dt) {
    if (debugMode()) {
      _dts.add(dt);
    }
  }

  /// Returns the average FPS for the last [average] measures.
  ///
  /// The values are only saved if in debug mode (override [debugMode] to use this).
  /// Selects the last [average] dts, averages then, and returns the inverse value.
  /// So it's technically updates per second, but the relation between updates and renders is 1:1.
  /// Returns 0 if empty.
  double fps([int average = 1]) {
    List<double> dts = _dts.sublist(math.max(0, _dts.length - average));
    if (dts.isEmpty) {
      return 0.0;
    }
    double dtSum = dts.reduce((s, t) => s + t);
    double averageDt = dtSum / average;
    if (averageDt == 0.0) {
      return 0.0;
    }
    return 1 / averageDt;
  }

  /// Returns the current time in seconds with microseconds precision.
  ///
  /// This is compatible with the `dt` value used in the [update] method.
  double currentTime() {
    return new DateTime.now().microsecondsSinceEpoch.toDouble() /
        Duration.microsecondsPerSecond;
  }
}
