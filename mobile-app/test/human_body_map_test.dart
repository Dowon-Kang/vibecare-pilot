import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vibecare_pilot/models/models.dart';
import 'package:vibecare_pilot/widgets/human_body_map.dart';

void main() {
  for (final part in [BodyPart.shoulder, BodyPart.wholeBody]) {
    testWidgets(
      'body highlight paints ${part.name} without chest band overlap',
      (tester) async {
        const captureKey = ValueKey('body-capture');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  child: RepaintBoundary(
                    key: captureKey,
                    child: HumanBodyMap(
                      results: const {},
                      selected: part,
                      onSelected: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(captureKey),
        );
        final map = tester.getRect(find.byKey(const ValueKey('body-hit-map')));
        final origin = tester.getTopLeft(find.byKey(captureKey));
        final picture = (await tester.runAsync(
          () => boundary.toImage(pixelRatio: 1),
        ))!;
        final bytes = (await tester.runAsync(
          () => picture.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        int red(double x, double y) {
          final pixel =
              map.topLeft + Offset(map.width * x, map.height * y) - origin;
          return bytes.getUint8(
            (pixel.dy.floor() * picture.width + pixel.dx.floor()) * 4,
          );
        }

        if (part == BodyPart.shoulder) {
          expect(
            red(.37, .26),
            lessThan(red(.50, .26) - 80),
            reason: 'only deltoids are selected, not the chest',
          );
          expect(red(.63, .26), lessThan(red(.50, .26) - 80));
        } else {
          expect(
            (red(.50, .26) - red(.50, .42)).abs(),
            lessThan(5),
            reason: 'whole-body fill must not paint the shoulder band twice',
          );
        }
        picture.dispose();
      },
    );
  }
}
