import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});
  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  late Future<List<MatchRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = Api.matches();
  }

  Future<void> _refresh() async {
    setState(() => _future = Api.matches());
    await _future;
  }

  String _ago(DateTime? d) {
    if (d == null) return '';
    final s = DateTime.now().difference(d).inSeconds;
    if (s < 60) return 'now';
    if (s < 3600) return '${s ~/ 60}m';
    if (s < 86400) return '${s ~/ 3600}h';
    return '${s ~/ 86400}d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: FutureBuilder<List<MatchRow>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: PawdColors.brand));
          }
          final matches = snap.data!;
          if (matches.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(children: [
                const SizedBox(height: 100),
                const Center(
                  child: Column(children: [
                    Text('💛', style: TextStyle(fontSize: 46)),
                    SizedBox(height: 8),
                    Text('No matches yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text('Head to Discover and start liking pets. When it\'s mutual they show up here.',
                          textAlign: TextAlign.center, style: TextStyle(color: PawdColors.inkSoft)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Center(
                  child: FilledButton(
                    onPressed: () => context.go('/discover'),
                    child: const Text('Go to Discover'),
                  ),
                ),
              ]),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: matches.length,
              itemBuilder: (context, i) {
                final m = matches[i];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: PawdColors.line)),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: PawdColors.surface2,
                      backgroundImage: m.otherPrimaryPhoto != null
                          ? CachedNetworkImageProvider(Config.publicUrl('pet-photos', m.otherPrimaryPhoto!))
                          : null,
                      child: m.otherPrimaryPhoto == null ? const Text('🐾', style: TextStyle(fontSize: 22)) : null,
                    ),
                    title: Text(m.otherPetName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      m.lastMessage ?? 'Matched with ${m.otherOwnerName} · say hi 👋',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(_ago(m.lastMessageAt ?? m.matchedAt),
                        style: const TextStyle(color: PawdColors.inkSoft, fontSize: 12)),
                    onTap: () => context.push('/chat/${m.matchId}').then((_) => _refresh()),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
