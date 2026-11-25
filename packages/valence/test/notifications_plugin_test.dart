import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:valence/valence.dart';

// The real adapter against flutter_local_notifications 23's Android method channel, so a plugin
// upgrade that changes the wire (a renamed schedule mode, an action that stops opening the UI, a
// payload that no longer round-trips) fails here and not on a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  late Directory dir;

  setUp(() {
    calls.clear();
    dir = Directory.systemTemp.createTempSync('valence_fln');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'canScheduleExactNotifications' => false,
        'getNotificationChannels' => <Object?>[],
        _ => null,
      };
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    dir.deleteSync(recursive: true);
  });

  test('schedule sends an absolute UTC instant, the mode it was given and opening actions',
      () async {
    final platform = ValenceNotificationPlatform();
    expect(await platform.canExact(), isFalse);
    final at = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
    final details = await platform.details(
        directory: dir,
        id: 7,
        channel: 'valence_reminders',
        actionIds: const ['done', 'snooze'],
        group: 'daily');
    for (final mode in [
      AndroidScheduleMode.inexactAllowWhileIdle,
      AndroidScheduleMode.exactAllowWhileIdle,
    ]) {
      await platform.schedule(
          id: 7,
          title: 'Water the plants',
          body: 'Before noon',
          at: at,
          details: details,
          mode: mode,
          payload: jsonEncode({'valence': 'local-v1', 'payload': 'p'}));
    }
    final sent = calls.where((c) => c.method == 'zonedSchedule').toList();
    expect(sent, hasLength(2));
    final args = sent.first.arguments as Map;
    expect(args['id'], 7);
    expect(args['timeZoneName'], 'Etc/UTC');
    expect(
        DateTime.parse('${args['scheduledDateTime']}Z').millisecondsSinceEpoch,
        at ~/ 1000 * 1000);
    expect(jsonDecode(args['payload'] as String),
        {'valence': 'local-v1', 'payload': 'p'});
    expect(args.containsKey('matchDateTimeComponents'), isFalse);
    final specifics = args['platformSpecifics'] as Map;
    expect(specifics['scheduleMode'], 'inexactAllowWhileIdle');
    expect(((sent.last.arguments as Map)['platformSpecifics'] as Map)['scheduleMode'],
        'exactAllowWhileIdle');
    expect(specifics['channelId'], 'valence_reminders');
    expect(specifics['groupKey'], 'daily');
    final actions = (specifics['actions'] as List).cast<Map>();
    expect(actions.map((a) => a['id']), ['done', 'snooze']);
    expect(actions.every((a) => a['showsUserInterface'] == true), isTrue);
  });

  test('channels are created once and cancel names only its own id', () async {
    final platform = ValenceNotificationPlatform();
    await platform.channel(
        id: 'valence_reminders', name: 'Reminders', ifAbsent: true);
    await platform.cancel(7);
    expect(calls.map((c) => c.method),
        ['getNotificationChannels', 'createNotificationChannel', 'cancel']);
    expect((calls[1].arguments as Map)['id'], 'valence_reminders');
    expect(calls.last.arguments, {'id': 7, 'tag': null});
  });
}
