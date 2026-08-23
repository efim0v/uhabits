/// The share sheet has to be anchored, or it never opens on an iPad.
///
/// `Activity.showSendFileScreen` opens the Android chooser, which needs no
/// anchor. iOS presents the same sheet as a popover on any device that has a
/// `popoverPresentationController` — iPad and Mac Catalyst — and share_plus
/// refuses outright rather than guessing where to put it:
///
///   if (hasPopoverPresentationController &&
///       (!isCoordinateSpaceOfSourceView || CGRectIsEmpty(origin))) {
///     result([FlutterError errorWithCode:@"error" message:sharePositionIssue …
///
/// (FPPSharePlusPlugin.m:378-394). The port targets iPad —
/// `TARGETED_DEVICE_FAMILY = "1,2"` — and both callers turn any failure into
/// "No app was found to support this action", so without an origin every
/// export path on an iPad ends in that message and the file is unreachable.
///
/// This test drives the real [PlatformFileSharer] and listens on share_plus's
/// own method channel, because a fake sharer is exactly what hid the defect.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uhabits/platform/flutter_files.dart';

const String rule =
    'feedback.share-sheet-has-no-anchor-on-ipad#1 — the share sheet must carry '
    'a non-empty origin rect inside the root view, or iOS refuses to present '
    'it on every device that shows it as a popover.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('dev.fluttercommunity.plus/share');
  final List<MethodCall> calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return 'dev.fluttercommunity.plus/share/success';
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('sharing an export anchors the sheet', (tester) async {
    // A phone-sized view, so the rect has a real coordinate space to sit in.
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await const PlatformFileSharer()
        .shareFile('/tmp/Loop Habits CSV.zip', mimeType: 'application/zip');

    expect(calls, hasLength(1), reason: rule);
    final args = (calls.single.arguments as Map).cast<String, Object?>();
    expect(args['paths'], <String>['/tmp/Loop Habits CSV.zip'], reason: rule);

    for (final key in <String>['originX', 'originY']) {
      expect(args[key], isA<double>(),
          reason: '$rule share_plus only forwards the origin when one is '
              'given, so a missing key is the defect itself.');
    }
    final width = args['originWidth'] as double?;
    final height = args['originHeight'] as double?;
    expect(width, isNotNull, reason: rule);
    expect(height, isNotNull, reason: rule);
    expect(width! > 0 && height! > 0, isTrue,
        reason: '$rule CGRectIsEmpty(origin) is the other half of the '
            'refusal, so a zero-sized rect fails exactly like no rect.');

    // …and inside the view, which is the first half of the refusal.
    final left = args['originX'] as double;
    final top = args['originY'] as double;
    expect(left >= 0 && left + width <= 402.0, isTrue,
        reason: '$rule CGRectContainsRect(controller.view.frame, origin).');
    expect(top >= 0 && top + height! <= 874.0, isTrue, reason: rule);
  });
}
