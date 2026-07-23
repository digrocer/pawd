import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models.dart';

class ChatScreen extends StatefulWidget {
  final String matchId;
  const ChatScreen({super.key, required this.matchId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  MatchRow? _match;
  bool _loading = true;
  bool _safetySeen = false;
  late final Stream<List<Message>> _stream;
  final _me = Api.uid;

  @override
  void initState() {
    super.initState();
    _stream = Api.messageStream(widget.matchId);
    Api.matches().then((all) {
      final matching = all.where((e) => e.matchId == widget.matchId).toList();
      setState(() {
        _match = matching.isEmpty ? null : matching.first;
        _loading = false;
        _safetySeen = false;
      });
    });
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    _text.clear();
    setState(() => _safetySeen = true);
    try {
      await Api.sendMessage(widget.matchId, body);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _block() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Block ${_match!.otherOwnerName}?'),
        content: const Text('This unmatches you and hides you from each other.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Block', style: TextStyle(color: PawdColors.danger))),
        ],
      ),
    );
    if (ok == true) {
      await Api.block(_match!.otherOwner);
      if (mounted) context.go('/matches');
    }
  }

  void _report() {
    showModalBottomSheet(
      context: context,
      backgroundColor: PawdColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Report — why?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          for (final r in ReportReason.values)
            ListTile(
              title: Text(reportLabels[r]!),
              onTap: () async {
                await Api.report(r, targetOwner: _match!.otherOwner, targetPet: _match!.otherPet);
                if (c.mounted) Navigator.pop(c);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Thanks — we review reports within 24h (2h for welfare/safety).')));
                }
              },
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: PawdColors.brand)));
    }
    if (_match == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Conversation not found.')),
      );
    }
    final m = _match!;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: PawdColors.surface2,
            backgroundImage: m.otherPrimaryPhoto != null
                ? CachedNetworkImageProvider(Config.publicUrl('pet-photos', m.otherPrimaryPhoto!))
                : null,
            child: m.otherPrimaryPhoto == null ? const Text('🐾') : null,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(m.otherPetName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text('with ${m.otherOwnerName}', style: const TextStyle(fontSize: 12, color: PawdColors.inkSoft)),
            ],
          ),
        ]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'report' ? _report() : _block(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('🚩 Report')),
              PopupMenuItem(value: 'block', child: Text('🚫 Block & unmatch', style: TextStyle(color: PawdColors.danger))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_safetySeen)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: PawdColors.surface2, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                  '🛡️ Meet safely. Always meet in a public place the first time, tell a friend where you\'re going, and never send money for a pet.',
                  style: TextStyle(color: PawdColors.inkSoft, fontSize: 13)),
            ),
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _stream,
              builder: (context, snap) {
                final msgs = snap.data ?? [];
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });
                if (msgs.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('👋', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 8),
                      Text('Say hi to ${m.otherOwnerName} and ${m.otherPetName}!',
                          style: const TextStyle(color: PawdColors.inkSoft)),
                    ]),
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final msg = msgs[i];
                    final mine = msg.senderId == _me;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                        decoration: BoxDecoration(
                          color: mine ? PawdColors.brand : PawdColors.surface2,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(mine ? 18 : 6),
                            bottomRight: Radius.circular(mine ? 6 : 18),
                          ),
                        ),
                        child: Text(msg.body ?? '',
                            style: TextStyle(color: mine ? Colors.white : PawdColors.ink, fontSize: 15)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: PawdColors.surface,
                border: Border(top: BorderSide(color: PawdColors.line)),
              ),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(hintText: 'Message…'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _text.text.trim().isEmpty ? null : _send,
                  style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
                  child: const Text('Send'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
