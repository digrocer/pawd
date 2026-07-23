import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';

/// Thin data layer over Supabase — mirrors the web client's RPC usage.
class Api {
  static SupabaseClient get _db => Supabase.instance.client;
  static GoTrueClient get auth => _db.auth;
  static String? get uid => auth.currentUser?.id;

  // ── Auth ────────────────────────────────────────────────
  static Future<void> sendOtp(String email) =>
      auth.signInWithOtp(email: email, shouldCreateUser: true);

  static Future<void> verifyOtp(String email, String token) =>
      auth.verifyOTP(email: email, token: token, type: OtpType.email);

  static Future<void> signOut() => auth.signOut();

  // ── Owner ───────────────────────────────────────────────
  static Future<Map<String, dynamic>?> myOwner() async {
    final r = await _db.from('owners').select().eq('id', uid!).maybeSingle();
    return r;
  }

  static Future<void> updateOwner({
    String? displayName,
    String? area,
    bool? ageAttested,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName;
    if (area != null) data['area'] = area;
    if (ageAttested != null) data['age_attested'] = ageAttested;
    if (data.isEmpty) return;
    await _db.from('owners').update(data).eq('id', uid!);
  }

  static Future<void> setLocation(double lat, double lng, {String? country}) =>
      _db.rpc('set_my_location',
          params: {'p_lat': lat, 'p_lng': lng, if (country != null) 'p_country': country});

  // ── Pets ────────────────────────────────────────────────
  static Future<List<Pet>> myPets() async {
    final rows = await _db
        .from('pets')
        .select('*, pet_photos(id, storage_path, position)')
        .eq('owner_id', uid!)
        .order('created_at');
    return (rows as List).map((e) => Pet.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Pet?> getPet(String id) async {
    final r = await _db
        .from('pets')
        .select('*, pet_photos(id, storage_path, position)')
        .eq('id', id)
        .eq('owner_id', uid!)
        .maybeSingle();
    return r == null ? null : Pet.fromJson(r);
  }

  static Future<String> createPet(Map<String, dynamic> payload) async {
    final r = await _db.from('pets').insert(payload).select('id').single();
    return r['id'] as String;
  }

  static Future<void> updatePet(String id, Map<String, dynamic> payload) =>
      _db.from('pets').update(payload).eq('id', id);

  static Future<void> deletePet(String id) => _db.from('pets').delete().eq('id', id);

  static Future<void> setPetActive(String id, bool active) =>
      _db.from('pets').update({'is_active': active}).eq('id', id);

  // ── Photos ──────────────────────────────────────────────
  static Future<String> uploadPetPhoto(
      String petId, Uint8List bytes, String ext) async {
    final path = '$uid/$petId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from('pet-photos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
        );
    return path;
  }

  static Future<void> addPhotoRow(String petId, String path, int position) =>
      _db.from('pet_photos').insert(
          {'pet_id': petId, 'storage_path': path, 'position': position, 'approved': true});

  static Future<void> deletePhoto(String id, String path) async {
    await _db.from('pet_photos').delete().eq('id', id);
    await _db.storage.from('pet-photos').remove([path]);
  }

  // ── Discovery ───────────────────────────────────────────
  static Future<List<DeckCard>> deck({
    required String viewerPet,
    double radiusKm = 25,
    Species? species,
    PetSex? sex,
    bool vaccinatedOnly = false,
  }) async {
    final res = await _db.rpc('discovery_deck', params: {
      'p_viewer_pet': viewerPet,
      'p_radius_km': radiusKm,
      'p_species': species == null ? null : enumToString(species),
      'p_sex': sex == null ? null : enumToString(sex),
      'p_vaccinated_only': vaccinatedOnly,
      'p_limit': 30,
    });
    return (res as List).map((e) => DeckCard.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Returns {ok, matched?, error?}.
  static Future<Map<String, dynamic>> swipe(
      String swiperPet, String targetPet, String direction) async {
    final res = await _db.rpc('record_swipe', params: {
      'p_swiper_pet': swiperPet,
      'p_target_pet': targetPet,
      'p_direction': direction,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  // ── Matches & chat ──────────────────────────────────────
  static Future<List<MatchRow>> matches() async {
    final res = await _db.rpc('my_matches');
    return (res as List).map((e) => MatchRow.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Stream<List<Message>> messageStream(String matchId) {
    return _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('match_id', matchId)
        .order('created_at')
        .map((rows) => rows.map((e) => Message.fromJson(e)).toList());
  }

  static Future<void> sendMessage(String matchId, String body) =>
      _db.from('messages').insert({'match_id': matchId, 'sender_id': uid, 'body': body});

  // ── Safety ──────────────────────────────────────────────
  static Future<void> block(String blockedOwner) =>
      _db.rpc('block_owner', params: {'p_blocked': blockedOwner});

  static Future<void> report(ReportReason reason,
          {String? targetOwner, String? targetPet}) =>
      _db.from('reports').insert({
        'reporter_id': uid,
        'target_owner': targetOwner,
        'target_pet': targetPet,
        'reason': enumToString(reason),
      });
}
