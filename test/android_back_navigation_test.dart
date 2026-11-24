import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guomu/hg/theme/hg_theme.dart';

void main() {
  test(
    'Android uses the stable back path instead of predictive back',
    () async {
      final manifest = await File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsString();
      expect(manifest, contains('android:enableOnBackInvokedCallback="false"'));
      expect(
        manifest,
        isNot(contains('android:enableOnBackInvokedCallback="true"')),
      );

      final theme = buildHgTheme(Brightness.light);
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<FadeForwardsPageTransitionsBuilder>(),
      );
    },
  );
}
