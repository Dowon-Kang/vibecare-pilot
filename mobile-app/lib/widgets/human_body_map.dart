import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '신체 부위 선택',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 200,
          decoration: const BoxDecoration(
            color: AppColors.canvasSoft,
            borderRadius: AppRadius.mdBorder,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              key: const ValueKey('body-hit-map'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final normalized = Offset(
                  details.localPosition.dx / constraints.maxWidth,
                  details.localPosition.dy / constraints.maxHeight,
                );
                for (final part in const [
                  BodyPart.shoulder,
                  BodyPart.arm,
                  BodyPart.abdomen,
                  BodyPart.thigh,
                  BodyPart.calf,
                ]) {
                  if (_regions[part]!.contains(normalized)) {
                    onSelected(part);
                    return;
                  }
                }
              },
              child: CustomPaint(
                key: ValueKey('body-visual-${selected.name}'),
                painter: _HumanSilhouettePainter(selected),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(16) > 22;
            final columns = largeText ? 2 : 3;
            const spacing = 7.0;
            final itemWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: 8,
              children: [
                for (final part in BodyPart.values)
                  SizedBox(
                    width: itemWidth,
                    child: _PartChip(
                      key: ValueKey('body-map-${part.name}'),
                      label: _labels[part]!,
                      selected: selected == part,
                      onTap: () => onSelected(part),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _PartChip extends StatelessWidget {
  const _PartChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$label 부위 선택',
    child: SizedBox(
      height: 48,
      width: double.infinity,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          color: selected ? AppColors.canvas : AppColors.ink,
          fontWeight: FontWeight.w600,
        ),
        selectedColor: AppColors.brand,
        backgroundColor: AppColors.canvas,
        side: BorderSide(
          color: selected ? AppColors.brand : AppColors.hairline,
        ),
        shape: const StadiumBorder(),
      ),
    ),
  );
}

class _NormalizedRect {
  const _NormalizedRect(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  Rect resolve(Size size) => Rect.fromLTWH(
    left * size.width,
    top * size.height,
    width * size.width,
    height * size.height,
  );

  bool contains(Offset point) =>
      point.dx >= left &&
      point.dx <= left + width &&
      point.dy >= top &&
      point.dy <= top + height;
}

class _BodyRegion {
  const _BodyRegion({required this.touch});

  final List<_NormalizedRect> touch;

  bool contains(Offset normalizedPoint) =>
      touch.any((region) => region.contains(normalizedPoint));
}

/// Painting geometry is kept independent from these deliberately wider touch
/// regions so the figure can stay anatomically balanced without shrinking the
/// one-handed interaction targets.
const _regions = <BodyPart, _BodyRegion>{
  BodyPart.shoulder: _BodyRegion(touch: [_NormalizedRect(.29, .18, .42, .13)]),
  BodyPart.arm: _BodyRegion(
    touch: [
      _NormalizedRect(.17, .26, .22, .31),
      _NormalizedRect(.61, .26, .22, .31),
    ],
  ),
  BodyPart.abdomen: _BodyRegion(touch: [_NormalizedRect(.37, .32, .26, .21)]),
  BodyPart.thigh: _BodyRegion(
    touch: [
      _NormalizedRect(.33, .52, .17, .21),
      _NormalizedRect(.50, .52, .17, .21),
    ],
  ),
  BodyPart.calf: _BodyRegion(
    touch: [
      _NormalizedRect(.32, .72, .18, .24),
      _NormalizedRect(.50, .72, .18, .24),
    ],
  ),
};

class _HumanSilhouettePainter extends CustomPainter {
  const _HumanSilhouettePainter(this.selected);

  final BodyPart selected;

  @override
  void paint(Canvas canvas, Size size) {
    const neutral = AppColors.canvas;
    const outlineColor = AppColors.faint;
    final selectedColor = AppColors.brand.withValues(alpha: .82);
    final wholeBodyColor = AppColors.brand.withValues(alpha: .38);

    Paint fill(BodyPart part) => Paint()
      ..color = selected == BodyPart.wholeBody
          ? wholeBodyColor
          : selected == part
          ? selectedColor
          : neutral
      ..style = PaintingStyle.fill
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final outline = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;

    Offset p(double x, double y) => Offset(size.width * x, size.height * y);

    final head = Rect.fromCenter(
      center: p(.5, .095),
      width: size.width * .105,
      height: size.height * .145,
    );
    canvas.drawOval(head, Paint()..color = neutral);
    canvas.drawOval(head, outline);

    final neck = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .475,
        size.height * .16,
        size.width * .05,
        size.height * .07,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(neck, Paint()..color = neutral);
    canvas.drawRRect(neck, outline);

    final torso = Path()
      ..moveTo(size.width * .405, size.height * .215)
      ..cubicTo(
        size.width * .37,
        size.height * .22,
        size.width * .355,
        size.height * .27,
        size.width * .38,
        size.height * .335,
      )
      ..lineTo(size.width * .405, size.height * .515)
      ..quadraticBezierTo(
        size.width * .5,
        size.height * .565,
        size.width * .595,
        size.height * .515,
      )
      ..lineTo(size.width * .62, size.height * .335)
      ..cubicTo(
        size.width * .645,
        size.height * .27,
        size.width * .63,
        size.height * .22,
        size.width * .595,
        size.height * .215,
      )
      ..quadraticBezierTo(
        size.width * .5,
        size.height * .18,
        size.width * .405,
        size.height * .215,
      )
      ..close();
    canvas.drawPath(
      torso,
      Paint()
        ..color = selected == BodyPart.wholeBody ? wholeBodyColor : neutral
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(torso, outline);

    Path arm({required bool left}) {
      final direction = left ? -1.0 : 1.0;
      final shoulderX = left ? .395 : .605;
      return Path()
        ..moveTo(size.width * shoulderX, size.height * .235)
        ..cubicTo(
          size.width * (shoulderX + direction * .055),
          size.height * .225,
          size.width * (.5 + direction * .19),
          size.height * .32,
          size.width * (.5 + direction * .255),
          size.height * .49,
        )
        ..cubicTo(
          size.width * (.5 + direction * .27),
          size.height * .535,
          size.width * (.5 + direction * .235),
          size.height * .565,
          size.width * (.5 + direction * .205),
          size.height * .525,
        )
        ..lineTo(size.width * (.5 + direction * .11), size.height * .345)
        ..quadraticBezierTo(
          size.width * (.5 + direction * .085),
          size.height * .29,
          size.width * shoulderX,
          size.height * .235,
        )
        ..close();
    }

    for (final left in [true, false]) {
      final path = arm(left: left);
      canvas.drawPath(path, fill(BodyPart.arm));
      canvas.drawPath(path, outline);
    }

    Path legSection({required bool left, required bool thigh}) {
      final inner = left ? .49 : .51;
      final outer = left ? .405 : .595;
      if (thigh) {
        return Path()
          ..moveTo(size.width * outer, size.height * .515)
          ..lineTo(size.width * inner, size.height * .525)
          ..lineTo(size.width * (left ? .475 : .525), size.height * .735)
          ..quadraticBezierTo(
            size.width * (left ? .43 : .57),
            size.height * .755,
            size.width * (left ? .39 : .61),
            size.height * .72,
          )
          ..lineTo(size.width * outer, size.height * .515)
          ..close();
      }
      return Path()
        ..moveTo(size.width * (left ? .39 : .61), size.height * .705)
        ..quadraticBezierTo(
          size.width * (left ? .43 : .57),
          size.height * .69,
          size.width * (left ? .475 : .525),
          size.height * .72,
        )
        ..lineTo(size.width * (left ? .46 : .54), size.height * .93)
        ..quadraticBezierTo(
          size.width * (left ? .42 : .58),
          size.height * .97,
          size.width * (left ? .38 : .62),
          size.height * .925,
        )
        ..close();
    }

    for (final left in [true, false]) {
      final thigh = legSection(left: left, thigh: true);
      canvas.drawPath(thigh, fill(BodyPart.thigh));
      canvas.drawPath(thigh, outline);
      final calf = legSection(left: left, thigh: false);
      canvas.drawPath(calf, fill(BodyPart.calf));
      canvas.drawPath(calf, outline);
    }

    final shoulderBand = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .355,
        size.height * .215,
        size.width * .29,
        size.height * .085,
      ),
      const Radius.circular(18),
    );
    final shoulderColor = selected == BodyPart.shoulder
        ? selectedColor
        : selected == BodyPart.wholeBody
        ? wholeBodyColor
        : Colors.transparent;
    canvas.drawRRect(shoulderBand, Paint()..color = shoulderColor);

    final abdomen = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .415,
        size.height * .345,
        size.width * .17,
        size.height * .165,
      ),
      const Radius.circular(16),
    );
    if (selected == BodyPart.abdomen) {
      canvas.drawRRect(abdomen, Paint()..color = selectedColor);
    }
  }

  @override
  bool shouldRepaint(covariant _HumanSilhouettePainter oldDelegate) =>
      selected != oldDelegate.selected;
}
