// PAWD data models — mirror the Supabase schema (migrations 0001–0005).

enum Species { dog, cat }

enum PetSex { male, female }

enum PurposeFlag { playdates, walking, friends, breeding }

enum VaccStatus { unknown, partial, up_to_date }

const purposeLabels = {
  PurposeFlag.playdates: 'Playdates',
  PurposeFlag.walking: 'Walking buddy',
  PurposeFlag.friends: 'Pet friends',
  PurposeFlag.breeding: 'Breeding',
};

const vaccLabels = {
  VaccStatus.unknown: 'Unknown',
  VaccStatus.partial: 'Partial',
  VaccStatus.up_to_date: 'Up to date',
};

T _enumFromString<T>(List<T> values, String? s, T fallback) {
  for (final v in values) {
    if (v.toString().split('.').last == s) return v;
  }
  return fallback;
}

String enumToString(Object e) => e.toString().split('.').last;

class Pet {
  final String id;
  final String ownerId;
  final String name;
  final Species species;
  final String breed;
  final PetSex sex;
  final String? dateOfBirth;
  final bool? neutered;
  final VaccStatus vaccination;
  final List<String> temperament;
  final int energyLevel;
  final String? bio;
  final List<PurposeFlag> purposes;
  final bool isActive;
  final List<PetPhoto> photos;

  Pet({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.species,
    required this.breed,
    required this.sex,
    this.dateOfBirth,
    this.neutered,
    required this.vaccination,
    required this.temperament,
    required this.energyLevel,
    this.bio,
    required this.purposes,
    required this.isActive,
    this.photos = const [],
  });

  factory Pet.fromJson(Map<String, dynamic> j) {
    final photosJson = (j['pet_photos'] as List?) ?? const [];
    final photos = photosJson
        .map((p) => PetPhoto.fromJson(p as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return Pet(
      id: j['id'] as String,
      ownerId: j['owner_id'] as String,
      name: j['name'] as String,
      species: _enumFromString(Species.values, j['species'] as String?, Species.dog),
      breed: (j['breed'] as String?) ?? 'Mixed/Unknown',
      sex: _enumFromString(PetSex.values, j['sex'] as String?, PetSex.male),
      dateOfBirth: j['date_of_birth'] as String?,
      neutered: j['neutered'] as bool?,
      vaccination: _enumFromString(VaccStatus.values, j['vaccination'] as String?, VaccStatus.unknown),
      temperament: ((j['temperament'] as List?) ?? const []).map((e) => e as String).toList(),
      energyLevel: (j['energy_level'] as int?) ?? 3,
      bio: j['bio'] as String?,
      purposes: ((j['purposes'] as List?) ?? const ['playdates'])
          .map((e) => _enumFromString(PurposeFlag.values, e as String, PurposeFlag.playdates))
          .toList(),
      isActive: (j['is_active'] as bool?) ?? true,
      photos: photos,
    );
  }
}

class PetPhoto {
  final String id;
  final String storagePath;
  final int position;
  PetPhoto({required this.id, required this.storagePath, required this.position});
  factory PetPhoto.fromJson(Map<String, dynamic> j) => PetPhoto(
        id: (j['id'] ?? '') as String,
        storagePath: j['storage_path'] as String,
        position: (j['position'] as int?) ?? 0,
      );
}

class DeckCard {
  final String petId;
  final String name;
  final Species species;
  final String breed;
  final PetSex sex;
  final int? ageMonths;
  final int energyLevel;
  final List<String> temperament;
  final String? bio;
  final List<PurposeFlag> purposes;
  final VaccStatus vaccination;
  final String ownerDisplayName;
  final double distanceKm;
  final String? primaryPhoto;

  DeckCard({
    required this.petId,
    required this.name,
    required this.species,
    required this.breed,
    required this.sex,
    this.ageMonths,
    required this.energyLevel,
    required this.temperament,
    this.bio,
    required this.purposes,
    required this.vaccination,
    required this.ownerDisplayName,
    required this.distanceKm,
    this.primaryPhoto,
  });

  factory DeckCard.fromJson(Map<String, dynamic> j) => DeckCard(
        petId: j['pet_id'] as String,
        name: j['name'] as String,
        species: _enumFromString(Species.values, j['species'] as String?, Species.dog),
        breed: (j['breed'] as String?) ?? 'Mixed/Unknown',
        sex: _enumFromString(PetSex.values, j['sex'] as String?, PetSex.male),
        ageMonths: (j['age_months'] as num?)?.toInt(),
        energyLevel: (j['energy_level'] as int?) ?? 3,
        temperament: ((j['temperament'] as List?) ?? const []).map((e) => e as String).toList(),
        bio: j['bio'] as String?,
        purposes: ((j['purposes'] as List?) ?? const [])
            .map((e) => _enumFromString(PurposeFlag.values, e as String, PurposeFlag.playdates))
            .toList(),
        vaccination: _enumFromString(VaccStatus.values, j['vaccination'] as String?, VaccStatus.unknown),
        ownerDisplayName: (j['owner_display_name'] as String?) ?? 'Owner',
        distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 1.0,
        primaryPhoto: j['primary_photo'] as String?,
      );

  String get ageLabel {
    if (ageMonths == null) return '';
    if (ageMonths! >= 12) return '${ageMonths! ~/ 12}y';
    return '${ageMonths}mo';
  }
}

class MatchRow {
  final String matchId;
  final DateTime matchedAt;
  final String myPet;
  final String otherPet;
  final String otherPetName;
  final String otherOwner;
  final String otherOwnerName;
  final String? otherPrimaryPhoto;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  MatchRow({
    required this.matchId,
    required this.matchedAt,
    required this.myPet,
    required this.otherPet,
    required this.otherPetName,
    required this.otherOwner,
    required this.otherOwnerName,
    this.otherPrimaryPhoto,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory MatchRow.fromJson(Map<String, dynamic> j) => MatchRow(
        matchId: j['match_id'] as String,
        matchedAt: DateTime.parse(j['matched_at'] as String),
        myPet: j['my_pet'] as String,
        otherPet: j['other_pet'] as String,
        otherPetName: j['other_pet_name'] as String,
        otherOwner: j['other_owner'] as String,
        otherOwnerName: (j['other_owner_name'] as String?) ?? 'Owner',
        otherPrimaryPhoto: j['other_primary_photo'] as String?,
        lastMessage: j['last_message'] as String?,
        lastMessageAt: j['last_message_at'] != null
            ? DateTime.parse(j['last_message_at'] as String)
            : null,
      );
}

class Message {
  final String id;
  final String matchId;
  final String senderId;
  final String? body;
  final String? imagePath;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.matchId,
    required this.senderId,
    this.body,
    this.imagePath,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        matchId: j['match_id'] as String,
        senderId: j['sender_id'] as String,
        body: j['body'] as String?,
        imagePath: j['image_path'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

enum ReportReason { fake_profile, welfare_concern, harassment, scam, spam }

const reportLabels = {
  ReportReason.fake_profile: 'Fake profile',
  ReportReason.welfare_concern: 'Animal welfare concern',
  ReportReason.harassment: 'Harassment',
  ReportReason.scam: 'Scam / pet sales',
  ReportReason.spam: 'Spam',
};
