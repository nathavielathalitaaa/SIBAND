import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum HeartbeatState { measuring, resting, stale, simulated }

class HeartbeatPulse extends StatefulWidget {
  final int? bpm;
  final HeartbeatState state;

  const HeartbeatPulse({
    super.key,
    required this.bpm,
    required this.state,
  });

  /// Durasi satu siklus denyut untuk keadaan [HeartbeatState.measuring]:
  /// 60000 / bpm ms, dibatasi pada rentang 500..1500 ms.
  @visibleForTesting
  static Duration cycleDurationForBpm(int? bpm) {
    if (bpm == null || bpm <= 0) {
      return const Duration(milliseconds: 1000);
    }
    final ms = (60000 / bpm).round().clamp(500, 1500);
    return Duration(milliseconds: ms);
  }

  @override
  State<HeartbeatPulse> createState() => HeartbeatPulseState();
}

class HeartbeatPulseState extends State<HeartbeatPulse>
    with SingleTickerProviderStateMixin {
  static const Duration _restingDuration = Duration(seconds: 3);

  static const Color tealColor = Color(0xFF1ECE9F);
  static const Color amberColor = Color(0xFFF59E0B);
  static const Color staleColor = Color(0xFF94A3B8);

  late final AnimationController _controller;

  @visibleForTesting
  Duration? get controllerDuration => _controller.duration;

  @visibleForTesting
  bool get isAnimating => _controller.isAnimating;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _targetDuration(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation(resetIfStateChanged: false);
  }

  @override
  void didUpdateWidget(covariant HeartbeatPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stateChanged = oldWidget.state != widget.state;
    final bpmChanged = oldWidget.bpm != widget.bpm;
    if (stateChanged || bpmChanged) {
      _syncAnimation(resetIfStateChanged: stateChanged);
    }
  }

  Duration _targetDuration() {
    switch (widget.state) {
      case HeartbeatState.measuring:
        return HeartbeatPulse.cycleDurationForBpm(widget.bpm);
      case HeartbeatState.resting:
        return _restingDuration;
      case HeartbeatState.stale:
      case HeartbeatState.simulated:
        return const Duration(milliseconds: 1000);
    }
  }

  void _syncAnimation({required bool resetIfStateChanged}) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final newDuration = _targetDuration();
    _controller.duration = newDuration;

    if (disableAnimations ||
        widget.state == HeartbeatState.stale ||
        widget.state == HeartbeatState.simulated) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _controller.value = 0.0;
      return;
    }

    // Untuk measuring & resting: perbarui durasi tanpa me-reset posisi ke 0
    // saat hanya BPM yang berubah.
    if (resetIfStateChanged && !_controller.isAnimating) {
      _controller.value = 0.0;
    }
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (widget.state == HeartbeatState.simulated) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            key: const Key('heartbeat_icon_simulated'),
            color: Colors.white.withValues(alpha: 0.85),
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            'Simulasi',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      );
    }

    final Color iconColor;
    final double maxScale;
    switch (widget.state) {
      case HeartbeatState.measuring:
        iconColor = tealColor;
        maxScale = 1.10;
        break;
      case HeartbeatState.resting:
        iconColor = amberColor;
        maxScale = 1.06;
        break;
      case HeartbeatState.stale:
      case HeartbeatState.simulated:
        iconColor = staleColor;
        maxScale = 1.0;
        break;
    }

    final icon = Icon(
      Icons.favorite_rounded,
      key: ValueKey<HeartbeatState>(widget.state),
      color: iconColor,
      size: 18,
    );

    if (disableAnimations || widget.state == HeartbeatState.stale) {
      return icon;
    }

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final scale = 1.0 + (maxScale - 1.0) * curved.value;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: icon,
    );
  }
}
