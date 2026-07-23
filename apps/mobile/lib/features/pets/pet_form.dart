import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models.dart';

const _temperaments = [
  'Friendly', 'Shy', 'Playful', 'Calm', 'Energetic', 'Protective', 'Curious', 'Gentle',
];

class PetForm extends StatefulWidget {
  final Pet? existing;
  final void Function(String petId) onSaved;
  const PetForm({super.key, this.existing, required this.onSaved});

  @override
  State<PetForm> createState() => _PetFormState();
}

class _PickedPhoto {
  final Uint8List bytes;
  final String ext;
  _PickedPhoto(this.bytes, this.ext);
}

class _PetFormState extends State<PetForm> {
  final _name = TextEditingController();
  final _breed = TextEditingController(text: 'Mixed/Unknown');
  final _bio = TextEditingController();
  Species _species = Species.dog;
  PetSex _sex = PetSex.male;
  DateTime? _dob;
  bool? _neutered;
  VaccStatus _vacc = VaccStatus.unknown;
  int _energy = 3;
  final Set<String> _temperament = {};
  final Set<PurposeFlag> _purposes = {PurposeFlag.playdates};

  List<PetPhoto> _existingPhotos = [];
  final List<_PickedPhoto> _newPhotos = [];
  bool _saving = false;
  String? _error;

  int get _totalPhotos => _existingPhotos.length + _newPhotos.length;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _breed.text = e.breed;
      _bio.text = e.bio ?? '';
      _species = e.species;
      _sex = e.sex;
      _dob = e.dateOfBirth != null ? DateTime.tryParse(e.dateOfBirth!) : null;
      _neutered = e.neutered;
      _vacc = e.vaccination;
      _energy = e.energyLevel;
      _temperament.addAll(e.temperament);
      _purposes
        ..clear()
        ..addAll(e.purposes);
      _existingPhotos = List.of(e.photos);
    }
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 75, limit: 6 - _totalPhotos);
    for (final f in files) {
      if (_totalPhotos >= 6) break;
      final bytes = await f.readAsBytes();
      final ext = f.name.contains('.') ? f.name.split('.').last.toLowerCase() : 'jpg';
      _newPhotos.add(_PickedPhoto(bytes, ext == 'jpg' ? 'jpeg' : ext));
    }
    setState(() {});
  }

  Future<void> _removeExisting(PetPhoto p) async {
    setState(() => _existingPhotos.remove(p));
    await Api.deletePhoto(p.id, p.storagePath);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (_purposes.isEmpty) return setState(() => _error = 'Pick at least one purpose.');
    if (_totalPhotos == 0) return setState(() => _error = 'Add at least one photo.');
    setState(() => _saving = true);
    try {
      final payload = {
        'owner_id': Api.uid,
        'name': _name.text.trim(),
        'species': enumToString(_species),
        'breed': _breed.text.trim().isEmpty ? 'Mixed/Unknown' : _breed.text.trim(),
        'sex': enumToString(_sex),
        'date_of_birth': _dob?.toIso8601String().split('T').first,
        'neutered': _neutered,
        'vaccination': enumToString(_vacc),
        'energy_level': _energy,
        'bio': _bio.text.trim().isEmpty ? null : _bio.text.trim(),
        'temperament': _temperament.take(5).toList(),
        'purposes': _purposes.map(enumToString).toList(),
      };

      String petId;
      if (widget.existing != null) {
        petId = widget.existing!.id;
        await Api.updatePet(petId, payload);
      } else {
        petId = await Api.createPet(payload);
      }

      var pos = _existingPhotos.length;
      for (final p in _newPhotos) {
        final path = await Api.uploadPetPhoto(petId, p.bytes, p.ext);
        await Api.addPhotoRow(petId, path, pos++);
      }
      widget.onSaved(petId);
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null) ...[
          _banner(_error!),
          const SizedBox(height: 12),
        ],
        _label('Photos (${_totalPhotos}/6) — first is the cover'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in _existingPhotos)
              _photoTile(
                CachedNetworkImageProvider(Config.publicUrl('pet-photos', p.storagePath)),
                () => _removeExisting(p),
              ),
            for (final p in _newPhotos)
              _photoTile(MemoryImage(p.bytes), () => setState(() => _newPhotos.remove(p))),
            if (_totalPhotos < 6) _addTile(),
          ],
        ),
        const SizedBox(height: 16),
        _label('Name'),
        TextField(controller: _name, maxLength: 60),
        _label('Species'),
        _seg<Species>(Species.values, _species, (v) => setState(() => _species = v),
            (v) => v == Species.dog ? '🐕 Dog' : '🐈 Cat'),
        const SizedBox(height: 12),
        _label('Breed'),
        TextField(controller: _breed, decoration: const InputDecoration(hintText: 'e.g. Golden Retriever')),
        const SizedBox(height: 12),
        _label('Sex'),
        _seg<PetSex>(PetSex.values, _sex, (v) => setState(() => _sex = v),
            (v) => v == PetSex.male ? '♂ Male' : '♀ Female'),
        const SizedBox(height: 12),
        _label('Date of birth'),
        OutlinedButton(
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _dob ?? DateTime(DateTime.now().year - 2),
              firstDate: DateTime(2005),
              lastDate: DateTime.now(),
            );
            if (d != null) setState(() => _dob = d);
          },
          child: Text(_dob == null ? 'Select date' : _dob!.toIso8601String().split('T').first),
        ),
        const SizedBox(height: 12),
        _label('Neutered / spayed'),
        _seg<bool?>(const [true, false, null], _neutered, (v) => setState(() => _neutered = v),
            (v) => v == true ? 'Yes' : v == false ? 'No' : 'Unsure'),
        const SizedBox(height: 12),
        _label('Vaccination (self-declared)'),
        _seg<VaccStatus>(VaccStatus.values, _vacc, (v) => setState(() => _vacc = v),
            (v) => vaccLabels[v]!),
        const SizedBox(height: 12),
        _label('Energy level: $_energy/5'),
        Slider(
          value: _energy.toDouble(),
          min: 1, max: 5, divisions: 4,
          activeColor: PawdColors.brand,
          label: '$_energy',
          onChanged: (v) => setState(() => _energy = v.round()),
        ),
        _label('Temperament (max 5)'),
        _chips(_temperaments, _temperament.contains, (t) {
          setState(() {
            if (_temperament.contains(t)) {
              _temperament.remove(t);
            } else if (_temperament.length < 5) {
              _temperament.add(t);
            }
          });
        }),
        const SizedBox(height: 12),
        _label('Looking for'),
        _chips(
          PurposeFlag.values.map((p) => purposeLabels[p]!).toList(),
          (label) {
            final p = PurposeFlag.values.firstWhere((e) => purposeLabels[e] == label);
            return _purposes.contains(p);
          },
          (label) {
            final p = PurposeFlag.values.firstWhere((e) => purposeLabels[e] == label);
            if (p == PurposeFlag.breeding) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Breeding matching unlocks in v1.1 (needs verification).')));
              return;
            }
            setState(() {
              _purposes.contains(p) ? _purposes.remove(p) : _purposes.add(p);
            });
          },
          disabledLabel: purposeLabels[PurposeFlag.breeding],
        ),
        const SizedBox(height: 12),
        _label('Short bio (${_bio.text.length}/280)'),
        TextField(
          controller: _bio,
          maxLength: 280,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(hintText: 'Loves fetch, hates the vacuum…'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving
              ? 'Saving…'
              : widget.existing != null
                  ? 'Save changes'
                  : 'Create pet profile'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, color: PawdColors.inkSoft, fontSize: 13)),
      );

  Widget _banner(String t) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: PawdColors.danger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12)),
        child: Text(t, style: const TextStyle(color: PawdColors.danger)),
      );

  Widget _seg<T>(List<T> values, T selected, void Function(T) onTap, String Function(T) label) {
    return Row(
      children: [
        for (final v in values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onTap(v),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v == selected ? PawdColors.brandSoft : PawdColors.surface,
                  border: Border.all(color: v == selected ? PawdColors.brand : PawdColors.line),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(label(v),
                    style: TextStyle(
                        color: v == selected ? PawdColors.brand : PawdColors.inkSoft,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          if (v != values.last) const SizedBox(width: 8),
        ]
      ],
    );
  }

  Widget _chips(List<String> items, bool Function(String) isOn, void Function(String) onTap,
      {String? disabledLabel}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in items)
          GestureDetector(
            onTap: () => onTap(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isOn(t) ? PawdColors.brandSoft : PawdColors.surface,
                border: Border.all(color: isOn(t) ? PawdColors.brand : PawdColors.line),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(t == disabledLabel ? '$t 🔒' : t,
                  style: TextStyle(
                      color: t == disabledLabel
                          ? PawdColors.inkSoft.withValues(alpha: 0.5)
                          : isOn(t)
                              ? PawdColors.brand
                              : PawdColors.inkSoft,
                      fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  Widget _photoTile(ImageProvider img, VoidCallback onRemove) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image(image: img, fit: BoxFit.cover),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addTile() => GestureDetector(
        onTap: _pick,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: PawdColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PawdColors.line, style: BorderStyle.solid),
          ),
          child: const Icon(Icons.add, color: PawdColors.inkSoft, size: 28),
        ),
      );
}
