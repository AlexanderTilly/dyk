import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A query must ask for every column the code beneath it reads.
///
/// `loadTourStops` ranked narration by language — app language first, then
/// English — but its `hotspot_media` query selected only
/// `hotspot_id, media_type, storage_path`. So `a['lang']` was always null,
/// every row ranked as English, and the first audio file won whatever
/// language it happened to be in. A German walking a tour heard English
/// beside a hotspot that was translated perfectly well.
///
/// Nothing caught it: the ranking code was correct, the parity test proves
/// keys exist in four languages, and no test could see that the data never
/// arrived. This one reads the query itself.
void main() {
  test('every hotspot_media query that ranks by language asks for lang', () {
    final src =
        File('lib/services/dyk_repository.dart').readAsStringSync();

    // Each `.from('hotspot_media')` and the select that follows it.
    final offenders = <String>[];
    var from = src.indexOf("from('hotspot_media')");
    while (from >= 0) {
      // The select is the next one after this from, within the same query.
      final selStart = src.indexOf('.select(', from);
      final selEnd = src.indexOf(')', selStart);
      final select = src.substring(selStart, selEnd + 1);

      // A bare .select() takes every column and is therefore safe.
      final bare = RegExp(r"\.select\(\s*\)").hasMatch(select);
      if (!bare && !select.contains('lang')) {
        final line = '\n'.allMatches(src.substring(0, selStart)).length + 1;
        offenders.add('dyk_repository.dart:$line  $select');
      }
      from = src.indexOf("from('hotspot_media')", from + 1);
    }

    expect(offenders, isEmpty,
        reason: 'These select an explicit column list without lang, while the '
            'code below them ranks narration by language — so every row will '
            'read as English and the first file will win.\n'
            '${offenders.join('\n')}');
  });
}
