import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/geo.dart';
import '../../core/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _area = TextEditingController();
  String _email = '';
  bool _loading = true;
  String _locMsg = '';

  @override
  void initState() {
    super.initState();
    _email = Api.auth.currentUser?.email ?? '';
    Api.myOwner().then((o) {
      if (o != null) {
        _name.text = (o['display_name'] as String?) ?? '';
        _area.text = (o['area'] as String?) ?? '';
      }
      setState(() => _loading = false);
    });
  }

  Future<void> _save() async {
    await Api.updateOwner(
      displayName: _name.text.trim().isEmpty ? 'Pet Owner' : _name.text.trim(),
      area: _area.text.trim().isEmpty ? null : _area.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved ✓')));
    }
  }

  Future<void> _updateLocation() async {
    setState(() => _locMsg = 'Getting location…');
    final r = await Geo.current();
    if (r == null) {
      setState(() => _locMsg = 'Location unavailable — grant permission or set your city in onboarding.');
      return;
    }
    await Api.setLocation(r.lat, r.lng, country: r.country);
    if (r.city != null) _area.text = r.city!;
    setState(() => _locMsg = '✓ Updated${r.country != null ? ' · ${r.country}' : ''}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: PawdColors.brand))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _lbl('Email'),
                TextField(controller: TextEditingController(text: _email), enabled: false),
                _lbl('Display name'),
                TextField(controller: _name),
                _lbl('Area'),
                TextField(controller: _area, decoration: const InputDecoration(hintText: 'e.g. Osu, Accra')),
                const SizedBox(height: 16),
                FilledButton(onPressed: _save, child: const Text('Save profile')),
                const SizedBox(height: 24),
                _lbl('Location'),
                OutlinedButton.icon(
                  onPressed: _updateLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Update my location'),
                ),
                if (_locMsg.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(_locMsg, style: const TextStyle(color: PawdColors.inkSoft, fontSize: 13))),
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: () async {
                    await Api.signOut();
                    if (mounted) context.go('/login');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PawdColors.danger,
                    side: BorderSide(color: PawdColors.danger.withValues(alpha: 0.4)),
                  ),
                  child: const Text('Sign out'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'PAWD v1.0 · Meet responsibly · Report concerns in-chat.\nYour exact location is never shown to others — only approximate distance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PawdColors.inkSoft, fontSize: 12),
                ),
              ],
            ),
    );
  }

  Widget _lbl(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, color: PawdColors.inkSoft, fontSize: 13)),
      );
}
