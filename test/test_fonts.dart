import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Load the app's real faces into a widget test.
///
/// `flutter_test`'s built-in font draws every glyph as a box roughly twice the
/// width of real text, which invents RenderFlex overflows that do not exist on
/// a phone — and, worse, hides real ones behind fake ones. Any test that
/// asserts anything about layout has to register the real fonts first.
Future<void> loadAppFonts() async {
  Future<void> reg(String family, List<String> files) async {
    final loader = FontLoader(family);
    var any = false;
    for (final f in files) {
      final file = File('assets/fonts/$f');
      if (!file.existsSync()) continue;
      any = true;
      loader.addFont(Future.value(
          ByteData.view(Uint8List.fromList(file.readAsBytesSync()).buffer)));
    }
    if (any) await loader.load();
  }

  await reg('Barlow', [
    'Barlow-Regular.ttf',
    'Barlow-Medium.ttf',
    'Barlow-SemiBold.ttf',
    'Barlow-Bold.ttf',
  ]);
  await reg('BarlowCondensed', [
    'BarlowCondensed-Medium.ttf',
    'BarlowCondensed-SemiBold.ttf',
    'BarlowCondensed-Bold.ttf',
  ]);
  // Anything that falls through to the default family still needs a real face.
  await reg('Roboto', ['Barlow-Regular.ttf']);
}
