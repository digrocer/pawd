import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models.dart';

class PetsScreen extends StatefulWidget {
  const PetsScreen({super.key});
  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  late Future<List<Pet>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.myPets();
  }

  Future<void> _refresh() async {
    setState(() => _future = Api.myPets());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Pets')),
      body: FutureBuilder<List<Pet>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: PawdColors.brand));
          }
          final pets = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Column(children: [
                      Text('🐶', style: TextStyle(fontSize: 46)),
                      SizedBox(height: 8),
                      Text('No pets yet', style: TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                for (final p in pets) _petTile(p),
                const SizedBox(height: 12),
                if (pets.length < 5)
                  FilledButton.icon(
                    onPressed: () => context.push('/pets/new').then((_) => _refresh()),
                    icon: const Icon(Icons.add),
                    label: const Text('Add a pet'),
                  )
                else
                  const Text('Free tier: up to 5 pets.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: PawdColors.inkSoft, fontSize: 13)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _petTile(Pet p) {
    final cover = p.photos.isNotEmpty ? p.photos.first.storagePath : null;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), side: const BorderSide(color: PawdColors.line)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: PawdColors.surface2,
          backgroundImage: cover != null
              ? CachedNetworkImageProvider(Config.publicUrl('pet-photos', cover))
              : null,
          child: cover == null
              ? Text(p.species == Species.dog ? '🐕' : '🐈', style: const TextStyle(fontSize: 22))
              : null,
        ),
        title: Row(children: [
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (!p.isActive) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: PawdColors.surface2, borderRadius: BorderRadius.circular(999)),
              child: const Text('Hidden', style: TextStyle(fontSize: 11, color: PawdColors.inkSoft)),
            ),
          ],
        ]),
        subtitle: Text(
          '${p.breed} · ${p.purposes.where((x) => x != PurposeFlag.breeding).map((x) => purposeLabels[x]).join(', ')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, color: PawdColors.inkSoft),
        onTap: () => context.push('/pets/${p.id}/edit').then((_) => _refresh()),
      ),
    );
  }
}
