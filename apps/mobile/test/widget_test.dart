import 'package:flutter_test/flutter_test.dart';

import 'package:pawd/models.dart';

void main() {
  test('DeckCard parses distance and age label', () {
    final card = DeckCard.fromJson({
      'pet_id': 'p1',
      'name': 'Bruno',
      'species': 'dog',
      'breed': 'Boerboel',
      'sex': 'male',
      'age_months': 18,
      'energy_level': 4,
      'temperament': ['Gentle'],
      'bio': 'Big softie',
      'purposes': ['playdates', 'walking'],
      'vaccination': 'up_to_date',
      'owner_display_name': 'Ama',
      'distance_km': 1.0,
      'primary_photo': null,
    });
    expect(card.name, 'Bruno');
    expect(card.distanceKm, 1.0);
    expect(card.ageLabel, '1y');
    expect(card.purposes.contains(PurposeFlag.walking), true);
  });
}
