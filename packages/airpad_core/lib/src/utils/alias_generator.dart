import 'dart:math';

/// Generates friendly, human-readable two-word aliases (e.g. "Quiet Falcon").
abstract final class AliasGenerator {
  static const List<String> _adjectives = [
    'Quiet',
    'Swift',
    'Calm',
    'Clever',
    'Bright',
    'Brave',
    'Gentle',
    'Silent',
    'Silver',
    'Golden',
    'Warm',
    'Cool',
    'Bold',
    'Noble',
    'Wise',
    'Keen',
    'Serene',
    'Nimble',
    'Patient',
    'Vivid',
    'Sturdy',
    'Mellow',
    'Radiant',
    'Cosmic',
  ];

  static const List<String> _nouns = [
    'Falcon',
    'Otter',
    'Cedar',
    'Pine',
    'Fox',
    'Hawk',
    'Eagle',
    'Badger',
    'Lynx',
    'Raven',
    'Panda',
    'Wolf',
    'Willow',
    'Orchid',
    'Comet',
    'River',
    'Meadow',
    'Harbor',
    'Canyon',
    'Summit',
    'Sparrow',
    'Breeze',
    'Glacier',
    'Echo',
  ];

  static final Random _random = Random();

  /// Generates a random friendly alias like "Quiet Falcon".
  static String generate([Random? customRandom]) {
    final rng = customRandom ?? _random;
    final adj = _adjectives[rng.nextInt(_adjectives.length)];
    final noun = _nouns[rng.nextInt(_nouns.length)];
    return '$adj $noun';
  }
}
