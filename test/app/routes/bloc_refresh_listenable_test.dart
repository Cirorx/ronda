import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/app/app.dart';

void main() {
  group(BlocRefreshListenable, () {
    late StreamController<int> controller;

    setUp(() {
      controller = StreamController<int>();
      addTearDown(controller.close);
    });

    test('notifies its listeners on every event of the stream', () async {
      final subject = BlocRefreshListenable(controller.stream);
      addTearDown(subject.dispose);
      var notified = 0;
      subject.addListener(() => notified++);

      controller
        ..add(1)
        ..add(2);
      await Future<void>.delayed(Duration.zero);

      expect(notified, equals(2));
    });

    test('stops listening to the stream once disposed', () async {
      BlocRefreshListenable(controller.stream).dispose();
      await Future<void>.delayed(Duration.zero);

      expect(controller.hasListener, isFalse);
    });
  });
}
