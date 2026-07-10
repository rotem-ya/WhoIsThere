import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whois_there/widgets/game/letter_bank_input.dart'
    show normalizeHebrewFinals;

// The proverbs catalog feeds the letter-bank guess input, whose slot cap for
// proverbs rooms is 24 — every baked answer must fit or it becomes unguessable.
const int kProverbsMaxAnswerLetters = 24;

void main() {
  final raw = File('assets/game_places/data/proverbs.json').readAsStringSync();
  final items = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

  test('proverbs catalog: unique proverbs_* ids, proverbs category', () {
    expect(items.length, greaterThanOrEqualTo(24));
    final ids = items.map((e) => e['id'] as String).toSet();
    expect(ids.length, items.length);
    for (final it in items) {
      expect(it['id'], startsWith('proverbs_'));
      expect(it['category'], 'proverbs');
      expect((it['name_he'] as String).trim(), isNotEmpty);
    }
  });

  test('every baked proverb image exists on disk', () {
    for (final it in items) {
      final asset = it['image_asset'] as String;
      expect(File(asset).existsSync(), isTrue, reason: 'missing $asset');
    }
  });

  test('every answer fits the proverbs letter-bank cap', () {
    for (final it in items) {
      final answer = (it['answer_he'] as String).trim();
      final n = normalizeHebrewFinals(answer).length;
      expect(n, greaterThanOrEqualTo(2), reason: '${it['id']}: "$answer"');
      expect(n, lessThanOrEqualTo(kProverbsMaxAnswerLetters),
          reason: '${it['id']}: "$answer" is $n letters');
    }
  });
}
