import 'dart:math' as math;
import 'dart:ui' show FlutterView;
import 'package:flutter/material.dart';

/// Shared auth screen scaffold that isolates keyboard inset changes from the
/// form widget tree and watermark background.
///
/// Android 11+ (API 30+) dispatches per-frame IME inset animations during
/// keyboard open and dismiss. Setting `resizeToAvoidBottomInset: false` and
/// confining `MediaQuery.viewInsetsOf` to a trailing sliver keeps the form,
/// typography, and watermark image completely static at 60fps.
class AuthWatermarkScaffold extends StatefulWidget {
  final Widget child;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;

  const AuthWatermarkScaffold({
    super.key,
    required this.child,
    this.scrollController,
    this.padding = const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 24.0),
    this.backgroundColor = const Color(0xFFF8FAFC),
  });

  @override
  State<AuthWatermarkScaffold> createState() => _AuthWatermarkScaffoldState();
}

class _AuthWatermarkScaffoldState extends State<AuthWatermarkScaffold>
    with WidgetsBindingObserver {
  late ScrollController _controller;
  late bool _ownsController;
  FlutterView? _view;
  double _lastBottomInset = 0.0;
  bool _postFrameScrollScheduled = false;
  bool _pendingAnimate = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.scrollController == null;
    _controller = widget.scrollController ?? ScrollController();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_handleFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.maybeOf(context);
  }

  @override
  void didUpdateWidget(covariant AuthWatermarkScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != oldWidget.scrollController) {
      if (_ownsController) {
        _controller.dispose();
      }
      _ownsController = widget.scrollController == null;
      _controller = widget.scrollController ?? ScrollController();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final view = _view;
    if (!mounted || view == null) return;
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
    final isOpening = bottomInset > _lastBottomInset;
    _lastBottomInset = bottomInset;

    // Only keep the focused field above the rising keyboard; let scroll clamping
    // smoothly settle when dismissing via Back without fighting the animation.
    if (isOpening && bottomInset > 0) {
      _scheduleScrollIntoView(animate: false);
    }
  }

  void _handleFocusChange() {
    final view = _view;
    if (!mounted || view == null) return;
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
    if (bottomInset > 0) {
      _scheduleScrollIntoView(animate: true);
    }
  }

  void _scheduleScrollIntoView({required bool animate}) {
    _pendingAnimate = _pendingAnimate || animate;
    if (_postFrameScrollScheduled) return;
    _postFrameScrollScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postFrameScrollScheduled = false;
      final shouldAnimate = _pendingAnimate;
      _pendingAnimate = false;
      _scrollFocusedFieldIntoView(animate: shouldAnimate);
    });
  }

  void _scrollFocusedFieldIntoView({required bool animate}) {
    final view = _view;
    if (!mounted || view == null || !_controller.hasClients) return;

    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null || !focusContext.mounted) return;
    if (focusContext.findAncestorStateOfType<_AuthWatermarkScaffoldState>() !=
        this) {
      return;
    }

    final renderObject = focusContext.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return;
    }

    final dpr = view.devicePixelRatio;
    final bottomInset = view.viewInsets.bottom / dpr;
    if (bottomInset <= 0) return;

    final screenHeight = view.physicalSize.height / dpr;
    final topSafeEdge = (view.padding.top / dpr) + 16.0;
    final visibleBottom = screenHeight - bottomInset;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final fieldTop = topLeft.dy;
    final fieldBottom = fieldTop + renderObject.size.height;
    const bottomMargin = 38.0;

    final currentOffset = _controller.offset;
    final maxExtent = _controller.position.maxScrollExtent;
    double? targetOffset;

    if (fieldBottom + bottomMargin > visibleBottom) {
      final neededDelta = (fieldBottom + bottomMargin) - visibleBottom;
      final headroomAbove = math.max(0.0, fieldTop - topSafeEdge);
      final delta = math.min(neededDelta, headroomAbove);
      if (delta > 1.0) {
        targetOffset = (currentOffset + delta).clamp(0.0, maxExtent);
      }
    } else if (fieldTop < topSafeEdge) {
      final delta = topSafeEdge - fieldTop;
      if (delta > 1.0) {
        targetOffset = (currentOffset - delta).clamp(0.0, maxExtent);
      }
    }

    if (targetOffset == null || (targetOffset - currentOffset).abs() < 1.0) {
      return;
    }

    if (animate) {
      _controller.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    } else {
      _controller.jumpTo(targetOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: _FixedAuthWatermark()),
          SafeArea(
            top: true,
            bottom: false,
            maintainBottomViewPadding: true,
            child: CustomScrollView(
              controller: _controller,
              physics: const ClampingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: widget.padding,
                  sliver: SliverToBoxAdapter(
                    child: RepaintBoundary(child: widget.child),
                  ),
                ),
                const _KeyboardBottomSliver(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedAuthWatermark extends StatelessWidget {
  const _FixedAuthWatermark();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: Image.asset(
          'assets/images/factory_bg_tinted_sketch.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          cacheWidth: 1080,
          filterQuality: FilterQuality.low,
          opacity: const AlwaysStoppedAnimation<double>(0.10),
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// The only widget subscribed to `MediaQuery.viewInsetsOf`, expanding the
/// scroll extent cleanly without relayouting or repainting the form above it.
class _KeyboardBottomSliver extends StatelessWidget {
  const _KeyboardBottomSliver();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SliverToBoxAdapter(
      child: SizedBox(height: bottomInset > 0 ? bottomInset + 24.0 : 0.0),
    );
  }
}

/// Hides a leaf widget behind the keyboard when open without shifting layout.
class KeyboardHiddenSlot extends StatelessWidget {
  final Widget child;

  const KeyboardHiddenSlot({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Visibility(
      visible: !isKeyboardOpen,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: child,
    );
  }
}
