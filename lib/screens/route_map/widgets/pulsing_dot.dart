import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';

/// Driver position marker with a continuous pulse — communicates
/// "live tracking" at a glance. The outer ring grows + fades while the
/// solid core stays steady.
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 1 - t,
              child: Container(
                width: 16 + (t * 28),
                height: 16 + (t * 28),
                decoration: const BoxDecoration(
                  color: AppColors.accentLive,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.accentLive,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bgBase, width: 2),
              ),
            ),
          ],
        );
      },
    );
  }
}
