import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The host's own screens (loading, error, update required) sit under whatever root the app chose:
// legacy MaterialApp, material_ui or Cupertino. Material and material_ui keep separate Theme and
// ScaffoldMessenger types, so a Material widget in the package ignores the app's theme under the other
// kind and throws on ScaffoldMessenger.of. The package therefore imports neither.
void main() {
  test('the package imports no design system', () {
    final offenders = [
      for (final f in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.dart') &&
            RegExp(
              r'''import\s+['"]package:(flutter/(material|cupertino)|material_ui)[./]''',
            ).hasMatch(f.readAsStringSync()))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
