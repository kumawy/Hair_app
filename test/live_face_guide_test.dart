import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hair_app/features/face_scanner/widgets/live_face_guide.dart';

void main() {
  testWidgets('white idle oval turns green and respects reduced motion', (
    tester,
  ) async {
    Widget guide(bool ready, {bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: SizedBox.expand(
          child: LiveFaceGuide(ready: ready, progress: ready ? .6 : 0),
        ),
      ),
    );
    await tester.pumpWidget(guide(false));
    Color target() =>
        (tester
                    .widget<TweenAnimationBuilder<Color?>>(
                      find.byWidgetPredicate(
                        (widget) => widget is TweenAnimationBuilder<Color?>,
                      ),
                    )
                    .tween
                as ColorTween)
            .end!;
    expect(target(), Colors.white);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(guide(true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(target(), const Color(0xFF66E3A0));
    await tester.pumpWidget(guide(false, reduced: true));
    await tester.pumpAndSettle();
    expect(target(), Colors.white);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
