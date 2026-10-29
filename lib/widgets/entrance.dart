// Slide-up-from-bottom card entrance, ported from DeliveryFlow's
// staggered entrance (lib/theme/staggered_entrance.dart):
// items fade in and slide up from ~20% of their own height, 80ms
// stagger per item, capped at index 7 so long lists never wait
// seconds, 300ms per item, easeOut. A [generation] bump replays the
// entrance in place (used for every dashboard entry: the dashboard
// tab stays mounted in the shell's IndexedStack, so mount-only
// animation would play once and never again). Data refreshes keep
// the same generation and never re-trigger or flicker.
// Reduce-motion: items appear immediately, never animate.

import 'dart:async';

import 'package:flutter/material.dart';

class SlideUpItem extends StatefulWidget {
  const SlideUpItem({
    super.key,
    required this.index,
    required this.generation,
    required this.child,
  });

  /// Stagger per item, matching DeliveryFlow's 80ms interval.
  static const stagger = Duration(milliseconds: 80);

  /// Items at or beyond this index share the capped delay.
  static const capIndex = 7;

  /// Single-item animation length.
  static const itemDuration = Duration(milliseconds: 300);

  /// Slide distance as a fraction of the item's own height
  /// (DeliveryFlow's slideY begin ~0.2).
  static const slideFraction = 0.2;

  /// Capped delay for [index].
  static Duration delayFor(int index) =>
      stagger * (index < capIndex ? index : capIndex);

  final int index;
  final int generation;
  final Widget child;

  @override
  State<SlideUpItem> createState() => _SlideUpItemState();
}

class _SlideUpItemState extends State<SlideUpItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;
  Timer? _timer;
  bool _immediate = false;
  var _initialized = false;
  var _firstDependencies = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SlideUpItem.itemDuration,
    );
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    // NOTE: no MediaQuery read here — inherited widgets cannot be
    // consulted from initState. The reduce-motion check lives in
    // didChangeDependencies (runs right after initState, and again
    // whenever dependencies change) and in build.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // First call only: plays the entrance on mount. Later
    // dependency changes (theme, locale) must NOT replay it —
    // only a generation bump (didUpdateWidget) replays.
    if (_firstDependencies) {
      _firstDependencies = false;
      _play();
    }
  }

  @override
  void didUpdateWidget(SlideUpItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only a generation bump replays; data refreshes (same
    // generation) never re-trigger.
    if (widget.generation != oldWidget.generation) {
      _play();
    }
  }

  void _play() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _timer?.cancel();
      if (_initialized) {
        setState(() => _immediate = true);
      } else {
        _immediate = true;
      }
      return;
    }
    _immediate = false;
    _controller.reset();
    _timer?.cancel();
    _timer = Timer(SlideUpItem.delayFor(widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _initialized = true;
    if (_immediate) return widget.child;
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        final t = _progress.value;
        return Opacity(
          opacity: t,
          child: FractionalTranslation(
            translation: Offset(0, SlideUpItem.slideFraction * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
