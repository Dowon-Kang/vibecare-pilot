import 'package:flutter/material.dart';

import '../models/models.dart';

class HumanBodyMap extends StatelessWidget {
  const HumanBodyMap({
    super.key,
    required this.results,
    required this.selected,
    required this.onSelected,
  });

  final Map<BodyPart, AlgorithmResult> results;
  final BodyPart selected;
  final ValueChanged<BodyPart> onSelected;

  static const _labels = {
    BodyPart.wholeBody: '전신',
    BodyPart.shoulder: '어깨',
    BodyPart.arm: '팔',
    BodyPart.abdomen: '복부',
    BodyPart.thigh: '허벅지',
    BodyPart.calf: '종아리',
  };
  static const _positions = {
    BodyPart.wholeBody: Alignment(-.92, -.92),
    BodyPart.shoulder: Alignment(.70, -.54),
    BodyPart.arm: Alignment(-.76, -.20),
    BodyPart.abdomen: Alignment(.68, .05),
    BodyPart.thigh: Alignment(-.68, .47),
    BodyPart.calf: Alignment(.65, .84),
  };

  @override
  Widget build(BuildContext context) => Semantics(
    label: '신체 부위별 진동 출력 지도',
    child: AspectRatio(
      aspectRatio: .86,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HumanSilhouettePainter()),
          ),
          for (final part in BodyPart.values)
            Align(
              alignment: _positions[part]!,
              child: _PartBadge(
                key: ValueKey('body-map-${part.name}'),
                label: _labels[part]!,
                result: results[part],
                selected: selected == part,
                onTap: () => onSelected(part),
              ),
            ),
        ],
      ),
    ),
  );
}

class _PartBadge extends StatelessWidget {
  const _PartBadge({
    super.key,
    required this.label,
    required this.result,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final AlgorithmResult? result;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final recommendation = result?.recommendation;
    return Material(
      color: selected ? const Color(0xFF087F6B) : Colors.white,
      elevation: selected ? 3 : 1,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 72, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF3A3A3C),
                  ),
                ),
                Text(
                  recommendation == null
                      ? '확인 필요'
                      : '${recommendation.intensityPct}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : const Color(0xFF087F6B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HumanSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    final paint = Paint()
      ..color = const Color(0xFFDCEAE6)
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      Offset(center, size.height * .12),
      size.width * .075,
      paint,
    );
    paint.strokeWidth = size.width * .15;
    canvas.drawLine(
      Offset(center, size.height * .24),
      Offset(center, size.height * .52),
      paint,
    );
    paint.strokeWidth = size.width * .075;
    canvas.drawLine(
      Offset(center - size.width * .06, size.height * .28),
      Offset(center - size.width * .24, size.height * .52),
      paint,
    );
    canvas.drawLine(
      Offset(center + size.width * .06, size.height * .28),
      Offset(center + size.width * .24, size.height * .52),
      paint,
    );
    canvas.drawLine(
      Offset(center - size.width * .04, size.height * .54),
      Offset(center - size.width * .12, size.height * .88),
      paint,
    );
    canvas.drawLine(
      Offset(center + size.width * .04, size.height * .54),
      Offset(center + size.width * .12, size.height * .88),
      paint,
    );
    final line = Paint()
      ..color = const Color(0xFF9CC8BE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(
      Offset(center, size.height * .12),
      size.width * .075,
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
