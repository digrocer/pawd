import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/geo.dart';
import '../../core/theme.dart';
import '../pets/pet_form.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  bool _locating = false;
  bool _hasLocation = false;
  String _locLabel = '';
  bool _manual = false;
  int _step = 0; // 0 = owner, 1 = pet
  String? _error;

  @override
  void initState() {
    super.initState();
    Api.myOwner().then((o) {
      if (o != null && mounted) {
        final dn = o['display_name'] as String?;
        if (dn != null && dn != 'Pet Owner') _name.text = dn;
        if (o['area'] != null) _city.text = o['area'] as String;
        setState(() {});
      }
    });
  }

  Future<void> _useGps() async {
    setState(() { _locating = true; _error = null; });
    final r = await Geo.current();
    if (r == null) {
      setState(() { _locating = false; _manual = true; });
      return;
    }
    await Api.setLocation(r.lat, r.lng, country: r.country);
    if (r.city != null && _city.text.trim().isEmpty) _city.text = r.city!;
    setState(() {
      _locating = false;
      _hasLocation = true;
      _locLabel = '✓ ${r.city ?? 'Location set'}${r.country != null ? ' · ${r.country}' : ''}';
    });
  }

  Future<void> _useCity() async {
    final q = _city.text.trim();
    if (q.isEmpty) { setState(() => _error = 'Enter a city or area first.'); return; }
    setState(() { _locating = true; _error = null; });
    final r = await Geo.fromQuery(q);
    if (r == null) {
      setState(() { _locating = false; _error = "Couldn't find that place. Try a nearby city."; });
      return;
    }
    await Api.setLocation(r.lat, r.lng, country: r.country);
    setState(() {
      _locating = false;
      _hasLocation = true;
      _locLabel = '✓ ${r.city ?? q}${r.country != null ? ' · ${r.country}' : ''}';
    });
  }

  Future<void> _saveOwner() async {
    setState(() => _error = null);
    if (!_hasLocation) { setState(() => _error = 'Set your location to continue.'); return; }
    try {
      await Api.updateOwner(
        displayName: _name.text.trim().isEmpty ? 'Pet Owner' : _name.text.trim(),
        area: _city.text.trim().isEmpty ? null : _city.text.trim(),
        ageAttested: true,
      );
      setState(() => _step = 1);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to PAWD')),
      body: _step == 0 ? _ownerStep() : _petStep(),
    );
  }

  Widget _ownerStep() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Let's set up your account. Under a minute.",
            style: TextStyle(color: PawdColors.inkSoft)),
        const SizedBox(height: 16),
        _fieldLabel('Your name'),
        TextField(controller: _name, decoration: const InputDecoration(hintText: 'e.g. Ama')),
        const SizedBox(height: 16),

        _fieldLabel('Location'),
        const Text('Required — this powers nearby discovery. Your exact spot is never shown to others.',
            style: TextStyle(color: PawdColors.inkSoft, fontSize: 12)),
        const SizedBox(height: 8),
        if (_hasLocation)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: PawdColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12)),
            child: Text(_locLabel, style: const TextStyle(color: PawdColors.accent, fontWeight: FontWeight.w700)),
          )
        else
          FilledButton.icon(
            onPressed: _locating ? null : _useGps,
            icon: const Icon(Icons.my_location),
            label: Text(_locating ? 'Locating…' : 'Use my location'),
          ),

        if (_manual && !_hasLocation) ...[
          const SizedBox(height: 12),
          const Text('GPS unavailable — enter your city instead:',
              style: TextStyle(color: PawdColors.inkSoft, fontSize: 13)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(controller: _city, decoration: const InputDecoration(hintText: 'e.g. Newark, NJ'))),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _locating ? null : _useCity,
              style: FilledButton.styleFrom(minimumSize: const Size(72, 52)),
              child: const Text('Set'),
            ),
          ]),
        ],

        if (_hasLocation) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() { _hasLocation = false; _manual = true; }),
            child: const Text('Change location'),
          ),
        ],

        if (_error != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: PawdColors.danger))),
        const SizedBox(height: 20),
        FilledButton(onPressed: _hasLocation ? _saveOwner : null, child: const Text('Continue')),
        const SizedBox(height: 8),
        const Text('By continuing you attest you are 18 or older.',
            textAlign: TextAlign.center, style: TextStyle(color: PawdColors.inkSoft, fontSize: 12)),
      ],
    );
  }

  Widget _petStep() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add your first pet 🐾', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text('The pet is the profile. Make it shine.', style: TextStyle(color: PawdColors.inkSoft)),
            ],
          ),
        ),
        Expanded(child: PetForm(onSaved: (_) => context.go('/discover'))),
      ],
    );
  }

  Widget _fieldLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, color: PawdColors.inkSoft, fontSize: 13)),
      );
}
